"""Tenant-scoped production batch lifecycle commands.

Commands append immutable batch events and update the status projection in the
caller's transaction. Callers remain responsible for authorization and commit /
rollback; this service enforces tenant context, module entitlement, transitions,
domain preconditions and request idempotency.
"""
from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session


class ProductionLifecycleError(Exception):
    """A production batch lifecycle command is invalid."""


class ProductionLifecyclePermissionDenied(PermissionError):
    """The production module is not enabled or database access is denied."""


@dataclass(frozen=True, slots=True)
class BatchTransitionResult:
    batch_id: UUID
    event_id: UUID
    from_status: str
    to_status: str
    command: str
    was_replayed: bool = False


def _set_context(session: Session, actor_user_id: UUID, tenant_id: UUID) -> None:
    session.execute(
        text("SELECT set_config('app.user_id', :user_id, true)"),
        {"user_id": str(actor_user_id)},
    )
    session.execute(
        text("SELECT set_config('app.tenant_id', :tenant_id, true)"),
        {"tenant_id": str(tenant_id)},
    )


def _require_production_module(session: Session, tenant_id: UUID) -> None:
    enabled = session.execute(
        text(
            """
            SELECT tm.status
              FROM tenant_modules AS tm
              JOIN modules AS m ON m.id=tm.module_id
             WHERE tm.tenant_id=:tenant_id AND m.code='production'
            """
        ),
        {"tenant_id": str(tenant_id)},
    ).scalar_one_or_none()
    if enabled != "enabled":
        raise ProductionLifecyclePermissionDenied(
            "The production module is not enabled for this tenant."
        )


def _request_hash(command: str, notes: str | None) -> str:
    payload = json.dumps(
        {"command": command, "notes": notes},
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _exists(session: Session, statement: str, params: dict[str, Any]) -> bool:
    return bool(session.execute(text(statement), params).scalar_one())


def _guard_transition(
    session: Session,
    *,
    tenant_id: UUID,
    batch_id: UUID,
    command: str,
    current_status: str,
) -> tuple[str, dict[str, Any]]:
    """Return target status and immutable event metadata after stage checks."""
    metadata: dict[str, Any] = {"command": command}

    if command == "plan_batch":
        if current_status != "draft":
            raise ProductionLifecycleError("Only a draft batch can be planned.")
        valid_recipe = _exists(
            session,
            """
            SELECT EXISTS (
                SELECT 1
                  FROM production_batches b
                  JOIN recipe_versions rv
                    ON rv.tenant_id=b.tenant_id AND rv.id=b.recipe_version_id
                  JOIN recipes r
                    ON r.tenant_id=rv.tenant_id AND r.id=rv.recipe_id
                 WHERE b.tenant_id=:tenant_id AND b.id=:batch_id
                   AND rv.status='active' AND r.is_active
            )
            """,
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        )
        if not valid_recipe:
            raise ProductionLifecycleError("Planning requires an active recipe and recipe version.")
        return "planned", metadata

    if command == "start_mixing":
        if current_status != "planned":
            raise ProductionLifecycleError("Only a planned batch can start mixing.")
        return "mixing", metadata

    if command == "complete_mixing":
        if current_status != "mixing":
            raise ProductionLifecycleError("Only a mixing batch can complete mixing.")
        consumed = _exists(
            session,
            """
            SELECT EXISTS (
                SELECT 1 FROM production_batch_consumptions
                 WHERE tenant_id=:tenant_id AND batch_id=:batch_id
            )
            """,
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        )
        if not consumed:
            raise ProductionLifecycleError(
                "Mixing cannot complete before actual material consumption is posted."
            )
        return "press_baglog", metadata

    if command == "complete_press":
        if current_status != "press_baglog":
            raise ProductionLifecycleError("Only a batch in press_baglog can complete pressing.")
        has_good_output = _exists(
            session,
            """
            SELECT EXISTS (
                SELECT 1 FROM production_press_outputs
                 WHERE tenant_id=:tenant_id AND batch_id=:batch_id
                   AND good_quantity > 0
            )
            """,
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        )
        if not has_good_output:
            raise ProductionLifecycleError("Press completion requires a recorded good output quantity.")
        return "sterilization", metadata

    if command == "start_inoculation":
        if current_status != "sterilization":
            raise ProductionLifecycleError("Only a sterilization batch can enter inoculation.")
        run_state = session.execute(
            text(
                """
                SELECT count(*) AS total_runs,
                       count(*) FILTER (
                           WHERE sr.status='completed'
                             AND sc.cooling_completed_at IS NOT NULL
                             AND sc.cooling_completed_at <= now()
                       ) AS ready_runs
                  FROM sterilization_run_batches rb
                  JOIN sterilization_runs sr
                    ON sr.tenant_id=rb.tenant_id AND sr.id=rb.sterilization_run_id
                  JOIN sterilization_cycles sc
                    ON sc.tenant_id=sr.tenant_id AND sc.id=sr.cycle_id
                 WHERE rb.tenant_id=:tenant_id AND rb.batch_id=:batch_id
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).mappings().one()
        if int(run_state["total_runs"]) == 0 or int(run_state["ready_runs"]) != int(
            run_state["total_runs"]
        ):
            raise ProductionLifecycleError(
                "Inoculation requires every allocated sterilization run to be completed and cooled."
            )
        return "inoculation", metadata

    if command == "complete_inoculation":
        if current_status != "inoculation":
            raise ProductionLifecycleError("Only an inoculation batch can complete inoculation.")
        has_completed_allocation = _exists(
            session,
            """
            SELECT EXISTS (
                SELECT 1
                  FROM inoculation_allocations a
                  JOIN inoculation_runs r
                    ON r.tenant_id=a.tenant_id AND r.id=a.inoculation_run_id
                 WHERE a.tenant_id=:tenant_id AND a.batch_id=:batch_id
                   AND r.status='completed'
            )
            """,
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        )
        if not has_completed_allocation:
            raise ProductionLifecycleError(
                "Inoculation completion requires at least one completed variety allocation."
            )
        has_incubation = _exists(
            session,
            """
            SELECT EXISTS (
                SELECT 1 FROM incubation_records
                 WHERE tenant_id=:tenant_id AND batch_id=:batch_id
                   AND status='incubating'
            )
            """,
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        )
        if not has_incubation:
            raise ProductionLifecycleError(
                "Inoculation completion requires an incubation record to be started."
            )
        return "incubation", metadata

    if command == "mark_ready_for_kumbung":
        if current_status != "incubation":
            raise ProductionLifecycleError("Only an incubating batch can be marked ready.")
        ready_record = _exists(
            session,
            """
            SELECT EXISTS (
                SELECT 1 FROM incubation_records
                 WHERE tenant_id=:tenant_id AND batch_id=:batch_id
                   AND status='ready_to_move' AND expected_move_at <= now()
            )
            """,
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        )
        if not ready_record:
            raise ProductionLifecycleError(
                "Incubation target time must be reached and the record marked ready_to_move."
            )
        return "ready", metadata

    if command == "hold_batch":
        if current_status in {"draft", "on_hold", "closed", "cancelled"}:
            raise ProductionLifecycleError("This batch status cannot be placed on hold.")
        metadata["previous_status"] = current_status
        return "on_hold", metadata

    if command == "resume_batch":
        if current_status != "on_hold":
            raise ProductionLifecycleError("Only an on-hold batch can be resumed.")
        previous = session.execute(
            text(
                """
                SELECT metadata->>'previous_status'
                  FROM production_batch_events
                 WHERE tenant_id=:tenant_id AND batch_id=:batch_id
                   AND event_type='hold_batch' AND to_status='on_hold'
                 ORDER BY occurred_at DESC, id DESC
                 LIMIT 1
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).scalar_one_or_none()
        resumable = {
            "planned", "mixing", "press_baglog", "sterilization",
            "inoculation", "incubation", "ready",
        }
        if previous not in resumable:
            raise ProductionLifecycleError("The batch's previous operational status cannot be resolved.")
        metadata["resumed_status"] = previous
        return str(previous), metadata

    if command == "cancel_batch":
        if current_status not in {"draft", "planned"}:
            raise ProductionLifecycleError("Only a draft or planned batch can be cancelled.")
        irreversible = _exists(
            session,
            """
            SELECT (
                EXISTS (SELECT 1 FROM production_batch_consumptions
                         WHERE tenant_id=:tenant_id AND batch_id=:batch_id)
                OR EXISTS (SELECT 1 FROM production_press_outputs
                            WHERE tenant_id=:tenant_id AND batch_id=:batch_id)
                OR EXISTS (SELECT 1 FROM sterilization_run_batches
                            WHERE tenant_id=:tenant_id AND batch_id=:batch_id)
                OR EXISTS (SELECT 1 FROM inoculation_allocations
                            WHERE tenant_id=:tenant_id AND batch_id=:batch_id)
                OR EXISTS (SELECT 1 FROM production_losses
                            WHERE tenant_id=:tenant_id AND batch_id=:batch_id)
                OR EXISTS (
                    SELECT 1 FROM production_lots pl
                    JOIN kumbung_placements kp
                      ON kp.tenant_id=pl.tenant_id AND kp.production_lot_id=pl.id
                     WHERE pl.tenant_id=:tenant_id AND pl.batch_id=:batch_id
                )
                OR EXISTS (
                    SELECT 1 FROM production_losses l
                    JOIN production_recovery_lots r
                      ON r.tenant_id=l.tenant_id AND r.loss_id=l.id
                     WHERE l.tenant_id=:tenant_id AND l.batch_id=:batch_id
                )
            )
            """,
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        )
        if irreversible:
            raise ProductionLifecycleError(
                "Cancellation is blocked after material, press, sterilization, inoculation, loss, placement or recovery posting."
            )
        return "cancelled", metadata

    if command == "reconcile_and_close":
        raise ProductionLifecycleError(
            "Batch closure is reserved for the M10.1.8 reconciliation workflow."
        )
    raise ProductionLifecycleError("Unsupported production batch command.")


def transition_production_batch(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    batch_id: UUID,
    command: str,
    idempotency_key: str,
    notes: str | None = None,
) -> BatchTransitionResult:
    """Apply one guarded lifecycle command atomically in the caller's transaction.

    An exact retry (same batch, key, command and notes) returns its original
    event. Reusing a key with a different request is rejected. A row lock
    serializes competing commands for the same batch.
    """
    key = idempotency_key.strip()
    if not key or len(key) > 120:
        raise ProductionLifecycleError("A non-empty idempotency key of at most 120 characters is required.")
    normalized_notes = notes.strip() if notes and notes.strip() else None
    request_hash = _request_hash(command, normalized_notes)
    _set_context(session, actor_user_id, tenant_id)
    _require_production_module(session, tenant_id)

    try:
        batch = session.execute(
            text(
                """
                SELECT id, status
                  FROM production_batches
                 WHERE tenant_id=:tenant_id AND id=:batch_id
                 FOR UPDATE
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).mappings().one_or_none()
        if batch is None:
            raise ProductionLifecycleError("Production batch was not found.")

        prior = session.execute(
            text(
                """
                SELECT id, event_type, request_hash, from_status, to_status
                  FROM production_batch_events
                 WHERE tenant_id=:tenant_id AND batch_id=:batch_id
                   AND idempotency_key=:idempotency_key
                """
            ),
            {
                "tenant_id": str(tenant_id),
                "batch_id": str(batch_id),
                "idempotency_key": key,
            },
        ).mappings().one_or_none()
        if prior is not None:
            if prior["event_type"] != command or prior["request_hash"] != request_hash:
                raise ProductionLifecycleError(
                    "This idempotency key has already been used for a different request."
                )
            return BatchTransitionResult(
                UUID(str(batch_id)),
                UUID(str(prior["id"])),
                str(prior["from_status"]),
                str(prior["to_status"]),
                command,
                True,
            )

        current_status = str(batch["status"])
        target_status, metadata = _guard_transition(
            session,
            tenant_id=tenant_id,
            batch_id=batch_id,
            command=command,
            current_status=current_status,
        )
        updated = session.execute(
            text(
                """
                UPDATE production_batches
                   SET status=:target_status,
                       started_at=CASE
                           WHEN :command='start_mixing' THEN COALESCE(started_at, now())
                           ELSE started_at
                       END,
                       updated_at=now()
                 WHERE tenant_id=:tenant_id AND id=:batch_id
                """
            ),
            {
                "target_status": target_status,
                "command": command,
                "tenant_id": str(tenant_id),
                "batch_id": str(batch_id),
            },
        )
        if updated.rowcount != 1:
            raise ProductionLifecycleError("Production batch status could not be updated.")

        event = session.execute(
            text(
                """
                INSERT INTO production_batch_events(
                    tenant_id, batch_id, event_type, from_status, to_status,
                    occurred_at, actor_user_id, notes, metadata,
                    idempotency_key, request_hash
                ) VALUES (
                    :tenant_id, :batch_id, :command, :from_status, :to_status,
                    now(), :actor_user_id, :notes, CAST(:metadata AS jsonb),
                    :idempotency_key, :request_hash
                )
                RETURNING id
                """
            ),
            {
                "tenant_id": str(tenant_id),
                "batch_id": str(batch_id),
                "command": command,
                "from_status": current_status,
                "to_status": target_status,
                "actor_user_id": str(actor_user_id),
                "notes": normalized_notes,
                "metadata": json.dumps(metadata, ensure_ascii=False, sort_keys=True),
                "idempotency_key": key,
                "request_hash": request_hash,
            },
        ).scalar_one()

        session.execute(
            text(
                """
                INSERT INTO tenant_audit_events(
                    tenant_id, actor_user_id, action, entity_type, entity_id,
                    before_data, after_data, metadata
                ) VALUES (
                    :tenant_id, :actor_user_id, 'production.batch.transition',
                    'production_batch', :batch_id,
                    jsonb_build_object('status', :from_status),
                    jsonb_build_object('status', :to_status, 'event_id', CAST(:event_id AS uuid)),
                    jsonb_build_object('command', :command, 'idempotency_key', :idempotency_key)
                )
                """
            ),
            {
                "tenant_id": str(tenant_id),
                "actor_user_id": str(actor_user_id),
                "batch_id": str(batch_id),
                "from_status": current_status,
                "to_status": target_status,
                "event_id": str(event),
                "command": command,
                "idempotency_key": key,
            },
        )
    except DBAPIError as exc:
        state = getattr(exc.orig, "sqlstate", getattr(exc.orig, "pgcode", None))
        if state == "42501":
            raise ProductionLifecyclePermissionDenied(
                "Production lifecycle permission is required."
            ) from None
        if state in {"23502", "23503", "23505", "23514", "22023", "P0002", "55000"}:
            raise ProductionLifecycleError(
                "The production lifecycle command violates a database invariant."
            ) from None
        raise

    return BatchTransitionResult(
        UUID(str(batch_id)),
        UUID(str(event)),
        current_status,
        target_status,
        command,
        False,
    )

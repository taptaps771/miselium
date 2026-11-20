"""Tenant-scoped inoculation allocation and incubation hand-off.

Callers authorize tenant membership/permissions and own transaction
commit/rollback. This service snapshots allocation inputs and relies on
database guards plus advisory locks for cross-request capacity safety.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from typing import Sequence
from uuid import UUID, uuid4

from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session


class InoculationError(Exception):
    """An inoculation allocation or incubation precondition failed."""


class InoculationPermissionDenied(PermissionError):
    """The production module is not enabled or database access is denied."""


@dataclass(frozen=True, slots=True)
class VarietyAllocation:
    batch_id: UUID
    variety_id: UUID
    quantity: Decimal
    unit_id: UUID
    seed_lot_id: UUID | None = None


@dataclass(frozen=True, slots=True)
class InoculationRunResult:
    run_id: UUID
    run_code: str
    allocation_count: int
    was_replayed: bool = False


@dataclass(frozen=True, slots=True)
class IncubationRecordResult:
    record_id: UUID
    batch_id: UUID
    started_at: datetime
    expected_move_at: datetime
    target_days: int


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
              FROM tenant_modules tm
              JOIN modules m ON m.id=tm.module_id
             WHERE tm.tenant_id=:tenant_id AND m.code='production'
            """
        ),
        {"tenant_id": str(tenant_id)},
    ).scalar_one_or_none()
    if enabled != "enabled":
        raise InoculationPermissionDenied(
            "The production module is not enabled for this tenant."
        )


def _lock_batches(session: Session, tenant_id: UUID, batch_ids: Sequence[UUID]) -> None:
    for batch_id in sorted(set(batch_ids), key=str):
        session.execute(
            text("SELECT pg_advisory_xact_lock(hashtextextended(:lock_key, 0))"),
            {"lock_key": f"{tenant_id}:production-batch:{batch_id}"},
        )


def _translate_db_error(exc: DBAPIError) -> None:
    message = str(getattr(exc, "orig", exc)).lower()
    if "permission denied" in message or "row-level security" in message:
        raise InoculationPermissionDenied(
            "The runtime role is not authorized for this inoculation operation."
        ) from exc
    if any(token in message for token in (
        "inoculation", "allocation", "foreign key", "unique constraint",
        "check constraint", "duplicate key",
    )):
        raise InoculationError(str(getattr(exc, "orig", exc))) from exc
    raise exc


def schedule_inoculation_run(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    production_unit_id: UUID,
    run_code: str,
    allocations: Sequence[VarietyAllocation],
    notes: str | None = None,
) -> InoculationRunResult:
    """Create one run that may allocate several cooled batches to varieties.

    Allocations may be partial. Unallocated sterilized quantity remains
    visible as the difference between cooled sterilization quantity and
    cumulative inoculation allocations; it is never silently discarded.
    """
    normalized_code = run_code.strip()
    if not normalized_code or len(normalized_code) > 70:
        raise InoculationError("A run code of 1-70 characters is required.")
    if not allocations:
        raise InoculationError("At least one variety allocation is required.")
    if any(item.quantity <= 0 for item in allocations):
        raise InoculationError("Every allocation quantity must be positive.")
    batch_ids = [item.batch_id for item in allocations]
    if len(set(batch_ids)) == 0:
        raise InoculationError("At least one production batch is required.")

    _set_context(session, actor_user_id, tenant_id)
    _require_production_module(session, tenant_id)
    _lock_batches(session, tenant_id, batch_ids)

    try:
        existing = session.execute(
            text(
                """
                SELECT id FROM inoculation_runs
                 WHERE tenant_id=:tenant_id AND run_code=:run_code
                """
            ),
            {"tenant_id": str(tenant_id), "run_code": normalized_code},
        ).scalar_one_or_none()
        if existing is not None:
            rows = session.execute(
                text(
                    """
                    SELECT batch_id, variety_id, allocated_quantity, quantity_unit_id,
                           seed_lot_id
                      FROM inoculation_allocations
                     WHERE tenant_id=:tenant_id AND inoculation_run_id=:run_id
                     ORDER BY batch_id, variety_id
                    """
                ),
                {"tenant_id": str(tenant_id), "run_id": str(existing)},
            ).mappings().all()
            expected = sorted((
                (
                    str(a.batch_id), str(a.variety_id), a.quantity,
                    str(a.unit_id), str(a.seed_lot_id) if a.seed_lot_id else None,
                )
                for a in allocations
            ), key=lambda row: tuple(str(value) for value in row))
            actual = sorted((
                (
                    str(r["batch_id"]), str(r["variety_id"]), Decimal(r["allocated_quantity"]),
                    str(r["quantity_unit_id"]),
                    str(r["seed_lot_id"]) if r["seed_lot_id"] else None,
                )
                for r in rows
            ), key=lambda row: tuple(str(value) for value in row))
            if expected != actual:
                raise InoculationError("The run code already exists with a different allocation payload.")
            return InoculationRunResult(UUID(str(existing)), normalized_code, len(rows), True)

        for batch_id in sorted(set(batch_ids), key=str):
            batch = session.execute(
                text(
                    """
                    SELECT status, production_unit_id, output_unit_id
                      FROM production_batches
                     WHERE tenant_id=:tenant_id AND id=:batch_id
                    """
                ),
                {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
            ).mappings().one_or_none()
            if batch is None:
                raise InoculationError("A referenced production batch was not found.")
            if batch["status"] != "inoculation":
                raise InoculationError("Every allocated batch must be in the inoculation stage.")
            if str(batch["production_unit_id"]) != str(production_unit_id):
                raise InoculationError("All batches must belong to the selected production unit.")
            if any(
                a.batch_id == batch_id and str(a.unit_id) != str(batch["output_unit_id"])
                for a in allocations
            ):
                raise InoculationError("Allocation units must match the batch output unit.")

        run_id = uuid4()
        session.execute(
            text(
                """
                INSERT INTO inoculation_runs(
                    id, tenant_id, production_unit_id, run_code, status,
                    operator_user_id, notes
                ) VALUES (
                    :id, :tenant_id, :production_unit_id, :run_code, 'planned',
                    :actor_user_id, :notes
                )
                """
            ),
            {
                "id": str(run_id), "tenant_id": str(tenant_id),
                "production_unit_id": str(production_unit_id),
                "run_code": normalized_code, "actor_user_id": str(actor_user_id),
                "notes": notes.strip() if notes and notes.strip() else None,
            },
        )
        for allocation in allocations:
            session.execute(
                text(
                    """
                    INSERT INTO inoculation_allocations(
                        tenant_id, inoculation_run_id, batch_id, variety_id,
                        allocated_quantity, quantity_unit_id, seed_lot_id
                    ) VALUES (
                        :tenant_id, :run_id, :batch_id, :variety_id,
                        :quantity, :unit_id, :seed_lot_id
                    )
                    """
                ),
                {
                    "tenant_id": str(tenant_id), "run_id": str(run_id),
                    "batch_id": str(allocation.batch_id),
                    "variety_id": str(allocation.variety_id),
                    "quantity": allocation.quantity, "unit_id": str(allocation.unit_id),
                    "seed_lot_id": str(allocation.seed_lot_id) if allocation.seed_lot_id else None,
                },
            )
        session.execute(
            text(
                """
                INSERT INTO inoculation_run_events(
                    tenant_id, inoculation_run_id, event_type, actor_user_id, metadata
                ) VALUES (
                    :tenant_id, :run_id, 'inoculation_scheduled', :actor_user_id,
                    jsonb_build_object('allocation_count', :allocation_count,
                                       'batch_count', :batch_count)
                )
                """
            ),
            {
                "tenant_id": str(tenant_id), "run_id": str(run_id),
                "actor_user_id": str(actor_user_id),
                "allocation_count": len(allocations), "batch_count": len(set(batch_ids)),
            },
        )
    except DBAPIError as exc:
        _translate_db_error(exc)

    return InoculationRunResult(run_id, normalized_code, len(allocations), False)


def complete_inoculation_run(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    run_id: UUID,
) -> InoculationRunResult:
    """Complete a planned inoculation run once all immutable allocations exist."""
    _set_context(session, actor_user_id, tenant_id)
    _require_production_module(session, tenant_id)
    try:
        run = session.execute(
            text(
                """
                SELECT id, run_code, status
                  FROM inoculation_runs
                 WHERE tenant_id=:tenant_id AND id=:run_id
                 FOR UPDATE
                """
            ),
            {"tenant_id": str(tenant_id), "run_id": str(run_id)},
        ).mappings().one_or_none()
        if run is None:
            raise InoculationError("Inoculation run was not found.")
        count = session.execute(
            text(
                """
                SELECT count(*) FROM inoculation_allocations
                 WHERE tenant_id=:tenant_id AND inoculation_run_id=:run_id
                """
            ),
            {"tenant_id": str(tenant_id), "run_id": str(run_id)},
        ).scalar_one()
        if int(count) == 0:
            raise InoculationError("An inoculation run cannot complete without allocations.")
        if run["status"] == "completed":
            return InoculationRunResult(UUID(str(run_id)), str(run["run_code"]), int(count), True)
        if run["status"] != "planned":
            raise InoculationError("Only a planned inoculation run can be completed.")
        session.execute(
            text(
                """
                UPDATE inoculation_runs
                   SET status='completed', started_at=COALESCE(started_at, now()),
                       completed_at=now()
                 WHERE tenant_id=:tenant_id AND id=:run_id
                """
            ),
            {"tenant_id": str(tenant_id), "run_id": str(run_id)},
        )
        session.execute(
            text(
                """
                INSERT INTO inoculation_run_events(
                    tenant_id, inoculation_run_id, event_type, actor_user_id,
                    metadata
                ) VALUES (
                    :tenant_id, :run_id, 'inoculation_completed', :actor_user_id,
                    jsonb_build_object('allocation_count', :allocation_count)
                )
                """
            ),
            {
                "tenant_id": str(tenant_id), "run_id": str(run_id),
                "actor_user_id": str(actor_user_id), "allocation_count": int(count),
            },
        )
    except DBAPIError as exc:
        _translate_db_error(exc)
    return InoculationRunResult(UUID(str(run_id)), str(run["run_code"]), int(count), False)


def create_incubation_record(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    batch_id: UUID,
    incubation_location_id: UUID,
    target_days: int,
    started_at: datetime | None = None,
    notes: str | None = None,
) -> IncubationRecordResult:
    """Create a configurable incubation timer after a completed variety allocation."""
    if target_days <= 0:
        raise InoculationError("Incubation target days must be positive.")
    _set_context(session, actor_user_id, tenant_id)
    _require_production_module(session, tenant_id)
    _lock_batches(session, tenant_id, [batch_id])
    start = started_at or datetime.now(UTC)
    if start.tzinfo is None:
        raise InoculationError("Incubation start time must include a timezone.")
    try:
        eligible = session.execute(
            text(
                """
                SELECT b.status, count(a.id) AS completed_allocations
                  FROM production_batches b
                  JOIN inoculation_allocations a
                    ON a.tenant_id=b.tenant_id AND a.batch_id=b.id
                  JOIN inoculation_runs r
                    ON r.tenant_id=a.tenant_id AND r.id=a.inoculation_run_id
                 WHERE b.tenant_id=:tenant_id AND b.id=:batch_id
                   AND r.status='completed'
                 GROUP BY b.status
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).mappings().one_or_none()
        if eligible is None or eligible["status"] != "inoculation":
            raise InoculationError(
                "Incubation requires an inoculation-stage batch with a completed variety allocation."
            )
        location_exists = session.execute(
            text(
                """
                SELECT EXISTS (
                    SELECT 1 FROM locations
                     WHERE tenant_id=:tenant_id AND id=:location_id
                )
                """
            ),
            {"tenant_id": str(tenant_id), "location_id": str(incubation_location_id)},
        ).scalar_one()
        if not location_exists:
            raise InoculationError("The incubation location does not belong to this tenant.")
        sequence_no = int(session.execute(
            text(
                """
                SELECT COALESCE(max(sequence_no),0)+1
                  FROM incubation_records
                 WHERE tenant_id=:tenant_id AND batch_id=:batch_id
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).scalar_one())
        record_id = uuid4()
        expected = start + timedelta(days=target_days)
        session.execute(
            text(
                """
                INSERT INTO incubation_records(
                    id, tenant_id, batch_id, sequence_no, incubation_location_id,
                    started_at, target_days, expected_move_at, status, notes
                ) VALUES (
                    :id, :tenant_id, :batch_id, :sequence_no, :location_id,
                    :started_at, :target_days, :expected_move_at, 'incubating', :notes
                )
                """
            ),
            {
                "id": str(record_id), "tenant_id": str(tenant_id),
                "batch_id": str(batch_id), "sequence_no": sequence_no,
                "location_id": str(incubation_location_id), "started_at": start,
                "target_days": target_days, "expected_move_at": expected,
                "notes": notes.strip() if notes and notes.strip() else None,
            },
        )
    except DBAPIError as exc:
        _translate_db_error(exc)
    return IncubationRecordResult(record_id, batch_id, start, expected, target_days)

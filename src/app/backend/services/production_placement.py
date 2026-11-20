"""Incubation readiness and variety-specific kumbung placement services.

Callers authorize membership/permissions and own transaction commit/rollback.
The database enforces tenant isolation, append-only lineage, source balances,
and concurrent kumbung capacity.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID, uuid4

from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session

from app.backend.services.production_lifecycle import (
    ProductionLifecycleError,
    transition_production_batch,
)


class ProductionPlacementError(Exception):
    """An incubation hand-off or kumbung placement precondition failed."""


class ProductionPlacementPermissionDenied(PermissionError):
    """The tenant cannot access production placement operations."""


@dataclass(frozen=True, slots=True)
class LotSegmentResult:
    segment_ids: tuple[UUID, ...]
    segment_count: int
    total_quantity: Decimal


@dataclass(frozen=True, slots=True)
class IncubationReadyResult:
    record_id: UUID
    batch_id: UUID
    ready_at: datetime
    was_replayed: bool = False


@dataclass(frozen=True, slots=True)
class PlacementResult:
    placement_id: UUID
    segment_id: UUID
    kumbung_id: UUID
    quantity_delta: Decimal
    unit_id: UUID
    reference_id: UUID
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
    status = session.execute(
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
    if status != "enabled":
        raise ProductionPlacementPermissionDenied(
            "The production module is not enabled for this tenant."
        )


def _lock_batch(session: Session, tenant_id: UUID, batch_id: UUID) -> None:
    session.execute(
        text("SELECT pg_advisory_xact_lock(hashtextextended(:lock_key, 0))"),
        {"lock_key": f"{tenant_id}:production-batch:{batch_id}"},
    )


def _translate_db_error(exc: DBAPIError) -> None:
    message = str(getattr(exc, "orig", exc)).lower()
    if "permission denied" in message or "row-level security" in message:
        raise ProductionPlacementPermissionDenied(
            "The runtime role is not authorized for this production placement operation."
        ) from exc
    if any(token in message for token in (
        "kumbung", "placement", "segment", "incubation", "capacity",
        "foreign key", "unique constraint", "check constraint", "duplicate key",
    )):
        raise ProductionPlacementError(str(getattr(exc, "orig", exc))) from exc
    raise exc


def materialize_variety_segments(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    batch_id: UUID,
) -> LotSegmentResult:
    """Create traceability partitions for completed inoculation allocations.

    Segments reference the existing production/inventory lot. They never
    create duplicate stock or inventory-ledger entries.
    """
    _set_context(session, actor_user_id, tenant_id)
    _require_production_module(session, tenant_id)
    _lock_batch(session, tenant_id, batch_id)
    try:
        lot = session.execute(
            text(
                """
                SELECT id, output_quantity, output_unit_id
                  FROM production_lots
                 WHERE tenant_id=:tenant_id AND batch_id=:batch_id
                 FOR UPDATE
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).mappings().one_or_none()
        if lot is None:
            raise ProductionPlacementError("The batch has no posted production lot.")
        allocations = session.execute(
            text(
                """
                SELECT a.id, a.batch_id, a.variety_id, a.allocated_quantity,
                       a.quantity_unit_id
                  FROM inoculation_allocations a
                  JOIN inoculation_runs r
                    ON r.tenant_id=a.tenant_id AND r.id=a.inoculation_run_id
                 WHERE a.tenant_id=:tenant_id AND a.batch_id=:batch_id
                   AND r.status='completed'
                 ORDER BY a.id
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).mappings().all()
        if not allocations:
            raise ProductionPlacementError(
                "At least one completed variety allocation is required."
            )
        existing = {
            str(row["inoculation_allocation_id"]): row
            for row in session.execute(
                text(
                    """
                    SELECT id, inoculation_allocation_id, variety_id, quantity, unit_id
                      FROM production_lot_segments
                     WHERE tenant_id=:tenant_id AND production_lot_id=:lot_id
                    """
                ),
                {"tenant_id": str(tenant_id), "lot_id": str(lot["id"])},
            ).mappings().all()
        }
        segment_ids: list[UUID] = []
        total = Decimal("0")
        for allocation in allocations:
            allocation_key = str(allocation["id"])
            prior = existing.get(allocation_key)
            quantity = Decimal(allocation["allocated_quantity"])
            if prior is not None:
                if (
                    str(prior["variety_id"]) != str(allocation["variety_id"])
                    or Decimal(prior["quantity"]) != quantity
                    or str(prior["unit_id"]) != str(allocation["quantity_unit_id"])
                ):
                    raise ProductionPlacementError(
                        "Existing variety lineage differs from its immutable inoculation allocation."
                    )
                segment_id = UUID(str(prior["id"]))
            else:
                segment_id = uuid4()
                session.execute(
                    text(
                        """
                        INSERT INTO production_lot_segments(
                            id, tenant_id, production_lot_id, inoculation_allocation_id,
                            batch_id, variety_id, quantity, unit_id
                        ) VALUES (
                            :id, :tenant_id, :lot_id, :allocation_id,
                            :batch_id, :variety_id, :quantity, :unit_id
                        )
                        """
                    ),
                    {
                        "id": str(segment_id), "tenant_id": str(tenant_id),
                        "lot_id": str(lot["id"]), "allocation_id": allocation_key,
                        "batch_id": str(batch_id), "variety_id": str(allocation["variety_id"]),
                        "quantity": quantity, "unit_id": str(allocation["quantity_unit_id"]),
                    },
                )
            segment_ids.append(segment_id)
            total += quantity
        if total > Decimal(lot["output_quantity"]):
            raise ProductionPlacementError(
                "Completed variety allocations exceed the posted production lot quantity."
            )
    except DBAPIError as exc:
        _translate_db_error(exc)
    return LotSegmentResult(tuple(segment_ids), len(segment_ids), total)


def mark_incubation_ready(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    batch_id: UUID,
    incubation_record_id: UUID,
    idempotency_key: str,
    occurred_at: datetime | None = None,
    notes: str | None = None,
) -> IncubationReadyResult:
    """Mark incubation ready only after its configured target timestamp."""
    now = occurred_at or datetime.now(UTC)
    if now.tzinfo is None:
        raise ProductionPlacementError("Readiness timestamp must include a timezone.")
    _set_context(session, actor_user_id, tenant_id)
    _require_production_module(session, tenant_id)
    _lock_batch(session, tenant_id, batch_id)
    try:
        record = session.execute(
            text(
                """
                SELECT id, batch_id, expected_move_at, status
                  FROM incubation_records
                 WHERE tenant_id=:tenant_id AND id=:record_id AND batch_id=:batch_id
                 FOR UPDATE
                """
            ),
            {
                "tenant_id": str(tenant_id), "record_id": str(incubation_record_id),
                "batch_id": str(batch_id),
            },
        ).mappings().one_or_none()
        if record is None:
            raise ProductionPlacementError("The incubation record was not found.")
        if record["status"] == "ready_to_move":
            return IncubationReadyResult(
                incubation_record_id, batch_id, now, True
            )
        if record["status"] != "incubating":
            raise ProductionPlacementError("Only an active incubation record can be marked ready.")
        if record["expected_move_at"] > now:
            raise ProductionPlacementError("The configured incubation target time has not arrived.")
        session.execute(
            text(
                """
                UPDATE incubation_records
                   SET status='ready_to_move'
                 WHERE tenant_id=:tenant_id AND id=:record_id
                """
            ),
            {"tenant_id": str(tenant_id), "record_id": str(incubation_record_id)},
        )
        session.execute(
            text(
                """
                INSERT INTO incubation_record_events(
                    tenant_id, incubation_record_id, event_type, occurred_at,
                    actor_user_id, metadata
                ) VALUES (
                    :tenant_id, :record_id, 'incubation_marked_ready', :occurred_at,
                    :actor_user_id, jsonb_build_object('notes', CAST(:notes AS text))
                )
                """
            ),
            {
                "tenant_id": str(tenant_id), "record_id": str(incubation_record_id),
                "occurred_at": now, "actor_user_id": str(actor_user_id),
                "notes": notes.strip() if notes and notes.strip() else None,
            },
        )
        transition_production_batch(
            session,
            actor_user_id=actor_user_id,
            tenant_id=tenant_id,
            batch_id=batch_id,
            command="mark_ready_for_kumbung",
            idempotency_key=idempotency_key,
            notes=notes,
        )
    except ProductionLifecycleError as exc:
        raise ProductionPlacementError(str(exc)) from exc
    except DBAPIError as exc:
        _translate_db_error(exc)
    return IncubationReadyResult(incubation_record_id, batch_id, now, False)


def place_lot_segment(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    segment_id: UUID,
    kumbung_id: UUID,
    quantity: Decimal,
    unit_id: UUID,
    reference_id: UUID | None = None,
    occurred_at: datetime | None = None,
    notes: str | None = None,
) -> PlacementResult:
    """Place part of a ready variety segment into a capacity-controlled kumbung."""
    if quantity <= 0:
        raise ProductionPlacementError("Placement quantity must be positive.")
    _set_context(session, actor_user_id, tenant_id)
    _require_production_module(session, tenant_id)
    _lock_key = f"{tenant_id}:lot-segment:{segment_id}"
    session.execute(
        text("SELECT pg_advisory_xact_lock(hashtextextended(:lock_key, 0))"),
        {"lock_key": _lock_key},
    )
    ref = reference_id or uuid4()
    placement_id = uuid4()
    timestamp = occurred_at or datetime.now(UTC)
    if timestamp.tzinfo is None:
        raise ProductionPlacementError("Placement timestamp must include a timezone.")
    try:
        inserted = session.execute(
            text(
                """
                INSERT INTO kumbung_placements(
                    id, tenant_id, production_lot_id, production_lot_segment_id,
                    kumbung_id, movement_type, quantity_delta, unit_id,
                    occurred_at, reference_id, notes, actor_user_id
                )
                SELECT :id, :tenant_id, s.production_lot_id, s.id,
                       :kumbung_id, 'place', :quantity, :unit_id,
                       :occurred_at, :reference_id, :notes, :actor_user_id
                  FROM production_lot_segments s
                 WHERE s.tenant_id=:tenant_id AND s.id=:segment_id
                """
            ),
            {
                "id": str(placement_id), "tenant_id": str(tenant_id),
                "kumbung_id": str(kumbung_id), "quantity": quantity,
                "unit_id": str(unit_id), "occurred_at": timestamp,
                "reference_id": str(ref),
                "notes": notes.strip() if notes and notes.strip() else None,
                "actor_user_id": str(actor_user_id), "segment_id": str(segment_id),
            },
        )
        if inserted.rowcount != 1:
            raise ProductionPlacementError("The requested variety lot segment was not found.")
        session.execute(
            text(
                """
                INSERT INTO tenant_audit_events(
                    tenant_id, actor_user_id, action, entity_type, entity_id,
                    after_data, metadata
                ) VALUES (
                    :tenant_id, :actor_user_id, 'production.kumbung.placed',
                    'production_lot_segment', :segment_id,
                    jsonb_build_object('kumbung_id', CAST(:kumbung_id AS uuid),
                                       'quantity', CAST(:quantity AS numeric),
                                       'unit_id', CAST(:unit_id AS uuid)),
                    jsonb_build_object('placement_id', CAST(:placement_id AS uuid),
                                       'reference_id', CAST(:reference_id AS uuid))
                )
                """
            ),
            {
                "tenant_id": str(tenant_id), "actor_user_id": str(actor_user_id),
                "segment_id": str(segment_id), "kumbung_id": str(kumbung_id),
                "quantity": quantity, "unit_id": str(unit_id),
                "placement_id": str(placement_id), "reference_id": str(ref),
            },
        )
    except DBAPIError as exc:
        _translate_db_error(exc)
    return PlacementResult(placement_id, segment_id, kumbung_id, quantity, unit_id, ref)


def move_lot_segment(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    segment_id: UUID,
    source_kumbung_id: UUID,
    destination_kumbung_id: UUID,
    quantity: Decimal,
    unit_id: UUID,
    reference_id: UUID | None = None,
    occurred_at: datetime | None = None,
    notes: str | None = None,
) -> tuple[PlacementResult, PlacementResult]:
    """Move a segment between kumbungs with a balanced immutable ledger pair."""
    if quantity <= 0:
        raise ProductionPlacementError("Move quantity must be positive.")
    if source_kumbung_id == destination_kumbung_id:
        raise ProductionPlacementError("Source and destination kumbung must differ.")
    _set_context(session, actor_user_id, tenant_id)
    _require_production_module(session, tenant_id)
    ref = reference_id or uuid4()
    timestamp = occurred_at or datetime.now(UTC)
    if timestamp.tzinfo is None:
        raise ProductionPlacementError("Move timestamp must include a timezone.")
    first_id, second_id = uuid4(), uuid4()
    try:
        for kumbung_id in sorted((source_kumbung_id, destination_kumbung_id), key=str):
            session.execute(
                text("SELECT pg_advisory_xact_lock(hashtextextended(:lock_key, 0))"),
                {"lock_key": f"{tenant_id}:kumbung:{kumbung_id}"},
            )
        session.execute(
            text("SELECT pg_advisory_xact_lock(hashtextextended(:lock_key, 0))"),
            {"lock_key": f"{tenant_id}:lot-segment:{segment_id}"},
        )
        for placement_id, kumbung_id, movement_type, delta in (
            (first_id, source_kumbung_id, "move_out", -quantity),
            (second_id, destination_kumbung_id, "move_in", quantity),
        ):
            session.execute(
                text(
                    """
                    INSERT INTO kumbung_placements(
                        id, tenant_id, production_lot_id, production_lot_segment_id,
                        kumbung_id, movement_type, quantity_delta, unit_id,
                        occurred_at, reference_id, notes, actor_user_id
                    )
                    SELECT :id, :tenant_id, s.production_lot_id, s.id,
                           :kumbung_id, :movement_type, :quantity, :unit_id,
                           :occurred_at, :reference_id, :notes, :actor_user_id
                      FROM production_lot_segments s
                     WHERE s.tenant_id=:tenant_id AND s.id=:segment_id
                    """
                ),
                {
                    "id": str(placement_id), "tenant_id": str(tenant_id),
                    "kumbung_id": str(kumbung_id), "movement_type": movement_type,
                    "quantity": delta, "unit_id": str(unit_id), "occurred_at": timestamp,
                    "reference_id": str(ref),
                    "notes": notes.strip() if notes and notes.strip() else None,
                    "actor_user_id": str(actor_user_id), "segment_id": str(segment_id),
                },
            )
        session.execute(
            text(
                """
                INSERT INTO tenant_audit_events(
                    tenant_id, actor_user_id, action, entity_type, entity_id,
                    after_data, metadata
                ) VALUES (
                    :tenant_id, :actor_user_id, 'production.kumbung.moved',
                    'production_lot_segment', :segment_id,
                    jsonb_build_object('source_kumbung_id', CAST(:source_id AS uuid),
                                       'destination_kumbung_id', CAST(:destination_id AS uuid),
                                       'quantity', CAST(:quantity AS numeric)),
                    jsonb_build_object('reference_id', CAST(:reference_id AS uuid),
                                       'out_placement_id', CAST(:out_id AS uuid),
                                       'in_placement_id', CAST(:in_id AS uuid))
                )
                """
            ),
            {
                "tenant_id": str(tenant_id), "actor_user_id": str(actor_user_id),
                "segment_id": str(segment_id), "source_id": str(source_kumbung_id),
                "destination_id": str(destination_kumbung_id), "quantity": quantity,
                "reference_id": str(ref), "out_id": str(first_id), "in_id": str(second_id),
            },
        )
    except DBAPIError as exc:
        _translate_db_error(exc)
    return (
        PlacementResult(first_id, segment_id, source_kumbung_id, -quantity, unit_id, ref),
        PlacementResult(second_id, segment_id, destination_kumbung_id, quantity, unit_id, ref),
    )

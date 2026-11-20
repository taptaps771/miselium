"""Tenant-scoped sterilization scheduling and run lifecycle.

The caller performs membership/permission authorization and owns transaction
commit/rollback. Capacity and schedule concurrency is serialized with
transaction-scoped advisory locks; no UPDATE privilege on machine master rows
is required.
"""
from __future__ import annotations

from dataclasses import dataclass
import json
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Sequence
from uuid import UUID, uuid4

from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session


class SterilizationError(Exception):
    """A sterilization scheduling or lifecycle invariant was violated."""


class SterilizationPermissionDenied(PermissionError):
    """Production module entitlement or database permission is missing."""


@dataclass(frozen=True, slots=True)
class BatchSterilizationAllocation:
    batch_id: UUID
    quantity: Decimal


@dataclass(frozen=True, slots=True)
class SterilizerSchedule:
    sterilizer_id: UUID
    allocations: tuple[BatchSterilizationAllocation, ...]


@dataclass(frozen=True, slots=True)
class SterilizationCycleResult:
    cycle_id: UUID
    cycle_code: str
    run_ids: tuple[UUID, ...]
    planned_capacity: Decimal
    capacity_unit_id: UUID


@dataclass(frozen=True, slots=True)
class SterilizationCommandResult:
    cycle_id: UUID
    run_id: UUID | None
    status: str
    cooling_due_at: datetime | None = None


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
        raise SterilizationPermissionDenied(
            "The production module is not enabled for this tenant."
        )


def _unit_factor(
    session: Session, from_unit_id: UUID, to_unit_id: UUID
) -> Decimal:
    if from_unit_id == to_unit_id:
        return Decimal(1)
    factor = session.execute(
        text(
            """
            SELECT factor FROM measurement_unit_conversions
             WHERE from_unit_id=:from_unit_id AND to_unit_id=:to_unit_id
            """
        ),
        {"from_unit_id": str(from_unit_id), "to_unit_id": str(to_unit_id)},
    ).scalar_one_or_none()
    if factor is None:
        raise SterilizationError(
            "A direct, explicitly configured conversion is required between capacity units."
        )
    return Decimal(factor)


def _lock_resources(
    session: Session,
    tenant_id: UUID,
    resource_ids: Sequence[UUID],
    *,
    namespace: str = "sterilizer",
) -> None:
    # Stable ordering prevents deadlocks when a cycle contains several resources.
    for resource_id in sorted(set(resource_ids), key=str):
        session.execute(
            text("SELECT pg_advisory_xact_lock(hashtextextended(:lock_key, 0))"),
            {"lock_key": f"{tenant_id}:{namespace}:{resource_id}"},
        )


def _append_event(
    session: Session,
    *,
    tenant_id: UUID,
    actor_user_id: UUID,
    cycle_id: UUID,
    event_type: str,
    run_id: UUID | None = None,
    metadata: dict | None = None,
) -> None:
    session.execute(
        text(
            """
            INSERT INTO sterilization_cycle_events(
                tenant_id, cycle_id, event_type, sterilization_run_id,
                actor_user_id, metadata
            ) VALUES (
                :tenant_id, :cycle_id, :event_type, :run_id,
                :actor_user_id, CAST(:metadata AS jsonb)
            )
            """
        ),
        {
            "tenant_id": str(tenant_id), "cycle_id": str(cycle_id),
            "event_type": event_type, "run_id": str(run_id) if run_id else None,
            "actor_user_id": str(actor_user_id),
            "metadata": json.dumps(metadata or {}, sort_keys=True),
        },
    )


def schedule_sterilization_cycle(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    production_unit_id: UUID,
    cycle_code: str,
    planned_start_at: datetime,
    sterilizers: Sequence[SterilizerSchedule],
) -> SterilizationCycleResult:
    """Schedule one shared turn across multiple sterilizers and batches.

    Each machine can be included only once in a cycle. Allocations use the
    batch's posted good-output unit. Machine and batch quantities are converted
    to the cycle's first machine capacity unit using explicit conversion rows.
    """
    if not cycle_code.strip() or len(cycle_code.strip()) > 70:
        raise SterilizationError("Cycle code must contain 1-70 characters.")
    if planned_start_at.tzinfo is None:
        raise SterilizationError("Planned start must be timezone-aware.")
    if not sterilizers:
        raise SterilizationError("A cycle requires at least one sterilizer.")
    machine_ids = [entry.sterilizer_id for entry in sterilizers]
    if len(machine_ids) != len(set(machine_ids)):
        raise SterilizationError("A sterilizer can only appear once in a cycle.")
    if any(
        len({allocation.batch_id for allocation in entry.allocations}) != len(entry.allocations)
        for entry in sterilizers
    ):
        raise SterilizationError("A batch can only be listed once per sterilizer run.")
    if any(not entry.allocations for entry in sterilizers):
        raise SterilizationError("Every participating sterilizer needs at least one batch allocation.")

    cycle_id = uuid4()
    _set_context(session, actor_user_id, tenant_id)
    _require_production_module(session, tenant_id)
    _lock_resources(session, tenant_id, machine_ids)
    _lock_resources(session, tenant_id, [cycle_id], namespace="sterilization-cycle")
    batch_ids = [
        allocation.batch_id
        for entry in sterilizers
        for allocation in entry.allocations
    ]
    _lock_resources(session, tenant_id, batch_ids, namespace="production-batch")

    try:
        machines = {}
        for entry in sterilizers:
            machine = session.execute(
                text(
                    """
                    SELECT id, production_unit_id, capacity, capacity_unit_id,
                           cycle_minutes, cooling_minutes, is_active
                      FROM sterilizers
                     WHERE tenant_id=:tenant_id AND id=:machine_id
                    """
                ),
                {"tenant_id": str(tenant_id), "machine_id": str(entry.sterilizer_id)},
            ).mappings().one_or_none()
            if machine is None or machine["production_unit_id"] != production_unit_id:
                raise SterilizationError(
                    "Every sterilizer must belong to the selected production unit."
                )
            if not machine["is_active"]:
                raise SterilizationError("Inactive sterilizers cannot be scheduled.")
            machines[entry.sterilizer_id] = machine

        cycle_capacity_unit_id = UUID(str(machines[machine_ids[0]]["capacity_unit_id"]))
        planned_capacity = Decimal(0)
        machine_factors: dict[UUID, Decimal] = {}
        machine_allocations: dict[UUID, list[tuple[UUID, Decimal, UUID, Decimal, Decimal]]] = {}

        for entry in sterilizers:
            machine = machines[entry.sterilizer_id]
            factor = _unit_factor(
                session, UUID(str(machine["capacity_unit_id"])), cycle_capacity_unit_id
            )
            machine_factors[entry.sterilizer_id] = factor
            planned_capacity += Decimal(machine["capacity"]) * factor
            machine_allocations[entry.sterilizer_id] = []
            allocated_for_machine = Decimal(0)

            for allocation in entry.allocations:
                quantity = Decimal(allocation.quantity)
                if quantity <= 0:
                    raise SterilizationError("Allocated quantity must be positive.")
                batch = session.execute(
                    text(
                        """
                        SELECT status, actual_output_quantity, output_unit_id,
                               production_unit_id
                          FROM production_batches
                         WHERE tenant_id=:tenant_id AND id=:batch_id
                        """
                    ),
                    {"tenant_id": str(tenant_id), "batch_id": str(allocation.batch_id)},
                ).mappings().one_or_none()
                if batch is None or batch["production_unit_id"] != production_unit_id:
                    raise SterilizationError(
                        "Every allocated batch must belong to the same production unit."
                    )
                if batch["status"] != "sterilization":
                    raise SterilizationError(
                        "Only batches in the sterilization lifecycle stage can be allocated."
                    )
                if batch["actual_output_quantity"] is None:
                    raise SterilizationError(
                        "A batch must have posted good press output before sterilization."
                    )
                output_unit_id = UUID(str(batch["output_unit_id"]))
                conversion = _unit_factor(session, output_unit_id, cycle_capacity_unit_id)
                capacity_quantity = quantity * conversion
                prior_quantity = Decimal(
                    session.execute(
                        text(
                            """
                            SELECT COALESCE(sum(allocated_quantity),0)
                              FROM sterilization_run_batches
                             WHERE tenant_id=:tenant_id AND batch_id=:batch_id
                            """
                        ),
                        {"tenant_id": str(tenant_id), "batch_id": str(allocation.batch_id)},
                    ).scalar_one()
                )
                if prior_quantity + quantity > Decimal(batch["actual_output_quantity"]):
                    raise SterilizationError(
                        "Total sterilization allocation cannot exceed the batch's good press output."
                    )
                allocated_for_machine += capacity_quantity
                machine_allocations[entry.sterilizer_id].append(
                    (allocation.batch_id, quantity, output_unit_id, conversion, capacity_quantity)
                )

            if allocated_for_machine > Decimal(machine["capacity"]) * factor:
                raise SterilizationError(
                    "Allocations assigned to a sterilizer exceed its individual capacity."
                )

        total_allocated = sum(
            (row[4] for rows in machine_allocations.values() for row in rows),
            Decimal(0),
        )
        if total_allocated > planned_capacity:
            raise SterilizationError(
                "Combined cycle allocation exceeds the sum of participating sterilizer capacities."
            )

            session.execute(
            text(
                """
                INSERT INTO sterilization_cycles(
                    id, tenant_id, production_unit_id, cycle_code, status,
                    planned_start_at, capacity_unit_id, planned_capacity,
                    operator_user_id, notes
                ) VALUES (
                    :id, :tenant_id, :production_unit_id, :cycle_code, 'planned',
                    :planned_start_at, :capacity_unit_id, :planned_capacity,
                    :actor_user_id, 'Shared multi-sterilizer production cycle'
                )
                """
            ),
            {
                "id": str(cycle_id), "tenant_id": str(tenant_id),
                "production_unit_id": str(production_unit_id),
                "cycle_code": cycle_code.strip(),
                "planned_start_at": planned_start_at,
                "capacity_unit_id": str(cycle_capacity_unit_id),
                "planned_capacity": planned_capacity,
                "actor_user_id": str(actor_user_id),
            },
        )

        run_ids: list[UUID] = []
        for entry in sterilizers:
            machine = machines[entry.sterilizer_id]
            run_id = uuid4()
            run_ids.append(run_id)
            cycle_minutes = int(machine["cycle_minutes"])
            planned_end_at = planned_start_at + timedelta(minutes=cycle_minutes)
            run_code = f"SR-{cycle_id.hex}-{entry.sterilizer_id.hex}"
            overlap = session.execute(
                text(
                    """
                    SELECT EXISTS (
                        SELECT 1 FROM sterilization_runs
                         WHERE tenant_id=:tenant_id AND sterilizer_id=:machine_id
                           AND (
                               status='running'
                               OR (
                                   status='planned'
                                   AND planned_start_at < :planned_end
                                   AND :planned_start < planned_end_at
                               )
                           )
                    )
                    """
                ),
                {
                    "tenant_id": str(tenant_id), "machine_id": str(entry.sterilizer_id),
                    "planned_start": planned_start_at, "planned_end": planned_end_at,
                },
            ).scalar_one()
            if overlap:
                raise SterilizationError("Sterilizer already has an overlapping scheduled run.")

            session.execute(
                text(
                    """
                    INSERT INTO sterilization_runs(
                        id, tenant_id, sterilizer_id, run_code, status, cycle_id,
                        planned_start_at, planned_end_at, cycle_minutes_snapshot,
                        cooling_minutes_snapshot, capacity_to_cycle_unit_snapshot,
                        operator_user_id, notes
                    ) VALUES (
                        :id, :tenant_id, :machine_id, :run_code, 'planned', :cycle_id,
                        :planned_start, :planned_end, :cycle_minutes,
                        :cooling_minutes, :capacity_factor, :actor_user_id,
                        'Scheduled as part of shared sterilization cycle'
                    )
                    """
                ),
                {
                    "id": str(run_id), "tenant_id": str(tenant_id),
                    "machine_id": str(entry.sterilizer_id), "run_code": run_code,
                    "cycle_id": str(cycle_id), "planned_start": planned_start_at,
                    "planned_end": planned_end_at, "cycle_minutes": cycle_minutes,
                    "cooling_minutes": int(machine["cooling_minutes"]),
                    "capacity_factor": machine_factors[entry.sterilizer_id],
                    "actor_user_id": str(actor_user_id),
                },
            )
            for batch_id, quantity, unit_id, conversion, capacity_quantity in machine_allocations[
                entry.sterilizer_id
            ]:
                session.execute(
                    text(
                        """
                        INSERT INTO sterilization_run_batches(
                            tenant_id, sterilization_run_id, batch_id,
                            allocated_quantity, quantity_unit_id,
                            quantity_to_capacity_unit_snapshot, capacity_quantity_snapshot
                        ) VALUES (
                            :tenant_id, :run_id, :batch_id, :quantity, :unit_id,
                            :conversion, :capacity_quantity
                        )
                        """
                    ),
                    {
                        "tenant_id": str(tenant_id), "run_id": str(run_id),
                        "batch_id": str(batch_id), "quantity": quantity,
                        "unit_id": str(unit_id), "conversion": conversion,
                        "capacity_quantity": capacity_quantity,
                    },
                )

        _append_event(
            session, tenant_id=tenant_id, actor_user_id=actor_user_id,
            cycle_id=cycle_id, event_type="cycle_scheduled",
            metadata={
                "cycle_code": cycle_code.strip(),
                "run_ids": [str(value) for value in run_ids],
                "machine_count": len(run_ids),
                "planned_capacity": str(planned_capacity),
                "capacity_unit_id": str(cycle_capacity_unit_id),
                "allocated_capacity": str(total_allocated),
            },
        )
        return SterilizationCycleResult(
            cycle_id, cycle_code.strip(), tuple(run_ids),
            planned_capacity, cycle_capacity_unit_id,
        )
    except DBAPIError as exc:
        state = getattr(exc.orig, "sqlstate", getattr(exc.orig, "pgcode", None))
        if state == "42501":
            raise SterilizationPermissionDenied(
                "Runtime role is missing a required production permission."
            ) from None
        if state in {"23502", "23503", "23505", "23514", "22023", "55000"}:
            raise SterilizationError(
                "Sterilization scheduling violates a database invariant."
            ) from None
        raise


def start_sterilization_run(
    session: Session, *, actor_user_id: UUID, tenant_id: UUID, run_id: UUID
) -> SterilizationCommandResult:
    _set_context(session, actor_user_id, tenant_id)
    _require_production_module(session, tenant_id)
    try:
        run = session.execute(
            text(
                """
                SELECT sr.id, sr.cycle_id, sr.sterilizer_id, sr.status,
                       sr.planned_start_at, sr.planned_end_at,
                       sc.status AS cycle_status
                  FROM sterilization_runs sr
                  JOIN sterilization_cycles sc
                    ON sc.tenant_id=sr.tenant_id AND sc.id=sr.cycle_id
                 WHERE sr.tenant_id=:tenant_id AND sr.id=:run_id
                """
            ),
            {"tenant_id": str(tenant_id), "run_id": str(run_id)},
        ).mappings().one_or_none()
        if run is None:
            raise SterilizationError("Sterilization run was not found.")
        _lock_resources(session, tenant_id, [UUID(str(run["sterilizer_id"]))])
        run = session.execute(
            text(
                """
                SELECT sr.id, sr.cycle_id, sr.sterilizer_id, sr.status,
                       sr.planned_start_at, sr.planned_end_at,
                       sc.status AS cycle_status
                  FROM sterilization_runs sr
                  JOIN sterilization_cycles sc
                    ON sc.tenant_id=sr.tenant_id AND sc.id=sr.cycle_id
                 WHERE sr.tenant_id=:tenant_id AND sr.id=:run_id
                """
            ),
            {"tenant_id": str(tenant_id), "run_id": str(run_id)},
        ).mappings().one()
        if run["status"] != "planned" or run["cycle_status"] not in {"planned", "running"}:
            raise SterilizationError("Only a planned run in an active cycle can be started.")
        now = datetime.now(timezone.utc)
        if run["planned_start_at"] > now:
            raise SterilizationError("A scheduled run cannot start before its planned start time.")
        if run["planned_end_at"] <= now:
            raise SterilizationError("The scheduled machine slot has expired; create a new cycle time.")
        session.execute(
            text(
                """
                UPDATE sterilization_runs
                   SET status='running', started_at=now()
                 WHERE tenant_id=:tenant_id AND id=:run_id AND status='planned'
                """
            ),
            {"tenant_id": str(tenant_id), "run_id": str(run_id)},
        )
        session.execute(
            text(
                """
                UPDATE sterilization_cycles SET status='running', started_at=COALESCE(started_at,now()),
                       updated_at=now()
                 WHERE tenant_id=:tenant_id AND id=:cycle_id AND status='planned'
                """
            ),
            {"tenant_id": str(tenant_id), "cycle_id": str(run["cycle_id"])},
        )
        _append_event(
            session, tenant_id=tenant_id, actor_user_id=actor_user_id,
            cycle_id=UUID(str(run["cycle_id"])), run_id=run_id,
            event_type="run_started",
        )
        return SterilizationCommandResult(
            UUID(str(run["cycle_id"])), run_id, "running"
        )
    except DBAPIError as exc:
        if getattr(exc.orig, "sqlstate", getattr(exc.orig, "pgcode", None)) == "42501":
            raise SterilizationPermissionDenied("Runtime role cannot start this sterilization run.") from None
        raise


def complete_sterilization_run(
    session: Session, *, actor_user_id: UUID, tenant_id: UUID, run_id: UUID
) -> SterilizationCommandResult:
    _set_context(session, actor_user_id, tenant_id)
    _require_production_module(session, tenant_id)
    run = session.execute(
        text(
            """
            SELECT id, cycle_id, sterilizer_id, status, cooling_minutes_snapshot
              FROM sterilization_runs
             WHERE tenant_id=:tenant_id AND id=:run_id
            """
        ),
        {"tenant_id": str(tenant_id), "run_id": str(run_id)},
    ).mappings().one_or_none()
    if run is None:
        raise SterilizationError("Sterilization run was not found.")
    _lock_resources(session, tenant_id, [UUID(str(run["sterilizer_id"]))])
    run = session.execute(
        text(
            """
            SELECT id, cycle_id, status, cooling_minutes_snapshot
              FROM sterilization_runs
             WHERE tenant_id=:tenant_id AND id=:run_id
            """
        ),
        {"tenant_id": str(tenant_id), "run_id": str(run_id)},
    ).mappings().one()
    if run["status"] != "running":
        raise SterilizationError("Only a running sterilization run can be completed.")
    due = session.execute(
        text(
            """
            UPDATE sterilization_runs
               SET status='completed', completed_at=now(),
                   cooling_due_at=now() + make_interval(mins => cooling_minutes_snapshot)
             WHERE tenant_id=:tenant_id AND id=:run_id
         RETURNING cooling_due_at
            """
        ),
        {"tenant_id": str(tenant_id), "run_id": str(run_id)},
    ).scalar_one()
    all_completed = session.execute(
        text(
            """
            SELECT NOT EXISTS (
                SELECT 1 FROM sterilization_runs
                 WHERE tenant_id=:tenant_id AND cycle_id=:cycle_id
                   AND status NOT IN ('completed','cancelled')
            )
            """
        ),
        {"tenant_id": str(tenant_id), "cycle_id": str(run["cycle_id"])},
    ).scalar_one()
    if all_completed:
        session.execute(
            text(
                """
                UPDATE sterilization_cycles
                   SET status='completed', completed_at=now(), updated_at=now()
                 WHERE tenant_id=:tenant_id AND id=:cycle_id
                """
            ),
            {"tenant_id": str(tenant_id), "cycle_id": str(run["cycle_id"])},
        )
    _append_event(
        session, tenant_id=tenant_id, actor_user_id=actor_user_id,
        cycle_id=UUID(str(run["cycle_id"])), run_id=run_id,
        event_type="run_completed",
        metadata={"cooling_due_at": due.isoformat()},
    )
    return SterilizationCommandResult(
        UUID(str(run["cycle_id"])), run_id, "completed", due
    )


def complete_sterilization_cooling(
    session: Session, *, actor_user_id: UUID, tenant_id: UUID, cycle_id: UUID
) -> SterilizationCommandResult:
    """Record cooling readiness only after every run's snapshotted cooling duration."""
    _set_context(session, actor_user_id, tenant_id)
    _require_production_module(session, tenant_id)
    _lock_resources(session, tenant_id, [cycle_id], namespace="sterilization-cycle")
    cycle = session.execute(
        text(
            """
            SELECT status, cooling_completed_at
              FROM sterilization_cycles
             WHERE tenant_id=:tenant_id AND id=:cycle_id
            """
        ),
        {"tenant_id": str(tenant_id), "cycle_id": str(cycle_id)},
    ).mappings().one_or_none()
    if cycle is None:
        raise SterilizationError("Sterilization cycle was not found.")
    if cycle["cooling_completed_at"] is not None:
        return SterilizationCommandResult(cycle_id, None, "cooling_completed")
    readiness = session.execute(
        text(
            """
            SELECT count(*) AS total_runs,
                   count(*) FILTER (
                       WHERE status='completed' AND cooling_due_at IS NOT NULL
                         AND cooling_due_at <= now()
                   ) AS ready_runs
              FROM sterilization_runs
             WHERE tenant_id=:tenant_id AND cycle_id=:cycle_id
            """
        ),
        {"tenant_id": str(tenant_id), "cycle_id": str(cycle_id)},
    ).mappings().one()
    if int(readiness["total_runs"]) == 0 or int(readiness["ready_runs"]) != int(readiness["total_runs"]):
        raise SterilizationError(
            "Cooling cannot be completed until every run is complete and its cooling duration has elapsed."
        )
    session.execute(
        text(
            """
            UPDATE sterilization_runs SET cooling_completed_at=now()
             WHERE tenant_id=:tenant_id AND cycle_id=:cycle_id
               AND cooling_completed_at IS NULL
            """
        ),
        {"tenant_id": str(tenant_id), "cycle_id": str(cycle_id)},
    )
    session.execute(
        text(
            """
            UPDATE sterilization_cycles
               SET cooling_completed_at=now(), updated_at=now()
             WHERE tenant_id=:tenant_id AND id=:cycle_id
            """
        ),
        {"tenant_id": str(tenant_id), "cycle_id": str(cycle_id)},
    )
    _append_event(
        session, tenant_id=tenant_id, actor_user_id=actor_user_id,
        cycle_id=cycle_id, event_type="cooling_completed",
    )
    return SterilizationCommandResult(cycle_id, None, "cooling_completed")

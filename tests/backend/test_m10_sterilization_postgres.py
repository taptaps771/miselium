from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

from app.backend.services.sterilization import (
    BatchSterilizationAllocation,
    SterilizationError,
    SterilizerSchedule,
    complete_sterilization_cooling,
    complete_sterilization_run,
    schedule_sterilization_cycle,
    start_sterilization_run,
)


def _urls() -> tuple[str, str]:
    admin_url = os.getenv("MISELIUM_ADMIN_DATABASE_URL")
    runtime_url = os.getenv("MISELIUM_DATABASE_URL")
    if not admin_url or not runtime_url:
        pytest.skip("PostgreSQL M10 sterilization environment is not configured")
    return admin_url, runtime_url


def test_shared_sterilization_cycle_capacity_schedule_and_cooling():
    admin_url, runtime_url = _urls()
    tenant_id, actor_id = uuid4(), uuid4()
    location_id, production_unit_id, unit_id = uuid4(), uuid4(), uuid4()
    item_id, recipe_id, recipe_version_id, batch_id = (uuid4() for _ in range(4))
    machine_a, machine_b = uuid4(), uuid4()
    admin_engine = create_engine(admin_url)
    runtime_engine = create_engine(runtime_url)
    planned_start = datetime.now(timezone.utc) - timedelta(minutes=2)

    try:
        with admin_engine.begin() as connection:
            connection.execute(
                text("INSERT INTO users(id, username, status) VALUES (:id, :username, 'active')"),
                {"id": actor_id, "username": f"m10-sterilize-{actor_id.hex}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO tenants(id, code, name, status)
                    VALUES (:id, :code, 'M10 sterilization', 'active')
                    """
                ),
                {"id": tenant_id, "code": f"m10-st-{tenant_id.hex[:12]}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO tenant_modules(tenant_id, module_id, status)
                    SELECT :tenant_id, id, 'enabled' FROM modules WHERE code='production'
                    """
                ),
                {"tenant_id": tenant_id},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO measurement_units(id, code, name, dimension)
                    VALUES (:id, :code, 'Baglog', 'count')
                    """
                ),
                {"id": unit_id, "code": f"st-{unit_id.hex[:18]}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO locations(id, tenant_id, code, name)
                    VALUES (:id, :tenant_id, :code, 'Sterilization location')
                    """
                ),
                {"id": location_id, "tenant_id": tenant_id, "code": f"SL-{tenant_id.hex[:8]}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO production_units(id, tenant_id, location_id, code, name)
                    VALUES (:id, :tenant_id, :location_id, :code, 'Sterilization unit')
                    """
                ),
                {
                    "id": production_unit_id, "tenant_id": tenant_id,
                    "location_id": location_id, "code": f"SU-{tenant_id.hex[:8]}",
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO inventory_items(
                        id, tenant_id, code, name, item_type, base_unit_id
                    ) VALUES (:id, :tenant_id, :code, 'Baglog output', 'finished_good', :unit_id)
                    """
                ),
                {
                    "id": item_id, "tenant_id": tenant_id,
                    "code": f"ST-ITEM-{tenant_id.hex[:8]}", "unit_id": unit_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO recipes(id, tenant_id, code, name, production_type, output_item_id)
                    VALUES (:id, :tenant_id, :code, 'Sterilization recipe', 'baglog', :item_id)
                    """
                ),
                {
                    "id": recipe_id, "tenant_id": tenant_id,
                    "code": f"ST-R-{tenant_id.hex[:8]}", "item_id": item_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO recipe_versions(
                        id, tenant_id, recipe_id, version_no, output_quantity,
                        output_unit_id, status
                    ) VALUES (:id, :tenant_id, :recipe_id, 1, 900, :unit_id, 'active')
                    """
                ),
                {
                    "id": recipe_version_id, "tenant_id": tenant_id,
                    "recipe_id": recipe_id, "unit_id": unit_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO production_batches(
                        id, tenant_id, location_id, production_unit_id, batch_code,
                        recipe_version_id, production_type, status,
                        planned_output_quantity, actual_output_quantity, output_unit_id
                    ) VALUES (
                        :id, :tenant_id, :location_id, :production_unit_id, :batch_code,
                        :recipe_version_id, 'baglog', 'sterilization', 900, 900, :unit_id
                    )
                    """
                ),
                {
                    "id": batch_id, "tenant_id": tenant_id, "location_id": location_id,
                    "production_unit_id": production_unit_id,
                    "batch_code": f"ST-B-{tenant_id.hex[:10]}",
                    "recipe_version_id": recipe_version_id, "unit_id": unit_id,
                },
            )
            for machine_id, suffix in [(machine_a, "A"), (machine_b, "B")]:
                connection.execute(
                    text(
                        """
                        INSERT INTO sterilizers(
                            id, tenant_id, production_unit_id, code, name,
                            capacity, capacity_unit_id, cycle_minutes, cooling_minutes, is_active
                        ) VALUES (
                            :id, :tenant_id, :production_unit_id, :code, :name,
                            500, :unit_id, 1, 0, true
                        )
                        """
                    ),
                    {
                        "id": machine_id, "tenant_id": tenant_id,
                        "production_unit_id": production_unit_id,
                        "code": f"ST-{suffix}-{tenant_id.hex[:8]}",
                        "name": f"Sterilizer {suffix}", "unit_id": unit_id,
                    },
                )

        with Session(runtime_engine) as session:
            scheduled = schedule_sterilization_cycle(
                session,
                actor_user_id=actor_id,
                tenant_id=tenant_id,
                production_unit_id=production_unit_id,
                cycle_code=f"SC-{tenant_id.hex[:10]}",
                planned_start_at=planned_start,
                sterilizers=(
                    SterilizerSchedule(
                        machine_a, (BatchSterilizationAllocation(batch_id, Decimal("450")),)
                    ),
                    SterilizerSchedule(
                        machine_b, (BatchSterilizationAllocation(batch_id, Decimal("450")),)
                    ),
                ),
            )
            assert len(scheduled.run_ids) == 2
            assert scheduled.planned_capacity == Decimal("1000")
            session.commit()

            # A second overlapping cycle on the same machine must be rejected.
            with pytest.raises(SterilizationError):
                schedule_sterilization_cycle(
                    session,
                    actor_user_id=actor_id,
                    tenant_id=tenant_id,
                    production_unit_id=production_unit_id,
                    cycle_code=f"SC-OVERLAP-{tenant_id.hex[:8]}",
                    planned_start_at=planned_start,
                    sterilizers=(
                        SterilizerSchedule(
                            machine_a, (BatchSterilizationAllocation(batch_id, Decimal("10")),)
                        ),
                    ),
                )
            session.rollback()

            # The original cycle remains intact after the rejected request.
            for run_id in scheduled.run_ids:
                started = start_sterilization_run(
                    session, actor_user_id=actor_id, tenant_id=tenant_id, run_id=run_id
                )
                assert started.status == "running"
            session.commit()

            for run_id in scheduled.run_ids:
                completed = complete_sterilization_run(
                    session, actor_user_id=actor_id, tenant_id=tenant_id, run_id=run_id
                )
                assert completed.status == "completed"
            session.commit()

            cooled = complete_sterilization_cooling(
                session, actor_user_id=actor_id, tenant_id=tenant_id,
                cycle_id=scheduled.cycle_id,
            )
            assert cooled.status == "cooling_completed"
            session.commit()

            session.execute(
                text("SELECT set_config('app.tenant_id', :tenant_id, true)"),
                {"tenant_id": str(tenant_id)},
            )
            result = session.execute(
                text(
                    """
                    SELECT c.status, c.cooling_completed_at, c.planned_capacity,
                           count(DISTINCT r.id) AS run_count,
                           sum(rb.allocated_quantity) AS allocated_quantity,
                           count(DISTINCT e.id) AS event_count
                      FROM sterilization_cycles c
                      JOIN sterilization_runs r
                        ON r.tenant_id=c.tenant_id AND r.cycle_id=c.id
                      JOIN sterilization_run_batches rb
                        ON rb.tenant_id=r.tenant_id AND rb.sterilization_run_id=r.id
                      JOIN sterilization_cycle_events e
                        ON e.tenant_id=c.tenant_id AND e.cycle_id=c.id
                     WHERE c.tenant_id=:tenant_id AND c.id=:cycle_id
                     GROUP BY c.status, c.cooling_completed_at, c.planned_capacity
                    """
                ),
                {"tenant_id": str(tenant_id), "cycle_id": scheduled.cycle_id},
            ).mappings().one()
            assert result["status"] == "completed"
            assert result["cooling_completed_at"] is not None
            assert Decimal(result["planned_capacity"]) == Decimal("1000")
            assert int(result["run_count"]) == 2
            assert Decimal(result["allocated_quantity"]) == Decimal("900")
            assert int(result["event_count"]) == 6

    finally:
        runtime_engine.dispose()
        admin_engine.dispose()

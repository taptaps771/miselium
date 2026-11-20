from __future__ import annotations

import os
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

from app.backend.services.production_placement import (
    ProductionPlacementError,
    mark_incubation_ready,
    materialize_variety_segments,
    move_lot_segment,
    place_lot_segment,
)


def _urls() -> tuple[str, str]:
    admin_url = os.getenv("MISELIUM_ADMIN_DATABASE_URL")
    runtime_url = os.getenv("MISELIUM_DATABASE_URL")
    if not admin_url or not runtime_url:
        pytest.skip("PostgreSQL M10 placement environment is not configured")
    return admin_url, runtime_url


def test_incubation_readiness_variety_lineage_and_kumbung_capacity():
    admin_url, runtime_url = _urls()
    tenant_id, actor_id = uuid4(), uuid4()
    location_id, production_unit_id, unit_id = uuid4(), uuid4(), uuid4()
    item_id, inventory_lot_id, recipe_id, recipe_version_id = (uuid4() for _ in range(4))
    batch_id, production_lot_id, variety_id = uuid4(), uuid4(), uuid4()
    inoculation_run_id, allocation_id, incubation_id = uuid4(), uuid4(), uuid4()
    kumbung_a, kumbung_b = uuid4(), uuid4()
    admin_engine = create_engine(admin_url)
    runtime_engine = create_engine(runtime_url)
    expected_move_at = datetime.now(UTC) - timedelta(days=30)

    try:
        with admin_engine.begin() as connection:
            connection.execute(
                text("INSERT INTO users(id, username, status) VALUES (:id, :username, 'active')"),
                {"id": actor_id, "username": f"m10-placement-{actor_id.hex}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO tenants(id, code, name, status, approved_at, approval_reason)
                    VALUES (:id, :code, 'M10 placement', 'active', now(), 'M10.1.7 fixture')
                    """
                ),
                {"id": tenant_id, "code": f"m10-pl-{tenant_id.hex[:12]}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO tenant_modules(tenant_id,module_id,status)
                    SELECT :tenant_id,id,'enabled' FROM modules WHERE code='production'
                    """
                ),
                {"tenant_id": tenant_id},
            )
            connection.execute(
                text(
                    "INSERT INTO measurement_units(id,code,name,dimension) "
                    "VALUES (:id,:code,'Baglog','count')"
                ),
                {"id": unit_id, "code": f"pl-{unit_id.hex[:18]}"},
            )
            connection.execute(
                text(
                    "INSERT INTO locations(id,tenant_id,code,name) "
                    "VALUES (:id,:tenant_id,:code,'Placement location')"
                ),
                {"id": location_id, "tenant_id": tenant_id, "code": f"PL-{tenant_id.hex[:8]}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO production_units(id,tenant_id,location_id,code,name)
                    VALUES (:id,:tenant_id,:location_id,:code,'Placement unit')
                    """
                ),
                {
                    "id": production_unit_id, "tenant_id": tenant_id,
                    "location_id": location_id, "code": f"PU-{tenant_id.hex[:8]}",
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO mushroom_varieties(id,tenant_id,code,name,is_active)
                    VALUES (:id,:tenant_id,:code,'Jamur Tiram Putih',true)
                    """
                ),
                {"id": variety_id, "tenant_id": tenant_id, "code": f"V-{tenant_id.hex[:8]}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO inventory_items(id,tenant_id,code,name,item_type,base_unit_id)
                    VALUES (:id,:tenant_id,:code,'Baglog','finished_good',:unit_id)
                    """
                ),
                {
                    "id": item_id, "tenant_id": tenant_id,
                    "code": f"PL-ITEM-{tenant_id.hex[:8]}", "unit_id": unit_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO inventory_lots(id,tenant_id,item_id,lot_code,status)
                    VALUES (:id,:tenant_id,:item_id,:lot_code,'active')
                    """
                ),
                {
                    "id": inventory_lot_id, "tenant_id": tenant_id,
                    "item_id": item_id, "lot_code": f"PL-LOT-{tenant_id.hex[:8]}",
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO recipes(id,tenant_id,code,name,production_type,output_item_id)
                    VALUES (:id,:tenant_id,:code,'Placement recipe','baglog',:item_id)
                    """
                ),
                {
                    "id": recipe_id, "tenant_id": tenant_id,
                    "code": f"PL-R-{tenant_id.hex[:8]}", "item_id": item_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO recipe_versions(
                        id,tenant_id,recipe_id,version_no,output_quantity,output_unit_id,status
                    ) VALUES (:id,:tenant_id,:recipe_id,1,100,:unit_id,'active')
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
                        id,tenant_id,location_id,production_unit_id,batch_code,
                        recipe_version_id,production_type,status,planned_output_quantity,
                        actual_output_quantity,output_unit_id
                    ) VALUES (
                        :id,:tenant_id,:location_id,:production_unit_id,:batch_code,
                        :recipe_version_id,'baglog','incubation',100,100,:unit_id
                    )
                    """
                ),
                {
                    "id": batch_id, "tenant_id": tenant_id, "location_id": location_id,
                    "production_unit_id": production_unit_id,
                    "batch_code": f"PL-B-{tenant_id.hex[:10]}",
                    "recipe_version_id": recipe_version_id, "unit_id": unit_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO production_lots(
                        id,tenant_id,batch_id,inventory_lot_id,variety_id,
                        output_quantity,output_unit_id,produced_at
                    ) VALUES (:id,:tenant_id,:batch_id,:inventory_lot_id,NULL,100,:unit_id,now())
                    """
                ),
                {
                    "id": production_lot_id, "tenant_id": tenant_id, "batch_id": batch_id,
                    "inventory_lot_id": inventory_lot_id, "unit_id": unit_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO inoculation_runs(
                        id,tenant_id,production_unit_id,run_code,status,started_at,completed_at
                    ) VALUES (:id,:tenant_id,:production_unit_id,:run_code,'completed',now(),now())
                    """
                ),
                {
                    "id": inoculation_run_id, "tenant_id": tenant_id,
                    "production_unit_id": production_unit_id,
                    "run_code": f"PL-INOC-{tenant_id.hex[:8]}",
                },
            )
            # Seed a valid historical allocation. Its domain guard is exercised
            # by the M10.1.6 service/integration test; this fixture focuses on
            # the downstream immutable lineage and placement workflow.
            connection.execute(text("ALTER TABLE inoculation_allocations DISABLE TRIGGER USER"))
            connection.execute(
                text(
                    """
                    INSERT INTO inoculation_allocations(
                        id,tenant_id,inoculation_run_id,batch_id,variety_id,
                        allocated_quantity,quantity_unit_id
                    ) VALUES (:id,:tenant_id,:run_id,:batch_id,:variety_id,100,:unit_id)
                    """
                ),
                {
                    "id": allocation_id, "tenant_id": tenant_id,
                    "run_id": inoculation_run_id, "batch_id": batch_id,
                    "variety_id": variety_id, "unit_id": unit_id,
                },
            )
            connection.execute(text("ALTER TABLE inoculation_allocations ENABLE TRIGGER USER"))
            connection.execute(
                text(
                    """
                    INSERT INTO incubation_records(
                        id,tenant_id,batch_id,sequence_no,incubation_location_id,
                        started_at,target_days,expected_move_at,status
                    ) VALUES (
                        :id,:tenant_id,:batch_id,1,:location_id,
                        :started_at,30,:expected_move_at,'incubating'
                    )
                    """
                ),
                {
                    "id": incubation_id, "tenant_id": tenant_id, "batch_id": batch_id,
                    "location_id": location_id,
                    "started_at": expected_move_at - timedelta(days=30),
                    "expected_move_at": expected_move_at,
                },
            )
            for kumbung_id, suffix in ((kumbung_a, "A"), (kumbung_b, "B")):
                connection.execute(
                    text(
                        """
                        INSERT INTO kumbungs(
                            id,tenant_id,location_id,code,name,capacity,capacity_unit,
                            capacity_unit_id,is_active
                        ) VALUES (
                            :id,:tenant_id,:location_id,:code,:name,60,'baglog',:unit_id,true
                        )
                        """
                    ),
                    {
                        "id": kumbung_id, "tenant_id": tenant_id, "location_id": location_id,
                        "code": f"PL-K-{suffix}-{tenant_id.hex[:6]}",
                        "name": f"Placement kumbung {suffix}", "unit_id": unit_id,
                    },
                )

        with Session(runtime_engine) as session:
            segments = materialize_variety_segments(
                session, actor_user_id=actor_id, tenant_id=tenant_id, batch_id=batch_id
            )
            assert segments.segment_count == 1
            assert segments.total_quantity == Decimal("100")
            session.commit()

            ready = mark_incubation_ready(
                session, actor_user_id=actor_id, tenant_id=tenant_id,
                batch_id=batch_id, incubation_record_id=incubation_id,
                idempotency_key=f"ready-{batch_id.hex}",
            )
            assert ready.was_replayed is False
            session.commit()

            placed = place_lot_segment(
                session, actor_user_id=actor_id, tenant_id=tenant_id,
                segment_id=segments.segment_ids[0], kumbung_id=kumbung_a,
                quantity=Decimal("50"), unit_id=unit_id,
            )
            assert placed.quantity_delta == Decimal("50")
            session.commit()

            moved_out, moved_in = move_lot_segment(
                session, actor_user_id=actor_id, tenant_id=tenant_id,
                segment_id=segments.segment_ids[0], source_kumbung_id=kumbung_a,
                destination_kumbung_id=kumbung_b, quantity=Decimal("20"), unit_id=unit_id,
            )
            assert moved_out.quantity_delta == Decimal("-20")
            assert moved_in.quantity_delta == Decimal("20")
            session.commit()

            with pytest.raises(ProductionPlacementError):
                place_lot_segment(
                    session, actor_user_id=actor_id, tenant_id=tenant_id,
                    segment_id=segments.segment_ids[0], kumbung_id=kumbung_b,
                    quantity=Decimal("50"), unit_id=unit_id,
                )
            session.rollback()

            session.execute(
                text("SELECT set_config('app.tenant_id',:tenant_id,true)"),
                {"tenant_id": str(tenant_id)},
            )
            state = session.execute(
                text(
                    """
                    SELECT b.status, s.quantity,
                           (SELECT COALESCE(sum(quantity_delta),0)
                              FROM kumbung_placements p
                             WHERE p.tenant_id=s.tenant_id
                               AND p.production_lot_segment_id=s.id) AS placed_quantity,
                           (SELECT count(*) FROM incubation_record_events e
                             WHERE e.tenant_id=s.tenant_id
                               AND e.incubation_record_id=:incubation_id) AS incubation_events
                      FROM production_lot_segments s
                      JOIN production_batches b
                        ON b.tenant_id=s.tenant_id AND b.id=s.batch_id
                     WHERE s.tenant_id=:tenant_id AND s.id=:segment_id
                    """
                ),
                {
                    "tenant_id": str(tenant_id), "segment_id": str(segments.segment_ids[0]),
                    "incubation_id": str(incubation_id),
                },
            ).mappings().one()
            assert state["status"] == "ready"
            assert Decimal(state["quantity"]) == Decimal("100")
            assert Decimal(state["placed_quantity"]) == Decimal("50")
            assert int(state["incubation_events"]) == 1
    finally:
        runtime_engine.dispose()
        admin_engine.dispose()

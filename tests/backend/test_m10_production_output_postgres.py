from __future__ import annotations

import os
from decimal import Decimal
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

from app.backend.services.inventory import (
    consume_production_materials,
    post_inventory_document,
)
from app.backend.services.production_output import post_production_output


def _urls() -> tuple[str, str]:
    admin_url = os.getenv("MISELIUM_ADMIN_DATABASE_URL")
    runtime_url = os.getenv("MISELIUM_DATABASE_URL")
    if not admin_url or not runtime_url:
        pytest.skip("PostgreSQL M10 production-output environment is not configured")
    return admin_url, runtime_url


def test_press_output_posts_inventory_lot_ledger_and_replays_once():
    admin_url, runtime_url = _urls()
    tenant_id, actor_id = uuid4(), uuid4()
    location_id, production_unit_id, unit_id = uuid4(), uuid4(), uuid4()
    material_id, output_item_id = uuid4(), uuid4()
    recipe_id, recipe_version_id, batch_id = (uuid4() for _ in range(3))
    warehouse_id, machine_id = uuid4(), uuid4()
    receipt_id, consumption_id = uuid4(), uuid4()
    receipt_line_id, consumption_line_id = uuid4(), uuid4()
    admin_engine = create_engine(admin_url)
    runtime_engine = create_engine(runtime_url)

    try:
        with admin_engine.begin() as connection:
            connection.execute(
                text("INSERT INTO users(id, username, status) VALUES (:id, :name, 'active')"),
                {"id": actor_id, "name": f"m10-output-{actor_id.hex}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO tenants(id, code, name, status, approved_at, approval_reason)
                    VALUES (:id, :code, 'M10 output', 'active', now(), 'M10.1.4 fixture')
                    """
                ),
                {"id": tenant_id, "code": f"m10-out-{tenant_id.hex[:14]}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO tenant_modules(tenant_id, module_id, status)
                    SELECT :tenant_id, id, 'enabled' FROM modules
                     WHERE code IN ('inventory','production')
                    """
                ),
                {"tenant_id": tenant_id},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO measurement_units(id, code, name, dimension)
                    VALUES (:id, :code, 'Piece', 'count')
                    """
                ),
                {"id": unit_id, "code": f"out-{unit_id.hex[:18]}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO locations(id, tenant_id, code, name)
                    VALUES (:id, :tenant_id, :code, 'Output location')
                    """
                ),
                {"id": location_id, "tenant_id": tenant_id, "code": f"OL-{tenant_id.hex[:8]}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO production_units(id, tenant_id, location_id, code, name)
                    VALUES (:id, :tenant_id, :location_id, :code, 'Output unit')
                    """
                ),
                {
                    "id": production_unit_id, "tenant_id": tenant_id,
                    "location_id": location_id, "code": f"OU-{tenant_id.hex[:8]}",
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO warehouses(id, tenant_id, location_id, code, name)
                    VALUES (:id, :tenant_id, :location_id, :code, 'Production output')
                    """
                ),
                {
                    "id": warehouse_id, "tenant_id": tenant_id,
                    "location_id": location_id, "code": f"WH-{tenant_id.hex[:8]}",
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO inventory_items(id, tenant_id, code, name, item_type, base_unit_id)
                    VALUES
                      (:material_id, :tenant_id, :material_code, 'Raw material', 'raw_material', :unit_id),
                      (:output_id, :tenant_id, :output_code, 'Baglog', 'finished_good', :unit_id)
                    """
                ),
                {
                    "material_id": material_id, "output_id": output_item_id,
                    "tenant_id": tenant_id, "material_code": f"MAT-{tenant_id.hex[:8]}",
                    "output_code": f"OUT-{tenant_id.hex[:8]}", "unit_id": unit_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO recipes(id, tenant_id, code, name, production_type, output_item_id)
                    VALUES (:id, :tenant_id, :code, 'Baglog recipe', 'baglog', :item_id)
                    """
                ),
                {
                    "id": recipe_id, "tenant_id": tenant_id,
                    "code": f"R-{tenant_id.hex[:8]}", "item_id": output_item_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO recipe_versions(
                        id, tenant_id, recipe_id, version_no, output_quantity,
                        output_unit_id, status
                    ) VALUES (:id, :tenant_id, :recipe_id, 1, 100, :unit_id, 'active')
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
                        planned_output_quantity, output_unit_id
                    ) VALUES (
                        :id, :tenant_id, :location_id, :production_unit_id, :batch_code,
                        :recipe_version_id, 'baglog', 'mixing', 100, :unit_id
                    )
                    """
                ),
                {
                    "id": batch_id, "tenant_id": tenant_id, "location_id": location_id,
                    "production_unit_id": production_unit_id,
                    "batch_code": f"B-{tenant_id.hex[:12]}",
                    "recipe_version_id": recipe_version_id, "unit_id": unit_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO production_machines(
                        id, tenant_id, location_id, production_unit_id,
                        machine_type_code, code, name, status
                    ) VALUES (
                        :id, :tenant_id, :location_id, :production_unit_id,
                        'PRESS_BAGLOG', :code, 'Press machine', 'active'
                    )
                    """
                ),
                {
                    "id": machine_id, "tenant_id": tenant_id, "location_id": location_id,
                    "production_unit_id": production_unit_id, "code": f"PM-{tenant_id.hex[:8]}",
                },
            )
            for doc_id, doc_no, doc_type, source_ref in [
                (receipt_id, f"RCV-{tenant_id.hex[:8]}", "receipt", None),
                (consumption_id, f"CON-{tenant_id.hex[:8]}", "production_consumption", batch_id),
            ]:
                connection.execute(
                    text(
                        """
                        INSERT INTO inventory_documents(
                            id, tenant_id, document_no, document_type,
                            destination_warehouse_id, source_warehouse_id,
                            source_reference_type, source_reference_id
                        ) VALUES (
                            :id, :tenant_id, :doc_no, :doc_type,
                            :destination, :source, :source_type, :source_ref
                        )
                        """
                    ),
                    {
                        "id": doc_id, "tenant_id": tenant_id, "doc_no": doc_no,
                        "doc_type": doc_type,
                        "destination": warehouse_id if doc_type == "receipt" else None,
                        "source": warehouse_id if doc_type == "production_consumption" else None,
                        "source_type": "production_batch" if source_ref else None,
                        "source_ref": source_ref,
                    },
                )
            for line_id, doc_id, item_id, quantity, unit_cost, line_value in [
                (receipt_line_id, receipt_id, material_id, 100, 10, 1000),
                (consumption_line_id, consumption_id, material_id, 10, 0, 0),
            ]:
                connection.execute(
                    text(
                        """
                        INSERT INTO inventory_document_lines(
                            id, tenant_id, document_id, line_no, item_id,
                            item_code_snapshot, item_name_snapshot, quantity,
                            unit_id, unit_name_snapshot, conversion_to_base_snapshot,
                            base_quantity, unit_cost_snapshot, currency, line_value_snapshot
                        ) VALUES (
                            :id, :tenant_id, :doc_id, 1, :item_id,
                            'MAT', 'Material', :quantity, :unit_id, 'Piece',
                            1, :quantity, :unit_cost, 'IDR', :line_value
                        )
                        """
                    ),
                    {
                        "id": line_id, "tenant_id": tenant_id, "doc_id": doc_id,
                        "item_id": item_id, "quantity": quantity, "unit_id": unit_id,
                        "unit_cost": unit_cost, "line_value": line_value,
                    },
                )

        with Session(runtime_engine) as session:
            receipt = post_inventory_document(
                session, actor_user_id=actor_id, tenant_id=tenant_id, document_id=receipt_id
            )
            assert receipt.ledger_entries == 1
            session.commit()
            consumed = consume_production_materials(
                session, actor_user_id=actor_id, tenant_id=tenant_id,
                batch_id=batch_id, inventory_document_id=consumption_id,
            )
            assert consumed.material_cost == Decimal("100")
            session.commit()

        with admin_engine.begin() as connection:
            connection.execute(
                text("UPDATE production_batches SET status='press_baglog' WHERE tenant_id=:tenant_id AND id=:batch_id"),
                {"tenant_id": tenant_id, "batch_id": batch_id},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO production_press_outputs(
                        tenant_id, batch_id, sequence_no, machine_id,
                        processed_quantity, good_quantity, rejected_quantity,
                        quantity_unit_id, recorded_by
                    ) VALUES (
                        :tenant_id, :batch_id, 1, :machine_id,
                        100, 90, 10, :unit_id, :actor_id
                    )
                    """
                ),
                {
                    "tenant_id": tenant_id, "batch_id": batch_id,
                    "machine_id": machine_id, "unit_id": unit_id, "actor_id": actor_id,
                },
            )
            connection.execute(
                text("UPDATE production_batches SET status='sterilization' WHERE tenant_id=:tenant_id AND id=:batch_id"),
                {"tenant_id": tenant_id, "batch_id": batch_id},
            )

        with Session(runtime_engine) as session:
            posted = post_production_output(
                session, actor_user_id=actor_id, tenant_id=tenant_id,
                batch_id=batch_id, warehouse_id=warehouse_id,
            )
            assert posted.output_quantity == Decimal("90")
            assert posted.material_cost == Decimal("100")
            assert posted.was_already_posted is False
            session.commit()

            replay = post_production_output(
                session, actor_user_id=actor_id, tenant_id=tenant_id,
                batch_id=batch_id, warehouse_id=warehouse_id,
            )
            assert replay.was_already_posted is True
            assert replay.posting_id == posted.posting_id
            session.commit()

            session.execute(
                text("SELECT set_config('app.tenant_id', :tenant_id, true)"),
                {"tenant_id": str(tenant_id)},
            )
            result = session.execute(
                text(
                    """
                    SELECT p.output_quantity, p.material_cost_snapshot,
                           d.status, count(le.id) AS ledger_entries,
                           count(DISTINCT pl.id) AS production_lots
                      FROM production_output_postings p
                      JOIN inventory_documents d
                        ON d.tenant_id=p.tenant_id AND d.id=p.inventory_document_id
                      JOIN inventory_ledger_entries le
                        ON le.tenant_id=d.tenant_id AND le.document_id=d.id
                      JOIN production_lots pl
                        ON pl.tenant_id=p.tenant_id AND pl.id=p.production_lot_id
                     WHERE p.tenant_id=:tenant_id AND p.batch_id=:batch_id
                     GROUP BY p.output_quantity, p.material_cost_snapshot, d.status
                    """
                ),
                {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
            ).mappings().one()
            assert Decimal(result["output_quantity"]) == Decimal("90")
            assert Decimal(result["material_cost_snapshot"]) == Decimal("100")
            assert result["status"] == "posted"
            assert int(result["ledger_entries"]) == 1
            assert int(result["production_lots"]) == 1
            assert int(session.execute(
                text("SELECT count(*) FROM production_losses WHERE tenant_id=:tenant_id AND batch_id=:batch_id AND stage='press_baglog'"),
                {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
            ).scalar_one()) == 1

    finally:
        runtime_engine.dispose()
        admin_engine.dispose()

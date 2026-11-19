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
    reverse_inventory_document,
)


def _urls() -> tuple[str, str]:
    admin_url = os.getenv("MISELIUM_ADMIN_DATABASE_URL")
    runtime_url = os.getenv("MISELIUM_DATABASE_URL")
    if not admin_url or not runtime_url:
        pytest.skip("PostgreSQL M10 application-service environment is not configured")
    return admin_url, runtime_url


def test_m10_inventory_posting_transfer_reversal_and_production_consumption():
    admin_url, runtime_url = _urls()
    tenant_id, actor_id = uuid4(), uuid4()
    location_id, unit_id, production_unit_id = uuid4(), uuid4(), uuid4()
    warehouse_a, warehouse_b, item_id = uuid4(), uuid4(), uuid4()
    recipe_id, recipe_version_id, batch_id = uuid4(), uuid4(), uuid4()
    receipt_id, issue_id, transfer_id, consumption_id = (uuid4() for _ in range(4))
    receipt_line, issue_line, transfer_line, consumption_line = (uuid4() for _ in range(4))
    admin_engine = create_engine(admin_url)
    runtime_engine = create_engine(runtime_url)

    try:
        with admin_engine.begin() as connection:
            connection.execute(
                text("INSERT INTO users(id, username, status) VALUES (:id, :name, 'active')"),
                {"id": actor_id, "name": f"m10-service-{actor_id.hex}"},
            )
            connection.execute(
                text("INSERT INTO tenants(id, code, name, status) VALUES (:id, :code, 'M10 service', 'active')"),
                {"id": tenant_id, "code": f"m10-{tenant_id.hex[:16]}"},
            )
            connection.execute(
                text("INSERT INTO measurement_units(id, code, name, dimension) VALUES (:id, :code, 'Piece', 'count')"),
                {"id": unit_id, "code": f"u-{unit_id.hex[:20]}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO locations(id, tenant_id, code, name)
                    VALUES (:id, :tenant_id, 'MAIN', 'Main')
                    """
                ),
                {"id": location_id, "tenant_id": tenant_id},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO warehouses(id, tenant_id, location_id, code, name)
                    VALUES
                      (:a, :tenant_id, :location_id, 'A', 'Warehouse A'),
                      (:b, :tenant_id, :location_id, 'B', 'Warehouse B')
                    """
                ),
                {"a": warehouse_a, "b": warehouse_b, "tenant_id": tenant_id, "location_id": location_id},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO production_units(id, tenant_id, location_id, code, name)
                    VALUES (:id, :tenant_id, 'MIX', 'Mixing')
                    """
                ),
                {"id": production_unit_id, "tenant_id": tenant_id, "location_id": location_id},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO inventory_items(
                        id, tenant_id, code, name, item_type, base_unit_id, allow_negative_stock
                    ) VALUES (:id, :tenant_id, 'MAT-1', 'Material 1', 'raw_material', :unit_id, false)
                    """
                ),
                {"id": item_id, "tenant_id": tenant_id, "unit_id": unit_id},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO recipes(id, tenant_id, code, name, production_type, output_item_id)
                    VALUES (:id, :tenant_id, 'R-1', 'Recipe 1', 'baglog', :item_id)
                    """
                ),
                {"id": recipe_id, "tenant_id": tenant_id, "item_id": item_id},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO recipe_versions(
                        id, tenant_id, recipe_id, version_no, output_quantity, output_unit_id, status
                    ) VALUES (:id, :tenant_id, :recipe_id, 1, 100, :unit_id, 'active')
                    """
                ),
                {"id": recipe_version_id, "tenant_id": tenant_id, "recipe_id": recipe_id, "unit_id": unit_id},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO production_batches(
                        id, tenant_id, location_id, production_unit_id, batch_code,
                        recipe_version_id, production_type, status,
                        planned_output_quantity, output_unit_id
                    ) VALUES (
                        :id, :tenant_id, :location_id, :unit_id, 'BATCH-1',
                        :recipe_version_id, 'baglog', 'planned', 100, :output_unit_id
                    )
                    """
                ),
                {
                    "id": batch_id, "tenant_id": tenant_id, "location_id": location_id,
                    "unit_id": production_unit_id, "recipe_version_id": recipe_version_id,
                    "output_unit_id": unit_id,
                },
            )

            documents = [
                (receipt_id, "RCV-1", "receipt", None, warehouse_a, None),
                (issue_id, "ISS-1", "issue", warehouse_a, None, None),
                (transfer_id, "TRF-1", "transfer", warehouse_a, warehouse_b, None),
                (consumption_id, "CON-1", "production_consumption", warehouse_a, None, batch_id),
            ]
            for doc_id, doc_no, doc_type, source, destination, source_ref in documents:
                connection.execute(
                    text(
                        """
                        INSERT INTO inventory_documents(
                            id, tenant_id, document_no, document_type,
                            source_warehouse_id, destination_warehouse_id,
                            source_reference_type, source_reference_id
                        ) VALUES (
                            :id, :tenant_id, :doc_no, :doc_type, :source, :destination,
                            :source_type, :source_ref
                        )
                        """
                    ),
                    {
                        "id": doc_id, "tenant_id": tenant_id, "doc_no": doc_no,
                        "doc_type": doc_type, "source": source, "destination": destination,
                        "source_type": "production_batch" if source_ref else None,
                        "source_ref": source_ref,
                    },
                )

            lines = [
                (receipt_line, receipt_id, 1, 100, 10, 1000),
                (issue_line, issue_id, 1, 30, 0, 0),
                (transfer_line, transfer_id, 1, 20, 0, 0),
                (consumption_line, consumption_id, 1, 10, 0, 0),
            ]
            for line_id, doc_id, line_no, quantity, unit_cost, line_value in lines:
                connection.execute(
                    text(
                        """
                        INSERT INTO inventory_document_lines(
                            id, tenant_id, document_id, line_no, item_id,
                            item_code_snapshot, item_name_snapshot, quantity,
                            unit_id, unit_name_snapshot, conversion_to_base_snapshot,
                            base_quantity, unit_cost_snapshot, currency, line_value_snapshot
                        ) VALUES (
                            :id, :tenant_id, :doc_id, :line_no, :item_id,
                            'MAT-1', 'Material 1', :quantity, :unit_id, 'Piece',
                            1, :quantity, :unit_cost, 'IDR', :line_value
                        )
                        """
                    ),
                    {
                        "id": line_id, "tenant_id": tenant_id, "doc_id": doc_id,
                        "line_no": line_no, "item_id": item_id, "quantity": quantity,
                        "unit_id": unit_id, "unit_cost": unit_cost, "line_value": line_value,
                    },
                )

        with Session(runtime_engine) as session:
            def set_tenant_context() -> None:
                session.execute(
                    text("SELECT set_config('app.tenant_id', :tenant_id, true)"),
                    {"tenant_id": str(tenant_id)},
                )

            receipt = post_inventory_document(
                session, actor_user_id=actor_id, tenant_id=tenant_id, document_id=receipt_id
            )
            assert receipt.ledger_entries == 1
            session.commit()

            duplicate = post_inventory_document(
                session, actor_user_id=actor_id, tenant_id=tenant_id, document_id=receipt_id
            )
            assert duplicate.was_already_posted
            session.commit()

            post_inventory_document(
                session, actor_user_id=actor_id, tenant_id=tenant_id, document_id=issue_id
            )
            session.commit()
            post_inventory_document(
                session, actor_user_id=actor_id, tenant_id=tenant_id, document_id=transfer_id
            )
            session.commit()
            set_tenant_context()

            source_balance = session.execute(
                text(
                    """
                    SELECT sum(quantity_delta) FROM inventory_ledger_entries
                     WHERE tenant_id=:tenant_id AND warehouse_id=:warehouse_id AND item_id=:item_id
                    """
                ),
                {"tenant_id": str(tenant_id), "warehouse_id": str(warehouse_a), "item_id": str(item_id)},
            ).scalar_one()
            destination_balance = session.execute(
                text(
                    """
                    SELECT sum(quantity_delta) FROM inventory_ledger_entries
                     WHERE tenant_id=:tenant_id AND warehouse_id=:warehouse_id AND item_id=:item_id
                    """
                ),
                {"tenant_id": str(tenant_id), "warehouse_id": str(warehouse_b), "item_id": str(item_id)},
            ).scalar_one()
            assert Decimal(source_balance) == Decimal("50")
            assert Decimal(destination_balance) == Decimal("20")

            reversal = reverse_inventory_document(
                session,
                actor_user_id=actor_id,
                tenant_id=tenant_id,
                document_id=transfer_id,
                reversal_document_no="TRF-1-REV",
            )
            assert reversal.ledger_entries == 2
            session.commit()
            set_tenant_context()
            destination_after_reversal = session.execute(
                text(
                    """
                    SELECT sum(quantity_delta) FROM inventory_ledger_entries
                     WHERE tenant_id=:tenant_id AND warehouse_id=:warehouse_id AND item_id=:item_id
                    """
                ),
                {"tenant_id": str(tenant_id), "warehouse_id": str(warehouse_b), "item_id": str(item_id)},
            ).scalar_one()
            assert Decimal(destination_after_reversal) == Decimal("0")
            original_status = session.execute(
                text("SELECT status FROM inventory_documents WHERE tenant_id=:tenant_id AND id=:id"),
                {"tenant_id": str(tenant_id), "id": str(transfer_id)},
            ).scalar_one()
            assert original_status == "reversed"

            consumed = consume_production_materials(
                session,
                actor_user_id=actor_id,
                tenant_id=tenant_id,
                batch_id=batch_id,
                inventory_document_id=consumption_id,
            )
            assert consumed.consumed_lines == 1
            assert consumed.material_cost == Decimal("100")
            session.commit()
            set_tenant_context()

            frozen_cost = session.execute(
                text(
                    """
                    SELECT material_cost_snapshot FROM production_batch_consumptions
                     WHERE tenant_id=:tenant_id AND batch_id=:batch_id
                    """
                ),
                {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
            ).scalar_one()
            assert Decimal(frozen_cost) == Decimal("100")

    finally:
        runtime_engine.dispose()
        admin_engine.dispose()

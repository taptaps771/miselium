from __future__ import annotations

import os
from decimal import Decimal
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

from app.backend.services.production_reconciliation import (
    ProductionReconciliationError,
    record_production_loss,
    recover_production_loss,
    reconcile_and_close_batch,
    set_production_loss_disposition,
)


def _urls() -> tuple[str, str]:
    admin_url = os.getenv("MISELIUM_ADMIN_DATABASE_URL")
    runtime_url = os.getenv("MISELIUM_DATABASE_URL")
    if not admin_url or not runtime_url:
        pytest.skip("PostgreSQL M10 reconciliation environment is not configured")
    return admin_url, runtime_url


def test_production_loss_idempotency_and_immutable_event_history():
    admin_url, runtime_url = _urls()
    tenant_id, actor_id = uuid4(), uuid4()
    location_id, production_unit_id, unit_id = uuid4(), uuid4(), uuid4()
    kg_unit_id, recovery_item_id = uuid4(), uuid4()
    item_id, recipe_id, recipe_version_id, batch_id = (uuid4() for _ in range(4))
    inventory_lot_id, production_lot_id, warehouse_id = uuid4(), uuid4(), uuid4()
    consumption_document_id, consumption_line_id = uuid4(), uuid4()
    admin_engine = create_engine(admin_url)
    runtime_engine = create_engine(runtime_url)

    try:
        with admin_engine.begin() as connection:
            connection.execute(
                text("INSERT INTO users(id,username,status) VALUES (:id,:username,'active')"),
                {"id": actor_id, "username": f"m10-loss-{actor_id.hex}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO tenants(id,code,name,status,approved_at,approval_reason)
                    VALUES (:id,:code,'M10 loss','active',now(),'M10.1.8 fixture')
                    """
                ),
                {"id": tenant_id, "code": f"m10-loss-{tenant_id.hex[:12]}"},
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
                {"id": unit_id, "code": f"loss-{unit_id.hex[:18]}"},
            )
            connection.execute(
                text(
                    "INSERT INTO measurement_units(id,code,name,dimension) "
                    "VALUES (:id,:code,'Kilogram','mass')"
                ),
                {"id": kg_unit_id, "code": f"loss-kg-{kg_unit_id.hex[:14]}"},
            )
            connection.execute(
                text(
                    "INSERT INTO locations(id,tenant_id,code,name) "
                    "VALUES (:id,:tenant_id,:code,'Loss location')"
                ),
                {"id": location_id, "tenant_id": tenant_id, "code": f"LL-{tenant_id.hex[:8]}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO production_units(id,tenant_id,location_id,code,name)
                    VALUES (:id,:tenant_id,:location_id,:code,'Loss unit')
                    """
                ),
                {
                    "id": production_unit_id, "tenant_id": tenant_id,
                    "location_id": location_id, "code": f"LU-{tenant_id.hex[:8]}",
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO inventory_items(id,tenant_id,code,name,item_type,base_unit_id)
                    VALUES (:id,:tenant_id,:code,'Loss fixture item','finished_good',:unit_id)
                    """
                ),
                {
                    "id": item_id, "tenant_id": tenant_id,
                    "code": f"LOSS-ITEM-{tenant_id.hex[:8]}", "unit_id": unit_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO inventory_items(id,tenant_id,code,name,item_type,base_unit_id)
                    VALUES (:id,:tenant_id,:code,'Recovered media','raw_material',:unit_id)
                    """
                ),
                {
                    "id": recovery_item_id, "tenant_id": tenant_id,
                    "code": f"REC-MEDIA-{tenant_id.hex[:8]}", "unit_id": kg_unit_id,
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
                    "id": inventory_lot_id, "tenant_id": tenant_id, "item_id": item_id,
                    "lot_code": f"LOSS-LOT-{tenant_id.hex[:8]}",
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO warehouses(id,tenant_id,location_id,code,name,is_active)
                    VALUES (:id,:tenant_id,:location_id,:code,'Recovery warehouse',true)
                    """
                ),
                {
                    "id": warehouse_id, "tenant_id": tenant_id, "location_id": location_id,
                    "code": f"LOSS-WH-{tenant_id.hex[:8]}",
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO recipes(id,tenant_id,code,name,production_type,output_item_id)
                    VALUES (:id,:tenant_id,:code,'Loss recipe','baglog',:item_id)
                    """
                ),
                {
                    "id": recipe_id, "tenant_id": tenant_id,
                    "code": f"LOSS-R-{tenant_id.hex[:8]}", "item_id": item_id,
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
                        recipe_version_id,production_type,status,planned_output_quantity,output_unit_id
                    ) VALUES (
                        :id,:tenant_id,:location_id,:production_unit_id,:batch_code,
                        :recipe_version_id,'baglog','mixing',100,:unit_id
                    )
                    """
                ),
                {
                    "id": batch_id, "tenant_id": tenant_id, "location_id": location_id,
                    "production_unit_id": production_unit_id,
                    "batch_code": f"LOSS-B-{tenant_id.hex[:10]}",
                    "recipe_version_id": recipe_version_id, "unit_id": unit_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO inventory_documents(
                        id,tenant_id,document_no,document_type,status,source_warehouse_id,
                        occurred_at,posted_at,posted_by,source_reference_type,
                        source_reference_id,notes,created_by
                    ) VALUES (
                        :id,:tenant_id,:document_no,'production_consumption','draft',:warehouse_id,
                        now(),NULL,NULL,'production_batch',:batch_id,'M10 cost fixture',:actor_id
                    )
                    """
                ),
                {
                    "id": consumption_document_id, "tenant_id": tenant_id,
                    "document_no": f"LOSS-CONS-{tenant_id.hex[:8]}",
                    "warehouse_id": warehouse_id, "actor_id": actor_id, "batch_id": batch_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO inventory_document_lines(
                        id,tenant_id,document_id,line_no,item_id,lot_id,
                        item_code_snapshot,item_name_snapshot,quantity,unit_id,
                        unit_name_snapshot,conversion_to_base_snapshot,base_quantity,
                        unit_cost_snapshot,currency,line_value_snapshot
                    ) VALUES (
                        :id,:tenant_id,:document_id,1,:item_id,:lot_id,
                        :item_code,'Loss fixture item',1,:unit_id,'Baglog',1,1,1600,'IDR',1600
                    )
                    """
                ),
                {
                    "id": consumption_line_id, "tenant_id": tenant_id,
                    "document_id": consumption_document_id, "item_id": item_id,
                    "lot_id": inventory_lot_id, "item_code": f"LOSS-ITEM-{tenant_id.hex[:8]}",
                    "unit_id": unit_id,
                },
            )
            connection.execute(
                text(
                    """
                    UPDATE inventory_documents
                       SET status='posted',posted_at=now(),posted_by=:actor_id,updated_at=now()
                     WHERE tenant_id=:tenant_id AND id=:document_id
                    """
                ),
                {
                    "actor_id": actor_id, "tenant_id": tenant_id,
                    "document_id": consumption_document_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO inventory_ledger_entries(
                        tenant_id,document_id,document_line_id,warehouse_id,item_id,lot_id,
                        quantity_delta,value_delta,currency,unit_cost_snapshot,occurred_at
                    ) VALUES (
                        :tenant_id,:document_id,:line_id,:warehouse_id,:item_id,:lot_id,
                        -1,-1600,'IDR',1600,now()
                    )
                    """
                ),
                {
                    "tenant_id": tenant_id, "document_id": consumption_document_id,
                    "line_id": consumption_line_id, "warehouse_id": warehouse_id,
                    "item_id": item_id, "lot_id": inventory_lot_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO production_batch_consumptions(
                        tenant_id,batch_id,inventory_document_line_id,item_id,
                        consumed_base_quantity,material_cost_snapshot,currency,consumed_at
                    ) VALUES (
                        :tenant_id,:batch_id,:line_id,:item_id,1,1600,'IDR',now()
                    )
                    """
                ),
                {
                    "tenant_id": tenant_id, "batch_id": batch_id,
                    "line_id": consumption_line_id, "item_id": item_id,
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

        with Session(runtime_engine) as session:
            first = record_production_loss(
                session, actor_user_id=actor_id, tenant_id=tenant_id, batch_id=batch_id,
                stage="mixing", idempotency_key=f"mix-loss-{batch_id.hex}",
                reason_code="spillage", quantity=Decimal("5"), unit_id=unit_id,
                disposition="permanent_loss", notes="Spillage during mixing",
            )
            session.commit()
            replay = record_production_loss(
                session, actor_user_id=actor_id, tenant_id=tenant_id, batch_id=batch_id,
                stage="mixing", idempotency_key=f"mix-loss-{batch_id.hex}",
                reason_code="spillage", quantity=Decimal("5"), unit_id=unit_id,
                disposition="permanent_loss", notes="Spillage during mixing",
            )
            assert replay.loss_id == first.loss_id
            assert replay.disposition == "permanent_loss"
            with pytest.raises(ProductionReconciliationError):
                record_production_loss(
                    session, actor_user_id=actor_id, tenant_id=tenant_id, batch_id=batch_id,
                    stage="mixing", idempotency_key=f"mix-loss-{batch_id.hex}",
                    reason_code="spillage", quantity=Decimal("6"), unit_id=unit_id,
                    disposition="permanent_loss", notes="Different payload",
                )
            session.rollback()

            pending = record_production_loss(
                session, actor_user_id=actor_id, tenant_id=tenant_id, batch_id=batch_id,
                stage="mixing", idempotency_key=f"pending-loss-{batch_id.hex}",
                reason_code="spillage", quantity=Decimal("2"), unit_id=unit_id,
            )
            session.commit()
            resolved = set_production_loss_disposition(
                session, actor_user_id=actor_id, tenant_id=tenant_id,
                loss_id=pending.loss_id, disposition="discarded",
            )
            assert resolved.disposition == "discarded"
            session.commit()

            recoverable = record_production_loss(
                session, actor_user_id=actor_id, tenant_id=tenant_id, batch_id=batch_id,
                stage="sterilization", idempotency_key=f"sterilization-loss-{batch_id.hex}",
                reason_code="baglog_damage", quantity=Decimal("5"), unit_id=unit_id,
                recoverable=True, production_lot_id=production_lot_id,
                notes="Baglog damaged but material remains reusable",
            )
            session.commit()
            recovered = recover_production_loss(
                session, actor_user_id=actor_id, tenant_id=tenant_id,
                loss_id=recoverable.loss_id, warehouse_id=warehouse_id,
                material_value_snapshot=Decimal("8"),
                recovery_cost_snapshot=Decimal("4"),
                notes="Reuse salvageable material",
            )
            assert recovered.quantity == Decimal("5")
            assert recovered.total_cost == Decimal("12")
            session.commit()
            replayed_recovery = recover_production_loss(
                session, actor_user_id=actor_id, tenant_id=tenant_id,
                loss_id=recoverable.loss_id, warehouse_id=warehouse_id,
                material_value_snapshot=Decimal("8"),
                recovery_cost_snapshot=Decimal("4"),
            )
            assert replayed_recovery.recovery_lot_id == recovered.recovery_lot_id
            session.commit()
            with pytest.raises(ProductionReconciliationError):
                recover_production_loss(
                    session, actor_user_id=actor_id, tenant_id=tenant_id,
                    loss_id=recoverable.loss_id, warehouse_id=warehouse_id,
                    material_value_snapshot=Decimal("9"),
                    recovery_cost_snapshot=Decimal("4"),
                )
            session.rollback()

            session.execute(
                text("SELECT set_config('app.tenant_id',:tenant_id,true)"),
                {"tenant_id": str(tenant_id)},
            )
            event_counts = session.execute(
                text(
                    """
                    SELECT loss_id,count(*) AS events
                      FROM production_loss_events
                     WHERE tenant_id=:tenant_id AND loss_id IN (:loss_a,:loss_b,:loss_c)
                     GROUP BY loss_id
                    """
                ),
                {
                    "tenant_id": str(tenant_id), "loss_a": str(first.loss_id),
                    "loss_b": str(recoverable.loss_id), "loss_c": str(recycled_loss.loss_id),
                },
            ).mappings().all()
            assert {str(row["loss_id"]): int(row["events"]) for row in event_counts} == {
                str(first.loss_id): 2, str(recoverable.loss_id): 3, str(recycled_loss.loss_id): 3,
            }
            recovery_ledger = session.execute(
                text(
                    """
                    SELECT d.status,le.quantity_delta,le.value_delta,rr.disposition
                      FROM production_recovery_lots r
                      JOIN inventory_documents d
                        ON d.tenant_id=r.tenant_id AND d.id=r.inventory_document_id
                      JOIN inventory_ledger_entries le
                        ON le.tenant_id=r.tenant_id AND le.document_id=d.id
                      JOIN production_losses rr
                        ON rr.tenant_id=r.tenant_id AND rr.id=r.loss_id
                     WHERE r.tenant_id=:tenant_id AND r.id=:recovery_id
                    """
                ),
                {"tenant_id": str(tenant_id), "recovery_id": str(recovered.recovery_lot_id)},
            ).mappings().one()
            assert recovery_ledger["status"] == "posted"
            assert Decimal(recovery_ledger["quantity_delta"]) == Decimal("5")
            assert Decimal(recovery_ledger["value_delta"]) == Decimal("12")
            assert recovery_ledger["disposition"] == "recovered"
            recycled_loss = record_production_loss(
                session, actor_user_id=actor_id, tenant_id=tenant_id, batch_id=batch_id,
                stage="inoculation", idempotency_key=f"recycled-loss-{batch_id.hex}",
                reason_code="damaged_packaging", quantity=Decimal("5"), unit_id=unit_id,
                recoverable=True, production_lot_id=production_lot_id,
                notes="Media recovered for reuse in mixing",
            )
            session.commit()
            recycled = recover_production_loss(
                session, actor_user_id=actor_id, tenant_id=tenant_id,
                loss_id=recycled_loss.loss_id, warehouse_id=warehouse_id,
                material_value_snapshot=Decimal("5"),
                recovery_cost_snapshot=Decimal("2"),
                recovery_mode="recycle_to_mixing",
                recovered_item_id=recovery_item_id,
                recovered_quantity=Decimal("1.5"),
                recovered_unit_id=kg_unit_id,
                notes="Measured reusable media",
            )
            assert recycled.quantity == Decimal("1.5")
            assert recycled.total_cost == Decimal("7")
            assert recycled.disposition == "recycled"
            session.commit()
            
            recycled_ledger = session.execute(
                text(
                    """
                    SELECT le.quantity_delta,le.value_delta,rr.disposition,
                           r.loss_quantity_snapshot,r.recovered_quantity,r.recovery_mode
                      FROM production_recovery_lots r
                      JOIN inventory_ledger_entries le
                        ON le.tenant_id=r.tenant_id AND le.document_id=r.inventory_document_id
                      JOIN production_losses rr
                        ON rr.tenant_id=r.tenant_id AND rr.id=r.loss_id
                     WHERE r.tenant_id=:tenant_id AND r.loss_id=:loss_id
                    """
                ),
                {"tenant_id": str(tenant_id), "loss_id": str(recycled_loss.loss_id)},
            ).mappings().one()
            assert Decimal(recycled_ledger["quantity_delta"]) == Decimal("1.5")
            assert Decimal(recycled_ledger["value_delta"]) == Decimal("7")
            assert Decimal(recycled_ledger["loss_quantity_snapshot"]) == Decimal("5")
            assert Decimal(recycled_ledger["recovered_quantity"]) == Decimal("1.5")
            assert recycled_ledger["recovery_mode"] == "recycle_to_mixing"
            assert recycled_ledger["disposition"] == "recycled"

            terminal_loss = record_production_loss(
                session, actor_user_id=actor_id, tenant_id=tenant_id, batch_id=batch_id,
                stage="inoculation", idempotency_key=f"inoculation-loss-{batch_id.hex}",
                reason_code="contamination", quantity=Decimal("90"), unit_id=unit_id,
                disposition="permanent_loss", production_lot_id=production_lot_id,
                notes="Remaining output permanently lost during inoculation",
            )
            assert terminal_loss.disposition == "permanent_loss"
            session.commit()
            with admin_engine.begin() as connection:
                connection.execute(
                    text(
                        "UPDATE production_batches SET status='ready',actual_output_quantity=100 "
                        "WHERE tenant_id=:tenant_id AND id=:batch_id"
                    ),
                    {"tenant_id": tenant_id, "batch_id": batch_id},
                )

            finalized = reconcile_and_close_batch(
                session, actor_user_id=actor_id, tenant_id=tenant_id,
                batch_id=batch_id, idempotency_key=f"close-{batch_id.hex}",
                notes="All baglog output placed or explicitly lost/recovered",
            )
            assert finalized.output_quantity == Decimal("100")
            assert finalized.placed_quantity == Decimal("0")
            assert finalized.loss_quantity == Decimal("100")
            assert finalized.total_cost == Decimal("1587")
            assert finalized.gross_cost == Decimal("1600")
            assert finalized.recovery_credit == Decimal("13")
            assert finalized.transition.to_status == "closed"
            session.commit()

            replayed_finalization = reconcile_and_close_batch(
                session, actor_user_id=actor_id, tenant_id=tenant_id,
                batch_id=batch_id, idempotency_key=f"close-{batch_id.hex}",
                notes="All baglog output placed or explicitly lost/recovered",
            )
            assert replayed_finalization.reconciliation_id == finalized.reconciliation_id
            assert replayed_finalization.transition.was_replayed is True
            session.commit()
    finally:
        runtime_engine.dispose()
        admin_engine.dispose()

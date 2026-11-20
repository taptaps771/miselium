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
    item_id, recipe_id, recipe_version_id, batch_id = (uuid4() for _ in range(4))
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
            session.execute(
                text("SELECT set_config('app.tenant_id',:tenant_id,true)"),
                {"tenant_id": str(tenant_id)},
            )
            event_count = session.execute(
                text(
                    "SELECT count(*) FROM production_loss_events "
                    "WHERE tenant_id=:tenant_id AND loss_id=:loss_id"
                ),
                {"tenant_id": str(tenant_id), "loss_id": str(first.loss_id)},
            ).scalar_one()
            assert int(event_count) == 2
    finally:
        runtime_engine.dispose()
        admin_engine.dispose()

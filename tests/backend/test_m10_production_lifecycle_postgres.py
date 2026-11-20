from __future__ import annotations

import os
from uuid import uuid4

import pytest
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

from app.backend.services.production_lifecycle import (
    ProductionLifecycleError,
    transition_production_batch,
)


def _urls() -> tuple[str, str]:
    admin_url = os.getenv("MISELIUM_ADMIN_DATABASE_URL")
    runtime_url = os.getenv("MISELIUM_DATABASE_URL")
    if not admin_url or not runtime_url:
        pytest.skip("PostgreSQL M10 lifecycle environment is not configured")
    return admin_url, runtime_url


def test_production_batch_transition_idempotency_hold_resume_and_guards():
    admin_url, runtime_url = _urls()
    tenant_id, actor_id = uuid4(), uuid4()
    location_id, production_unit_id, unit_id = uuid4(), uuid4(), uuid4()
    item_id, recipe_id, recipe_version_id, batch_id = (uuid4() for _ in range(4))
    admin_engine = create_engine(admin_url)
    runtime_engine = create_engine(runtime_url)

    try:
        with admin_engine.begin() as connection:
            connection.execute(
                text("INSERT INTO users(id, username, status) VALUES (:id, :name, 'active')"),
                {"id": actor_id, "name": f"m10-lifecycle-{actor_id.hex}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO tenants(id, code, name, status, approved_at, approval_reason)
                    VALUES (:id, :code, 'M10 lifecycle', 'active', now(), 'M10 lifecycle fixture')
                    """
                ),
                {"id": tenant_id, "code": f"m10-life-{tenant_id.hex[:14]}"},
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
                    VALUES (:id, :code, 'Piece', 'count')
                    """
                ),
                {"id": unit_id, "code": f"life-{unit_id.hex[:18]}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO locations(id, tenant_id, code, name)
                    VALUES (:id, :tenant_id, :code, 'Lifecycle location')
                    """
                ),
                {"id": location_id, "tenant_id": tenant_id, "code": f"L-{tenant_id.hex[:8]}"},
            )
            connection.execute(
                text(
                    """
                    INSERT INTO production_units(id, tenant_id, location_id, code, name)
                    VALUES (:id, :tenant_id, :location_id, :code, 'Lifecycle unit')
                    """
                ),
                {
                    "id": production_unit_id,
                    "tenant_id": tenant_id,
                    "location_id": location_id,
                    "code": f"PU-{tenant_id.hex[:8]}",
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO inventory_items(
                        id, tenant_id, code, name, item_type, base_unit_id
                    ) VALUES (:id, :tenant_id, :code, 'Lifecycle output', 'finished_good', :unit_id)
                    """
                ),
                {
                    "id": item_id,
                    "tenant_id": tenant_id,
                    "code": f"OUT-{tenant_id.hex[:8]}",
                    "unit_id": unit_id,
                },
            )
            connection.execute(
                text(
                    """
                    INSERT INTO recipes(id, tenant_id, code, name, production_type, output_item_id)
                    VALUES (:id, :tenant_id, :code, 'Lifecycle recipe', 'baglog', :item_id)
                    """
                ),
                {
                    "id": recipe_id,
                    "tenant_id": tenant_id,
                    "code": f"R-{tenant_id.hex[:8]}",
                    "item_id": item_id,
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
                    "id": recipe_version_id,
                    "tenant_id": tenant_id,
                    "recipe_id": recipe_id,
                    "unit_id": unit_id,
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
                        :recipe_version_id, 'baglog', 'draft', 100, :unit_id
                    )
                    """
                ),
                {
                    "id": batch_id,
                    "tenant_id": tenant_id,
                    "location_id": location_id,
                    "production_unit_id": production_unit_id,
                    "batch_code": f"B-{tenant_id.hex[:12]}",
                    "recipe_version_id": recipe_version_id,
                    "unit_id": unit_id,
                },
            )

        with Session(runtime_engine) as session:
            planned = transition_production_batch(
                session,
                actor_user_id=actor_id,
                tenant_id=tenant_id,
                batch_id=batch_id,
                command="plan_batch",
                idempotency_key="plan-1",
            )
            assert planned.from_status == "draft"
            assert planned.to_status == "planned"
            session.commit()

            replay = transition_production_batch(
                session,
                actor_user_id=actor_id,
                tenant_id=tenant_id,
                batch_id=batch_id,
                command="plan_batch",
                idempotency_key="plan-1",
            )
            assert replay.was_replayed
            assert replay.event_id == planned.event_id
            session.commit()

            with pytest.raises(ProductionLifecycleError, match="different request"):
                transition_production_batch(
                    session,
                    actor_user_id=actor_id,
                    tenant_id=tenant_id,
                    batch_id=batch_id,
                    command="start_mixing",
                    idempotency_key="plan-1",
                )

            started = transition_production_batch(
                session,
                actor_user_id=actor_id,
                tenant_id=tenant_id,
                batch_id=batch_id,
                command="start_mixing",
                idempotency_key="mix-start-1",
            )
            assert started.to_status == "mixing"
            session.commit()

            with pytest.raises(ProductionLifecycleError, match="material consumption"):
                transition_production_batch(
                    session,
                    actor_user_id=actor_id,
                    tenant_id=tenant_id,
                    batch_id=batch_id,
                    command="complete_mixing",
                    idempotency_key="complete-mix-too-early",
                )

            held = transition_production_batch(
                session,
                actor_user_id=actor_id,
                tenant_id=tenant_id,
                batch_id=batch_id,
                command="hold_batch",
                idempotency_key="hold-1",
            )
            assert held.to_status == "on_hold"
            session.commit()

            resumed = transition_production_batch(
                session,
                actor_user_id=actor_id,
                tenant_id=tenant_id,
                batch_id=batch_id,
                command="resume_batch",
                idempotency_key="resume-1",
            )
            assert resumed.to_status == "mixing"
            session.commit()

            session.execute(
                text("SELECT set_config('app.tenant_id', :tenant_id, true)"),
                {"tenant_id": str(tenant_id)},
            )
            status_value = session.execute(
                text("SELECT status FROM production_batches WHERE tenant_id=:tenant_id AND id=:batch_id"),
                {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
            ).scalar_one()
            event_count = session.execute(
                text(
                    "SELECT count(*) FROM production_batch_events "
                    "WHERE tenant_id=:tenant_id AND batch_id=:batch_id"
                ),
                {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
            ).scalar_one()
            assert status_value == "mixing"
            assert int(event_count) == 4

    finally:
        runtime_engine.dispose()
        admin_engine.dispose()

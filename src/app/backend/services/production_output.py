"""Atomic press-output posting into the tenant inventory ledger.

The service creates the inventory lot, production lot, production-output
inventory document, ledger movement, posting link, batch projection, event and
audit record in the caller's transaction. Callers must authorize production
and inventory permissions and commit/rollback the transaction.
"""
from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from uuid import UUID, uuid4

from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session


class ProductionOutputError(Exception):
    """A production output posting violates a business invariant."""


class ProductionOutputPermissionDenied(PermissionError):
    """A required tenant module is not enabled or database access is denied."""


@dataclass(frozen=True, slots=True)
class ProductionOutputResult:
    batch_id: UUID
    posting_id: UUID
    inventory_document_id: UUID
    production_lot_id: UUID
    output_quantity: Decimal
    material_cost: Decimal
    currency: str
    was_already_posted: bool = False


def _set_context(session: Session, actor_user_id: UUID, tenant_id: UUID) -> None:
    session.execute(
        text("SELECT set_config('app.user_id', :user_id, true)"),
        {"user_id": str(actor_user_id)},
    )
    session.execute(
        text("SELECT set_config('app.tenant_id', :tenant_id, true)"),
        {"tenant_id": str(tenant_id)},
    )


def _require_modules(session: Session, tenant_id: UUID) -> None:
    rows = session.execute(
        text(
            """
            SELECT m.code, tm.status
              FROM tenant_modules tm
              JOIN modules m ON m.id=tm.module_id
             WHERE tm.tenant_id=:tenant_id
               AND m.code IN ('inventory','production')
            """
        ),
        {"tenant_id": str(tenant_id)},
    ).all()
    enabled = {str(row.code) for row in rows if row.status == "enabled"}
    if enabled != {"inventory", "production"}:
        raise ProductionOutputPermissionDenied(
            "Both inventory and production modules must be enabled for this tenant."
        )


def _translate_db_error(exc: DBAPIError) -> None:
    state = getattr(exc.orig, "sqlstate", getattr(exc.orig, "pgcode", None))
    if state == "42501":
        raise ProductionOutputPermissionDenied(
            "Production and inventory posting permissions are required."
        ) from None
    if state in {"23502", "23503", "23505", "23514", "22023", "P0002", "55000"}:
        raise ProductionOutputError(
            "Production output posting violates a database invariant."
        ) from None
    raise exc


def post_production_output(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    batch_id: UUID,
    warehouse_id: UUID,
) -> ProductionOutputResult:
    """Post the sum of good press output once, atomically, into inventory.

    Press rejects are deliberately excluded from finished stock. Their loss
    disposition remains a separate M10.1.8 workflow. The inventory value is
    the actual posted material-consumption cost; machine overhead is not
    silently estimated or finalized by this service.
    """
    _set_context(session, actor_user_id, tenant_id)
    _require_modules(session, tenant_id)

    try:
        batch = session.execute(
            text(
                """
                SELECT b.id, b.batch_code, b.status, b.location_id,
                       b.output_unit_id, b.production_unit_id,
                       r.output_item_id, i.code AS item_code, i.name AS item_name,
                       i.base_unit_id, i.is_active AS item_is_active,
                       i.item_type, u.name AS output_unit_name,
                       base_u.name AS base_unit_name,
                       CASE WHEN i.base_unit_id=b.output_unit_id THEN 1::numeric
                            ELSE iu.conversion_to_base END AS conversion_to_base,
                       t.default_currency
                  FROM production_batches b
                  JOIN recipe_versions rv
                    ON rv.tenant_id=b.tenant_id AND rv.id=b.recipe_version_id
                  JOIN recipes r
                    ON r.tenant_id=rv.tenant_id AND r.id=rv.recipe_id
                  JOIN inventory_items i
                    ON i.tenant_id=b.tenant_id AND i.id=r.output_item_id
                  JOIN measurement_units u ON u.id=b.output_unit_id
                  JOIN measurement_units base_u ON base_u.id=i.base_unit_id
                  JOIN tenants t ON t.id=b.tenant_id
             LEFT JOIN inventory_item_units iu
                    ON iu.tenant_id=i.tenant_id AND iu.item_id=i.id
                   AND iu.unit_id=b.output_unit_id
                 WHERE b.tenant_id=:tenant_id AND b.id=:batch_id
                 FOR UPDATE OF b
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).mappings().one_or_none()
        if batch is None:
            raise ProductionOutputError("Production batch was not found.")

        existing = session.execute(
            text(
                """
                SELECT p.id AS posting_id, p.inventory_document_id,
                       p.production_lot_id, p.output_quantity,
                       p.material_cost_snapshot, p.currency
                  FROM production_output_postings p
                 WHERE p.tenant_id=:tenant_id AND p.batch_id=:batch_id
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).mappings().one_or_none()
        if existing is not None:
            return ProductionOutputResult(
                UUID(str(batch_id)), UUID(str(existing["posting_id"])),
                UUID(str(existing["inventory_document_id"])),
                UUID(str(existing["production_lot_id"])),
                Decimal(existing["output_quantity"]),
                Decimal(existing["material_cost_snapshot"]),
                str(existing["currency"]).strip(), True,
            )

        if batch["status"] != "sterilization":
            raise ProductionOutputError(
                "Production output can only be posted after the press-completion transition."
            )
        if not bool(batch["item_is_active"]) or batch["item_type"] not in {
            "work_in_process", "finished_good"
        }:
            raise ProductionOutputError(
                "The recipe output item must be active and configured as work-in-process or finished-good."
            )
        if batch["conversion_to_base"] is None:
            raise ProductionOutputError(
                "The output unit must be the item's base unit or have a configured conversion."
            )

        warehouse = session.execute(
            text(
                """
                SELECT id FROM warehouses
                 WHERE tenant_id=:tenant_id AND id=:warehouse_id
                   AND location_id=:location_id AND is_active
                 FOR UPDATE
                """
            ),
            {
                "tenant_id": str(tenant_id),
                "warehouse_id": str(warehouse_id),
                "location_id": str(batch["location_id"]),
            },
        ).scalar_one_or_none()
        if warehouse is None:
            raise ProductionOutputError(
                "Output warehouse must be active and belong to the batch location."
            )

        press = session.execute(
            text(
                """
                SELECT count(*) AS passes,
                       COALESCE(sum(good_quantity),0) AS good_quantity,
                       COALESCE(sum(rejected_quantity),0) AS rejected_quantity,
                       count(DISTINCT quantity_unit_id) AS unit_count
                  FROM production_press_outputs
                 WHERE tenant_id=:tenant_id AND batch_id=:batch_id
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).mappings().one()
        output_quantity = Decimal(press["good_quantity"])
        if int(press["passes"]) == 0 or output_quantity <= 0:
            raise ProductionOutputError("The batch has no positive good press output to post.")
        if int(press["unit_count"]) != 1:
            raise ProductionOutputError("All press output passes must use one output unit.")

        cost = session.execute(
            text(
                """
                SELECT count(*) AS lines,
                       COALESCE(sum(material_cost_snapshot),0) AS material_cost,
                       count(DISTINCT currency) AS currencies,
                       min(currency) AS currency
                  FROM production_batch_consumptions
                 WHERE tenant_id=:tenant_id AND batch_id=:batch_id
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).mappings().one()
        if int(cost["lines"]) == 0 or int(cost["currencies"]) != 1:
            raise ProductionOutputError(
                "Output posting requires actual material consumption in one currency."
            )
        currency = str(cost["currency"]).strip()
        if currency != str(batch["default_currency"]).strip():
            raise ProductionOutputError("Production material cost must use the tenant base currency.")

        conversion = Decimal(batch["conversion_to_base"])
        base_quantity = (output_quantity * conversion).quantize(Decimal("0.00000001"))
        material_cost = Decimal(cost["material_cost"]).quantize(Decimal("0.00000001"))
        if base_quantity <= 0:
            raise ProductionOutputError("Converted output quantity must be positive.")
        base_unit_cost = (material_cost / base_quantity).quantize(Decimal("0.00000001"))
        display_unit_cost = (material_cost / output_quantity).quantize(Decimal("0.00000001"))

        inventory_lot_id = uuid4()
        production_lot_id = uuid4()
        document_id = uuid4()
        line_id = uuid4()
        posting_id = uuid4()
        lot_code = f"PRD-{batch_id.hex}"
        document_no = f"PO-{batch_id.hex[:32]}"
        idempotency_key = f"production-output:{batch_id}"

        session.execute(
            text(
                """
                INSERT INTO inventory_lots(
                    id, tenant_id, item_id, lot_code, manufactured_at,
                    received_at, status, attributes
                ) VALUES (
                    :id, :tenant_id, :item_id, :lot_code, CURRENT_DATE,
                    now(), 'active',
                    jsonb_build_object('source', 'production_batch',
                                       'batch_id', CAST(:batch_id AS uuid))
                )
                """
            ),
            {
                "id": str(inventory_lot_id), "tenant_id": str(tenant_id),
                "item_id": str(batch["output_item_id"]), "lot_code": lot_code,
                "batch_id": str(batch_id),
            },
        )
        session.execute(
            text(
                """
                INSERT INTO production_lots(
                    id, tenant_id, batch_id, inventory_lot_id, variety_id,
                    output_quantity, output_unit_id, produced_at
                ) VALUES (
                    :id, :tenant_id, :batch_id, :inventory_lot_id, NULL,
                    :quantity, :unit_id, now()
                )
                """
            ),
            {
                "id": str(production_lot_id), "tenant_id": str(tenant_id),
                "batch_id": str(batch_id), "inventory_lot_id": str(inventory_lot_id),
                "quantity": output_quantity, "unit_id": str(batch["output_unit_id"]),
            },
        )
        session.execute(
            text(
                """
                INSERT INTO inventory_documents(
                    id, tenant_id, document_no, document_type, status,
                    destination_warehouse_id, occurred_at, source_reference_type,
                    source_reference_id, idempotency_key, notes, created_by
                ) VALUES (
                    :id, :tenant_id, :document_no, 'production_output', 'draft',
                    :warehouse_id, now(), 'production_batch',
                    :batch_id, :idempotency_key, 'Press Baglog production output', :actor_user_id
                )
                """
            ),
            {
                "id": str(document_id), "tenant_id": str(tenant_id),
                "document_no": document_no, "warehouse_id": str(warehouse_id),
                "batch_id": str(batch_id), "idempotency_key": idempotency_key,
                "actor_user_id": str(actor_user_id),
            },
        )
        session.execute(
            text(
                """
                INSERT INTO inventory_document_lines(
                    id, tenant_id, document_id, line_no, item_id, lot_id,
                    item_code_snapshot, item_name_snapshot, quantity, unit_id,
                    unit_name_snapshot, conversion_to_base_snapshot, base_quantity,
                    unit_cost_snapshot, currency, line_value_snapshot, notes
                ) VALUES (
                    :id, :tenant_id, :document_id, 1, :item_id, :lot_id,
                    :item_code, :item_name, :quantity, :unit_id,
                    :unit_name, :conversion, :base_quantity,
                    :unit_cost, :currency, :line_value, 'Good output from press'
                )
                """
            ),
            {
                "id": str(line_id), "tenant_id": str(tenant_id),
                "document_id": str(document_id), "item_id": str(batch["output_item_id"]),
                "lot_id": str(inventory_lot_id), "item_code": batch["item_code"],
                "item_name": batch["item_name"], "quantity": output_quantity,
                "unit_id": str(batch["output_unit_id"]), "unit_name": batch["output_unit_name"],
                "conversion": conversion, "base_quantity": base_quantity,
                "unit_cost": display_unit_cost, "currency": currency,
                "line_value": material_cost,
            },
        )
        session.execute(
            text(
                """
                UPDATE inventory_documents
                   SET status='posted', posted_at=now(), posted_by=:actor_user_id,
                       updated_at=now()
                 WHERE tenant_id=:tenant_id AND id=:document_id
                """
            ),
            {
                "actor_user_id": str(actor_user_id), "tenant_id": str(tenant_id),
                "document_id": str(document_id),
            },
        )
        session.execute(
            text(
                """
                INSERT INTO inventory_ledger_entries(
                    tenant_id, document_id, document_line_id, warehouse_id,
                    item_id, lot_id, quantity_delta, value_delta, currency,
                    unit_cost_snapshot, occurred_at
                ) VALUES (
                    :tenant_id, :document_id, :line_id, :warehouse_id,
                    :item_id, :lot_id, :quantity, :value, :currency,
                    :unit_cost, now()
                )
                """
            ),
            {
                "tenant_id": str(tenant_id), "document_id": str(document_id),
                "line_id": str(line_id), "warehouse_id": str(warehouse_id),
                "item_id": str(batch["output_item_id"]), "lot_id": str(inventory_lot_id),
                "quantity": base_quantity, "value": material_cost,
                "currency": currency, "unit_cost": base_unit_cost,
            },
        )
        session.execute(
            text(
                """
                UPDATE production_batches
                   SET actual_output_quantity=:quantity, updated_at=now()
                 WHERE tenant_id=:tenant_id AND id=:batch_id
                """
            ),
            {
                "quantity": output_quantity, "tenant_id": str(tenant_id),
                "batch_id": str(batch_id),
            },
        )
        session.execute(
            text(
                """
                INSERT INTO production_output_postings(
                    id, tenant_id, batch_id, inventory_document_id,
                    inventory_document_line_id, production_lot_id,
                    output_quantity, material_cost_snapshot, currency, posted_by
                ) VALUES (
                    :id, :tenant_id, :batch_id, :document_id, :line_id,
                    :production_lot_id, :quantity, :material_cost, :currency, :actor_user_id
                )
                """
            ),
            {
                "id": str(posting_id), "tenant_id": str(tenant_id),
                "batch_id": str(batch_id), "document_id": str(document_id),
                "line_id": str(line_id), "production_lot_id": str(production_lot_id),
                "quantity": output_quantity, "material_cost": material_cost,
                "currency": currency, "actor_user_id": str(actor_user_id),
            },
        )
        session.execute(
            text(
                """
                INSERT INTO production_batch_events(
                    tenant_id, batch_id, event_type, from_status, to_status,
                    quantity, unit_id, occurred_at, actor_user_id, metadata
                ) VALUES (
                    :tenant_id, :batch_id, 'production_output_posted',
                    'sterilization', 'sterilization', :quantity, :unit_id, now(),
                    :actor_user_id,
                    jsonb_build_object('posting_id', CAST(:posting_id AS uuid),
                                       'inventory_document_id', CAST(:document_id AS uuid),
                                       'production_lot_id', CAST(:lot_id AS uuid),
                                       'rejected_quantity', CAST(:rejected_quantity AS numeric))
                )
                """
            ),
            {
                "tenant_id": str(tenant_id), "batch_id": str(batch_id),
                "quantity": output_quantity, "unit_id": str(batch["output_unit_id"]),
                "actor_user_id": str(actor_user_id), "posting_id": str(posting_id),
                "document_id": str(document_id), "lot_id": str(production_lot_id),
                "rejected_quantity": press["rejected_quantity"],
            },
        )
        session.execute(
            text(
                """
                INSERT INTO tenant_audit_events(
                    tenant_id, actor_user_id, action, entity_type, entity_id,
                    after_data, metadata
                ) VALUES (
                    :tenant_id, :actor_user_id, 'production.output.posted',
                    'production_batch', :batch_id,
                    jsonb_build_object('output_quantity', CAST(:quantity AS numeric),
                                       'material_cost', CAST(:material_cost AS numeric),
                                       'currency', CAST(:currency AS text)),
                    jsonb_build_object('posting_id', CAST(:posting_id AS uuid),
                                       'inventory_document_id', CAST(:document_id AS uuid),
                                       'production_lot_id', CAST(:lot_id AS uuid))
                )
                """
            ),
            {
                "tenant_id": str(tenant_id), "actor_user_id": str(actor_user_id),
                "batch_id": str(batch_id), "quantity": output_quantity,
                "material_cost": material_cost, "currency": currency,
                "posting_id": str(posting_id), "document_id": str(document_id),
                "lot_id": str(production_lot_id),
            },
        )
    except DBAPIError as exc:
        _translate_db_error(exc)

    return ProductionOutputResult(
        UUID(str(batch_id)), posting_id, document_id, production_lot_id,
        output_quantity, material_cost, currency, False,
    )

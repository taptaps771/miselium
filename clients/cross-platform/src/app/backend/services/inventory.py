"""Tenant-scoped inventory posting, reversal, and production consumption services.

Callers must authorize the requested tenant permission before invoking these
services and commit/rollback the surrounding SQLAlchemy transaction. Every
write is performed in that caller-owned transaction.
"""
from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
from uuid import UUID

from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session


class InventoryServiceError(Exception):
    """An inventory document or production consumption is invalid."""


class InventoryPermissionDenied(PermissionError):
    """The caller is not authorized for the requested inventory operation."""


@dataclass(frozen=True, slots=True)
class InventoryPostingResult:
    document_id: UUID
    status: str
    ledger_entries: int
    was_already_posted: bool = False


@dataclass(frozen=True, slots=True)
class ProductionConsumptionResult:
    batch_id: UUID
    document_id: UUID
    consumed_lines: int
    material_cost: Decimal


def _sqlstate(exc: DBAPIError) -> str | None:
    return getattr(exc.orig, "sqlstate", getattr(exc.orig, "pgcode", None))


def _set_context(session: Session, actor_user_id: UUID, tenant_id: UUID) -> None:
    session.execute(
        text("SELECT set_config('app.user_id', :user_id, true)"),
        {"user_id": str(actor_user_id)},
    )
    session.execute(
        text("SELECT set_config('app.tenant_id', :tenant_id, true)"),
        {"tenant_id": str(tenant_id)},
    )


def _require_module_enabled(session: Session, tenant_id: UUID, module_code: str) -> None:
    status = session.execute(
        text(
            """
            SELECT tm.status
              FROM tenant_modules AS tm
              JOIN modules AS m ON m.id=tm.module_id
             WHERE tm.tenant_id=:tenant_id AND m.code=:module_code
            """
        ),
        {"tenant_id": str(tenant_id), "module_code": module_code},
    ).scalar_one_or_none()
    if status != "enabled":
        raise InventoryPermissionDenied(
            f"The {module_code} module is not enabled for this tenant."
        )


def _db_error(exc: DBAPIError) -> None:
    state = _sqlstate(exc)
    if state == "42501":
        raise InventoryPermissionDenied("Inventory permission is required.") from None
    if state in {"23502", "23503", "23505", "23514", "22023", "P0002", "55000"}:
        raise InventoryServiceError("The inventory operation violates a business invariant.") from None
    raise exc


def _lock_stock_keys(
    session: Session, tenant_id: UUID, keys: set[tuple[UUID, UUID, UUID | None]]
) -> None:
    # Stable ordering avoids deadlocks when a document touches several balances.
    for warehouse_id, item_id, lot_id in sorted(
        keys, key=lambda key: (str(key[0]), str(key[1]), str(key[2] or ""))
    ):
        lock_key = f"{tenant_id}:{warehouse_id}:{item_id}:{lot_id or 'untracked'}"
        session.execute(
            text("SELECT pg_advisory_xact_lock(hashtextextended(:lock_key, 0))"),
            {"lock_key": lock_key},
        )


def post_inventory_document(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    document_id: UUID,
    _production_batch_id: UUID | None = None,
) -> InventoryPostingResult:
    """Atomically validate and post a draft document into the stock ledger.

    The document row serializes duplicate posting. Transaction-scoped advisory
    locks serialize all movements that affect the same warehouse/item/lot
    balance, including when no ledger row exists yet.
    """
    _set_context(session, actor_user_id, tenant_id)
    _require_module_enabled(session, tenant_id, "inventory")
    tenant_currency = session.execute(
        text("SELECT default_currency FROM tenants WHERE id=:tenant_id"),
        {"tenant_id": str(tenant_id)},
    ).scalar_one_or_none()
    if tenant_currency is None:
        raise InventoryServiceError("Tenant currency could not be resolved.")
    try:
        document = session.execute(
            text(
                """
                SELECT id, document_no, document_type, status, source_warehouse_id,
                       destination_warehouse_id, occurred_at, source_reference_type,
                       source_reference_id
                  FROM inventory_documents
                 WHERE tenant_id=:tenant_id AND id=:document_id
                 FOR UPDATE
                """
            ),
            {"tenant_id": str(tenant_id), "document_id": str(document_id)},
        ).mappings().one_or_none()
        if document is None:
            raise InventoryServiceError("Inventory document was not found.")
        if document["status"] == "posted":
            count = session.execute(
                text(
                    "SELECT count(*) FROM inventory_ledger_entries "
                    "WHERE tenant_id=:tenant_id AND document_id=:document_id"
                ),
                {"tenant_id": str(tenant_id), "document_id": str(document_id)},
            ).scalar_one()
            return InventoryPostingResult(document_id, "posted", int(count), True)
        if document["status"] != "draft":
            raise InventoryServiceError("Only a draft inventory document can be posted.")

        document_type = str(document["document_type"])
        source = document["source_warehouse_id"]
        destination = document["destination_warehouse_id"]
        if document_type == "adjustment":
            raise InventoryServiceError(
                "Adjustment posting requires an explicit signed adjustment workflow."
            )
        if document_type == "transfer":
            if source is None or destination is None or source == destination:
                raise InventoryServiceError("A transfer requires two different warehouses.")
        elif document_type in {"issue", "production_consumption"}:
            if source is None or destination is not None:
                raise InventoryServiceError("This document requires a source warehouse only.")
        elif document_type in {"receipt", "return", "recovery"}:
            if destination is None or source is not None:
                raise InventoryServiceError("This document requires a destination warehouse only.")
        elif document_type == "production_consumption":
            if source is None or destination is not None:
                raise InventoryServiceError("This document requires a source warehouse only.")
            if (
                _production_batch_id is None
                or document["source_reference_type"] != "production_batch"
                or str(document["source_reference_id"]) != str(_production_batch_id)
            ):
                raise InventoryServiceError(
                    "Production consumption must be posted through its linked batch service."
                )
        elif document_type == "production_output":
            raise InventoryServiceError("Production output requires the production-output service.")
        else:
            raise InventoryServiceError("Unsupported inventory document type.")

        lines = session.execute(
            text(
                """
                SELECT l.id, l.line_no, l.item_id, l.lot_id, l.quantity, l.unit_id,
                       l.unit_cost_snapshot, l.currency, l.line_value_snapshot,
                       l.conversion_to_base_snapshot, l.base_quantity,
                       i.is_lot_tracked, i.allow_negative_stock, i.is_active AS item_is_active,
                       i.base_unit_id, iu.conversion_to_base AS configured_conversion,
                       lot.status AS lot_status, lot.item_id AS lot_item_id,
                       lot.expires_at AS lot_expires_at
                  FROM inventory_document_lines AS l
                  JOIN inventory_items AS i
                    ON i.tenant_id=l.tenant_id AND i.id=l.item_id
             LEFT JOIN inventory_item_units AS iu
                    ON iu.tenant_id=l.tenant_id AND iu.item_id=l.item_id AND iu.unit_id=l.unit_id
             LEFT JOIN inventory_lots AS lot
                    ON lot.tenant_id=l.tenant_id AND lot.id=l.lot_id
                 WHERE l.tenant_id=:tenant_id AND l.document_id=:document_id
                 ORDER BY l.line_no
                """
            ),
            {"tenant_id": str(tenant_id), "document_id": str(document_id)},
        ).mappings().all()
        if not lines:
            raise InventoryServiceError("An inventory document must contain at least one line.")

        movement_warehouses = {UUID(str(source))} if source else set()
        if destination:
            movement_warehouses.add(UUID(str(destination)))
        warehouse_rows = session.execute(
            text(
                """
                SELECT id, is_active FROM warehouses
                 WHERE tenant_id=:tenant_id AND id = ANY(:warehouse_ids)
                """
            ),
            {"tenant_id": str(tenant_id), "warehouse_ids": list(movement_warehouses)},
        ).mappings().all()
        if len(warehouse_rows) != len(movement_warehouses) or any(
            not bool(row["is_active"]) for row in warehouse_rows
        ):
            raise InventoryServiceError("Every inventory movement warehouse must be active.")
        lock_keys = {
            (warehouse_id, UUID(str(line["item_id"])), line["lot_id"])
            for warehouse_id in movement_warehouses
            for line in lines
        }
        _lock_stock_keys(session, tenant_id, lock_keys)

        ledger_rows: list[dict[str, object]] = []
        for line in lines:
            item_id = UUID(str(line["item_id"]))
            lot_id = UUID(str(line["lot_id"])) if line["lot_id"] else None
            base_quantity = Decimal(line["base_quantity"])
            if str(line["currency"]).strip() != str(tenant_currency).strip():
                raise InventoryServiceError("Inventory documents must use the tenant's base currency.")
            if not bool(line["item_is_active"]):
                raise InventoryServiceError("Inactive inventory items cannot be moved.")
            base_unit_id = UUID(str(line["base_unit_id"]))
            unit_id = UUID(str(line["unit_id"]))
            expected_conversion = (
                Decimal("1")
                if unit_id == base_unit_id
                else Decimal(line["configured_conversion"])
                if line["configured_conversion"] is not None
                else None
            )
            if expected_conversion is None or Decimal(line["conversion_to_base_snapshot"]) != expected_conversion:
                raise InventoryServiceError("The document unit conversion does not match the configured item unit.")
            if bool(line["is_lot_tracked"]) and lot_id is None:
                raise InventoryServiceError("A lot-tracked item requires a lot on every movement.")
            if lot_id is not None:
                if line["lot_item_id"] is None or UUID(str(line["lot_item_id"])) != item_id:
                    raise InventoryServiceError("The selected lot does not belong to this item.")
                if line["lot_status"] != "active":
                    raise InventoryServiceError("Only active inventory lots can be moved.")
                if line["lot_expires_at"] is not None and line["lot_expires_at"] < document["occurred_at"].date():
                    raise InventoryServiceError("Expired inventory lots cannot be moved.")

            outbound = document_type in {"issue", "production_consumption", "transfer"}
            inbound = not outbound
            if outbound:
                warehouse_id = UUID(str(source))
                balance = session.execute(
                    text(
                        """
                        SELECT COALESCE(sum(quantity_delta),0) AS quantity,
                               COALESCE(sum(value_delta),0) AS value
                          FROM inventory_ledger_entries
                         WHERE tenant_id=:tenant_id AND warehouse_id=:warehouse_id
                           AND item_id=:item_id AND lot_id IS NOT DISTINCT FROM :lot_id
                           AND currency=:currency
                        """
                    ),
                    {
                        "tenant_id": str(tenant_id),
                        "warehouse_id": str(warehouse_id),
                        "item_id": str(item_id),
                        "lot_id": str(lot_id) if lot_id else None,
                        "currency": line["currency"],
                    },
                ).mappings().one()
                on_hand = Decimal(balance["quantity"])
                inventory_value = Decimal(balance["value"])
                if on_hand < base_quantity and not bool(line["allow_negative_stock"]):
                    raise InventoryServiceError(
                        f"Insufficient stock for item on document line {line['line_no']}."
                    )
                if on_hand > 0:
                    base_unit_cost = inventory_value / on_hand
                else:
                    base_unit_cost = Decimal(line["unit_cost_snapshot"]) / Decimal(
                        line["conversion_to_base_snapshot"]
                    )
                if base_unit_cost < 0:
                    raise InventoryServiceError("Negative inventory valuation is not supported.")
                line_value = (base_quantity * base_unit_cost).quantize(Decimal("0.00000001"))
                display_unit_cost = (
                    base_unit_cost * Decimal(line["conversion_to_base_snapshot"])
                ).quantize(Decimal("0.00000001"))
                session.execute(
                    text(
                        """
                        UPDATE inventory_document_lines
                           SET unit_cost_snapshot=:unit_cost, line_value_snapshot=:line_value
                         WHERE tenant_id=:tenant_id AND id=:line_id
                        """
                    ),
                    {
                        "unit_cost": display_unit_cost,
                        "line_value": line_value,
                        "tenant_id": str(tenant_id),
                        "line_id": str(line["id"]),
                    },
                )
                ledger_rows.append(
                    {
                        "line_id": line["id"], "warehouse_id": warehouse_id,
                        "item_id": item_id, "lot_id": lot_id,
                        "quantity_delta": -base_quantity, "value_delta": -line_value,
                        "currency": line["currency"], "unit_cost": base_unit_cost,
                    }
                )
                if document_type == "transfer":
                    ledger_rows.append(
                        {
                            "line_id": line["id"], "warehouse_id": UUID(str(destination)),
                            "item_id": item_id, "lot_id": lot_id,
                            "quantity_delta": base_quantity, "value_delta": line_value,
                            "currency": line["currency"], "unit_cost": base_unit_cost,
                        }
                    )
            elif inbound:
                warehouse_id = UUID(str(destination))
                quantity = Decimal(line["quantity"])
                entered_unit_cost = Decimal(line["unit_cost_snapshot"])
                line_value = Decimal(line["line_value_snapshot"])
                if line_value == 0 and entered_unit_cost > 0:
                    line_value = (quantity * entered_unit_cost).quantize(
                        Decimal("0.00000001")
                    )
                base_unit_cost = (
                    line_value / base_quantity if base_quantity else Decimal("0")
                )
                ledger_rows.append(
                    {
                        "line_id": line["id"], "warehouse_id": warehouse_id,
                        "item_id": item_id, "lot_id": lot_id,
                        "quantity_delta": base_quantity, "value_delta": line_value,
                        "currency": line["currency"], "unit_cost": base_unit_cost,
                    }
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
                "actor_user_id": str(actor_user_id),
                "tenant_id": str(tenant_id),
                "document_id": str(document_id),
            },
        )
        for entry in ledger_rows:
            session.execute(
                text(
                    """
                    INSERT INTO inventory_ledger_entries(
                        tenant_id, document_id, document_line_id, warehouse_id,
                        item_id, lot_id, quantity_delta, value_delta, currency,
                        unit_cost_snapshot, occurred_at
                    ) VALUES (
                        :tenant_id, :document_id, :line_id, :warehouse_id,
                        :item_id, :lot_id, :quantity_delta, :value_delta, :currency,
                        :unit_cost, :occurred_at
                    )
                    """
                ),
                {
                    "tenant_id": str(tenant_id),
                    "document_id": str(document_id),
                    **entry,
                    "occurred_at": document["occurred_at"],
                },
            )
        session.execute(
            text(
                """
                INSERT INTO tenant_audit_events(
                    tenant_id, actor_user_id, action, entity_type, entity_id,
                    after_data, metadata
                ) VALUES (
                    :tenant_id, :actor_user_id, 'inventory.document.posted',
                    'inventory_document', :document_id,
                    jsonb_build_object('document_no', :document_no,
                                       'document_type', :document_type,
                                       'ledger_entries', :entry_count),
                    jsonb_build_object('source_reference_type', :source_type,
                                       'source_reference_id', :source_id)
                )
                """
            ),
            {
                "tenant_id": str(tenant_id),
                "actor_user_id": str(actor_user_id),
                "document_id": str(document_id),
                "document_no": document["document_no"],
                "document_type": document_type,
                "entry_count": len(ledger_rows),
                "source_type": document["source_reference_type"],
                "source_id": str(document["source_reference_id"])
                if document["source_reference_id"] else None,
            },
        )
    except DBAPIError as exc:
        _db_error(exc)
    return InventoryPostingResult(document_id, "posted", len(ledger_rows))


def reverse_inventory_document(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    document_id: UUID,
    reversal_document_no: str,
) -> InventoryPostingResult:
    """Create an exact inverse ledger document; never rewrite original history."""
    if not reversal_document_no.strip() or len(reversal_document_no.strip()) > 60:
        raise InventoryServiceError("A valid reversal document number is required.")
    _set_context(session, actor_user_id, tenant_id)
    _require_module_enabled(session, tenant_id, "inventory")
    try:
        original = session.execute(
            text(
                """
                SELECT id, document_no, document_type, status, source_warehouse_id,
                       destination_warehouse_id
                  FROM inventory_documents
                 WHERE tenant_id=:tenant_id AND id=:document_id
                 FOR UPDATE
                """
            ),
            {"tenant_id": str(tenant_id), "document_id": str(document_id)},
        ).mappings().one_or_none()
        if original is None:
            raise InventoryServiceError("Original inventory document was not found.")
        existing = session.execute(
            text(
                """
                SELECT id FROM inventory_documents
                 WHERE tenant_id=:tenant_id AND reversed_document_id=:document_id
                """
            ),
            {"tenant_id": str(tenant_id), "document_id": str(document_id)},
        ).scalar_one_or_none()
        if existing is not None:
            count = session.execute(
                text(
                    "SELECT count(*) FROM inventory_ledger_entries "
                    "WHERE tenant_id=:tenant_id AND document_id=:reversal_id"
                ),
                {"tenant_id": str(tenant_id), "reversal_id": str(existing)},
            ).scalar_one()
            return InventoryPostingResult(UUID(str(existing)), "posted", int(count), True)
        if original["status"] != "posted":
            raise InventoryServiceError("Only a posted document can be reversed.")

        reverse_type = {
            "receipt": "issue",
            "issue": "receipt",
            "production_consumption": "production_output",
            "production_output": "production_consumption",
            "return": "issue",
            "recovery": "issue",
            "transfer": "transfer",
        }.get(str(original["document_type"]))
        if reverse_type is None:
            raise InventoryServiceError("This document type does not support automatic reversal.")
        if reverse_type == "transfer":
            reverse_source = original["destination_warehouse_id"]
            reverse_destination = original["source_warehouse_id"]
        elif reverse_type in {"issue", "production_consumption"}:
            reverse_source = original["destination_warehouse_id"] or original["source_warehouse_id"]
            reverse_destination = None
        else:
            reverse_source = None
            reverse_destination = original["source_warehouse_id"] or original["destination_warehouse_id"]

        original_lines = session.execute(
            text(
                """
                SELECT line_no, item_id, lot_id, item_code_snapshot, item_name_snapshot,
                       quantity, unit_id, unit_name_snapshot, conversion_to_base_snapshot,
                       base_quantity, unit_cost_snapshot, currency, line_value_snapshot, notes
                  FROM inventory_document_lines
                 WHERE tenant_id=:tenant_id AND document_id=:document_id
                 ORDER BY line_no
                """
            ),
            {"tenant_id": str(tenant_id), "document_id": str(document_id)},
        ).mappings().all()
        original_entries = session.execute(
            text(
                """
                SELECT le.document_line_id, le.warehouse_id, le.item_id, le.lot_id,
                       le.quantity_delta, le.value_delta, le.currency,
                       le.unit_cost_snapshot, ol.line_no
                  FROM inventory_ledger_entries AS le
                  JOIN inventory_document_lines AS ol
                    ON ol.tenant_id=le.tenant_id AND ol.id=le.document_line_id
                 WHERE le.tenant_id=:tenant_id AND le.document_id=:document_id
                 ORDER BY ol.line_no, le.warehouse_id
                """
            ),
            {"tenant_id": str(tenant_id), "document_id": str(document_id)},
        ).mappings().all()
        if not original_lines or not original_entries:
            raise InventoryServiceError("The original document has no complete ledger history.")

        reversal_id = session.execute(
            text(
                """
                INSERT INTO inventory_documents(
                    tenant_id, document_no, document_type, source_warehouse_id,
                    destination_warehouse_id, occurred_at, reversed_document_id,
                    source_reference_type, source_reference_id, notes, created_by
                ) VALUES (
                    :tenant_id, :document_no, :document_type, :source_warehouse_id,
                    :destination_warehouse_id, now(), :original_id,
                    'inventory_reversal', :original_id, :notes, :actor_user_id
                ) RETURNING id
                """
            ),
            {
                "tenant_id": str(tenant_id),
                "document_no": reversal_document_no.strip(),
                "document_type": reverse_type,
                "source_warehouse_id": str(reverse_source) if reverse_source else None,
                "destination_warehouse_id": str(reverse_destination)
                if reverse_destination else None,
                "original_id": str(document_id),
                "notes": f"Reversal of {original['document_no']}",
                "actor_user_id": str(actor_user_id),
            },
        ).scalar_one()
        for line in original_lines:
            session.execute(
                text(
                    """
                    INSERT INTO inventory_document_lines(
                        tenant_id, document_id, line_no, item_id, lot_id,
                        item_code_snapshot, item_name_snapshot, quantity, unit_id,
                        unit_name_snapshot, conversion_to_base_snapshot, base_quantity,
                        unit_cost_snapshot, currency, line_value_snapshot, notes
                    ) VALUES (
                        :tenant_id, :document_id, :line_no, :item_id, :lot_id,
                        :item_code_snapshot, :item_name_snapshot, :quantity, :unit_id,
                        :unit_name_snapshot, :conversion_to_base_snapshot, :base_quantity,
                        :unit_cost_snapshot, :currency, :line_value_snapshot, :notes
                    )
                    """
                ),
                {"tenant_id": str(tenant_id), "document_id": str(reversal_id), **line},
            )

        reversal_lines = session.execute(
            text(
                """
                SELECT id, line_no FROM inventory_document_lines
                 WHERE tenant_id=:tenant_id AND document_id=:document_id
                """
            ),
            {"tenant_id": str(tenant_id), "document_id": str(reversal_id)},
        ).mappings().all()
        reversal_line_ids = {int(row["line_no"]): row["id"] for row in reversal_lines}
        stock_keys = {
            (
                UUID(str(entry["warehouse_id"])),
                UUID(str(entry["item_id"])),
                UUID(str(entry["lot_id"])) if entry["lot_id"] else None,
            )
            for entry in original_entries
        }
        _lock_stock_keys(session, tenant_id, stock_keys)

        # A reversal that would make a non-negative item negative is rejected.
        for entry in original_entries:
            inverse_quantity = -Decimal(entry["quantity_delta"])
            if inverse_quantity >= 0:
                continue
            balance = session.execute(
                text(
                    """
                    SELECT COALESCE(sum(quantity_delta),0)
                      FROM inventory_ledger_entries
                     WHERE tenant_id=:tenant_id AND warehouse_id=:warehouse_id
                       AND item_id=:item_id AND lot_id IS NOT DISTINCT FROM :lot_id
                       AND currency=:currency
                    """
                ),
                {
                    "tenant_id": str(tenant_id),
                    "warehouse_id": str(entry["warehouse_id"]),
                    "item_id": str(entry["item_id"]),
                    "lot_id": str(entry["lot_id"]) if entry["lot_id"] else None,
                    "currency": entry["currency"],
                },
            ).scalar_one()
            negative_allowed = session.execute(
                text(
                    "SELECT allow_negative_stock FROM inventory_items "
                    "WHERE tenant_id=:tenant_id AND id=:item_id"
                ),
                {"tenant_id": str(tenant_id), "item_id": str(entry["item_id"])},
            ).scalar_one()
            if Decimal(balance) < abs(inverse_quantity) and not bool(negative_allowed):
                raise InventoryServiceError(
                    "The reversal would create negative stock because the original quantity has since been used."
                )

        session.execute(
            text(
                """
                UPDATE inventory_documents
                   SET status='posted', posted_at=now(), posted_by=:actor_user_id
                 WHERE tenant_id=:tenant_id AND id=:reversal_id
                """
            ),
            {
                "tenant_id": str(tenant_id),
                "reversal_id": str(reversal_id),
                "actor_user_id": str(actor_user_id),
            },
        )
        for entry in original_entries:
            session.execute(
                text(
                    """
                    INSERT INTO inventory_ledger_entries(
                        tenant_id, document_id, document_line_id, warehouse_id,
                        item_id, lot_id, quantity_delta, value_delta, currency,
                        unit_cost_snapshot, occurred_at
                    ) VALUES (
                        :tenant_id, :reversal_id, :line_id, :warehouse_id,
                        :item_id, :lot_id, :quantity_delta, :value_delta, :currency,
                        :unit_cost, now()
                    )
                    """
                ),
                {
                    "tenant_id": str(tenant_id),
                    "reversal_id": str(reversal_id),
                    "line_id": reversal_line_ids[int(entry["line_no"])],
                    "warehouse_id": entry["warehouse_id"],
                    "item_id": entry["item_id"],
                    "lot_id": entry["lot_id"],
                    "quantity_delta": -Decimal(entry["quantity_delta"]),
                    "value_delta": -Decimal(entry["value_delta"]),
                    "currency": entry["currency"],
                    "unit_cost": entry["unit_cost_snapshot"],
                },
            )
        session.execute(
            text(
                """
                UPDATE inventory_documents SET status='reversed', updated_at=now()
                 WHERE tenant_id=:tenant_id AND id=:document_id AND status='posted'
                """
            ),
            {"tenant_id": str(tenant_id), "document_id": str(document_id)},
        )
        session.execute(
            text(
                """
                INSERT INTO tenant_audit_events(
                    tenant_id, actor_user_id, action, entity_type, entity_id,
                    before_data, after_data
                ) VALUES (
                    :tenant_id, :actor_user_id, 'inventory.document.reversed',
                    'inventory_document', :document_id,
                    jsonb_build_object('status','posted'),
                    jsonb_build_object('status','reversed','reversal_document_id',:reversal_id)
                )
                """
            ),
            {
                "tenant_id": str(tenant_id),
                "actor_user_id": str(actor_user_id),
                "document_id": str(document_id),
                "reversal_id": str(reversal_id),
            },
        )
    except DBAPIError as exc:
        _db_error(exc)
    return InventoryPostingResult(UUID(str(reversal_id)), "posted", len(original_entries))

def consume_production_materials(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    batch_id: UUID,
    inventory_document_id: UUID,
) -> ProductionConsumptionResult:
    """Post a batch's issue document and freeze its actual material-cost links."""
    _set_context(session, actor_user_id, tenant_id)
    _require_module_enabled(session, tenant_id, "inventory")
    _require_module_enabled(session, tenant_id, "production")
    try:
        batch = session.execute(
            text(
                """
                SELECT id, status FROM production_batches
                 WHERE tenant_id=:tenant_id AND id=:batch_id FOR UPDATE
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).mappings().one_or_none()
        if batch is None:
            raise InventoryServiceError("Production batch was not found.")
        if batch["status"] not in {"planned", "mixing"}:
            raise InventoryServiceError("Materials can only be consumed by a planned or mixing batch.")
        document = session.execute(
            text(
                """
                SELECT document_type, source_reference_type, source_reference_id
                  FROM inventory_documents
                 WHERE tenant_id=:tenant_id AND id=:document_id
                """
            ),
            {"tenant_id": str(tenant_id), "document_id": str(inventory_document_id)},
        ).mappings().one_or_none()
        if document is None or document["document_type"] != "production_consumption":
            raise InventoryServiceError("A production-consumption inventory document is required.")
        if (
            document["source_reference_type"] != "production_batch"
            or str(document["source_reference_id"]) != str(batch_id)
        ):
            raise InventoryServiceError("The inventory document is not linked to this production batch.")
        existing = session.execute(
            text(
                """
                SELECT count(*) FROM production_batch_consumptions
                 WHERE tenant_id=:tenant_id AND batch_id=:batch_id
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).scalar_one()
        if int(existing):
            raise InventoryServiceError("Production materials have already been consumed for this batch.")

        post_inventory_document(
            session,
            actor_user_id=actor_user_id,
            tenant_id=tenant_id,
            document_id=inventory_document_id,
            _production_batch_id=batch_id,
        )
        rows = session.execute(
            text(
                """
                SELECT l.id, l.item_id, l.base_quantity, l.currency,
                       abs(le.value_delta) AS material_cost
                  FROM inventory_document_lines AS l
                  JOIN inventory_ledger_entries AS le
                    ON le.tenant_id=l.tenant_id
                   AND le.document_line_id=l.id
                   AND le.document_id=l.document_id
                   AND le.quantity_delta < 0
                 WHERE l.tenant_id=:tenant_id AND l.document_id=:document_id
                 ORDER BY l.line_no
                """
            ),
            {"tenant_id": str(tenant_id), "document_id": str(inventory_document_id)},
        ).mappings().all()
        if not rows:
            raise InventoryServiceError("The posted consumption document has no outbound ledger entries.")
        total_cost = Decimal("0")
        for row in rows:
            cost = Decimal(row["material_cost"])
            total_cost += cost
            session.execute(
                text(
                    """
                    INSERT INTO production_batch_consumptions(
                        tenant_id, batch_id, inventory_document_line_id, item_id,
                        consumed_base_quantity, material_cost_snapshot, currency, consumed_at
                    ) VALUES (
                        :tenant_id, :batch_id, :line_id, :item_id,
                        :quantity, :cost, :currency, now()
                    )
                    """
                ),
                {
                    "tenant_id": str(tenant_id),
                    "batch_id": str(batch_id),
                    "line_id": str(row["id"]),
                    "item_id": str(row["item_id"]),
                    "quantity": row["base_quantity"],
                    "cost": cost,
                    "currency": row["currency"],
                },
            )
        session.execute(
            text(
                """
                INSERT INTO tenant_audit_events(
                    tenant_id, actor_user_id, action, entity_type, entity_id, after_data
                ) VALUES (
                    :tenant_id, :actor_user_id, 'production.batch.materials_consumed',
                    'production_batch', :batch_id,
                    jsonb_build_object('document_id', :document_id,
                                       'line_count', :line_count,
                                       'material_cost', :material_cost)
                )
                """
            ),
            {
                "tenant_id": str(tenant_id),
                "actor_user_id": str(actor_user_id),
                "batch_id": str(batch_id),
                "document_id": str(inventory_document_id),
                "line_count": len(rows),
                "material_cost": total_cost,
            },
        )
    except DBAPIError as exc:
        _db_error(exc)
    return ProductionConsumptionResult(
        UUID(str(batch_id)), UUID(str(inventory_document_id)), len(rows), total_cost
    )

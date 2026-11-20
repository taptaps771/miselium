"""Loss, recovery and final production-batch reconciliation services.

All operations are tenant-scoped and participate in the caller's transaction.
Callers remain responsible for membership/permission authorization and commit /
rollback. Inventory recovery is posted through the immutable inventory ledger.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from decimal import Decimal
from uuid import UUID, uuid4

from sqlalchemy import text
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import Session

from app.backend.services.production_lifecycle import (
    BatchTransitionResult,
    ProductionLifecycleError,
    transition_production_batch,
)


class ProductionReconciliationError(Exception):
    """A production loss, recovery or batch reconciliation is invalid."""


class ProductionReconciliationPermissionDenied(PermissionError):
    """The tenant cannot access production reconciliation operations."""


@dataclass(frozen=True, slots=True)
class ProductionLossResult:
    loss_id: UUID
    batch_id: UUID
    stage: str
    quantity: Decimal
    unit_id: UUID
    disposition: str


@dataclass(frozen=True, slots=True)
class ProductionRecoveryResult:
    loss_id: UUID
    recovery_lot_id: UUID
    inventory_lot_id: UUID
    inventory_document_id: UUID
    quantity: Decimal
    total_cost: Decimal
    currency: str


@dataclass(frozen=True, slots=True)
class ProductionReconciliationResult:
    batch_id: UUID
    reconciliation_id: UUID
    cost_snapshot_id: UUID
    output_quantity: Decimal
    placed_quantity: Decimal
    loss_quantity: Decimal
    total_cost: Decimal
    currency: str
    transition: BatchTransitionResult


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
        raise ProductionReconciliationPermissionDenied(
            "The production module is not enabled for this tenant."
        )


def _lock_batch(session: Session, tenant_id: UUID, batch_id: UUID) -> None:
    session.execute(
        text("SELECT pg_advisory_xact_lock(hashtextextended(:lock_key,0))"),
        {"lock_key": f"{tenant_id}:production-batch:{batch_id}"},
    )


def _translate_db_error(exc: DBAPIError) -> None:
    message = str(getattr(exc, "orig", exc)).lower()
    if "permission denied" in message or "row-level security" in message:
        raise ProductionReconciliationPermissionDenied(
            "The runtime role is not authorized for this production reconciliation."
        ) from exc
    if any(token in message for token in (
        "production loss", "loss", "recovery", "reconciliation", "inventory",
        "foreign key", "unique constraint", "check constraint", "duplicate key",
    )):
        raise ProductionReconciliationError(str(getattr(exc, "orig", exc))) from exc
    raise exc


def record_production_loss(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    batch_id: UUID,
    stage: str,
    idempotency_key: str,
    reason_code: str,
    quantity: Decimal,
    unit_id: UUID,
    recoverable: bool = False,
    disposition: str = "pending",
    production_lot_id: UUID | None = None,
    production_lot_segment_id: UUID | None = None,
    source_kumbung_id: UUID | None = None,
    occurred_at: datetime | None = None,
    notes: str | None = None,
) -> ProductionLossResult:
    """Append a stage loss and, when supplied, its terminal disposition."""
    allowed_stages = {
        "mixing", "press_baglog", "sterilization", "cooling",
        "inoculation", "incubation", "kumbung", "other",
    }
    if stage not in allowed_stages:
        raise ProductionReconciliationError(
            "Loss stage is not supported by M10.1.8; harvest losses await M10 harvest."
        )
    if quantity <= 0:
        raise ProductionReconciliationError("Loss quantity must be positive.")
    if not reason_code.strip() or len(reason_code.strip()) > 50:
        raise ProductionReconciliationError("A loss reason code of 1-50 characters is required.")
    if disposition not in {"pending", "permanent_loss", "discarded"}:
        raise ProductionReconciliationError(
            "A new loss may remain pending or be marked permanent_loss/discarded; recovery uses its own command."
        )
    if stage == "kumbung":
        if not production_lot_id or not production_lot_segment_id or not source_kumbung_id:
            raise ProductionReconciliationError(
                "Kumbung loss requires the source production lot, variety segment and kumbung."
            )
    elif production_lot_segment_id is not None or source_kumbung_id is not None:
        raise ProductionReconciliationError(
            "Only a kumbung-stage loss may reference a lot segment and source kumbung."
        )
    if stage == "mixing" and production_lot_id is not None:
        raise ProductionReconciliationError("Mixing loss must be recorded before a production lot exists.")
    if stage not in {"mixing"} and production_lot_id is None:
        raise ProductionReconciliationError("This loss stage requires a source production lot.")
    timestamp = occurred_at or datetime.now(UTC)
    if timestamp.tzinfo is None:
        raise ProductionReconciliationError("Loss occurrence time must include a timezone.")
    key = idempotency_key.strip()
    if not key or len(key) > 120:
        raise ProductionReconciliationError("A non-empty loss idempotency key of at most 120 characters is required.")

    request_payload = {
        "stage": stage, "reason_code": reason_code.strip(), "quantity": str(quantity),
        "unit_id": str(unit_id), "recoverable": recoverable, "disposition": disposition,
        "production_lot_id": str(production_lot_id) if production_lot_id else None,
        "production_lot_segment_id": str(production_lot_segment_id) if production_lot_segment_id else None,
        "source_kumbung_id": str(source_kumbung_id) if source_kumbung_id else None,
        "notes": notes.strip() if notes and notes.strip() else None,
    }
    request_hash = hashlib.sha256(
        json.dumps(request_payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()

    _set_context(session, actor_user_id, tenant_id)
    _require_production_module(session, tenant_id)
    _lock_batch(session, tenant_id, batch_id)
    try:
        existing = session.execute(
            text(
                """
                SELECT id,disposition,request_hash
                  FROM production_losses
                 WHERE tenant_id=:tenant_id AND batch_id=:batch_id
                   AND idempotency_key=:idempotency_key
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id), "idempotency_key": key},
        ).mappings().one_or_none()
        if existing is not None:
            if existing["request_hash"] != request_hash:
                raise ProductionReconciliationError(
                    "The loss idempotency key was already used with a different payload."
                )
            return ProductionLossResult(
                UUID(str(existing["id"])), batch_id, stage, quantity, unit_id,
                str(existing["disposition"]),
            )

        loss_id = uuid4()
        session.execute(
            text(
                """
                INSERT INTO production_losses(
                    id,tenant_id,batch_id,production_lot_id,
                    production_lot_segment_id,source_kumbung_id,
                    stage,reason_code,quantity,unit_id,recoverable,
                    disposition,idempotency_key,request_hash,
                    occurred_at,recorded_by,notes
                ) VALUES (
                    :id,:tenant_id,:batch_id,:lot_id,
                    :segment_id,:kumbung_id,
                    :stage,:reason_code,:quantity,:unit_id,:recoverable,
                    'pending',:idempotency_key,:request_hash,
                    :occurred_at,:actor_user_id,:notes
                )
                """
            ),
            {
                "id": str(loss_id), "tenant_id": str(tenant_id), "batch_id": str(batch_id),
                "lot_id": str(production_lot_id) if production_lot_id else None,
                "segment_id": str(production_lot_segment_id) if production_lot_segment_id else None,
                "kumbung_id": str(source_kumbung_id) if source_kumbung_id else None,
                "stage": stage, "reason_code": reason_code.strip(), "quantity": quantity,
                "unit_id": str(unit_id), "recoverable": recoverable,
                "idempotency_key": key, "request_hash": request_hash,
                "occurred_at": timestamp, "actor_user_id": str(actor_user_id),
                "notes": notes.strip() if notes and notes.strip() else None,
            },
        )
        if disposition != "pending":
            session.execute(
                text(
                    """
                    UPDATE production_losses SET disposition=:disposition
                     WHERE tenant_id=:tenant_id AND id=:loss_id
                    """
                ),
                {"disposition": disposition, "tenant_id": str(tenant_id), "loss_id": str(loss_id)},
            )
        session.execute(
            text(
                """
                INSERT INTO tenant_audit_events(
                    tenant_id,actor_user_id,action,entity_type,entity_id,after_data,metadata
                ) VALUES (
                    :tenant_id,:actor_user_id,'production.loss.recorded',
                    'production_loss',:loss_id,
                    jsonb_build_object('stage',:stage,'quantity',CAST(:quantity AS numeric),
                                       'unit_id',CAST(:unit_id AS uuid),
                                       'disposition',:disposition),
                    jsonb_build_object('batch_id',CAST(:batch_id AS uuid),
                                       'recoverable',CAST(:recoverable AS boolean),
                                       'idempotency_key',:idempotency_key)
                )
                """
            ),
            {
                "tenant_id": str(tenant_id), "actor_user_id": str(actor_user_id),
                "loss_id": str(loss_id), "stage": stage, "quantity": quantity,
                "unit_id": str(unit_id), "disposition": disposition,
                "batch_id": str(batch_id), "recoverable": recoverable,
                "idempotency_key": key,
            },
        )
    except DBAPIError as exc:
        _translate_db_error(exc)
    return ProductionLossResult(loss_id, batch_id, stage, quantity, unit_id, disposition)

def recover_production_loss(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    loss_id: UUID,
    warehouse_id: UUID,
    material_value_snapshot: Decimal,
    recovery_cost_snapshot: Decimal,
    recovered_at: datetime | None = None,
    notes: str | None = None,
) -> ProductionRecoveryResult:
    """Recover one full recoverable loss into a new inventory lot at historical cost.

    material_value_snapshot is the salvageable historical material value;
    recovery_cost_snapshot is the incremental recycle/rework cost. Their sum
    becomes the recovered inventory value (e.g. 800 + 400 = 1,200).
    """
    if material_value_snapshot < 0 or recovery_cost_snapshot < 0:
        raise ProductionReconciliationError("Recovery cost snapshots cannot be negative.")
    timestamp = recovered_at or datetime.now(UTC)
    if timestamp.tzinfo is None:
        raise ProductionReconciliationError("Recovery timestamp must include a timezone.")
    _set_context(session, actor_user_id, tenant_id)
    _require_production_module(session, tenant_id)

    try:
        loss = session.execute(
            text(
                """
                SELECT l.id,l.batch_id,l.production_lot_id,l.quantity,l.unit_id,
                       l.recoverable,l.disposition,pl.inventory_lot_id,pl.output_unit_id,
                       b.location_id,il.item_id,ii.code AS item_code,ii.name AS item_name,
                       ii.base_unit_id,base_unit.name AS base_unit_name,
                       output_unit.name AS output_unit_name,t.default_currency,
                       CASE WHEN ii.base_unit_id=pl.output_unit_id THEN 1
                            ELSE iiu.conversion_to_base END AS conversion_to_base
                  FROM production_losses l
                  JOIN production_batches b
                    ON b.tenant_id=l.tenant_id AND b.id=l.batch_id
                  JOIN production_lots pl
                    ON pl.tenant_id=l.tenant_id AND pl.id=l.production_lot_id
                  JOIN inventory_lots il
                    ON il.tenant_id=pl.tenant_id AND il.id=pl.inventory_lot_id
                  JOIN inventory_items ii
                    ON ii.tenant_id=il.tenant_id AND ii.id=il.item_id
                  JOIN measurement_units base_unit ON base_unit.id=ii.base_unit_id
                  JOIN measurement_units output_unit ON output_unit.id=pl.output_unit_id
                  JOIN tenants t ON t.id=l.tenant_id
                  LEFT JOIN inventory_item_units iiu
                    ON iiu.tenant_id=ii.tenant_id AND iiu.item_id=ii.id
                   AND iiu.unit_id=pl.output_unit_id
                 WHERE l.tenant_id=:tenant_id AND l.id=:loss_id
                 FOR UPDATE OF l
                """
            ),
            {"tenant_id": str(tenant_id), "loss_id": str(loss_id)},
        ).mappings().one_or_none()
        if loss is None:
            raise ProductionReconciliationError("The production loss was not found or has no source production lot.")
        _lock_batch(session, tenant_id, UUID(str(loss["batch_id"])))
        if loss["recoverable"] is not True or loss["disposition"] != "pending":
            raise ProductionReconciliationError("Only a pending loss marked recoverable can be recovered.")
        if loss["conversion_to_base"] is None:
            raise ProductionReconciliationError(
                "The recovered output unit must be the item base unit or have an explicit item-unit conversion."
            )
        if str(loss["unit_id"]) != str(loss["output_unit_id"]):
            raise ProductionReconciliationError("Recovery quantity unit must match the source production lot unit.")
        warehouse_exists = session.execute(
            text(
                """
                SELECT EXISTS (
                    SELECT 1 FROM warehouses
                     WHERE tenant_id=:tenant_id AND id=:warehouse_id
                       AND location_id=:location_id AND is_active
                )
                """
            ),
            {
                "tenant_id": str(tenant_id), "warehouse_id": str(warehouse_id),
                "location_id": str(loss["location_id"]),
            },
        ).scalar_one()
        if not warehouse_exists:
            raise ProductionReconciliationError(
                "Recovery warehouse must be active and belong to the source batch location."
            )

        quantity = Decimal(loss["quantity"])
        conversion = Decimal(loss["conversion_to_base"])
        base_quantity = (quantity * conversion).quantize(Decimal("0.00000001"))
        total_cost = (material_value_snapshot + recovery_cost_snapshot).quantize(
            Decimal("0.00000001")
        )
        currency = str(loss["default_currency"]).strip()
        inventory_lot_id, document_id, line_id, recovery_id = (
            uuid4(), uuid4(), uuid4(), uuid4()
        )
        lot_code = f"REC-{loss_id.hex}"
        document_no = f"REC-{loss_id.hex[:32]}"
        idempotency_key = f"production-recovery:{loss_id}"
        session.execute(
            text(
                """
                INSERT INTO inventory_lots(
                    id,tenant_id,item_id,lot_code,received_at,status,attributes
                ) VALUES (
                    :id,:tenant_id,:item_id,:lot_code,:received_at,'active',
                    jsonb_build_object('source','production_recovery',
                                       'loss_id',CAST(:loss_id AS uuid),
                                       'source_inventory_lot_id',CAST(:source_lot AS uuid))
                )
                """
            ),
            {
                "id": str(inventory_lot_id), "tenant_id": str(tenant_id),
                "item_id": str(loss["item_id"]), "lot_code": lot_code,
                "received_at": timestamp, "loss_id": str(loss_id),
                "source_lot": str(loss["inventory_lot_id"]),
            },
        )
        session.execute(
            text(
                """
                INSERT INTO inventory_documents(
                    id,tenant_id,document_no,document_type,status,
                    destination_warehouse_id,occurred_at,source_reference_type,
                    source_reference_id,idempotency_key,notes,created_by
                ) VALUES (
                    :id,:tenant_id,:document_no,'recovery','draft',
                    :warehouse_id,:occurred_at,'production_loss',
                    :loss_id,:idempotency_key,:notes,:actor_user_id
                )
                """
            ),
            {
                "id": str(document_id), "tenant_id": str(tenant_id),
                "document_no": document_no, "warehouse_id": str(warehouse_id),
                "occurred_at": timestamp, "loss_id": str(loss_id),
                "idempotency_key": idempotency_key,
                "notes": notes.strip() if notes and notes.strip() else "Recovered production loss",
                "actor_user_id": str(actor_user_id),
            },
        )
        session.execute(
            text(
                """
                INSERT INTO inventory_document_lines(
                    id,tenant_id,document_id,line_no,item_id,lot_id,
                    item_code_snapshot,item_name_snapshot,quantity,unit_id,
                    unit_name_snapshot,conversion_to_base_snapshot,base_quantity,
                    unit_cost_snapshot,currency,line_value_snapshot,notes
                ) VALUES (
                    :id,:tenant_id,:document_id,1,:item_id,:lot_id,
                    :item_code,:item_name,:quantity,:unit_id,
                    :unit_name,:conversion,:base_quantity,:unit_cost,:currency,
                    :line_value,:notes
                )
                """
            ),
            {
                "id": str(line_id), "tenant_id": str(tenant_id),
                "document_id": str(document_id), "item_id": str(loss["item_id"]),
                "lot_id": str(inventory_lot_id), "item_code": loss["item_code"],
                "item_name": loss["item_name"], "quantity": quantity,
                "unit_id": str(loss["output_unit_id"]),
                "unit_name": loss["output_unit_name"], "conversion": conversion,
                "base_quantity": base_quantity,
                "unit_cost": (total_cost / quantity).quantize(Decimal("0.00000001")),
                "currency": currency, "line_value": total_cost,
                "notes": "Recovered quantity from production loss",
            },
        )
        session.execute(
            text(
                """
                UPDATE inventory_documents
                   SET status='posted',posted_at=:posted_at,posted_by=:actor_user_id,
                       updated_at=:posted_at
                 WHERE tenant_id=:tenant_id AND id=:document_id
                """
            ),
            {
                "posted_at": timestamp, "actor_user_id": str(actor_user_id),
                "tenant_id": str(tenant_id), "document_id": str(document_id),
            },
        )
        session.execute(
            text(
                """
                INSERT INTO inventory_ledger_entries(
                    tenant_id,document_id,document_line_id,warehouse_id,item_id,lot_id,
                    quantity_delta,value_delta,currency,unit_cost_snapshot,occurred_at
                ) VALUES (
                    :tenant_id,:document_id,:line_id,:warehouse_id,:item_id,:lot_id,
                    :quantity,:value,:currency,:unit_cost,:occurred_at
                )
                """
            ),
            {
                "tenant_id": str(tenant_id), "document_id": str(document_id),
                "line_id": str(line_id), "warehouse_id": str(warehouse_id),
                "item_id": str(loss["item_id"]), "lot_id": str(inventory_lot_id),
                "quantity": base_quantity, "value": total_cost, "currency": currency,
                "unit_cost": (total_cost / base_quantity).quantize(Decimal("0.00000001")),
                "occurred_at": timestamp,
            },
        )
        session.execute(
            text(
                """
                INSERT INTO production_recovery_lots(
                    id,tenant_id,loss_id,recovered_inventory_lot_id,recovered_quantity,
                    unit_id,original_cost_snapshot,recovery_cost_snapshot,currency,
                    recovered_at,inventory_document_id,inventory_document_line_id,recovered_by
                ) VALUES (
                    :id,:tenant_id,:loss_id,:inventory_lot_id,:quantity,
                    :unit_id,:material_value,:recovery_cost,:currency,
                    :recovered_at,:document_id,:line_id,:actor_user_id
                )
                """
            ),
            {
                "id": str(recovery_id), "tenant_id": str(tenant_id),
                "loss_id": str(loss_id), "inventory_lot_id": str(inventory_lot_id),
                "quantity": quantity, "unit_id": str(loss["unit_id"]),
                "material_value": material_value_snapshot, "recovery_cost": recovery_cost_snapshot,
                "currency": currency, "recovered_at": timestamp,
                "document_id": str(document_id), "line_id": str(line_id),
                "actor_user_id": str(actor_user_id),
            },
        )
        session.execute(
            text(
                """
                UPDATE production_losses SET disposition='recovered'
                 WHERE tenant_id=:tenant_id AND id=:loss_id
                """
            ),
            {"tenant_id": str(tenant_id), "loss_id": str(loss_id)},
        )
        session.execute(
            text(
                """
                INSERT INTO tenant_audit_events(
                    tenant_id,actor_user_id,action,entity_type,entity_id,after_data,metadata
                ) VALUES (
                    :tenant_id,:actor_user_id,'production.loss.recovered',
                    'production_loss',:loss_id,
                    jsonb_build_object('quantity',CAST(:quantity AS numeric),
                                       'total_cost',CAST(:total_cost AS numeric),
                                       'currency',:currency),
                    jsonb_build_object('recovery_lot_id',CAST(:recovery_id AS uuid),
                                       'inventory_lot_id',CAST(:inventory_lot_id AS uuid),
                                       'inventory_document_id',CAST(:document_id AS uuid))
                )
                """
            ),
            {
                "tenant_id": str(tenant_id), "actor_user_id": str(actor_user_id),
                "loss_id": str(loss_id), "quantity": quantity, "total_cost": total_cost,
                "currency": currency, "recovery_id": str(recovery_id),
                "inventory_lot_id": str(inventory_lot_id), "document_id": str(document_id),
            },
        )
    except DBAPIError as exc:
        _translate_db_error(exc)
    return ProductionRecoveryResult(
        loss_id,recovery_id,inventory_lot_id,document_id,quantity,total_cost,currency
    )


def reconcile_and_close_batch(
    session: Session,
    *,
    actor_user_id: UUID,
    tenant_id: UUID,
    batch_id: UUID,
    idempotency_key: str,
    notes: str | None = None,
) -> ProductionReconciliationResult:
    """Finalize immutable cost and close only when all good output is accounted for."""
    _set_context(session, actor_user_id, tenant_id)
    _require_production_module(session, tenant_id)
    _lock_batch(session, tenant_id, batch_id)
    try:
        batch = session.execute(
            text(
                """
                SELECT status,t.default_currency
                  FROM production_batches b
                  JOIN tenants t ON t.id=b.tenant_id
                 WHERE b.tenant_id=:tenant_id AND b.id=:batch_id
                 FOR UPDATE OF b
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).mappings().one_or_none()
        if batch is None or batch["status"] != "ready":
            raise ProductionReconciliationError("Only a ready production batch can be reconciled and closed.")
        existing = session.execute(
            text(
                """
                SELECT r.id,r.cost_snapshot_id,r.output_quantity,r.placed_quantity,
                       r.loss_quantity,cs.total_cost,r.currency
                  FROM production_batch_reconciliations r
                  JOIN production_cost_snapshots cs
                    ON cs.tenant_id=r.tenant_id AND cs.id=r.cost_snapshot_id
                 WHERE r.tenant_id=:tenant_id AND r.batch_id=:batch_id
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).mappings().one_or_none()
        if existing is not None:
            transition = transition_production_batch(
                session, actor_user_id=actor_user_id, tenant_id=tenant_id,
                batch_id=batch_id, command="reconcile_and_close",
                idempotency_key=idempotency_key, notes=notes,
            )
            return ProductionReconciliationResult(
                batch_id,UUID(str(existing["id"])),UUID(str(existing["cost_snapshot_id"])),
                Decimal(existing["output_quantity"]),Decimal(existing["placed_quantity"]),
                Decimal(existing["loss_quantity"]),Decimal(existing["total_cost"]),
                str(existing["currency"]).strip(),transition,
            )

        output = Decimal(session.execute(
            text(
                """
                SELECT COALESCE(sum(output_quantity),0)
                  FROM production_lots
                 WHERE tenant_id=:tenant_id AND batch_id=:batch_id
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).scalar_one())
        placed = Decimal(session.execute(
            text(
                """
                SELECT COALESCE(sum(p.quantity_delta),0) - COALESCE((
                           SELECT sum(l.quantity) FROM production_losses l
                            WHERE l.tenant_id=:tenant_id AND l.batch_id=:batch_id
                              AND l.stage='kumbung'
                              AND l.disposition IN ('recovered','recycled','permanent_loss','discarded')
                       ),0)
                  FROM kumbung_placements p
                  JOIN production_lot_segments s
                    ON s.tenant_id=p.tenant_id AND s.id=p.production_lot_segment_id
                 WHERE p.tenant_id=:tenant_id AND s.batch_id=:batch_id
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).scalar_one())
        loss_state = session.execute(
            text(
                """
                SELECT COALESCE(sum(quantity),0) AS loss_quantity,
                       count(*) FILTER (WHERE disposition='pending') AS pending_count,
                       count(*) FILTER (
                           WHERE disposition IN ('recovered','recycled')
                             AND NOT EXISTS (
                                 SELECT 1 FROM production_recovery_lots r
                                  WHERE r.tenant_id=l.tenant_id AND r.loss_id=l.id
                                    AND r.recovered_quantity=l.quantity
                             )
                       ) AS missing_recovery_count
                  FROM production_losses l
                 WHERE l.tenant_id=:tenant_id AND l.batch_id=:batch_id
                   AND l.stage <> 'press_baglog'
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).mappings().one()
        losses = Decimal(loss_state["loss_quantity"])
        if int(loss_state["pending_count"]) or int(loss_state["missing_recovery_count"]):
            raise ProductionReconciliationError(
                "Every non-press loss must have a terminal disposition and any recovery must be fully posted."
            )
        if output <= 0 or placed < 0 or losses < 0 or placed + losses != output:
            raise ProductionReconciliationError(
                "Good production output must equal current kumbung placement plus recorded losses/recoveries."
            )

        material = session.execute(
            text(
                """
                SELECT count(*) AS line_count,
                       COALESCE(sum(material_cost_snapshot),0) AS amount,
                       count(DISTINCT currency) AS currencies,
                       min(currency) AS currency
                  FROM production_batch_consumptions
                 WHERE tenant_id=:tenant_id AND batch_id=:batch_id
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).mappings().one()
        if int(material["line_count"]) == 0 or int(material["currencies"]) != 1:
            raise ProductionReconciliationError(
                "Final costing requires posted material consumption in one currency."
            )
        currency = str(batch["default_currency"]).strip()
        if str(material["currency"]).strip() != currency:
            raise ProductionReconciliationError("Material cost must use the tenant base currency.")
        overhead = session.execute(
            text(
                """
                SELECT COALESCE(sum(total_cost),0) AS amount,
                       count(DISTINCT currency) AS currencies,
                       min(currency) AS currency
                  FROM production_machine_cost_allocations
                 WHERE tenant_id=:tenant_id AND batch_id=:batch_id
                """
            ),
            {"tenant_id": str(tenant_id), "batch_id": str(batch_id)},
        ).mappings().one()
        if int(overhead["currencies"]) > 1 or (
            int(overhead["currencies"]) == 1 and str(overhead["currency"]).strip() != currency
        ):
            raise ProductionReconciliationError("Machine overhead must use the tenant base currency.")
        material_cost = Decimal(material["amount"])
        overhead_cost = Decimal(overhead["amount"])
        snapshot_id = uuid4()
        session.execute(
            text(
                """
                INSERT INTO production_cost_snapshots(
                    id,tenant_id,batch_id,output_quantity,material_cost,
                    overhead_cost,currency,finalized_at,finalized_by
                ) VALUES (
                    :id,:tenant_id,:batch_id,:output,:material,:overhead,
                    :currency,now(),:actor_user_id
                )
                """
            ),
            {
                "id": str(snapshot_id), "tenant_id": str(tenant_id),
                "batch_id": str(batch_id), "output": output,
                "material": material_cost, "overhead": overhead_cost,
                "currency": currency, "actor_user_id": str(actor_user_id),
            },
        )
        reconciliation_id = uuid4()
        session.execute(
            text(
                """
                INSERT INTO production_batch_reconciliations(
                    id,tenant_id,batch_id,cost_snapshot_id,output_quantity,
                    placed_quantity,loss_quantity,accounted_quantity,currency,finalized_by
                ) VALUES (
                    :id,:tenant_id,:batch_id,:snapshot_id,:output,
                    :placed,:losses,:accounted,:currency,:actor_user_id
                )
                """
            ),
            {
                "id": str(reconciliation_id), "tenant_id": str(tenant_id),
                "batch_id": str(batch_id), "snapshot_id": str(snapshot_id),
                "output": output, "placed": placed, "losses": losses,
                "accounted": placed + losses, "currency": currency,
                "actor_user_id": str(actor_user_id),
            },
        )
        transition = transition_production_batch(
            session, actor_user_id=actor_user_id, tenant_id=tenant_id,
            batch_id=batch_id, command="reconcile_and_close",
            idempotency_key=idempotency_key, notes=notes,
        )
    except ProductionLifecycleError as exc:
        raise ProductionReconciliationError(str(exc)) from exc
    except DBAPIError as exc:
        _translate_db_error(exc)
    return ProductionReconciliationResult(
        batch_id,reconciliation_id,snapshot_id,output,placed,losses,
        material_cost+overhead_cost,currency,transition,
    )

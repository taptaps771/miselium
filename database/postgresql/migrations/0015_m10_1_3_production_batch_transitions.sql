-- Miselium M10.1.3 / 0015 Production batch transitions and idempotency
-- PostgreSQL 16+. Requires migrations 0001-0014.
BEGIN;

ALTER TABLE production_batch_events
    ADD COLUMN idempotency_key varchar(120),
    ADD COLUMN request_hash char(64),
    ADD CONSTRAINT production_batch_events_idempotency_key_check
        CHECK (idempotency_key IS NULL OR length(btrim(idempotency_key)) BETWEEN 1 AND 120),
    ADD CONSTRAINT production_batch_events_request_hash_check
        CHECK (request_hash IS NULL OR request_hash ~ '^[0-9a-f]{64}$'),
    ADD CONSTRAINT production_batch_events_idempotency_pair_check
        CHECK ((idempotency_key IS NULL) = (request_hash IS NULL));

CREATE UNIQUE INDEX uq_production_batch_event_idempotency
    ON production_batch_events(tenant_id, batch_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

CREATE TRIGGER production_batch_events_immutable
    BEFORE UPDATE OR DELETE ON production_batch_events
    FOR EACH ROW EXECUTE FUNCTION reject_immutable_mutation();

-- The runtime can read batch/event context and update only lifecycle-owned fields.
GRANT SELECT ON production_batch_events TO miselium_app;
GRANT INSERT ON production_batch_events TO miselium_app;
GRANT UPDATE (status, started_at, updated_at) ON production_batches TO miselium_app;
GRANT SELECT ON recipes, recipe_versions TO miselium_app;
GRANT SELECT ON production_batch_consumptions, production_press_outputs TO miselium_app;
GRANT SELECT ON sterilization_run_batches, sterilization_runs, sterilization_cycles TO miselium_app;
GRANT SELECT ON inoculation_allocations, inoculation_runs, incubation_records TO miselium_app;
GRANT SELECT ON production_losses, production_lots, kumbung_placements, production_recovery_lots TO miselium_app;

COMMIT;

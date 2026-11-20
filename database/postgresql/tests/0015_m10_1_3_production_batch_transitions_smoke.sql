-- M10.1.3 production lifecycle schema smoke test.
-- Run as administrator after applying migrations 0001-0015.
BEGIN;
DO $m1013$
DECLARE
    v_count integer;
    v_definition text;
BEGIN
    SELECT count(*) INTO v_count
      FROM information_schema.columns
     WHERE table_schema=current_schema()
       AND table_name='production_batch_events'
       AND column_name IN ('idempotency_key','request_hash');
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'Production batch events must carry idempotency key and request hash';
    END IF;

    SELECT count(*) INTO v_count
      FROM pg_indexes
     WHERE schemaname=current_schema()
       AND indexname='uq_production_batch_event_idempotency';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Batch event idempotency unique index is missing';
    END IF;

    SELECT count(*) INTO v_count
      FROM pg_trigger
     WHERE tgrelid='production_batch_events'::regclass
       AND tgname='production_batch_events_immutable'
       AND NOT tgisinternal;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Production batch event immutability trigger is missing';
    END IF;

    SELECT pg_get_triggerdef(oid) INTO v_definition
      FROM pg_trigger
     WHERE tgrelid='production_batch_events'::regclass
       AND tgname='production_batch_events_immutable';
    IF position('UPDATE' IN v_definition) = 0
       OR position('DELETE' IN v_definition) = 0 THEN
        RAISE EXCEPTION 'Production batch event trigger must reject updates and deletes';
    END IF;

    IF NOT (SELECT relforcerowsecurity FROM pg_class WHERE oid='production_batch_events'::regclass) THEN
        RAISE EXCEPTION 'Production batch events must retain forced RLS';
    END IF;
    IF NOT has_table_privilege('miselium_app','production_batch_events','SELECT')
       OR NOT has_table_privilege('miselium_app','production_batch_events','INSERT') THEN
        RAISE EXCEPTION 'Runtime role requires event SELECT and INSERT';
    END IF;
    IF NOT has_column_privilege('miselium_app','production_batches','status','UPDATE')
       OR has_column_privilege('miselium_app','production_batches','batch_code','UPDATE') THEN
        RAISE EXCEPTION 'Runtime role must have narrow lifecycle update privileges only';
    END IF;
END;
$m1013$;
ROLLBACK;

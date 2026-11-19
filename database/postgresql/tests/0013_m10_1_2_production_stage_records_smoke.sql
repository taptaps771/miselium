-- M10.1.2 schema and invariant smoke test. Disposable PostgreSQL 16 database.
-- Run as database administrator after migrations 0001, 0002, 0011, 0012 and 0013.
BEGIN;
DO $m1012$
DECLARE
    v_count integer;
    v_def text;
BEGIN
    SELECT count(*) INTO v_count
      FROM information_schema.columns
     WHERE table_schema = current_schema()
       AND table_name = 'sterilization_runs'
       AND column_name = 'cycle_id';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'sterilization_runs.cycle_id is missing';
    END IF;

    SELECT count(*) INTO v_count
      FROM pg_constraint
     WHERE conrelid = 'production_press_outputs'::regclass
       AND contype = 'c'
       AND pg_get_constraintdef(oid) ILIKE '%processed_quantity%good_quantity%rejected_quantity%';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Press output must enforce processed = good + rejected';
    END IF;

    SELECT count(*) INTO v_count
      FROM pg_indexes
     WHERE schemaname = current_schema()
       AND indexname = 'uq_sterilization_cycle_machine';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'A sterilizer may only appear once in a grouped cycle';
    END IF;

    SELECT count(*) INTO v_count
      FROM pg_constraint
     WHERE conrelid = 'production_losses'::regclass
       AND contype = 'c'
       AND pg_get_constraintdef(oid) ILIKE '%press_baglog%';
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Press Baglog is missing from production loss stages';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_class
         WHERE oid = 'sterilization_cycles'::regclass
           AND relrowsecurity AND relforcerowsecurity
    ) THEN
        RAISE EXCEPTION 'Sterilization cycles must have forced RLS';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_class
         WHERE oid = 'production_press_outputs'::regclass
           AND relrowsecurity AND relforcerowsecurity
    ) THEN
        RAISE EXCEPTION 'Press outputs must have forced RLS';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid = 'production_press_outputs'::regclass
           AND tgname = 'production_press_outputs_immutable'
           AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'Press output immutability trigger is missing';
    END IF;

    -- Legacy rows are intentionally allowed to have a NULL cycle_id.
    IF (SELECT is_nullable FROM information_schema.columns
         WHERE table_schema=current_schema()
           AND table_name='sterilization_runs'
           AND column_name='cycle_id') <> 'YES' THEN
        RAISE EXCEPTION 'Legacy sterilization runs must remain nullable until explicitly mapped';
    END IF;
END;
$m1012$;
ROLLBACK;

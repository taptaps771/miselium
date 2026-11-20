-- M10.1.5 sterilization scheduling/capacity schema smoke test.
-- Run as database administrator after migrations 0001-0017 on disposable PostgreSQL.
BEGIN;
DO $m1015$
DECLARE
    v_count integer;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class
         WHERE oid='sterilization_cycle_events'::regclass
           AND relrowsecurity AND relforcerowsecurity
    ) THEN
        RAISE EXCEPTION 'Sterilization cycle events must have forced RLS';
    END IF;

    SELECT count(*) INTO v_count
      FROM information_schema.columns
     WHERE table_schema=current_schema()
       AND (
         (table_name='sterilization_cycles' AND column_name IN ('capacity_unit_id','planned_capacity'))
         OR (table_name='sterilization_runs' AND column_name IN (
             'planned_start_at','planned_end_at','cooling_due_at',
             'cycle_minutes_snapshot','cooling_minutes_snapshot',
             'capacity_to_cycle_unit_snapshot'
         ))
         OR (table_name='sterilization_run_batches' AND column_name IN (
             'quantity_to_capacity_unit_snapshot','capacity_quantity_snapshot'
         ))
    );
    IF v_count <> 10 THEN
        RAISE EXCEPTION 'Sterilization schedule and capacity snapshot columns are incomplete';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='sterilization_runs'::regclass
           AND tgname='sterilization_run_schedule_overlap_guard'
           AND NOT tgisinternal
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='sterilization_run_batches'::regclass
           AND tgname='sterilization_run_batch_capacity_guard'
           AND NOT tgisinternal
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='sterilization_cycle_events'::regclass
           AND tgname='sterilization_cycle_events_immutable'
           AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'Sterilization schedule/capacity/event guards are missing';
    END IF;

    IF NOT has_table_privilege('miselium_app','public.sterilization_cycles','INSERT')
       OR NOT has_table_privilege('miselium_app','public.sterilization_runs','UPDATE')
       OR NOT has_table_privilege('miselium_app','public.sterilization_run_batches','INSERT')
       OR NOT has_table_privilege('miselium_app','public.sterilization_cycle_events','INSERT')
       OR NOT has_table_privilege('miselium_app','public.measurement_unit_conversions','SELECT') THEN
        RAISE EXCEPTION 'Runtime role is missing restricted sterilization service privileges';
    END IF;

    IF has_table_privilege('miselium_app','public.sterilizers','UPDATE') THEN
        RAISE EXCEPTION 'Runtime role must not update sterilizer master data to schedule a run';
    END IF;
END;
$m1015$;
ROLLBACK;

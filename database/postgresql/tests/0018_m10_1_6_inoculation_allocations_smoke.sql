-- M10.1.6 inoculation allocation schema smoke test.
-- Run as database administrator after migrations 0001-0018 on disposable PostgreSQL.
BEGIN;
DO $m1016$
DECLARE
    v_count integer;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class
         WHERE oid='inoculation_run_events'::regclass
           AND relrowsecurity AND relforcerowsecurity
    ) THEN
        RAISE EXCEPTION 'Inoculation run events must have forced RLS';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='inoculation_allocations'::regclass
           AND tgname='inoculation_allocation_capacity_guard'
           AND NOT tgisinternal
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='inoculation_allocations'::regclass
           AND tgname='inoculation_allocations_immutable'
           AND NOT tgisinternal
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='inoculation_run_events'::regclass
           AND tgname='inoculation_run_events_immutable'
           AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'Inoculation allocation and event guards are missing';
    END IF;

    IF NOT has_table_privilege('miselium_app','public.inoculation_runs','INSERT')
       OR NOT has_table_privilege('miselium_app','public.inoculation_runs','UPDATE')
       OR NOT has_table_privilege('miselium_app','public.inoculation_allocations','INSERT')
       OR NOT has_table_privilege('miselium_app','public.inoculation_run_events','INSERT')
       OR NOT has_table_privilege('miselium_app','public.incubation_records','INSERT') THEN
        RAISE EXCEPTION 'Runtime role is missing restricted inoculation/incubation privileges';
    END IF;

    IF has_table_privilege('miselium_app','public.inoculation_allocations','UPDATE')
       OR has_table_privilege('miselium_app','public.inoculation_allocations','DELETE')
       OR has_table_privilege('miselium_app','public.inoculation_run_events','UPDATE')
       OR has_table_privilege('miselium_app','public.inoculation_run_events','DELETE') THEN
        RAISE EXCEPTION 'Runtime role must not mutate immutable inoculation allocations or events';
    END IF;
END;
$m1016$;
ROLLBACK;

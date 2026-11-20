-- M10.1.7 incubation readiness, variety lineage and kumbung capacity smoke test.
-- Run as database administrator after migrations 0001-0019 on disposable PostgreSQL.
BEGIN;
DO $m1017$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class
         WHERE oid='incubation_record_events'::regclass
           AND relrowsecurity AND relforcerowsecurity
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_class
         WHERE oid='production_lot_segments'::regclass
           AND relrowsecurity AND relforcerowsecurity
    ) THEN
        RAISE EXCEPTION 'M10.1.7 tenant-owned history tables must have forced RLS';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='production_lot_segments'::regclass
           AND tgname='production_lot_segment_insert_guard'
           AND NOT tgisinternal
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='kumbung_placements'::regclass
           AND tgname='kumbung_placement_capacity_guard'
           AND NOT tgisinternal
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='production_lot_segments'::regclass
           AND tgname='production_lot_segments_immutable'
           AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'M10.1.7 lineage or capacity guards are missing';
    END IF;

    IF NOT has_table_privilege('miselium_app','public.production_lot_segments','INSERT')
       OR NOT has_table_privilege('miselium_app','public.incubation_record_events','INSERT')
       OR NOT has_table_privilege('miselium_app','public.kumbung_placements','INSERT')
       OR NOT has_column_privilege('miselium_app','public.kumbungs','capacity_unit_id','SELECT') THEN
        RAISE EXCEPTION 'Runtime role is missing restricted M10.1.7 privileges';
    END IF;

    IF has_table_privilege('miselium_app','public.production_lot_segments','UPDATE')
       OR has_table_privilege('miselium_app','public.production_lot_segments','DELETE')
       OR has_table_privilege('miselium_app','public.incubation_record_events','UPDATE')
       OR has_table_privilege('miselium_app','public.incubation_record_events','DELETE') THEN
        RAISE EXCEPTION 'M10.1.7 lineage and event history must be immutable';
    END IF;
END;
$m1017$;
ROLLBACK;

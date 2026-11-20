-- M10.1.4 atomic production-output schema smoke test.
-- Run as database administrator after migrations 0001-0016 on a disposable database.
BEGIN;
DO $m1014$
DECLARE
    v_count integer;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class
         WHERE oid='production_output_postings'::regclass
           AND relrowsecurity AND relforcerowsecurity
    ) THEN
        RAISE EXCEPTION 'Production output postings must have forced RLS';
    END IF;

    SELECT count(*) INTO v_count
      FROM pg_constraint
     WHERE conrelid='production_output_postings'::regclass
       AND contype='u';
    IF v_count <> 5 THEN
        RAISE EXCEPTION 'Production output posting must have tenant/id and batch/document/line/lot unique constraints';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='production_output_postings'::regclass
           AND tgname='production_output_posting_insert_guard'
           AND NOT tgisinternal
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='production_output_postings'::regclass
           AND tgname='production_output_postings_immutable'
           AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'Production output posting guard or immutability trigger is missing';
    END IF;

    IF NOT has_table_privilege('miselium_app','public.production_output_postings','INSERT')
       OR NOT has_table_privilege('miselium_app','public.production_lots','INSERT')
       OR NOT has_table_privilege('miselium_app','public.inventory_lots','INSERT')
       OR NOT has_column_privilege('miselium_app','public.production_batches','actual_output_quantity','UPDATE') THEN
        RAISE EXCEPTION 'Runtime role is missing production-output insert or projection privileges';
    END IF;

    IF has_column_privilege('miselium_app','public.production_batches','batch_code','UPDATE') THEN
        RAISE EXCEPTION 'Runtime role must not receive broad production batch update privileges';
    END IF;
END;
$m1014$;
ROLLBACK;

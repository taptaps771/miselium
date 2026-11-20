-- M10.1.8 loss, recovery and batch reconciliation schema smoke test.
-- Run as database administrator after migrations 0001-0020 on disposable PostgreSQL.
BEGIN;
DO $m1018$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class
         WHERE oid='production_loss_events'::regclass
           AND relrowsecurity AND relforcerowsecurity
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_class
         WHERE oid='production_batch_reconciliations'::regclass
           AND relrowsecurity AND relforcerowsecurity
    ) THEN
        RAISE EXCEPTION 'M10.1.8 tenant-owned history tables must have forced RLS';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='production_losses'::regclass
           AND tgname='production_loss_insert_guard' AND NOT tgisinternal
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='production_losses'::regclass
           AND tgname='production_losses_mutation_guard' AND NOT tgisinternal
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='production_recovery_lots'::regclass
           AND tgname='production_recovery_insert_guard' AND NOT tgisinternal
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='production_batch_reconciliations'::regclass
           AND tgname='production_batch_reconciliation_insert_guard' AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION 'M10.1.8 loss, recovery or reconciliation guards are missing';
    END IF;

    IF NOT has_table_privilege('miselium_app','public.production_losses','INSERT')
       OR NOT has_column_privilege('miselium_app','public.production_losses','disposition','UPDATE')
       OR NOT has_table_privilege('miselium_app','public.production_loss_events','INSERT')
       OR NOT has_table_privilege('miselium_app','public.production_recovery_lots','INSERT')
       OR NOT has_table_privilege('miselium_app','public.production_batch_reconciliations','INSERT')
       OR NOT has_table_privilege('miselium_app','public.production_cost_snapshots','INSERT') THEN
        RAISE EXCEPTION 'Runtime role is missing restricted M10.1.8 privileges';
    END IF;

    IF has_table_privilege('miselium_app','public.production_losses','DELETE')
       OR has_table_privilege('miselium_app','public.production_loss_events','UPDATE')
       OR has_table_privilege('miselium_app','public.production_loss_events','DELETE')
       OR has_table_privilege('miselium_app','public.production_recovery_lots','UPDATE')
       OR has_table_privilege('miselium_app','public.production_recovery_lots','DELETE')
       OR has_table_privilege('miselium_app','public.production_batch_reconciliations','UPDATE')
       OR has_table_privilege('miselium_app','public.production_batch_reconciliations','DELETE') THEN
        RAISE EXCEPTION 'M10.1.8 immutable history privileges are too broad';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_indexes
         WHERE schemaname='public'
           AND indexname='uq_production_loss_idempotency'
    ) THEN
        RAISE EXCEPTION 'Production loss idempotency index is missing';
    END IF;
END;
$m1018$;
ROLLBACK;

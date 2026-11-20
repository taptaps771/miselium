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
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='production_cost_snapshots'::regclass
           AND tgname='production_cost_snapshot_insert_guard' AND NOT tgisinternal
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='production_lot_segments'::regclass
           AND tgname='production_lot_segment_00_batch_lock_guard' AND NOT tgisinternal
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_trigger
         WHERE tgrelid='production_lot_segments'::regclass
           AND tgname='production_lot_segment_loss_capacity_guard' AND NOT tgisinternal
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
        SELECT 1 FROM information_schema.columns
         WHERE table_schema='public' AND table_name='production_cost_snapshots'
           AND column_name='recovery_credit'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema='public' AND table_name='production_cost_snapshots'
           AND column_name='net_total_cost'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema='public' AND table_name='production_batch_reconciliations'
           AND column_name='net_cost'
    ) THEN
        RAISE EXCEPTION 'M10.1.8 final costing must record salvage credit and net batch cost';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema='public' AND table_name='production_recovery_lots'
           AND column_name='loss_quantity_snapshot'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema='public' AND table_name='production_recovery_lots'
           AND column_name='recovery_mode'
    ) OR NOT EXISTS (
        SELECT 1 FROM information_schema.columns
         WHERE table_schema='public' AND table_name='production_recovery_lots'
           AND column_name='recovered_item_id'
    ) THEN
        RAISE EXCEPTION 'M10.1.8 must preserve both original loss and recovered stock quantity/item';
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

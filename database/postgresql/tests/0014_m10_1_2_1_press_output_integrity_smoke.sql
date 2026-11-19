-- M10.1.2.1 press output integrity guard smoke test.
-- Run as database administrator after migrations 0001, 0002, 0011, 0012, 0013 and 0014.
BEGIN;
DO $m10121$
DECLARE
    v_function text;
    v_count integer;
BEGIN
    SELECT pg_get_functiondef('guard_production_press_output_insert()'::regprocedure)
      INTO v_function;

    IF position('v_machine_status IS DISTINCT FROM ''active''' IN v_function) = 0 THEN
        RAISE EXCEPTION 'Press output guard must require an active machine';
    END IF;
    IF position('v_machine_unit <> v_batch_unit' IN v_function) = 0 THEN
        RAISE EXCEPTION 'Press output guard must enforce a shared production unit';
    END IF;
    IF position('NEW.quantity_unit_id <> v_batch_output_unit' IN v_function) = 0 THEN
        RAISE EXCEPTION 'Press output guard must match the batch output unit';
    END IF;
    IF position('FOR SHARE OF b, m' IN v_function) = 0 THEN
        RAISE EXCEPTION 'Press output guard must lock batch and machine during validation';
    END IF;

    SELECT count(*) INTO v_count
      FROM pg_trigger
     WHERE tgrelid = 'production_press_outputs'::regclass
       AND tgname = 'production_press_output_insert_guard'
       AND NOT tgisinternal;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Press output insert guard trigger must exist exactly once';
    END IF;
END;
$m10121$;
ROLLBACK;

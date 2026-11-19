-- Miselium M10.1.2.1 / 0014 Press output integrity guard
-- PostgreSQL 16+. Requires migrations 0001, 0002, 0011, 0012 and 0013.
-- Additive follow-up: do not rewrite 0013, which may already be applied.
BEGIN;

CREATE OR REPLACE FUNCTION guard_production_press_output_insert()
RETURNS trigger LANGUAGE plpgsql AS $m10121$
DECLARE
    v_batch_status varchar(30);
    v_batch_unit uuid;
    v_batch_output_unit uuid;
    v_machine_type varchar(40);
    v_machine_status varchar(20);
    v_machine_unit uuid;
BEGIN
    -- Lock both operational records while validating the output snapshot.
    -- This prevents a concurrent status/unit change during this insert.
    SELECT b.status, b.production_unit_id, b.output_unit_id,
           m.machine_type_code, m.status, m.production_unit_id
      INTO v_batch_status, v_batch_unit, v_batch_output_unit,
           v_machine_type, v_machine_status, v_machine_unit
      FROM production_batches AS b
      JOIN production_machines AS m
        ON m.tenant_id = b.tenant_id
     WHERE b.tenant_id = NEW.tenant_id
       AND b.id = NEW.batch_id
       AND m.id = NEW.machine_id
     FOR SHARE OF b, m;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Press output batch and machine must exist in the same tenant'
            USING ERRCODE = '23503';
    END IF;

    IF v_batch_status IS DISTINCT FROM 'press_baglog' THEN
        RAISE EXCEPTION 'Press output can only be recorded for a batch in press_baglog stage'
            USING ERRCODE = '23514';
    END IF;
    IF v_machine_type IS DISTINCT FROM 'PRESS_BAGLOG' THEN
        RAISE EXCEPTION 'Press output requires a PRESS_BAGLOG machine'
            USING ERRCODE = '23514';
    END IF;
    IF v_machine_status IS DISTINCT FROM 'active' THEN
        RAISE EXCEPTION 'Press output requires an active production machine'
            USING ERRCODE = '23514';
    END IF;
    IF v_machine_unit IS NULL OR v_batch_unit IS NULL
       OR v_machine_unit <> v_batch_unit THEN
        RAISE EXCEPTION 'Press machine and production batch must belong to the same production unit'
            USING ERRCODE = '23514';
    END IF;
    IF v_batch_output_unit IS NULL
       OR NEW.quantity_unit_id <> v_batch_output_unit THEN
        RAISE EXCEPTION 'Press output unit must match the production batch output unit'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$m10121$;

COMMIT;

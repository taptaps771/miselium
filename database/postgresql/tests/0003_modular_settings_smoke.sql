-- M11 modular Settings / production machine smoke test.
-- Run after M9 + M10 + M11 on a disposable PostgreSQL 16+ database.
-- The script is transactional and rolls back all fixtures.

BEGIN;

DO $m11$
DECLARE
    v_tenant uuid := gen_random_uuid();
    v_location uuid := gen_random_uuid();
    v_unit uuid := gen_random_uuid();
    v_production_unit uuid := gen_random_uuid();
    v_machine uuid := gen_random_uuid();
    v_rate uuid := gen_random_uuid();
BEGIN
    INSERT INTO tenants(id,code,name,status)
    VALUES (v_tenant,'M11-SMOKE-' || substr(v_tenant::text,1,8),'M11 Settings Smoke','active');

    PERFORM set_config('app.tenant_id',v_tenant::text,true);

    INSERT INTO locations(id,tenant_id,code,name)
    VALUES (v_location,v_tenant,'MAIN','Lokasi Utama');

    INSERT INTO production_units(id,tenant_id,location_id,code,name,production_type)
    VALUES (v_production_unit,v_tenant,v_location,'PROD','Unit Produksi','baglog');

    INSERT INTO measurement_units(id,code,name,dimension)
    VALUES (v_unit,'M11-BAG-' || substr(v_unit::text,1,8),'Baglog','count');

    INSERT INTO tenant_setting_configs(tenant_id,setting_module_code,config_version,configuration)
    VALUES (v_tenant,'appearance',1,'{"theme":"system","font_scale":1}'::jsonb);

    INSERT INTO production_machines(
        id,tenant_id,location_id,production_unit_id,machine_type_code,code,name,
        capacity,capacity_unit_id,acquisition_cost,residual_value,useful_life_months,
        depreciation_method,status
    ) VALUES (
        v_machine,v_tenant,v_location,v_production_unit,'MIXER','MIX-01','Mixer Smoke',
        500,v_unit,12000000,1000000,60,'straight_line','active'
    );

    INSERT INTO machine_overhead_rates(
        id,tenant_id,machine_id,activity_code,calculation_method,rate,currency,
        basis_unit_id,effective_from
    ) VALUES (
        v_rate,v_tenant,v_machine,'mixing','per_baglog_estimate',50,'IDR',
        v_unit,DATE '2026-01-01'
    );

    IF NOT EXISTS (
        SELECT 1 FROM setting_modules
        WHERE code='fingerprint' AND section_code='devices'
    ) THEN
        RAISE EXCEPTION 'Fingerprint settings module was not registered';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM production_machine_types
        WHERE code IN ('MIXER','PRESS_BAGLOG','STEAMER','AUTOCLAVE','SPRAYER_PUMP')
        HAVING count(*)=5
    ) THEN
        RAISE EXCEPTION 'Expected production machine types are missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM production_machines
        WHERE tenant_id=v_tenant AND id=v_machine AND machine_type_code='MIXER'
    ) THEN
        RAISE EXCEPTION 'Tenant machine setup failed';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM machine_overhead_rates
        WHERE tenant_id=v_tenant AND id=v_rate AND calculation_method='per_baglog_estimate'
    ) THEN
        RAISE EXCEPTION 'Machine overhead rate setup failed';
    END IF;
END;
$m11$;

ROLLBACK;

CREATE SCHEMA IF NOT EXISTS dw;
CREATE TABLE IF NOT EXISTS dw.dim_date (date_key integer PRIMARY KEY, full_date date UNIQUE NOT NULL, day smallint NOT NULL, month smallint NOT NULL, month_name text NOT NULL, quarter smallint NOT NULL, year smallint NOT NULL, iso_week smallint NOT NULL, weekday smallint NOT NULL, weekday_name text NOT NULL, is_weekend boolean NOT NULL);
CREATE TABLE IF NOT EXISTS dw.dim_machine (machine_key smallserial PRIMARY KEY, machine_code text UNIQUE NOT NULL, machine_name text NOT NULL, line_number smallint, active boolean NOT NULL DEFAULT true);
CREATE TABLE IF NOT EXISTS dw.dim_shift (shift_key smallserial PRIMARY KEY, shift_code text UNIQUE NOT NULL, shift_name text NOT NULL, start_time time, end_time time, shift_group text);
CREATE TABLE IF NOT EXISTS dw.dim_reference (reference_key bigserial PRIMARY KEY, reference_name text UNIQUE NOT NULL, family text, nominal_pack_size text);
CREATE TABLE IF NOT EXISTS dw.dim_stop (stop_key bigserial PRIMARY KEY, stop_source_token text UNIQUE NOT NULL, stop_code text, stop_label text, subcode text, subcode_label text, impact_area text, owner_group text, hierarchy_level text NOT NULL, is_mapped boolean NOT NULL DEFAULT false);
CREATE TABLE IF NOT EXISTS dw.fact_production (source_row_id bigint PRIMARY KEY, date_key integer NOT NULL REFERENCES dw.dim_date, machine_key smallint NOT NULL REFERENCES dw.dim_machine, shift_key smallint NOT NULL REFERENCES dw.dim_shift, reference_key bigint NOT NULL REFERENCES dw.dim_reference, record_count smallint NOT NULL DEFAULT 1, cases_produced numeric(14,3), operating_hours numeric(20,12), reported_nonworking_hours numeric(20,12), reported_downtime_hours numeric(20,12), source_sheet text NOT NULL DEFAULT 'Base De Datos', source_excel_row integer NOT NULL, loaded_at timestamptz NOT NULL DEFAULT now(), CHECK (cases_produced IS NULL OR cases_produced >= 0), CHECK (operating_hours IS NULL OR operating_hours >= 0), CHECK (reported_nonworking_hours IS NULL OR reported_nonworking_hours >= 0), CHECK (reported_downtime_hours IS NULL OR reported_downtime_hours >= 0));
COMMENT ON TABLE dw.fact_production IS 'Grano: una fila fuente no vacía de Base De Datos para un registro de producción por fecha, máquina, turno y referencia.';
CREATE TABLE IF NOT EXISTS dw.fact_downtime (downtime_id bigserial PRIMARY KEY, source_row_id bigint NOT NULL REFERENCES dw.fact_production ON DELETE CASCADE, stop_key bigint NOT NULL REFERENCES dw.dim_stop, source_slot smallint NOT NULL, duration_hours numeric(20,12) NOT NULL CHECK(duration_hours >= 0), duration_source text NOT NULL, loaded_at timestamptz NOT NULL DEFAULT now(), UNIQUE(source_row_id,source_slot));
COMMENT ON TABLE dw.fact_downtime IS 'Grano: una fila por cada intervalo de duración de paro registrado dentro de una fila fuente de producción; las categorías no mapeadas se conservan explícitas.';
CREATE TABLE IF NOT EXISTS dw.fact_live_hour (hour_start timestamptz NOT NULL, machine_key smallint NOT NULL REFERENCES dw.dim_machine, shift_key smallint REFERENCES dw.dim_shift, planned_minutes numeric(8,2) NOT NULL, run_minutes numeric(8,2) NOT NULL, downtime_minutes numeric(8,2) NOT NULL, produced_cases numeric(12,2), source_mode text NOT NULL DEFAULT 'simulation', PRIMARY KEY(hour_start,machine_key), CHECK(planned_minutes>=0 AND run_minutes>=0 AND downtime_minutes>=0));
COMMENT ON TABLE dw.fact_live_hour IS 'Grano: una fila por máquina y hora de telemetría simulada; registra minutos planificados, en marcha, de paro y producción para monitoreo operativo.';
CREATE TABLE IF NOT EXISTS dw.etl_audit (run_id bigserial PRIMARY KEY, started_at timestamptz NOT NULL DEFAULT now(), finished_at timestamptz, source_file text NOT NULL, source_rows integer NOT NULL DEFAULT 0, accepted_rows integer NOT NULL DEFAULT 0, rejected_rows integer NOT NULL DEFAULT 0, downtime_events integer NOT NULL DEFAULT 0, quality_summary jsonb NOT NULL DEFAULT '{}'::jsonb, status text NOT NULL DEFAULT 'running');
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fact_production_nonworking_nonnegative') THEN
    ALTER TABLE dw.fact_production ADD CONSTRAINT fact_production_nonworking_nonnegative CHECK (reported_nonworking_hours IS NULL OR reported_nonworking_hours >= 0);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fact_production_downtime_nonnegative') THEN
    ALTER TABLE dw.fact_production ADD CONSTRAINT fact_production_downtime_nonnegative CHECK (reported_downtime_hours IS NULL OR reported_downtime_hours >= 0);
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS ix_fact_prod_date_machine ON dw.fact_production(date_key,machine_key);
CREATE INDEX IF NOT EXISTS ix_fact_prod_machine_shift ON dw.fact_production(machine_key,shift_key,date_key);
CREATE INDEX IF NOT EXISTS ix_fact_downtime_stop ON dw.fact_downtime(stop_key,source_row_id);
CREATE INDEX IF NOT EXISTS ix_fact_downtime_source ON dw.fact_downtime(source_row_id);
CREATE INDEX IF NOT EXISTS ix_fact_live_hour_machine_time ON dw.fact_live_hour(machine_key,hour_start DESC);

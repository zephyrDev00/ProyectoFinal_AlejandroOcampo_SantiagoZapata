-- Hecho de paro con llaves conformadas para dimensiones compartidas (sin relación hecho-a-hecho en Power BI).
CREATE OR REPLACE VIEW dw.vw_downtime_detail AS
SELECT x.downtime_id, x.source_row_id, x.stop_key, f.date_key, f.machine_key, f.shift_key, f.reference_key,
       x.source_slot, x.duration_hours, x.duration_source
FROM dw.fact_downtime x JOIN dw.fact_production f USING(source_row_id);

-- Demostraciones de negocio (conexión directa desde Power BI/Grafana al DW).
-- Disponibilidad de registro = horas trabajadas / (horas trabajadas + horas no trabajadas).
-- Es proxy; valide definición de tiempo planificado con Producción.
CREATE OR REPLACE VIEW dw.vw_monthly_machine AS
SELECT d.year,d.month,d.month_name,m.machine_code,
       SUM(f.cases_produced) AS pacas, SUM(f.operating_hours) AS horas_operativas,
       SUM(f.reported_nonworking_hours) AS horas_no_trabajadas,
       SUM(f.reported_downtime_hours) AS paro_reportado_h,
       SUM(f.operating_hours)/NULLIF(SUM(f.operating_hours)+SUM(f.reported_nonworking_hours),0) AS disponibilidad_proxy,
       SUM(f.cases_produced)/NULLIF(SUM(f.operating_hours),0) AS pacas_por_hora,
       LAG(SUM(f.cases_produced)) OVER(PARTITION BY m.machine_code ORDER BY d.year,d.month) AS pacas_mes_anterior,
       SUM(f.cases_produced)-LAG(SUM(f.cases_produced)) OVER(PARTITION BY m.machine_code ORDER BY d.year,d.month) AS variacion_mensual_pacas
FROM dw.fact_production f JOIN dw.dim_date d USING(date_key) JOIN dw.dim_machine m USING(machine_key)
GROUP BY d.year,d.month,d.month_name,m.machine_code;
-- Pareto de causas. Incluye explícitamente las categorías sin mapear.
SELECT s.stop_code,s.stop_label,s.subcode_label,SUM(x.duration_hours) AS paro_h,
       SUM(SUM(x.duration_hours)) OVER() AS total_h,
       SUM(x.duration_hours)/NULLIF(SUM(SUM(x.duration_hours)) OVER(),0) AS share_total
FROM dw.fact_downtime x JOIN dw.dim_stop s USING(stop_key)
GROUP BY s.stop_code,s.stop_label,s.subcode_label ORDER BY paro_h DESC;
-- Calidad disponible: no hay campos históricos de unidades buenas/malas o ciclo ideal.
SELECT 'OEE' AS indicador,NULL::numeric AS valor,'NO CALCULABLE: falta calidad y ciclo ideal' AS estado;

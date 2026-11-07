-- Hecho de paro con llaves conformadas para dimensiones compartidas (sin relación hecho-a-hecho en Power BI).
CREATE OR REPLACE VIEW dw.vw_downtime_detail AS
SELECT x.downtime_id, x.source_row_id, x.stop_key, f.date_key, f.machine_key, f.shift_key, f.reference_key,
       x.source_slot, x.duration_hours, x.duration_source
FROM dw.fact_downtime x JOIN dw.fact_production f USING(source_row_id);

-- Vista mensual por máquina con funciones de ventana (LAG) para comparación entre periodos.
CREATE OR REPLACE VIEW dw.vw_monthly_machine AS
SELECT d.year, d.month, d.month_name, m.machine_code, m.machine_name,
       SUM(f.cases_produced) AS pacas,
       SUM(f.operating_hours) AS horas_operativas,
       SUM(f.reported_nonworking_hours) AS horas_no_trabajadas,
       SUM(f.reported_downtime_hours) AS paro_reportado_h,
       SUM(f.operating_hours)/NULLIF(SUM(f.operating_hours)+SUM(f.reported_nonworking_hours),0) AS disponibilidad_proxy,
       SUM(f.cases_produced)/NULLIF(SUM(f.operating_hours),0) AS pacas_por_hora,
       LAG(SUM(f.cases_produced)) OVER(PARTITION BY m.machine_code ORDER BY d.year,d.month) AS pacas_mes_anterior,
       SUM(f.cases_produced)-LAG(SUM(f.cases_produced)) OVER(PARTITION BY m.machine_code ORDER BY d.year,d.month) AS variacion_mensual_pacas,
       ROUND(
           (SUM(f.cases_produced) - LAG(SUM(f.cases_produced)) OVER (PARTITION BY m.machine_code ORDER BY d.year, d.month))
           / NULLIF(LAG(SUM(f.cases_produced)) OVER (PARTITION BY m.machine_code ORDER BY d.year, d.month), 0) * 100,
           2
       ) AS variacion_mensual_pct
FROM dw.fact_production f
JOIN dw.dim_date d USING(date_key)
JOIN dw.dim_machine m USING(machine_key)
GROUP BY d.year, d.month, d.month_name, m.machine_code, m.machine_name;

-- 1. Comparativo intermensual por línea con funciones de ventana (LAG)
SELECT
    m.machine_name,
    d.year,
    d.month,
    SUM(fp.cases_produced) AS pacas_mes,
    ROUND(SUM(fp.operating_hours), 2) AS horas_operativas,
    ROUND(
        SUM(fp.operating_hours) / NULLIF(SUM(fp.operating_hours) + SUM(fp.reported_nonworking_hours), 0) * 100, 
        2
    ) AS disponibilidad_proxy_pct,
    LAG(SUM(fp.cases_produced)) OVER (
        PARTITION BY m.machine_name ORDER BY d.year, d.month
    ) AS pacas_mes_anterior,
    ROUND(
        (SUM(fp.cases_produced) - LAG(SUM(fp.cases_produced)) OVER (PARTITION BY m.machine_name ORDER BY d.year, d.month))
        / NULLIF(LAG(SUM(fp.cases_produced)) OVER (PARTITION BY m.machine_name ORDER BY d.year, d.month), 0) * 100,
        2
    ) AS variacion_mensual_pct
FROM dw.fact_production fp
JOIN dw.dim_date d ON fp.date_key = d.date_key
JOIN dw.dim_machine m ON fp.machine_key = m.machine_key
GROUP BY m.machine_name, d.year, d.month
ORDER BY m.machine_name, d.year, d.month;

-- 2. Análisis de Pareto (80/20) de causas y subcausas de paro con SUM() OVER y RANK()
WITH paros_agrupados AS (
    SELECT
        s.stop_code,
        s.stop_label,
        COALESCE(s.subcode, 'SIN SUBCÓDIGO') AS subcodigo,
        s.subcode_label,
        ROUND(SUM(fd.duration_hours), 2) AS horas_paro
    FROM dw.fact_downtime fd
    JOIN dw.dim_stop s ON fd.stop_key = s.stop_key
    GROUP BY s.stop_code, s.stop_label, COALESCE(s.subcode, 'SIN SUBCÓDIGO'), s.subcode_label
)
SELECT
    RANK() OVER (ORDER BY horas_paro DESC) AS ranking,
    stop_code,
    stop_label,
    subcodigo,
    subcode_label,
    horas_paro,
    ROUND(horas_paro / SUM(horas_paro) OVER () * 100, 2) AS participacion_pct,
    ROUND(
        SUM(horas_paro) OVER (ORDER BY horas_paro DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        / SUM(horas_paro) OVER () * 100,
        2
    ) AS pareto_acumulado_pct
FROM paros_agrupados
ORDER BY horas_paro DESC;

-- 3. Estado del indicador OEE certificado
SELECT 'OEE' AS indicador, NULL::numeric AS valor, 'NO CALCULABLE: falta calidad y ciclo ideal en hoja Base De Datos' AS estado;

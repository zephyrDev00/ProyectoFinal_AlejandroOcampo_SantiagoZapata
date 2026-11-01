# Proyecto Power BI

`BI_ProyectoFinal.pbip` apunta al reporte PBIR y al modelo TMDL. El formato de texto se elige porque facilita la revisión y el control de cambios en Git frente a un PBIX binario. Las consultas leen PostgreSQL, no el libro fuente.

## Conexión

El modelo usa `PostgreSQL.Database("localhost:5433", "vinilos_bi")`, esquema `dw`. Cada consulta navega por la clave compuesta `Schema` + `Item` del catálogo PostgreSQL para resolver cada objeto de forma única. La credencial la administra Power BI Desktop en el equipo; no se serializa en el proyecto. Para otra configuración, cambie host/puerto por el entorno, guarde y refresque. El origen incluye `fact_production`, `vw_downtime_detail` y las dimensiones de fecha, máquina, turno, referencia y paro.

## Modelo y medidas

Relaciones 1:* y filtro unidireccional de las dimensiones hacia ambos hechos. `vw_downtime_detail` añade al evento las llaves de fecha, máquina, turno y referencia sin conectar hechos entre sí. Marcar `dim_date[full_date]` como tabla de fechas. La jerarquía de paro es `dim_stop[stop_label] > dim_stop[subcode_label]`.

El modelo incluye medidas de pacas, horas, disponibilidad proxy, pacas/h, paro detallado, Pareto, comparativo interanual y OEE BLANK (faltan velocidad ideal y piezas buenas/rechazadas). Véase `OEE_DAX.md`.

## Informe

La página inicial contiene segmentadores de año, línea, turno y referencia; tarjetas para pacas, horas operativas, horas de paro y disponibilidad proxy; tendencia de producción por línea; Pareto de paros con jerarquía causa/subcausa; comparación de producción por línea y paros por turno. Los visuales se guardan como archivos JSON PBIR separados para facilitar revisión y control de cambios. Tras cambiar las definiciones, cierre y vuelva a abrir el PBIP en Power BI Desktop para cargar la versión guardada. La disponibilidad es una aproximación con las horas reportadas; el OEE permanece sin calcular hasta contar con tiempo planificado, velocidad ideal y unidades buenas/rechazadas.

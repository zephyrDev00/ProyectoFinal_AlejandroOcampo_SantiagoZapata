# Proyecto Power BI (Formato PBIP + PBIR + TMDL)

`BI_ProyectoFinal.pbip` (disponible tanto en la raíz del repositorio como dentro de `powerbi/`) apunta al reporte PBIR y al modelo semántico TMDL. Se eligió este formato sobre PBIX binario porque expone todas las definiciones de modelo, medidas DAX y objetos visuales en texto plano legible para control de versiones en Git.

## Estructura de Páginas del Reporte

1. **Pág. 1 (`1. Resumen Ejecutivo`)**:
   - Segmentadores por Año, Línea, Turno y Referencia.
   - 6 Tarjetas KPI: Pacas producidas, Variación YoY (%), Horas operativas, Productividad (pacas/h), Horas paro detallado y Disponibilidad proxy.
   - Serie temporal de producción por línea con jerarquía `Año → Mes → Fecha`.
   - Diagrama de Pareto 80/20 combinado (columnas ordenadas descendentemente por `Paro detallado (h)` + curva `% Pareto Acumulado` + línea de referencia `Umbral Pareto 80%`) con *drill-down* hacia subcausa.
   - Comparativo de producción por línea (`Pacas` vs. `Pacas año anterior`) y Horas de paro por turno.

2. **Pág. 2 (`2. Pareto y Subcausas`)**:
   - Segmentadores por Año, Línea, Categoría de paro (P-MTO-22) y Grupo responsable (`Operarios` vs. `Personal_de_mantenimiento`).
   - 4 Tarjetas KPI de paros: Horas de paro detallado, Eventos de paro (16.532 slots), Duración media por evento (h) y Variación interanual de paro (%).
   - Pareto expandido directamente al Nivel 2 de subcódigos (códigos 01, 03 y 05 del P-MTO-22).
   - Distribución de horas de paro por grupo responsable y área de impacto.
   - Tabla de auditoría completa con código, causa, subcódigo, subcausa, eventos, horas, % de participación y % Pareto acumulado.

3. **Pág. 3 (`3. Calidad y Conciliación`)**:
   - Segmentadores por Año, Línea, Grupo de turno y bandera de causa mapeada (`is_mapped`).
   - 6 Tarjetas de control de calidad: Filas aceptadas (8.208), `% Sin turno` (47,7%), `% Sin referencia` (47,2%), Horas no trabajadas (41.519,85 h), Brecha vs. Paro detallado (33.070,20 h) y OEE Certificado (`BLANK`).
   - Gráfico comparativo de los 3 conceptos de tiempo por línea y gráfico de completitud de registros.
   - Tabla de conciliación mensual e inteligencia de tiempo (YoY).

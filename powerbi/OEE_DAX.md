# Capa semántica Power BI (conexión PostgreSQL)

Importar `dw.fact_production`, `dw.vw_downtime_detail` (vista analítica del hecho, con llaves dimensionales conformadas), `dw.dim_date`, `dw.dim_machine`, `dw.dim_shift`, `dw.dim_reference`, `dw.dim_stop`. Relaciones 1:* de cada dimensión a hechos, filtro de una dirección. Marcar dim_date como tabla de fechas con full_date. No relacionar hechos entre sí.

```DAX
Pacas = SUM(fact_production[cases_produced])
Horas operativas registradas = SUM(fact_production[operating_hours])
Horas no trabajadas reportadas = SUM(fact_production[reported_nonworking_hours])
Disponibilidad proxy = DIVIDE([Horas operativas registradas], [Horas operativas registradas] + [Horas no trabajadas reportadas])
Pacas por hora = DIVIDE([Pacas], [Horas operativas registradas])
Paro detalle (h) = SUM(fact_downtime[duration_hours])
Pacas año anterior = CALCULATE([Pacas], SAMEPERIODLASTYEAR(dim_date[full_date]))
Variación interanual % = DIVIDE([Pacas]-[Pacas año anterior],[Pacas año anterior])
OEE = BLANK() -- Bloqueado hasta disponer de velocidad ideal y unidades buenas/rechazadas
```

Crear jerarquía dim_stop[stop_label] > dim_stop[subcode_label], slicers fecha/máquina/turno/referencia y matriz mensual por máquina. Vista Pareto por causa con `Paro detalle (h)` y porcentaje del total. Dimensiones ocultas no se requieren. Formato preferido: PBIP (TMDL + definición de reporte) para diff de texto. Esta carpeta ofrece contrato de modelo y medidas; el autorado visual/conexión debe completarse y guardarse desde Power BI Desktop con credenciales de cada equipo.

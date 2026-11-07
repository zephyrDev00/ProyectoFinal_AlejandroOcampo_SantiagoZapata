# Capa semántica Power BI (conexión PostgreSQL)

El modelo importa `dw.fact_production`, `dw.vw_downtime_detail` (expuesta en el modelo como `fact_downtime` con llaves dimensionales conformadas), `dw.dim_date`, `dw.dim_machine`, `dw.dim_shift`, `dw.dim_reference` y `dw.dim_stop`.
- Relaciones `1:*` de cada dimensión hacia ambos hechos con filtro unidireccional.
- `dim_date` está marcada oficialmente como **Tabla de Fechas** (`dataCategory: Time`, `isKey` en `full_date`) y ` __PBI_TimeIntelligenceEnabled = 0` para eliminar las tablas de fecha ocultas autogeneradas.
- Los hechos no se relacionan entre sí (constelación de hechos).

## Catálogo completo de medidas DAX implementadas

### En `fact_production`:
```dax
Pacas = SUM(fact_production[cases_produced])
Horas operativas registradas = SUM(fact_production[operating_hours])
Horas no trabajadas reportadas = SUM(fact_production[reported_nonworking_hours])
Horas de paro reportadas (hoja) = SUM(fact_production[reported_downtime_hours])
Disponibilidad proxy = DIVIDE([Horas operativas registradas], [Horas operativas registradas] + [Horas no trabajadas reportadas])
Pacas por hora = DIVIDE([Pacas], [Horas operativas registradas])
Pacas año anterior = CALCULATE([Pacas], SAMEPERIODLASTYEAR(dim_date[full_date]))
Variación interanual % = DIVIDE([Pacas] - [Pacas año anterior], [Pacas año anterior])
Pacas mes anterior = CALCULATE([Pacas], PREVIOUSMONTH(dim_date[full_date]))
Variación mensual % = DIVIDE([Pacas] - [Pacas mes anterior], [Pacas mes anterior])
Registros de producción = COUNTROWS(fact_production)
Registros sin turno = CALCULATE(COUNTROWS(fact_production), dim_shift[shift_code] = "SIN TURNO")
% Registros sin turno = DIVIDE([Registros sin turno], [Registros de producción])
Registros sin referencia = CALCULATE(COUNTROWS(fact_production), dim_reference[reference_name] = "SIN REFERENCIA")
% Registros sin referencia = DIVIDE([Registros sin referencia], [Registros de producción])
Brecha horas no trabajadas vs paro (h) = [Horas no trabajadas reportadas] - [Paro detallado (h)]
OEE = BLANK() -- Bloqueado hasta disponer de velocidad ideal y unidades buenas/rechazadas
```

### En `fact_downtime`:
```dax
Paro detallado (h) = SUM(fact_downtime[duration_hours])
% paro Pareto = DIVIDE([Paro detallado (h)], CALCULATE([Paro detallado (h)], ALL(dim_stop)))
% Participación de paro = DIVIDE([Paro detallado (h)], CALCULATE([Paro detallado (h)], ALLSELECTED(dim_stop)))

% Pareto Acumulado = 
VAR TotalParoGlobal = CALCULATE([Paro detallado (h)], ALLSELECTED(dim_stop))
VAR ParoActual = [Paro detallado (h)]
VAR TablaResumen = 
    ADDCOLUMNS(
        ALLSELECTED(dim_stop[stop_label]),
        "@Horas", [Paro detallado (h)]
    )
VAR Acumulado = 
    SUMX(
        FILTER(TablaResumen, [@Horas] >= ParoActual),
        [@Horas]
    )
RETURN
    DIVIDE(Acumulado, TotalParoGlobal, BLANK())

% Pareto Acumulado Subcausa = 
VAR TotalParoGlobal = CALCULATE([Paro detallado (h)], ALLSELECTED(dim_stop))
VAR ParoActual = [Paro detallado (h)]
VAR TablaResumen = 
    ADDCOLUMNS(
        ALLSELECTED(dim_stop[stop_label], dim_stop[subcode_label]),
        "@Horas", [Paro detallado (h)]
    )
VAR Acumulado = 
    SUMX(
        FILTER(TablaResumen, [@Horas] >= ParoActual),
        [@Horas]
    )
RETURN
    DIVIDE(Acumulado, TotalParoGlobal, BLANK())

Umbral Pareto 80% = 0.80
Eventos de paro = COUNTROWS(fact_downtime)
Duración media por paro (h) = AVERAGE(fact_downtime[duration_hours])
Paro año anterior (h) = CALCULATE([Paro detallado (h)], SAMEPERIODLASTYEAR(dim_date[full_date]))
Variación paro YoY % = DIVIDE([Paro detallado (h)] - [Paro año anterior (h)], [Paro año anterior (h)])
```

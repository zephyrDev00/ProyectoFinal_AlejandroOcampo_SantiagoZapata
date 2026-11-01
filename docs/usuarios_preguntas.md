# Usuarios y decisiones

| Usuario | Frecuencia | Preguntas que responde | Consumo |
|---|---|---|---|
| Gerencia/Comité | Mensual/trimestral | ¿Cómo cambió la producción por año, máquina, referencia y mes? ¿Qué causas justifican inversión? | Power BI |
| Coordinación de mantenimiento | Diario y mensual | ¿Qué causas concentran tiempo de paro? ¿Qué máquina y subcausa priorizar? ¿Cambió frente al periodo previo? | Grafana y Power BI |
| Supervisores de línea | Hora a hora | ¿Qué líneas están detenidas? ¿Cuánto paro lleva la hora? ¿Se superó el umbral? | Grafana |
| Analista BI / DBeaver | Carga y auditoría | ¿Qué filas se aceptaron? ¿Cuáles controles y conciliaciones fallaron? | PostgreSQL / DBeaver |

# Modelo dimensional y bus

Esquema estrella en PostgreSQL: `fact_production` a grano de una fila fuente de producción; `fact_downtime` a grano de una casilla con duración de paro de esa fila; `fact_live_hour` a grano de máquina-hora para señal de monitoreo. Dimensiones conformadas: `dim_date`, `dim_machine`, `dim_shift`, `dim_reference`, `dim_stop`. Fecha se deriva de Fecha, jerarquía Año > Trimestre > Mes > Día. `dim_stop` separa categoría padre, subcódigo y etiqueta. La relación de paro se conserva como dimensión desnormalizada/jerárquica para simplificar el drill-down en ambas herramientas; valores no mapeables se muestran explícitamente.

| Proceso | Fecha | Máquina | Turno | Referencia | Causa de paro |
|---|---|---|---|---|---|
| Producción | X | X | X | X |  |
| Paros | X | X | X | X | X |
| Estado horario | X (hora) | X | X |  |  |

Dimensión propia: Fecha, derivada y no procedente de un calendario fuente confiable. `dim_machine` y `dim_shift` podrían requerir SCD2 si cambian atributos/horarios; como no hay historial confiable de vigencias, el prototipo usa overwrite simple (SCD1) y documenta que cambios estructurales requieren fecha efectiva para evolución a SCD2.

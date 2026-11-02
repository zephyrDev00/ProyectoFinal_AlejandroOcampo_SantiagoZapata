# Diagnóstico y reglas de calidad

Fuente: `Base De Datos` del libro de seguimiento, con encabezado en la fila 9. Hay 8.208 registros con contenido, fecha mínima 2022-01-01 y máxima 2025-03-28. La hoja contiene 58 columnas: fecha, atributos de producción y turno, campos de descanso/paro, hasta 18 casillas asociadas a tiempos y observaciones. Se detectan 4 máquinas. El procedimiento P-MTO-22 (vigencia 14/05/2025) describe registro manual hora a hora, transcripción posterior y consolidación mensual; indica 17 categorías oficiales, mientras el libro conserva códigos heredados (hasta 19 y categorías en texto) y otros grupos.

## Conteos de perfil

| Control | Antes | Después / efecto | Regla |
|---|---:|---:|---|
| Filas con datos en la tabla fuente | 8.208 | 8.208 filas aceptadas; 0 rechazadas en esta revisión | Retener filas con fecha válida y máquina reconocida |
| Filas completamente vacías dentro del rango | 0 como filas contiguas; el rango llega hasta fila 8.217 | 0 hechos vacíos | Ignorar filas vacías si aparecen |
| Fecha no interpretable | 0 | 0 | Rechazar y auditar si ocurre en futuras cargas |
| Máquina fuera del catálogo de cuatro líneas | 0 | 0 | Rechazar y auditar |
| Turno nulo | 3.912 (47,7%) | 3.912 con miembro explícito `SIN TURNO` | No imputar turno |
| Referencia nula | 3.874 (47,2%) | 3.874 con `SIN REFERENCIA` | No imputar referencia |
| Pacas sin valor numérico | 3.051 (37,2%) | Se conservan como NULL | Cero y desconocido son distintos |
| Horas trabajadas sin valor numérico | 3.049 (37,1%) | Se conservan como NULL | Cero y desconocido son distintos |
| Valores negativos en medidas revisadas | 0 | 0 | Futuros negativos se rechazan y quedan contados en la auditoría |
| Filas idénticas en contenido completo | 42 filas excedentes frente a valores únicos | No se eliminan; hay ausencia de ID de evento | Conservar origen por fila Excel, revisar antes de deduplicar |

Las hojas auxiliares contienen catálogos y tablas dinámicas de distintas generaciones; las etiquetas de códigos no tienen un catálogo único plenamente relacionado con cada fila de producción. El ETL conserva causa/subcódigo disponible; si la fuente no permite derivar la causa, la clasifica como no mapeada. No convierte valores ambiguos de las casillas en categorías inventadas. Las columnas de nombres de operario y personal de mantenimiento se excluyen por privacidad.

## Conciliación de cantidades

| Medida | Total fuente | Tratamiento |
|---|---:|---|
| Pacas reportadas | 378.778 | Suma de valores numéricos presentes; 3.051 registros sin dato no se cuentan como cero |
| Horas trabajadas | 38.063,35 h | Suma de datos numéricos; 3.049 ausentes |
| Horas no trabajadas | 41.519,85 h | Total del campo M; mantener separado |
| Tiempo de Paro (BE) | 8.449,6517 h | Total de 8.208 filas |
| Detalle de slots de paro | 8.449,6517 h | Suma de R,T,W,Y,AB,AF,...,BD; diferencia agregada <0,000001 h; 0 registros con diferencia >0,02 h |

Aunque el total detallado reconcilia con Tiempo de Paro, no concuerda con Horas no trabajadas (diferencia 33.070,20 h). No se corrige por inferencia: hace falta que Producción/Mantenimiento aclare si el campo incluye tiempo calendario, descansos, disponibilidad extendida o fórmulas distintas. El proceso preserva ambas medidas y ofrece trazabilidad por fila Excel. Las cifras en este diagnóstico se calcularon sobre el archivo entregado; pueden variar si la fuente se actualiza.

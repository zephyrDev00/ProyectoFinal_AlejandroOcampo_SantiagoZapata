# BI de producción y paros — Vinilos y témperas

Solución de Inteligencia de Negocios de extremo a extremo (*end-to-end*) contenerizada para integrar el registro histórico en Excel (`SEGUIMIENTO TEMPERAS Y VINILOS Actividad.xlsm`) y las reglas de negocio del procedimiento `P-MTO-22` de cuatro líneas de envasado (`Vinilos_1` a `Vinilos_4`) en un repositorio analítico dimensional sobre PostgreSQL, habilitando una capa operativa en Grafana y una capa analítica en Power BI.

* **Autores:** Alejandro Ocampo y Santiago Zapata (Institución Universitaria Pascual Bravo, Medellín, 2026).
* **Repositorio GitHub:** [ProyectoFinal_AlejandroOcampo_SantiagoZapata](https://github.com/zephyrDev00/ProyectoFinal_AlejandroOcampo_SantiagoZapata)
* **Privacidad por diseño:** Se omiten del modelo dimensional y de los tableros los nombres propios de operarias y personal de mantenimiento en cumplimiento de la Ley 1581 de 2012.

---

## 1. Arquitectura y Estructura del Proyecto

El flujo de datos sigue la arquitectura:

`Excel XLSM privado + Procedimiento P-MTO-22 -> Contenedor ETL Python (openpyxl + psycopg) + auditoría -> PostgreSQL dimensional (esquema dw + dw.etl_audit) -> Grafana operativo (simulación horaria + alertas) / Power BI analítico (PBIP + TMDL + PBIR)`

DBeaver se utiliza para la administración del esquema y la ejecución de consultas analíticas SQL. El diagrama fuente en formato Mermaid se encuentra en `docs/arquitectura.mmd`.

### Estructura del repositorio

```text
├── .env.example                  # Plantilla de variables de entorno (sin credenciales reales)
├── .gitignore                    # Exclusión de .env, libros Excel/CSV, cachés de Power BI y logs
├── BI_ProyectoFinal.pbip         # Lanzador del proyecto Power BI en la raíz
├── docker-compose.yml            # Orquestación de PostgreSQL, ETL/Simulador y Grafana
├── docs/
│   ├── BI_ProyectoFinal_AlejandroOcampo_SantiagoZapata_FINAL.pdf  # Informe técnico final del proyecto
│   ├── indicadores.csv           # Catálogo estructurado de KPIs y métricas del modelo
│   └── preguntas_sql.sql         # Consultas analíticas SQL (agregaciones, LAG, RANK, Pareto)
├── etl/
│   ├── Dockerfile                # Imagen Python 3.12 para ejecución reproducible del ETL
│   ├── requirements.txt          # Dependencias (openpyxl==3.1.5, psycopg[binary]==3.2.3)
│   ├── load.py                   # Extracción, limpieza, despivoteo, conciliación y carga a PostgreSQL
│   └── simulate.py               # Simulador horario para monitoreo continuo y disparo de alertas
├── grafana/
│   ├── README.md                 # Documentación de aprovisionamiento y alertas en Grafana
│   ├── dashboards/operacion.json # Tablero operativo exportado y versionado
│   └── provisioning/             # Configuración automática de datasource, dashboards y reglas
├── powerbi/
│   ├── BI_ProyectoFinal.pbip     # Proyecto Power BI en formato controlable por versiones
│   ├── BI_ProyectoFinal.Report/  # Definición PBIR de las 3 páginas y objetos visuales
│   ├── BI_ProyectoFinal.SemanticModel/ # Modelo semántico en formato TMDL (tablas, relaciones, DAX)
│   ├── ConectarPostgreSQL.pq     # Script Power Query (M) de conexión a localhost:5433
│   ├── OEE_DAX.md                # Catálogo documentado de las 27 medidas DAX
│   └── README_POWERBI.md         # Guía de uso y actualización del modelo en Power BI Desktop
└── sql/
    ├── 00_native_setup.sql       # Preparación opcional para entornos locales
    ├── 01_schema.sql             # DDL del modelo en estrella, restricciones, PK/FK e índices
    └── 02_analytics.sql          # Vistas analíticas (vw_downtime_detail, vw_monthly_machine) y consultas
```

---

## 2. Estado Implementado por Capa

* **Motor relacional y modelo dimensional (PostgreSQL 16):** Desplegado en contenedor sobre `localhost:5433` (manteniendo intacta cualquier instalación nativa de PostgreSQL en el equipo host). Implementa un esquema en estrella/constelación (`dw`) con 5 dimensiones (`dim_date`, `dim_machine`, `dim_shift`, `dim_reference`, `dim_stop`), 3 tablas de hechos (`fact_production`, `fact_downtime`, `fact_live_hour`) y la tabla de auditoría `dw.etl_audit`.
* **ETL reproducible en Python 3.12:** Lee la hoja `Base De Datos` desde la fila 9, aplica validaciones de dominio y no negatividad, despivotea los 17 pares de columnas horizontales de paro y carga 8.208 filas en `dw.fact_production` y 16.532 eventos en `dw.fact_downtime`. Utiliza bloqueo asesor (`pg_advisory_lock`) para impedir cargas concurrentes y registra el resumen de calidad en JSONB dentro de `dw.etl_audit`.
* **Monitoreo casi en tiempo real en Grafana 11.4 (`http://localhost:3001`):** Incluye variable de tablero para filtrar por máquina, tarjeta de paro móvil de los últimos 60 minutos, serie temporal de minutos de marcha vs. paro y tabla de estado actual por línea con refresco automático cada minuto.
* **Simulación horaria y regla de alerta ($> 20\%$):** El script `simulate.py` genera 24 horas de operación por línea en `dw.fact_live_hour`; al ejecutarse con `--trigger`, fija 18 minutos de paro sobre 60 planificados ($30\%$) en `Vinilos_1`, superando el umbral del $20\%$ ($> 12\text{ min/h}$). Este umbral se fundamenta en el informe histórico del procedimiento `P-MTO-22`, donde la productividad promedio es del $76,3\%$ (pérdida histórica acumulada del $23,7\%$).
* **Modelo semántico y reporte analítico en Power BI (`PBIP` / `TMDL`):** Conectado exclusivamente a PostgreSQL (`localhost:5433`, base `vinilos_bi`, esquema `dw`), importando `fact_production`, `vw_downtime_detail` (expuesta como `fact_downtime`) y las 5 dimensiones con relaciones `1:*` unidireccionales. La tabla `dim_date` está marcada oficialmente como tabla de fechas (`dataCategory: Time`, `isKey` en `full_date`), eliminando las tablas de fecha ocultas autogeneradas y ordenando cronológicamente meses y días.
* **Navegación en 3 páginas y 27 medidas DAX en Power BI:**
  1. **Pág. 1 (`1. Resumen Ejecutivo`):** Segmentadores por año, línea, turno y referencia; 6 tarjetas KPI (`Pacas producidas`, `Variación YoY %`, `Horas operativas`, `Productividad pacas/h`, `Horas paro detallado` y `Disponibilidad proxy`); tendencia con jerarquía `Año -> Mes -> Fecha`; gráfico combinado de Pareto 80/20 ordenado descendentemente con línea acumulada y *drill-down* `causa -> subcausa`; comparativo interanual por línea y paros por turno.
  2. **Pág. 2 (`2. Pareto y Subcausas`):** Profundización directa en el Nivel 2 de subcódigos (códigos `01`, `03` y `05` del `P-MTO-22`), distribución por grupo responsable (`Operarios` vs. `Personal_de_mantenimiento`), área de impacto y tabla de auditoría completa.
  3. **Pág. 3 (`3. Calidad y Conciliación`):** Monitoreo de filas aceptadas (8.208), `% Sin turno` ($47,7\%$), `% Sin referencia` ($47,2\%$), conciliación entre los tres conceptos de tiempo (`Horas operativas`, `Horas no trabajadas` y `Paro detallado`), brecha de $33.070,20\text{ h}$ y estado del `OEE Certificado (BLANK)`.

---

## 3. Guía de Reproducción desde Cero

1. **Fuente de datos:** Copie el archivo original a `data/SEGUIMIENTO TEMPERAS Y VINILOS Actividad.xlsm`. La carpeta `data/` está excluida de Git.
2. **Variables de entorno:** Copie `.env.example` a `.env` y defina claves locales propias para PostgreSQL y Grafana. Nunca suba `.env` al repositorio.
3. **Base de datos y esquema:** Con Docker Desktop activo, levante el contenedor ejecutando:
   ```bash
   docker compose --profile container-db up -d db
   ```
   El puerto se publica únicamente en loopback (`127.0.0.1:5433`).
4. **Ejecución del ETL:** Ejecute el contenedor de extracción, limpieza y carga:
   ```bash
   docker compose --profile etl run --rm etl
   ```
   La carga es transaccional e idempotente por `source_row_id`; el resultado detallado queda registrado en `dw.etl_audit`.
5. **Capa analítica SQL (DBeaver):** Conéctese a `localhost:5433` (base de datos `vinilos_bi`) y ejecute `sql/02_analytics.sql` (o `docs/preguntas_sql.sql`) para crear las vistas analíticas y revisar las consultas con funciones de ventana (`LAG`, `RANK`, `SUM OVER`).
6. **Tablero operativo Grafana:** Inicie el servicio ejecutando:
   ```bash
   docker compose up -d grafana
   ```
   Acceda a `http://localhost:3001` con el usuario `admin` y la contraseña definida en `.env`.
7. **Simulación horaria y disparo de alerta:**
   * Para simular 24 horas en operación normal:
     ```bash
     docker compose --profile etl run --rm etl python simulate.py
     ```
   * Para simular un evento crítico en `Vinilos_1` ($30\%$ de paro en la última hora) y disparar la alerta ($> 20\%$):
     ```bash
     docker compose --profile etl run --rm etl python simulate.py --trigger
     ```
8. **Tablero analítico Power BI:** Abra `BI_ProyectoFinal.pbip` (en la raíz o en `powerbi/BI_ProyectoFinal.pbip`) con Power BI Desktop, configure sus credenciales locales para PostgreSQL (`localhost:5433`) y haga clic en **Actualizar** para cargar las 3 páginas del reporte.

---

## 4. Diagnóstico de Calidad de Datos, Conciliación y Modelado

### Hallazgos en la fuente histórica (`2022-01-01` a `2025-03-28`)

* **Diagnóstico estructural del libro XLSM:** El archivo original consta de 21 hojas, 8 tablas dinámicas, macros VBA (`vbaProject.bin`) y un modelo PowerPivot interno con dos tablas separadas (`Base_datos_1` y `Base_datos_subcodigos`), donde los paros del 1 al 17 estaban almacenados como grupos repetitivos horizontales y las medidas MDX porcentuales usaban erróneamente `COUNTA` en lugar de `SUM`.
* **Desfase documental en el procedimiento `P-MTO-22`:** La lista de la sección 4 enumera 17 códigos (`[01]` a `[17]`), pero el formulario de captura y los gráficos gerenciales incluyen `[18] Desinfección` y `[19] No aplica`, además de omitir en la hoja digital `Base De Datos` el campo `NO CONFORME` presente en el formato físico `F-PRO-33`.
* **Tratamiento de valores faltantes y duplicados:** De las 8.208 filas válidas, 3.912 registros sin turno ($47,7\%$) y 3.874 sin referencia ($47,2\%$) se asignan a los miembros explícitos `SIN TURNO` y `SIN REFERENCIA` sin imputar valores artificiales. Los faltantes numéricos en pacas (3.051 filas, $37,2\%$) y horas operativas (3.049 filas, $37,1\%$) se conservan como `NULL` (desconocido no equivale a cero), y las 42 filas con contenido repetido se preservan al no existir un identificador único de evento en el origen.
* **Estrategia de Slowly Changing Dimensions (SCD):** Se documenta y propone **SCD Tipo 2** sobre `dim_shift` (con `valid_from`, `valid_to`, `is_current`) para preservar cambios históricos en la configuración horaria de los turnos, y un enfoque **SCD Híbrido (Tipo 1 + Tipo 2)** en `dim_stop` ante reasignaciones de área o grupo responsable.

### Tabla de conciliación certificada (Excel vs. PostgreSQL)

| Métrica / Concepto | Total Fuente (`Actividad.xlsm`) | Total Cargado (`PostgreSQL dw`) | Diferencia | Observación de auditoría |
| :--- | :--- | :--- | :--- | :--- |
| **Filas de producción** | 8.208 registros | 8.208 filas (`fact_production`) | 0 | $100\%$ aceptadas desde la fila 9 de `Base De Datos`. |
| **Pacas producidas** | 378.778 pacas | 378.778 pacas (`cases_produced`) | 0 | Conciliación exacta; nulos conservados como `NULL`. |
| **Horas operativas** | $38.063,35\text{ h}$ | $38.063,35\text{ h}$ (`operating_hours`) | $0,00\text{ h}$ | Conciliación exacta con `Horas trabajadas`. |
| **Horas no trabajadas** | $41.519,85\text{ h}$ | $41.519,85\text{ h}$ (`reported_nonworking_hours`) | $0,00\text{ h}$ | Incluye turnos sin programación (`[19] No aplica`); no equivale al paro detallado. |
| **Paro detallado** | $8.449,6517\text{ h}$ | $8.449,6517\text{ h}$ (`fact_downtime`, 16.532 slots) | $0,0000\text{ h}$ | Concilia con `Tiempo de Paro` reportado (0 diferencias $> 0,02\text{ h}$). |
| **OEE Certificado** | No disponible | `NULL` / `BLANK()` | N/A | Las columnas de velocidad (`Unidades/min`) tienen vacíos y `NO CONFORME` no fue digitalizado. |

---

## 5. Gobierno de Datos (Ley 1581 de 2012), Seguridad y Evolución

* **Protección de datos personales (Ley Estatutaria 1581 de 2012):** El formato físico `F-PRO-33` y las hojas del Excel contienen nombres propios en las columnas `Operario` y `Personal involucrado`. Aplicando el principio de minimización y privacidad por diseño (*Privacy by Design*), el ETL excluye dichas columnas nominales y conserva en `dim_stop` únicamente la atribución por rol institucional (`Operarios` vs. `Personal_de_mantenimiento`).
* **Seguridad de acceso y control de versiones:** PostgreSQL se publica únicamente en loopback (`127.0.0.1:5433`), recomendando roles separados de escritura para el ETL y de solo lectura para Grafana y Power BI. El archivo `.gitignore` excluye `.env`, fuentes `.xlsm`/`.csv`, cachés binarios de Power BI y registros locales.
* **Evolución hacia PLC / SCADA:** La arquitectura permite sustituir el simulador horario por ingesta de eventos industriales vía **OPC UA** o **MQTT** con una capa de streaming y buffer, capturando estampas de tiempo con zona horaria, estado de línea, ciclo ideal y conteos de unidades buenas/rechazadas para habilitar el cálculo certificado del OEE.

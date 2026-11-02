# BI de producción y paros - Vinilos y témperas

Solución académica para integrar el histórico Excel en PostgreSQL y consumirlo desde Grafana y Power BI. Autores: Alejandro Ocampo y Santiago Zapata. Se omiten del modelo nombres de operarias y personal de mantenimiento.

Repositorio GitHub: [ProyectoFinal_AlejandroOcampo_SantiagoZapata](https://github.com/zephyrDev00/ProyectoFinal_AlejandroOcampo_SantiagoZapata).

## Arquitectura

`XLSM privado -> ETL Python + auditoría -> PostgreSQL dimensional -> Grafana operativo / Power BI analítico`. DBeaver administra y consulta la base. El diagrama está en `docs/arquitectura.mmd`.

## Estado implementado

- PostgreSQL 16 aislado en Docker en `localhost:5433` (la instalación PostgreSQL 18 nativa del equipo queda sin modificar).
- ETL desde el archivo XLSM a 5 dimensiones y 3 hechos: 8.208 filas de producción y 16.532 eventos de paro; calidad y conciliación en `dw.etl_audit`.
- Grafana 11.4 en `http://localhost:3001`, con filtro por máquina, serie horaria, estado por línea y regla de alerta provisional (>20% en 60 min).
- Simulador con 24 h por línea; `--trigger` fija 18 min de paro en Vinilos_1 y demuestra el umbral. La captura del tablero está en `docs/screenshots/grafana_operacion.png`. La simulación es manual y no representa señales reales de PLC/SCADA.
- Proyecto Power BI PBIP/TMDL con consulta a PostgreSQL, medidas semánticas, relaciones dimensionales y visuales PBIR para filtros, KPI, series y Pareto. Configure sus credenciales locales y actualice en Desktop para confirmar la carga. No hay contraseñas en el PBIP.
- Informe académico en `docs/BI_ProyectoFinal_Ocampo_Zapata.pdf`, con enlace al repositorio.

## Reproducción desde cero

1. Copie el libro original a `data/SEGUIMIENTO TEMPERAS Y VINILOS Actividad.xlsm`. La carpeta `data/` está excluida de Git.
2. Copie `.env.example` a `.env`, defina claves propias de PostgreSQL y Grafana, y no suba `.env`.
3. Con Docker Desktop activo, cree la base y el esquema: `docker compose --profile container-db up -d db`. El puerto se publica sólo en loopback.
4. Ejecute el ETL: `docker compose --profile etl run --rm etl`. La carga es idempotente por `source_row_id`; la ejecución queda en `dw.etl_audit`.
5. En DBeaver abra la conexión `localhost:5433`, ejecute `sql/02_analytics.sql` para crear vistas analíticas y revisar el Pareto.
6. Inicie el tablero: `docker compose up -d grafana`. Acceda a `http://localhost:3001` con el usuario `admin` y la contraseña local de `.env`. Grafana usa el host y puerto configurados en `POSTGRES_HOST` y `POSTGRES_PORT`; por defecto apunta al PostgreSQL del contenedor publicado en `localhost:5433`.
7. Para captura PNG, active el perfil de captura y aplique su configuración al reiniciar Grafana: `docker compose -f docker-compose.yml -f docker-compose.capture.yml --profile capture up -d renderer grafana`. Use la API `/render/d/vinilos-operacion/operacion-lineas-vinilos` autenticado. El servicio usa credenciales Grafana y no permite acceso anónimo.
8. Simule 24 horas con `docker compose --profile etl run --rm etl python simulate.py`; para exceder umbral use `... simulate.py --trigger`. El tablero se refresca cada minuto. La regla de alerta requiere un minuto sobre 20%; los umbrales son demostrativos y deben aprobarse en planta.
9. Abra `powerbi/BI_ProyectoFinal.pbip` en Power BI Desktop. Seleccione autenticación PostgreSQL para `localhost:5433` y actualice las tablas. La página con visuales ya está diseñada; verifique que las consultas carguen datos.

## Datos y calidad

La fuente cubre 2022-01-01 a 2025-03-28. `dw.fact_production` tiene una fila por registro no vacío del origen; `dw.fact_downtime`, una fila por slot de duración positiva. Cada ejecución reemplaza el histórico por la instantánea actual del libro, dentro de una transacción, para que correcciones o cambios de posición en filas no dejen datos obsoletos. `dim_date` deriva su jerarquía desde la fecha real. Hay faltantes de turno/referencia y producción; 42 duplicados de contenido se conservan por falta de un identificador de evento fiable. Horas de paro detallado concilian con el campo reportado dentro de tolerancia. `Horas no trabajadas` es otro campo y no se equipara al paro. No existen velocidad ideal ni unidades buenas/rechazadas, por lo que el OEE devuelve BLANK/no disponible; disponibilidad es sólo un proxy. Ver `docs/diagnostico.md` y `docs/indicadores.csv`.

## Seguridad y versionado

El modelo evita PII. Use roles de lectura separados para tableros, claves locales fuertes y acceso restringido a Grafana. No publicar puertos en redes públicas. El `.gitignore` excluye `.env`, fuentes XLSM/CSV, cachés PBI y registros locales.

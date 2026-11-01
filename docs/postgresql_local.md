# PostgreSQL nativo detectado

Se detectó PostgreSQL 18 en `C:\Program Files\PostgreSQL\18`, con servicio `postgresql-x64-18` y directorio de datos existente. Tras el reinicio, una consulta elevada informó el servicio `Running` y `pg_isready` aceptó conexiones; la sesión de trabajo no puede consultar directamente el puerto por sus restricciones locales. Una prueba con el usuario `bi_user` falló autenticación porque la contraseña aleatoria de `.env` no es la contraseña de la instancia local. La base todavía no está lista para la carga de este proyecto hasta sincronizar esa credencial y crear/verificar `vinilos_bi` y el esquema.

1. Si PostgreSQL no está activo, inicie `postgresql-x64-18` desde `services.msc` como administrador.
2. Confirme con `C:\Program Files\PostgreSQL\18\bin\pg_isready.exe -h 127.0.0.1 -p 5432`.
3. En DBeaver, conecte con su usuario administrador local; verifique si existen `bi_user` y `vinilos_bi`. Si faltan, ejecute separadamente las sentencias de `sql/00_native_setup.sql` con autocommit. Asigne una contraseña fuerte a `bi_user` desde el editor de roles de pgAdmin/DBeaver.
4. Ejecute `sql/01_schema.sql` conectado como `bi_user` a `vinilos_bi`.
5. Ajuste `.env` con la contraseña de `bi_user` y `docker compose up -d grafana`. Para ETL: `docker compose --profile etl run --rm etl`.

El servicio PostgreSQL está instalado localmente; no se requiere levantar el servicio `db` de Compose. La alternativa `--profile container-db` ofrece un PostgreSQL aislado en el puerto 5433 para otra máquina/entorno. `docker-compose.yml` conecta Grafana y el contenedor ETL al PostgreSQL local por `host.docker.internal`.

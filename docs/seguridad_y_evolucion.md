# Seguridad, privacidad y evolución

## Datos personales y acceso

La fuente incluye nombres de operarias y personas de mantenimiento. El modelo no carga nombres, observaciones libres ni datos identificables; el resumen es por línea, fecha, turno, referencia y causa. No usar PII en Grafana/Power BI ni en capturas. Restringir la fuente en disco y carpeta de trabajo; el libro está excluido del repositorio. Para la operación: credenciales distintas por servicio; usuario ETL con escritura, Grafana y Power BI con solo lectura; contraseñas en secretos de Docker/administrador, rotación y TLS al salir de red local; SSO/RBAC en Grafana y workspace Power BI, RLS solo si se aprueba segmentación por planta/rol. No publicar credenciales ni puertos a Internet. Retención y legitimación de datos deben alinearse con política interna y normativa aplicable.

## Alertas y calidad

La alerta de demostración se activa si el paro supera 20% del tiempo planificado en los últimos 60 minutos (más de 12 minutos en una hora planificada). Es umbral de prueba transparente, no meta aprobada. Notificaciones externas requieren que el administrador configure un contact point corporativo. El simulador inserta datos marcados `simulation` y nunca los mezcla con el histórico.

## Evolución a PLC/SCADA

Ingerir eventos con timestamp, máquina, estado, contador de producción y código desde OPC UA/MQTT/broker; conservar evento crudo, zona horaria, secuencia del dispositivo y calidad/calibración. Una capa de streaming con buffer/reintentos reemplazaría el simulador; validación y dimensiones conformadas alimentarían un fact de eventos y agregados por minuto/hora. Definir reglas de parada, microparos, producto bueno/rechazado y ciclo ideal conjuntamente con Ingeniería. Mantener Grafana para supervisión en minutos y Power BI para agregados certificados, con retención/particionado, monitoreo de retraso y reconciliación SCADA vs ERP.

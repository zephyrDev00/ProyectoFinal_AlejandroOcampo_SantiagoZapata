-- Preparar PostgreSQL nativo (ejecutar conectado a la base postgres con autocommit)
CREATE ROLE bi_user LOGIN;
CREATE DATABASE vinilos_bi OWNER bi_user;

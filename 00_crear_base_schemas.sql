/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - Script 00: Creacion de la base de datos y esquemas
 Grupo 02 - Comision 02-5600
 Integrantes: [Nombre - nickGitHub], [Nombre - nick], [Nombre - nick], [Nombre - nick]
 Fecha: [completar]
 Objetivo: crear la base MundialDB (filegroups, opciones, collation) y
           los schemas de organizacion. DEBE EJECUTARSE PRIMERO (orden 00).
=====================================================================
*/

USE master;
GO

/* --- 1. Recreacion desde cero ---------------------------------------
   El coloquio exige poder borrar la base y recrearla completa.
   SINGLE_USER + ROLLBACK IMMEDIATE corta las conexiones abiertas. */
IF DB_ID(N'MundialDB') IS NOT NULL
BEGIN
    ALTER DATABASE MundialDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE MundialDB;
END
GO

/* --- 2. Creacion de la base con filegroups --------------------------
   AJUSTAR la ruta a una carpeta que exista en el equipo (crearla antes).
   En PRODUCCION los archivos van en volumenes separados segun el
   documento de Instalacion (Entrega 4): datos en G:, log en H:, etc.
   Aca van juntos solo para que el script sea portable en el coloquio.
   - PRIMARY queda chico (solo metadatos del sistema).
   - FG_DATOS es DEFAULT: las tablas se crean ahi, no en PRIMARY.
   - Autogrowth en MB fijos (no %), como se justifico en la Entrega 4. */
CREATE DATABASE MundialDB
 ON PRIMARY
   ( NAME = N'MundialDB_sys',
     FILENAME = N'C:\MundialDB\MundialDB_sys.mdf',
     SIZE = 64MB,  FILEGROWTH = 64MB ),
 FILEGROUP FG_DATOS DEFAULT
   ( NAME = N'MundialDB_dat',
     FILENAME = N'C:\MundialDB\MundialDB_dat.ndf',
     SIZE = 256MB, FILEGROWTH = 128MB )
 LOG ON
   ( NAME = N'MundialDB_log',
     FILENAME = N'C:\MundialDB\MundialDB_log.ldf',
     SIZE = 128MB, FILEGROWTH = 64MB )
 COLLATE Modern_Spanish_CI_AS;   -- espanol, CI/AS (Entrega 4)
GO

/* --- 3. Opciones de la base ----------------------------------------- */
-- SIMPLE para desarrollo/coloquio (no hay que gestionar backups de log).
-- En produccion seria FULL por el Availability Group (ver Entrega 4).
ALTER DATABASE MundialDB SET RECOVERY SIMPLE;
ALTER DATABASE MundialDB SET AUTO_CREATE_STATISTICS ON;
ALTER DATABASE MundialDB SET AUTO_UPDATE_STATISTICS ON;
GO

/* --- 4. Schemas de organizacion (por DOMINIO, no por integrante) -----
   CREATE SCHEMA debe ser la 1ra sentencia del batch; por eso, para
   poder validar existencia antes de crear, se usa EXEC(...) (unica
   excepcion justificada de SQL dinamico en este script).
   ACORDAR esta lista con el grupo y reflejarla en la norma de nombres. */
USE MundialDB;
GO
IF SCHEMA_ID(N'cat')  IS NULL EXEC(N'CREATE SCHEMA cat');   -- catalogos geo/economicos (Moneda, Idioma, Pais, Ciudad, IndicadorEconomico, TipoCambio, Feriado)
IF SCHEMA_ID(N'comp') IS NULL EXEC(N'CREATE SCHEMA comp');  -- competicion: Torneo, Fase, Grupo, Sede, Partido, Seleccion, Convocado, Alineacion...
IF SCHEMA_ID(N'disc') IS NULL EXEC(N'CREATE SCHEMA disc');  -- disciplina y arbitraje: Gol, Tarjeta, Suspension, Arbitro, Designacion...
IF SCHEMA_ID(N'pub')  IS NULL EXEC(N'CREATE SCHEMA pub');   -- publicidad
IF SCHEMA_ID(N'imp')  IS NULL EXEC(N'CREATE SCHEMA imp');   -- importacion (LogImportacion, ErrorImportacion)
GO

PRINT 'OK: base MundialDB, filegroups y schemas creados.';
GO
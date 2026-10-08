/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - Script 00: Creacion de la base de datos y schemas
 Grupo 02 - Comision 02-5600
 Integrantes: Miro, Saba.
 Fecha: 2026-10-08
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
   documento de Instalacion (Entrega 4). Aca van juntos para que el
   script sea portable en el coloquio. */
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
 COLLATE Modern_Spanish_CI_AS;
GO

/* --- 3. Opciones de la base ----------------------------------------- */
ALTER DATABASE MundialDB SET RECOVERY SIMPLE;
ALTER DATABASE MundialDB SET AUTO_CREATE_STATISTICS ON;
ALTER DATABASE MundialDB SET AUTO_UPDATE_STATISTICS ON;
GO

/* --- 4. Schemas de organizacion (por DOMINIO) -----------------------
   CREATE SCHEMA debe ser la 1ra sentencia del batch; por eso se usa
   EXEC(...) para poder validar existencia (unica excepcion de SQL
   dinamico, justificada). */
USE MundialDB;
GO
IF SCHEMA_ID(N'cat')  IS NULL EXEC(N'CREATE SCHEMA cat');   -- catalogos geo/economicos
IF SCHEMA_ID(N'comp') IS NULL EXEC(N'CREATE SCHEMA comp');  -- torneo, sedes, partidos, selecciones, convocatoria, alineaciones
IF SCHEMA_ID(N'disc') IS NULL EXEC(N'CREATE SCHEMA disc');  -- goles, tarjetas, suspensiones, arbitros
IF SCHEMA_ID(N'pub')  IS NULL EXEC(N'CREATE SCHEMA pub');   -- publicidad
IF SCHEMA_ID(N'imp')  IS NULL EXEC(N'CREATE SCHEMA imp');   -- importacion
GO

PRINT 'OK: base MundialDB, filegroups y schemas (cat/comp/disc/pub/imp) creados.';
GO
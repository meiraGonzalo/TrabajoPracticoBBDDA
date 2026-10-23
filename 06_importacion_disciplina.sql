/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 6 - Script 06: Importacion de Disciplina (arbitros)
 Grupo 02 - Comision 02-5600
 Integrantes: Miro, Saba.
              Mendez Camacho, Tatiana Antonella
              Rocha Escalera, Sheila
              Meira Da Cruz Saleiro, Gonzalo
 Fecha: 2026-10-23
 Objetivo: proceso de importacion del modulo disc (arbitros).
           Crea la tabla de staging imp.stg_Arbitro y el SP de importacion
           que recibe el nombre del archivo XML (scrapeado de Wikipedia) como
           parametro, lo carga a staging, valida e inserta mediante los SP ABM
           de la Entrega 5 (comp.usp_Persona_Alta / disc.usp_Arbitro_Alta),
           con importacion parcial y registro de errores en imp.ErrorImportacion.
           Requiere ejecutar antes: 00 (base y schemas), 01 (tablas, incluye
           imp.LogImportacion / imp.ErrorImportacion) y 02 (SP ABM de la E5).
=====================================================================
*/
IF OBJECT_ID('imp.stg_Arbitro') IS NULL
BEGIN
    CREATE TABLE imp.stg_Arbitro (
        id_stg INT IDENTITY(1,1) PRIMARY KEY,
        nombre NVARCHAR(200),
        apellido NVARCHAR(200),
        pais NVARCHAR(200),
        categoria NVARCHAR(200)
    );
END
GO
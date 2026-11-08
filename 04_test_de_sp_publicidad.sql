/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - 03: Testing de los SP de ABM - Selecciones y convocatoria
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana (nickGithub: tatimendez)
              Rocha Escalera, Sheila Belisa nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo nickGithub: meiraGonzalo
 Fecha: 08/10/2026
 Objetivo: probar todos los SP de ABM. Por cada SP hay
           casos OK y casos que disparan las validaciones

 COMO CORRERLO:
   1) Ejecutar 00 y 01 (base recien creada, vacia).
   2) Ejecutar el script de SP de ABM 
   3) Ejecutar este script completo 

=====================================================================*/
USE MundialDB;
GO

SET NOCOUNT ON;

-- ==============================================================================
-- LIMPIEZA PREVENTIVA (Elimina remanentes si una prueba previa se interrumpió)
-- ==============================================================================
DELETE FROM imp.ErrorImportacion WHERE mensaje LIKE '%Test%' OR id_log_importacion IN (SELECT id_log_importacion FROM imp.LogImportacion WHERE nombre_archivo = 'test.csv');
DELETE FROM imp.LogImportacion WHERE nombre_archivo = 'test.csv';
DELETE FROM pub.ExhibicionPublicitaria WHERE puntaje_prioridad = 45.0;
DELETE FROM pub.Tarifa WHERE id_franja_horaria IN (SELECT id_franja_horaria FROM pub.FranjaHoraria WHERE nombre LIKE '%Test%');
DELETE FROM pub.FranjaHoraria WHERE nombre LIKE '%Test%';
DELETE FROM pub.PiezaPublicitaria WHERE titulo LIKE '%Test%';
DELETE FROM pub.CampaniaPais WHERE id_campania IN (SELECT id_campania FROM pub.Campania WHERE titulo LIKE '%Test%');
DELETE FROM pub.Campania WHERE titulo LIKE '%Test%';
DELETE FROM pub.Marca WHERE nombre LIKE '%Test%';
DELETE FROM pub.Agencia WHERE nombre LIKE '%Test%';
DELETE FROM pub.Anunciante WHERE nombre LIKE '%Test%';
DELETE FROM cat.Feriado WHERE nombre LIKE '%Test%';
DELETE FROM cat.TipoCambio WHERE id_moneda IN (SELECT id_moneda FROM cat.Moneda WHERE codigo_iso = 'TT1');
DELETE FROM cat.IndicadorEconomico WHERE codigo_indicador = 'PBI Test';
DELETE FROM cat.Ciudad WHERE nombre LIKE '%Test%';
DELETE FROM cat.Pais WHERE nombre LIKE '%Test%';
DELETE FROM cat.Idioma WHERE codigo_iso = 'TT';
DELETE FROM cat.Moneda WHERE codigo_iso = 'TT1';

-- ==============================================================================
-- 0. PREPARACIÓN DE VARIABLES
-- ==============================================================================
DECLARE @id_moneda INT, @id_idioma INT, @id_pais INT, @id_ciudad INT;
DECLARE @id_anunciante INT, @id_marca INT, @id_agencia INT, @id_campania INT;
DECLARE @id_pieza INT, @id_franja INT, @id_tarifa INT, @id_exhibicion INT;
DECLARE @id_log INT, @id_error INT;

-- Referencias externas obligatorias
DECLARE @id_torneo INT = (SELECT TOP 1 id_torneo FROM comp.Torneo);
DECLARE @id_fase INT = (SELECT TOP 1 id_fase FROM comp.Fase);
DECLARE @id_partido INT = (SELECT TOP 1 id_partido FROM comp.Partido);

PRINT '==========================================================';
PRINT ' PARTE 1: ALTAS, MODIFICACIONES Y BAJAS FALLIDAS';
PRINT '==========================================================';

-- 1. cat.Moneda
PRINT '--- 1. cat.Moneda ---';
EXEC cat.usp_Moneda_Alta 'TT1', 'Moneda Test';
SELECT @id_moneda = id_moneda FROM cat.Moneda WHERE codigo_iso = 'TT1';
SELECT 'Alta OK' AS [cat.Moneda], * FROM cat.Moneda WHERE id_moneda = @id_moneda;

BEGIN TRY EXEC cat.usp_Moneda_Alta 'TT1', 'Duplicada'; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

EXEC cat.usp_Moneda_Modificacion @id_moneda, 'TT1', 'Moneda Mod Test';
SELECT 'Mod OK' AS [cat.Moneda], * FROM cat.Moneda WHERE id_moneda = @id_moneda;

BEGIN TRY EXEC cat.usp_Moneda_Modificacion -1, 'ZZZ', 'Inexistente'; END TRY
BEGIN CATCH PRINT 'Mod Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC cat.usp_Moneda_Baja -1; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


-- 2. cat.Idioma
PRINT '--- 2. cat.Idioma ---';
EXEC cat.usp_Idioma_Alta 'TT', 'Idioma Test';
SELECT @id_idioma = id_idioma FROM cat.Idioma WHERE codigo_iso = 'TT';
SELECT 'Alta OK' AS [cat.Idioma], * FROM cat.Idioma WHERE id_idioma = @id_idioma;

BEGIN TRY EXEC cat.usp_Idioma_Alta 'TT', 'Duplicado'; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

EXEC cat.usp_Idioma_Modificacion @id_idioma, 'TT', 'Idioma Mod Test';
SELECT 'Mod OK' AS [cat.Idioma], * FROM cat.Idioma WHERE id_idioma = @id_idioma;

BEGIN TRY EXEC cat.usp_Idioma_Modificacion -1, 'ZZ', 'Inexistente'; END TRY
BEGIN CATCH PRINT 'Mod Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC cat.usp_Idioma_Baja -1; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


-- 3. cat.Pais
PRINT '--- 3. cat.Pais ---';
EXEC cat.usp_Pais_Alta 'Pais Test', 'CONMEBOL', @id_moneda, 'UTC';
SELECT @id_pais = id_pais FROM cat.Pais WHERE nombre = 'Pais Test';
SELECT 'Alta OK' AS [cat.Pais], * FROM cat.Pais WHERE id_pais = @id_pais;

BEGIN TRY EXEC cat.usp_Pais_Alta 'Pais Test', 'UEFA', NULL, 'UTC'; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

EXEC cat.usp_Pais_Modificacion @id_pais, 'Pais Mod Test', 'CONMEBOL', @id_moneda, 'UTC';
SELECT 'Mod OK' AS [cat.Pais], * FROM cat.Pais WHERE id_pais = @id_pais;

BEGIN TRY EXEC cat.usp_Pais_Modificacion -1, 'Nada', 'CONMEBOL', NULL, 'UTC'; END TRY
BEGIN CATCH PRINT 'Mod Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC cat.usp_Pais_Baja -1; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


-- 4. cat.Ciudad
PRINT '--- 4. cat.Ciudad ---';
EXEC cat.usp_Ciudad_Alta 'Ciudad Test', @id_pais, 'UTC';
SELECT @id_ciudad = id_ciudad FROM cat.Ciudad WHERE nombre = 'Ciudad Test' AND id_pais = @id_pais;
SELECT 'Alta OK' AS [cat.Ciudad], * FROM cat.Ciudad WHERE id_ciudad = @id_ciudad;

BEGIN TRY EXEC cat.usp_Ciudad_Alta 'Ciudad Test', @id_pais, 'UTC'; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

EXEC cat.usp_Ciudad_Modificacion @id_ciudad, 'Ciudad Mod Test', @id_pais, 'UTC';
SELECT 'Mod OK' AS [cat.Ciudad], * FROM cat.Ciudad WHERE id_ciudad = @id_ciudad;

BEGIN TRY EXEC cat.usp_Ciudad_Modificacion -1, 'Nada', @id_pais, 'UTC'; END TRY
BEGIN CATCH PRINT 'Mod Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC cat.usp_Ciudad_Baja -1; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


-- 5. cat.IndicadorEconomico
PRINT '--- 5. cat.IndicadorEconomico ---';
EXEC cat.usp_IndicadorEconomico_Alta @id_pais, 2026, 'PBI Test', 1000.50;
SELECT 'Alta OK' AS [cat.Indicador], * FROM cat.IndicadorEconomico WHERE id_pais = @id_pais AND codigo_indicador = 'PBI Test';

BEGIN TRY EXEC cat.usp_IndicadorEconomico_Alta @id_pais, 2026, 'PBI Test', 2000; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

EXEC cat.usp_IndicadorEconomico_Modificacion @id_pais, 2026, 'PBI Test', 1500.00;
SELECT 'Mod OK' AS [cat.Indicador], * FROM cat.IndicadorEconomico WHERE id_pais = @id_pais AND codigo_indicador = 'PBI Test';

BEGIN TRY EXEC cat.usp_IndicadorEconomico_Modificacion -1, 2026, 'Nada', 0; END TRY
BEGIN CATCH PRINT 'Mod Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC cat.usp_IndicadorEconomico_Baja -1, 2026, 'Nada'; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


-- 6. cat.TipoCambio
PRINT '--- 6. cat.TipoCambio ---';
EXEC cat.usp_TipoCambio_Alta @id_moneda, '2026-01-01', 1.5;
SELECT 'Alta OK' AS [cat.TipoCambio], * FROM cat.TipoCambio WHERE id_moneda = @id_moneda AND fecha = '2026-01-01';

BEGIN TRY EXEC cat.usp_TipoCambio_Alta @id_moneda, '2026-01-01', 2.0; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

EXEC cat.usp_TipoCambio_Modificacion @id_moneda, '2026-01-01', 1.75;
SELECT 'Mod OK' AS [cat.TipoCambio], * FROM cat.TipoCambio WHERE id_moneda = @id_moneda AND fecha = '2026-01-01';

BEGIN TRY EXEC cat.usp_TipoCambio_Modificacion -1, '2026-01-01', 1.0; END TRY
BEGIN CATCH PRINT 'Mod Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC cat.usp_TipoCambio_Baja -1, '2026-01-01'; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


-- 7. cat.Feriado
PRINT '--- 7. cat.Feriado ---';
EXEC cat.usp_Feriado_Alta @id_pais, '2026-01-01', 'Feriado Test';
SELECT 'Alta OK' AS [cat.Feriado], * FROM cat.Feriado WHERE id_pais = @id_pais AND fecha = '2026-01-01';

BEGIN TRY EXEC cat.usp_Feriado_Alta @id_pais, '2026-01-01', 'Duplicado'; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

EXEC cat.usp_Feriado_Modificacion @id_pais, '2026-01-01', 'Feriado Mod Test';
SELECT 'Mod OK' AS [cat.Feriado], * FROM cat.Feriado WHERE id_pais = @id_pais AND fecha = '2026-01-01';

BEGIN TRY EXEC cat.usp_Feriado_Modificacion -1, '2026-01-01', 'Nada'; END TRY
BEGIN CATCH PRINT 'Mod Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC cat.usp_Feriado_Baja -1, '2026-01-01'; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


-- 8. pub.Anunciante
PRINT '--- 8. pub.Anunciante ---';
EXEC pub.usp_Anunciante_Alta 'Anunciante Test', @id_pais;
SELECT @id_anunciante = id_anunciante FROM pub.Anunciante WHERE nombre = 'Anunciante Test';
SELECT 'Alta OK' AS [pub.Anunciante], * FROM pub.Anunciante WHERE id_anunciante = @id_anunciante;

BEGIN TRY EXEC pub.usp_Anunciante_Alta '', @id_pais; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

EXEC pub.usp_Anunciante_Modificacion @id_anunciante, 'Anunciante Mod Test', @id_pais;
SELECT 'Mod OK' AS [pub.Anunciante], * FROM pub.Anunciante WHERE id_anunciante = @id_anunciante;

BEGIN TRY EXEC pub.usp_Anunciante_Modificacion -1, 'Nada', @id_pais; END TRY
BEGIN CATCH PRINT 'Mod Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC pub.usp_Anunciante_Baja -1; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


-- 9. pub.Marca
PRINT '--- 9. pub.Marca ---';
EXEC pub.usp_Marca_Alta @id_anunciante, 'Marca Test';
SELECT @id_marca = id_marca FROM pub.Marca WHERE nombre = 'Marca Test' AND id_anunciante = @id_anunciante;
SELECT 'Alta OK' AS [pub.Marca], * FROM pub.Marca WHERE id_marca = @id_marca;

BEGIN TRY EXEC pub.usp_Marca_Alta @id_anunciante, ''; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

EXEC pub.usp_Marca_Modificacion @id_marca, @id_anunciante, 'Marca Mod Test';
SELECT 'Mod OK' AS [pub.Marca], * FROM pub.Marca WHERE id_marca = @id_marca;

BEGIN TRY EXEC pub.usp_Marca_Modificacion -1, @id_anunciante, 'Nada'; END TRY
BEGIN CATCH PRINT 'Mod Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC pub.usp_Marca_Baja -1; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


-- 10. pub.Agencia
PRINT '--- 10. pub.Agencia ---';
EXEC pub.usp_Agencia_Alta 'Agencia Test';
SELECT @id_agencia = id_agencia FROM pub.Agencia WHERE nombre = 'Agencia Test';
SELECT 'Alta OK' AS [pub.Agencia], * FROM pub.Agencia WHERE id_agencia = @id_agencia;

BEGIN TRY EXEC pub.usp_Agencia_Alta 'Agencia Test'; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

EXEC pub.usp_Agencia_Modificacion @id_agencia, 'Agencia Mod Test';
SELECT 'Mod OK' AS [pub.Agencia], * FROM pub.Agencia WHERE id_agencia = @id_agencia;

BEGIN TRY EXEC pub.usp_Agencia_Modificacion -1, 'Nada'; END TRY
BEGIN CATCH PRINT 'Mod Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC pub.usp_Agencia_Baja -1; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


-- 11. pub.Campania
PRINT '--- 11. pub.Campania ---';
EXEC pub.usp_Campania_Alta @id_marca, @id_agencia, 'Campania Test', '2026-01-01', '2026-12-31', 'Desc Test';
SELECT @id_campania = id_campania FROM pub.Campania WHERE titulo = 'Campania Test';
SELECT 'Alta OK' AS [pub.Campania], * FROM pub.Campania WHERE id_campania = @id_campania;

BEGIN TRY EXEC pub.usp_Campania_Alta @id_marca, @id_agencia, 'Campania Error', '2026-12-31', '2026-01-01', 'Fechas Invertidas'; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

EXEC pub.usp_Campania_Modificacion @id_campania, @id_marca, @id_agencia, 'Campania Mod Test', '2026-01-01', '2026-12-31', 'Desc Mod';
SELECT 'Mod OK' AS [pub.Campania], * FROM pub.Campania WHERE id_campania = @id_campania;

BEGIN TRY EXEC pub.usp_Campania_Modificacion -1, @id_marca, @id_agencia, 'Nada', '2026-01-01', '2026-12-31', 'Nada'; END TRY
BEGIN CATCH PRINT 'Mod Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC pub.usp_Campania_Baja -1; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


-- 12. pub.CampaniaPais (Tabla puente: Alta y Baja)
PRINT '--- 12. pub.CampaniaPais ---';
EXEC pub.usp_CampaniaPais_Alta @id_campania, @id_pais;
SELECT 'Alta OK' AS [pub.CampaniaPais], * FROM pub.CampaniaPais WHERE id_campania = @id_campania AND id_pais = @id_pais;

BEGIN TRY EXEC pub.usp_CampaniaPais_Alta @id_campania, @id_pais; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC pub.usp_CampaniaPais_Baja -1, -1; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


-- 13. pub.PiezaPublicitaria
PRINT '--- 13. pub.PiezaPublicitaria ---';
EXEC pub.usp_PiezaPublicitaria_Alta @id_campania, @id_idioma, @id_pais, 'Pieza Test', 'http://test.com/1';
SELECT @id_pieza = id_pieza_publicitaria FROM pub.PiezaPublicitaria WHERE titulo = 'Pieza Test';
SELECT 'Alta OK' AS [pub.Pieza], * FROM pub.PiezaPublicitaria WHERE id_pieza_publicitaria = @id_pieza;

BEGIN TRY EXEC pub.usp_PiezaPublicitaria_Alta @id_campania, @id_idioma, @id_pais, '', 'http://test.com'; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

EXEC pub.usp_PiezaPublicitaria_Modificacion @id_pieza, @id_campania, @id_idioma, @id_pais, 'Pieza Mod Test', 'http://test.com/2';
SELECT 'Mod OK' AS [pub.Pieza], * FROM pub.PiezaPublicitaria WHERE id_pieza_publicitaria = @id_pieza;

BEGIN TRY EXEC pub.usp_PiezaPublicitaria_Modificacion -1, @id_campania, @id_idioma, @id_pais, 'Nada', ''; END TRY
BEGIN CATCH PRINT 'Mod Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC pub.usp_PiezaPublicitaria_Baja -1; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


-- 14. pub.FranjaHoraria
PRINT '--- 14. pub.FranjaHoraria ---';
EXEC pub.usp_FranjaHoraria_Alta 'Franja Test', '10:00', '12:00', 0;
SELECT @id_franja = id_franja_horaria FROM pub.FranjaHoraria WHERE nombre = 'Franja Test';
SELECT 'Alta OK' AS [pub.Franja], * FROM pub.FranjaHoraria WHERE id_franja_horaria = @id_franja;

BEGIN TRY EXEC pub.usp_FranjaHoraria_Alta 'Franja Test', '14:00', '16:00', 0; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

EXEC pub.usp_FranjaHoraria_Modificacion @id_franja, 'Franja Mod Test', '11:00', '13:00', 1;
SELECT 'Mod OK' AS [pub.Franja], * FROM pub.FranjaHoraria WHERE id_franja_horaria = @id_franja;

BEGIN TRY EXEC pub.usp_FranjaHoraria_Modificacion -1, 'Nada', '00:00', '01:00', 0; END TRY
BEGIN CATCH PRINT 'Mod Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC pub.usp_FranjaHoraria_Baja -1; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


-- 15. pub.Tarifa
PRINT '--- 15. pub.Tarifa ---';
EXEC pub.usp_Tarifa_Alta @id_torneo, @id_fase, @id_franja, 1000.00, @id_moneda;
SELECT @id_tarifa = id_tarifa FROM pub.Tarifa WHERE id_torneo = @id_torneo AND id_fase = @id_fase AND id_franja_horaria = @id_franja;
SELECT 'Alta OK' AS [pub.Tarifa], * FROM pub.Tarifa WHERE id_tarifa = @id_tarifa;

BEGIN TRY EXEC pub.usp_Tarifa_Alta @id_torneo, @id_fase, @id_franja, -500.00, @id_moneda; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

EXEC pub.usp_Tarifa_Modificacion @id_tarifa, 1500.00, @id_moneda;
SELECT 'Mod OK' AS [pub.Tarifa], * FROM pub.Tarifa WHERE id_tarifa = @id_tarifa;

BEGIN TRY EXEC pub.usp_Tarifa_Modificacion -1, 500.00, @id_moneda; END TRY
BEGIN CATCH PRINT 'Mod Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC pub.usp_Tarifa_Baja -1; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


-- 16. pub.ExhibicionPublicitaria
PRINT '--- 16. pub.ExhibicionPublicitaria ---';
EXEC pub.usp_ExhibicionPublicitaria_Alta @id_partido, 1, @id_pieza, @id_tarifa, 1500.00, @id_moneda, 45.0, 'PROPUESTA';
SELECT @id_exhibicion = id_exhibicion_publicitaria FROM pub.ExhibicionPublicitaria WHERE id_partido = @id_partido AND nro_espacio = 1;
SELECT 'Alta OK' AS [pub.Exhibicion], * FROM pub.ExhibicionPublicitaria WHERE id_exhibicion_publicitaria = @id_exhibicion;

BEGIN TRY EXEC pub.usp_ExhibicionPublicitaria_Alta @id_partido, 1, @id_pieza, @id_tarifa, -100.00, @id_moneda, 45.0, 'FALSO'; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

EXEC pub.usp_ExhibicionPublicitaria_Modificacion @id_exhibicion, 'EXHIBIDA';
SELECT 'Mod OK' AS [pub.Exhibicion], * FROM pub.ExhibicionPublicitaria WHERE id_exhibicion_publicitaria = @id_exhibicion;

BEGIN TRY EXEC pub.usp_ExhibicionPublicitaria_Modificacion -1, 'EXHIBIDA'; END TRY
BEGIN CATCH PRINT 'Mod Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC pub.usp_ExhibicionPublicitaria_Baja -1; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


-- 17. imp.LogImportacion
PRINT '--- 17. imp.LogImportacion ---';
EXEC imp.usp_LogImportacion_Alta 'test.csv', 'TEST', '2026-01-01 10:00:00', '2026-01-01 10:05:00', 10, 10, 0;
SELECT @id_log = id_log_importacion FROM imp.LogImportacion WHERE nombre_archivo = 'test.csv';
SELECT 'Alta OK' AS [imp.Log], * FROM imp.LogImportacion WHERE id_log_importacion = @id_log;

BEGIN TRY EXEC imp.usp_LogImportacion_Alta '', 'TEST', '2026-01-01 10:00:00', '2026-01-01 10:05:00', 10, 10, 0; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

EXEC imp.usp_LogImportacion_Modificacion @id_log, '2026-01-01 10:10:00', 10, 8, 2;
SELECT 'Mod OK' AS [imp.Log], * FROM imp.LogImportacion WHERE id_log_importacion = @id_log;

BEGIN TRY EXEC imp.usp_LogImportacion_Modificacion -1, '2026-01-01 10:10:00', 10, 8, 2; END TRY
BEGIN CATCH PRINT 'Mod Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC imp.usp_LogImportacion_Baja -1; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


-- 18. imp.ErrorImportacion
PRINT '--- 18. imp.ErrorImportacion ---';
EXEC imp.usp_ErrorImportacion_Alta @id_log, 1, 'Dato Corrupto', 'Fallo general';
SELECT @id_error = id_error_importacion FROM imp.ErrorImportacion WHERE id_log_importacion = @id_log;
SELECT 'Alta OK' AS [imp.Error], * FROM imp.ErrorImportacion WHERE id_error_importacion = @id_error;

BEGIN TRY EXEC imp.usp_ErrorImportacion_Alta @id_log, 1, 'Dato', ''; END TRY
BEGIN CATCH PRINT 'Alta Fallida: ' + ERROR_MESSAGE(); END CATCH;

EXEC imp.usp_ErrorImportacion_Modificacion @id_error, 'Mensaje Modificado Test';
SELECT 'Mod OK' AS [imp.Error], * FROM imp.ErrorImportacion WHERE id_error_importacion = @id_error;

BEGIN TRY EXEC imp.usp_ErrorImportacion_Modificacion -1, 'Nada'; END TRY
BEGIN CATCH PRINT 'Mod Fallida: ' + ERROR_MESSAGE(); END CATCH;

BEGIN TRY EXEC imp.usp_ErrorImportacion_Baja -1; END TRY
BEGIN CATCH PRINT 'Baja Fallida: ' + ERROR_MESSAGE(); END CATCH;


PRINT '==========================================================';
PRINT ' PARTE 2: BAJAS EXITOSAS (LIMPIEZA EN ORDEN INVERSO)';
PRINT '==========================================================';

EXEC imp.usp_ErrorImportacion_Baja @id_error;
SELECT 'Baja OK (Debería estar vacío)' AS [imp.Error], * FROM imp.ErrorImportacion WHERE id_error_importacion = @id_error;

EXEC imp.usp_LogImportacion_Baja @id_log;
SELECT 'Baja OK (Debería estar vacío)' AS [imp.Log], * FROM imp.LogImportacion WHERE id_log_importacion = @id_log;

EXEC pub.usp_ExhibicionPublicitaria_Baja @id_exhibicion;
SELECT 'Baja OK (Debería estar vacío)' AS [pub.Exhibicion], * FROM pub.ExhibicionPublicitaria WHERE id_exhibicion_publicitaria = @id_exhibicion;

EXEC pub.usp_Tarifa_Baja @id_tarifa;
SELECT 'Baja OK (Debería estar vacío)' AS [pub.Tarifa], * FROM pub.Tarifa WHERE id_tarifa = @id_tarifa;

EXEC pub.usp_FranjaHoraria_Baja @id_franja;
SELECT 'Baja OK (Debería estar vacío)' AS [pub.Franja], * FROM pub.FranjaHoraria WHERE id_franja_horaria = @id_franja;

EXEC pub.usp_PiezaPublicitaria_Baja @id_pieza;
SELECT 'Baja OK (Debería estar vacío)' AS [pub.Pieza], * FROM pub.PiezaPublicitaria WHERE id_pieza_publicitaria = @id_pieza;

EXEC pub.usp_CampaniaPais_Baja @id_campania, @id_pais;
SELECT 'Baja OK (Debería estar vacío)' AS [pub.CampaniaPais], * FROM pub.CampaniaPais WHERE id_campania = @id_campania AND id_pais = @id_pais;

EXEC pub.usp_Campania_Baja @id_campania;
SELECT 'Baja OK (Debería estar vacío)' AS [pub.Campania], * FROM pub.Campania WHERE id_campania = @id_campania;

EXEC pub.usp_Agencia_Baja @id_agencia;
SELECT 'Baja OK (Debería estar vacío)' AS [pub.Agencia], * FROM pub.Agencia WHERE id_agencia = @id_agencia;

EXEC pub.usp_Marca_Baja @id_marca;
SELECT 'Baja OK (Debería estar vacío)' AS [pub.Marca], * FROM pub.Marca WHERE id_marca = @id_marca;

EXEC pub.usp_Anunciante_Baja @id_anunciante;
SELECT 'Baja OK (Debería estar vacío)' AS [pub.Anunciante], * FROM pub.Anunciante WHERE id_anunciante = @id_anunciante;

EXEC cat.usp_Feriado_Baja @id_pais, '2026-01-01';
SELECT 'Baja OK (Debería estar vacío)' AS [cat.Feriado], * FROM cat.Feriado WHERE id_pais = @id_pais AND fecha = '2026-01-01';

EXEC cat.usp_TipoCambio_Baja @id_moneda, '2026-01-01';
SELECT 'Baja OK (Debería estar vacío)' AS [cat.TipoCambio], * FROM cat.TipoCambio WHERE id_moneda = @id_moneda AND fecha = '2026-01-01';

EXEC cat.usp_IndicadorEconomico_Baja @id_pais, 2026, 'PBI Test';
SELECT 'Baja OK (Debería estar vacío)' AS [cat.Indicador], * FROM cat.IndicadorEconomico WHERE id_pais = @id_pais AND codigo_indicador = 'PBI Test';

EXEC cat.usp_Ciudad_Baja @id_ciudad;
SELECT 'Baja OK (Debería estar vacío)' AS [cat.Ciudad], * FROM cat.Ciudad WHERE id_ciudad = @id_ciudad;

EXEC cat.usp_Pais_Baja @id_pais;
SELECT 'Baja OK (Debería estar vacío)' AS [cat.Pais], * FROM cat.Pais WHERE id_pais = @id_pais;

EXEC cat.usp_Idioma_Baja @id_idioma;
SELECT 'Baja OK (Debería estar vacío)' AS [cat.Idioma], * FROM cat.Idioma WHERE id_idioma = @id_idioma;

EXEC cat.usp_Moneda_Baja @id_moneda;
SELECT 'Baja OK (Debería estar vacío)' AS [cat.Moneda], * FROM cat.Moneda WHERE id_moneda = @id_moneda;
GO
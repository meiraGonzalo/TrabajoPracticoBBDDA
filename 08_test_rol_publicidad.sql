/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 8 - Script 08: Test del usuario usr_publicidad (rol_gestor_publicidad)
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 2026-11-24
 Objetivo: demostrar lo que rol_gestor_publicidad puede y no puede hacer, ejecutando como usr_publicidad.
             PERMITIDO: SPs de pub (aca: alta de un anunciante) y los reportes de publicidad.
             DENEGADO:  tablas directas, SPs de competencia, catalogos e importacion, y descifrar.
           Cada prueba imprime el resultado esperado (OK / DENEGADO (esperado) / FALLO).
 Orden:    ejecutar despues de 08_cifrado.sql y 08_roles_permisos.sql
=====================================================================
*/
USE MundialDB;
GO
SET NOCOUNT ON;

/* ----------------- ANTES (como dbo) ---------------------------------------------- */
PRINT '===== ANTES (como dbo) =====';
DECLARE @id_pais int = (SELECT TOP 1 id_pais FROM cat.Pais ORDER BY id_pais);
DECLARE @id_viejo int = (SELECT MAX(id_anunciante) FROM pub.Anunciante WHERE nombre = 'Anunciante E8 Test');
IF @id_viejo IS NOT NULL EXEC pub.usp_Anunciante_Baja @id_viejo;   -- limpia restos de una corrida anterior
SELECT COUNT(*) AS anunciantes_antes FROM pub.Anunciante;

/* ----------------- EJECUCION ------------------------------------------------------ */
EXECUTE AS USER = 'usr_publicidad';
PRINT '===== EJECUCION como: ' + USER_NAME() + ' =====';
PRINT '--- PERMITIDO ---';
BEGIN TRY EXEC pub.usp_Anunciante_Alta 'Anunciante E8 Test', @id_pais;
    PRINT 'OK  EXEC pub.usp_Anunciante_Alta';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO EXEC pub.usp_Anunciante_Alta: ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC pub.usp_Reporte_OcupacionPublicitaria;
    PRINT 'OK  EXEC pub.usp_Reporte_OcupacionPublicitaria';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO EXEC pub.usp_Reporte_OcupacionPublicitaria: ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC pub.usp_Reporte_IngresosPublicidadGlobal;
    PRINT 'OK  EXEC pub.usp_Reporte_IngresosPublicidadGlobal';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO EXEC pub.usp_Reporte_IngresosPublicidadGlobal: ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC pub.usp_Reporte_MatrizPrimeTime;
    PRINT 'OK  EXEC pub.usp_Reporte_MatrizPrimeTime';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO EXEC pub.usp_Reporte_MatrizPrimeTime: ' + ERROR_MESSAGE(); END CATCH

PRINT '--- DENEGADO ---';
BEGIN TRY SELECT TOP 1 * FROM pub.Anunciante;
    PRINT 'FALLO: SELECT pub.Anunciante deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) SELECT pub.Anunciante -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY SELECT TOP 1 * FROM comp.Persona;
    PRINT 'FALLO: SELECT comp.Persona deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) SELECT comp.Persona -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC comp.usp_Persona_Alta N'Intruso', N'Intruso', '1990-01-01', @id_pais, 'DNI', '22222222';
    PRINT 'FALLO: EXEC comp.usp_Persona_Alta deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) EXEC comp.usp_Persona_Alta -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC comp.usp_Reporte_Resultados @anio = 2026;
    PRINT 'FALLO: EXEC comp.usp_Reporte_Resultados deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) EXEC comp.usp_Reporte_Resultados -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC cat.usp_Moneda_Alta 'ZZZ', 'Moneda intrusa';
    PRINT 'FALLO: EXEC cat.usp_Moneda_Alta deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) EXEC cat.usp_Moneda_Alta -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC imp.usp_Reporte_LogImportacion;
    PRINT 'FALLO: EXEC imp.usp_Reporte_LogImportacion deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) EXEC imp.usp_Reporte_LogImportacion -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC comp.usp_Persona_DescifrarDocumento @id_persona = 1;
    PRINT 'FALLO: EXEC comp.usp_Persona_DescifrarDocumento deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) EXEC comp.usp_Persona_DescifrarDocumento -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH

REVERT;
PRINT '===== fin de la ejecucion, usuario actual: ' + USER_NAME() + ' =====';

/* ----------------- DESPUES (como dbo) --------------------------------------------- */
PRINT '===== DESPUES (como dbo): un anunciante mas =====';
SELECT COUNT(*) AS anunciantes_despues FROM pub.Anunciante;
SELECT id_anunciante, nombre, id_pais FROM pub.Anunciante WHERE nombre = 'Anunciante E8 Test';

-- Limpieza: se borra el anunciante de prueba con el SP de baja
DECLARE @id_nuevo int = (SELECT MAX(id_anunciante) FROM pub.Anunciante WHERE nombre = 'Anunciante E8 Test');
EXEC pub.usp_Anunciante_Baja @id_nuevo;
SELECT COUNT(*) AS anunciantes_tras_limpieza FROM pub.Anunciante;
GO

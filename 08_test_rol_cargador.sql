/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 8 - Script 08: Test del usuario usr_cargador (rol_cargador_resultados)
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 2026-11-24
 Objetivo: demostrar lo que rol_cargador_resultados puede y no puede hacer, ejecutando como usr_cargador.
             PERMITIDO: SPs de comp y disc (aca: alta de una persona con documento, que se guarda
                        cifrado) y los reportes de competencia y disciplina.
             DENEGADO:  tablas directas, SPs de publicidad, catalogos e importacion, y descifrar.
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
DECLARE @id_viejo int = (SELECT MAX(id_persona) FROM comp.Persona WHERE apellido = N'Cargador-E8');
IF @id_viejo IS NOT NULL EXEC comp.usp_Persona_Baja @id_viejo;   -- limpia restos de una corrida anterior
SELECT COUNT(*) AS personas_antes FROM comp.Persona;

/* ----------------- EJECUCION ------------------------------------------------------ */
EXECUTE AS USER = 'usr_cargador';
PRINT '===== EJECUCION como: ' + USER_NAME() + ' =====';
PRINT '--- PERMITIDO ---';
BEGIN TRY EXEC comp.usp_Persona_Alta N'Test', N'Cargador-E8', '1995-05-05', @id_pais, 'DNI', 'E8-CARGADOR-01';
    PRINT 'OK  EXEC comp.usp_Persona_Alta (con documento)';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO EXEC comp.usp_Persona_Alta (con documento): ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC comp.usp_Reporte_Resultados @anio = 2026;
    PRINT 'OK  EXEC comp.usp_Reporte_Resultados';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO EXEC comp.usp_Reporte_Resultados: ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC disc.usp_Reporte_Tarjetas @anio = 2026;
    PRINT 'OK  EXEC disc.usp_Reporte_Tarjetas';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO EXEC disc.usp_Reporte_Tarjetas: ' + ERROR_MESSAGE(); END CATCH

PRINT '--- DENEGADO ---';
BEGIN TRY SELECT TOP 1 * FROM comp.Persona;
    PRINT 'FALLO: SELECT comp.Persona deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) SELECT comp.Persona -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC pub.usp_Anunciante_Alta 'Intruso E8', @id_pais;
    PRINT 'FALLO: EXEC pub.usp_Anunciante_Alta deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) EXEC pub.usp_Anunciante_Alta -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC cat.usp_Moneda_Alta 'ZZZ', 'Moneda intrusa';
    PRINT 'FALLO: EXEC cat.usp_Moneda_Alta deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) EXEC cat.usp_Moneda_Alta -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC pub.usp_Reporte_OcupacionPublicitaria;
    PRINT 'FALLO: EXEC pub.usp_Reporte_OcupacionPublicitaria deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) EXEC pub.usp_Reporte_OcupacionPublicitaria -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC imp.usp_Reporte_LogImportacion;
    PRINT 'FALLO: EXEC imp.usp_Reporte_LogImportacion deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) EXEC imp.usp_Reporte_LogImportacion -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC comp.usp_Persona_DescifrarDocumento @id_persona = 1;
    PRINT 'FALLO: EXEC comp.usp_Persona_DescifrarDocumento deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) EXEC comp.usp_Persona_DescifrarDocumento -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH

REVERT;
PRINT '===== fin de la ejecucion, usuario actual: ' + USER_NAME() + ' =====';

/* ----------------- DESPUES (como dbo) --------------------------------------------- */
PRINT '===== DESPUES (como dbo): una persona mas, y el documento guardado cifrado =====';
SELECT COUNT(*) AS personas_despues FROM comp.Persona;
SELECT id_persona, nombre, apellido, tipo_documento, nro_documento_cif   -- ilegible: varbinary
FROM comp.Persona WHERE apellido = N'Cargador-E8';

-- Limpieza: se borra la persona de prueba con el SP de baja
DECLARE @id_nuevo int = (SELECT MAX(id_persona) FROM comp.Persona WHERE apellido = N'Cargador-E8');
EXEC comp.usp_Persona_Baja @id_nuevo;
SELECT COUNT(*) AS personas_tras_limpieza FROM comp.Persona;
GO

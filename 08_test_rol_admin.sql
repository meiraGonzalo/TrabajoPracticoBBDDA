/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 8 - Script 08: Test del usuario usr_admin (rol_administrador)
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 2026-11-24
 Objetivo: demostrar lo que rol_administrador puede y no puede hacer, ejecutando como usr_admin.
             PERMITIDO: leer tablas (el documento se ve cifrado), usar SPs de todos los esquemas y
                        DESCIFRAR el documento con comp.usp_Persona_DescifrarDocumento.
             DENEGADO:  cambiar la estructura (crear tablas o roles): no es dbo ni db_owner.
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
DECLARE @id_viejo int = (SELECT MAX(id_persona) FROM comp.Persona WHERE apellido = N'Admin-E8');
IF @id_viejo IS NOT NULL EXEC comp.usp_Persona_Baja @id_viejo;   -- limpia restos de una corrida anterior
SELECT COUNT(*) AS personas_antes FROM comp.Persona;

/* ----------------- EJECUCION ------------------------------------------------------ */
EXECUTE AS USER = 'usr_admin';
PRINT '===== EJECUCION como: ' + USER_NAME() + ' =====';
PRINT '--- PERMITIDO ---';
BEGIN TRY EXEC comp.usp_Persona_Alta N'Test', N'Admin-E8', '1980-03-03', @id_pais, 'DNI', 'E8-ADMIN-01';
    PRINT 'OK  EXEC comp.usp_Persona_Alta (con documento)';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO EXEC comp.usp_Persona_Alta (con documento): ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY SELECT TOP 1 id_persona, nombre, apellido, nro_documento_cif FROM comp.Persona WHERE apellido = N'Admin-E8';
    PRINT 'OK  SELECT directo comp.Persona (documento ilegible, cifrado)';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO SELECT directo comp.Persona (documento ilegible, cifrado): ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY
    DECLARE @id_nuevo int = (SELECT MAX(id_persona) FROM comp.Persona WHERE apellido = N'Admin-E8');
    EXEC comp.usp_Persona_DescifrarDocumento @id_persona = @id_nuevo;   -- debe mostrar E8-ADMIN-01
    PRINT 'OK  EXEC comp.usp_Persona_DescifrarDocumento (el administrador si descifra)';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO descifrar: ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC pub.usp_Reporte_OcupacionPublicitaria;
    PRINT 'OK  EXEC pub.usp_Reporte_OcupacionPublicitaria';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO EXEC pub.usp_Reporte_OcupacionPublicitaria: ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC disc.usp_Reporte_Tarjetas @anio = 2026;
    PRINT 'OK  EXEC disc.usp_Reporte_Tarjetas';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO EXEC disc.usp_Reporte_Tarjetas: ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY EXEC imp.usp_Reporte_LogImportacion;
    PRINT 'OK  EXEC imp.usp_Reporte_LogImportacion';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO EXEC imp.usp_Reporte_LogImportacion: ' + ERROR_MESSAGE(); END CATCH

PRINT '--- DENEGADO (cambios de estructura) ---';
BEGIN TRY CREATE TABLE comp.TablaIntrusa (x int);
    PRINT 'FALLO: CREATE TABLE deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) CREATE TABLE -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH
BEGIN TRY CREATE ROLE rol_intruso;
    PRINT 'FALLO: CREATE ROLE deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) CREATE ROLE -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH

REVERT;
PRINT '===== fin de la ejecucion, usuario actual: ' + USER_NAME() + ' =====';

/* ----------------- DESPUES (como dbo) --------------------------------------------- */
PRINT '===== DESPUES (como dbo): una persona mas =====';
SELECT COUNT(*) AS personas_despues FROM comp.Persona;

-- Limpieza: se borra la persona de prueba con el SP de baja
DECLARE @id_borrar int = (SELECT MAX(id_persona) FROM comp.Persona WHERE apellido = N'Admin-E8');
EXEC comp.usp_Persona_Baja @id_borrar;
SELECT COUNT(*) AS personas_tras_limpieza FROM comp.Persona;
GO

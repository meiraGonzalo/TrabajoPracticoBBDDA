/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 8 - Script 08: Test del usuario usr_consulta (rol_consulta)
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 2026-11-24
 Objetivo: demostrar lo que rol_consulta puede y no puede hacer, ejecutando como usr_consulta.
             PERMITIDO: ejecutar los 10 reportes y leer las vistas del esquema bi.
             DENEGADO:  leer o modificar tablas, ejecutar SPs de carga y descifrar documentos.
           Cada prueba imprime el resultado esperado. Al final se verifica que la base no cambio
           (cantidad de personas ANTES y DESPUES).
 Orden:    ejecutar despues de 08_cifrado.sql y 08_roles_permisos.sql
=====================================================================
*/
USE MundialDB;
GO

SET NOCOUNT ON;

/* ----------------- ANTES ---------------------------------------------------------- */
PRINT '===== ANTES (como dbo) =====';
SELECT COUNT(*) AS personas_antes FROM comp.Persona;
GO

/* ----------------- EJECUCION ------------------------------------------------------ */
EXECUTE AS USER = 'usr_consulta';
PRINT '===== EJECUCION como: ' + USER_NAME() + ' =====';

PRINT '';
PRINT '--- PERMITIDO: reportes (deben ejecutarse sin error) ---';

BEGIN TRY EXEC disc.usp_Reporte_Goleadores @anio = 2026;           PRINT 'OK  disc.usp_Reporte_Goleadores';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO disc.usp_Reporte_Goleadores: ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY EXEC disc.usp_Reporte_Tarjetas @anio = 2026;             PRINT 'OK  disc.usp_Reporte_Tarjetas';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO disc.usp_Reporte_Tarjetas: ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY EXEC disc.usp_Reporte_Designaciones_XML @anio = 2026;    PRINT 'OK  disc.usp_Reporte_Designaciones_XML';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO disc.usp_Reporte_Designaciones_XML: ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY EXEC comp.usp_Reporte_Plantillas_XML @anio = 2026;       PRINT 'OK  comp.usp_Reporte_Plantillas_XML';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO comp.usp_Reporte_Plantillas_XML: ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY EXEC comp.usp_Reporte_Resultados @anio = 2026;           PRINT 'OK  comp.usp_Reporte_Resultados';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO comp.usp_Reporte_Resultados: ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY EXEC cat.usp_Reporte_ContextoEconomicoFeriados @anio = 2026; PRINT 'OK  cat.usp_Reporte_ContextoEconomicoFeriados';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO cat.usp_Reporte_ContextoEconomicoFeriados: ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY EXEC pub.usp_Reporte_IngresosPublicidadGlobal;           PRINT 'OK  pub.usp_Reporte_IngresosPublicidadGlobal';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO pub.usp_Reporte_IngresosPublicidadGlobal: ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY EXEC pub.usp_Reporte_MatrizPrimeTime;                    PRINT 'OK  pub.usp_Reporte_MatrizPrimeTime';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO pub.usp_Reporte_MatrizPrimeTime: ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY EXEC pub.usp_Reporte_OcupacionPublicitaria;              PRINT 'OK  pub.usp_Reporte_OcupacionPublicitaria';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO pub.usp_Reporte_OcupacionPublicitaria: ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY EXEC imp.usp_Reporte_LogImportacion;                     PRINT 'OK  imp.usp_Reporte_LogImportacion';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO imp.usp_Reporte_LogImportacion: ' + ERROR_MESSAGE(); END CATCH

PRINT '';
PRINT '--- PERMITIDO: vistas del esquema bi ---';
BEGIN TRY SELECT TOP 5 * FROM bi.vw_Goles;                          PRINT 'OK  SELECT bi.vw_Goles';
END TRY BEGIN CATCH PRINT 'FALLO INESPERADO bi.vw_Goles: ' + ERROR_MESSAGE(); END CATCH

PRINT '';
PRINT '--- DENEGADO: acceso directo a las tablas (deben dar error de permisos) ---';

BEGIN TRY SELECT TOP 1 * FROM comp.Persona;
    PRINT 'FALLO: SELECT sobre comp.Persona deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) SELECT comp.Persona -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY
    INSERT INTO comp.Persona (nombre, apellido, id_pais_nacionalidad) VALUES (N'Intruso', N'Intruso', 1);
    PRINT 'FALLO: INSERT sobre comp.Persona deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) INSERT comp.Persona -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY DELETE FROM pub.Tarifa WHERE 1 = 0;
    PRINT 'FALLO: DELETE sobre pub.Tarifa deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) DELETE pub.Tarifa -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH

PRINT '';
PRINT '--- DENEGADO: SPs de carga y descifrado ---';

BEGIN TRY EXEC comp.usp_Persona_Alta N'Intruso', N'Intruso', '1990-01-01', 1, 'DNI', '11111111';
    PRINT 'FALLO: usp_Persona_Alta deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) EXEC comp.usp_Persona_Alta -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY EXEC pub.usp_AsignarPublicidadTodosPartidos;
    PRINT 'FALLO: usp_AsignarPublicidadTodosPartidos deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) EXEC pub.usp_AsignarPublicidadTodosPartidos -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH

BEGIN TRY EXEC comp.usp_Persona_DescifrarDocumento @id_persona = 1;
    PRINT 'FALLO: DescifrarDocumento deberia estar denegado';
END TRY BEGIN CATCH PRINT 'DENEGADO (esperado) EXEC comp.usp_Persona_DescifrarDocumento -> error ' + CAST(ERROR_NUMBER() AS varchar(10)) + ': ' + ERROR_MESSAGE(); END CATCH

REVERT;
PRINT '';
PRINT '===== fin de la ejecucion, usuario actual: ' + USER_NAME() + ' =====';
GO

/* ----------------- DESPUES -------------------------------------------------------- */
PRINT '===== DESPUES (como dbo): tiene que dar el mismo valor que ANTES =====';
SELECT COUNT(*) AS personas_despues FROM comp.Persona;
GO

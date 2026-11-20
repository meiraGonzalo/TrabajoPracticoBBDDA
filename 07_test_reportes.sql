/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 7 - Script 07: Prueba de los 7 reportes (07_test_reportes)
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 2026-11-20
 Objetivo: ejecutar los siete reportes de la Entrega 7 sobre el torneo 2026 y avisar cuales fallan.
           Cada reporte va en su propio lote y dentro de TRY/CATCH: si uno falla, imprime
           "FALLO ..." con el mensaje y se sigue con el siguiente. No modifica datos.
 Orden:    despues de todo el resto: 00 -> 01 -> 02 -> 03 -> importaciones -> 10 (seed) -> 07 (creacion) -> este script
=====================================================================
*/
USE MundialDB;
GO
SET NOCOUNT ON;
PRINT '=== E7: control de datos que alimentan los reportes ===';

SELECT 'partidos 2026'               AS dato, COUNT(*) AS filas
FROM comp.Partido p JOIN comp.Torneo t ON t.id_torneo = p.id_torneo AND t.anio = 2026
UNION ALL SELECT 'convocados (todos los torneos)', COUNT(*) FROM comp.Convocado
UNION ALL SELECT 'goles',                          COUNT(*) FROM disc.Gol
UNION ALL SELECT 'tarjetas',                       COUNT(*) FROM disc.Tarjeta
UNION ALL SELECT 'suspensiones',                   COUNT(*) FROM disc.Suspension
UNION ALL SELECT 'designaciones',                  COUNT(*) FROM disc.Designacion
UNION ALL SELECT 'exhibiciones publicitarias',     COUNT(*) FROM pub.ExhibicionPublicitaria
UNION ALL SELECT 'campanias',                      COUNT(*) FROM pub.Campania;
/* Esperado con todo cargado: partidos 104; goles > 0 (importacion de goles); tarjetas 6 y suspensiones 3 (seed de disciplina);
   designaciones 520 (5 por partido); exhibiciones y campanias > 0 (publicidad). Si alguno da 0, el reporte que lo usa saldra vacio. */
GO

PRINT '--- R1 Goleadores (disc.usp_Reporte_Goleadores) ---';
BEGIN TRY
    EXEC disc.usp_Reporte_Goleadores @anio = 2026;
END TRY
BEGIN CATCH
    PRINT 'FALLO R1: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '--- R2 Tarjetas y suspensiones activas (disc.usp_Reporte_Tarjetas) ---';
BEGIN TRY
    EXEC disc.usp_Reporte_Tarjetas @anio = 2026;
END TRY
BEGIN CATCH
    PRINT 'FALLO R2: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '--- R3 Designaciones arbitrales, en XML (disc.usp_Reporte_Designaciones_XML) ---';
BEGIN TRY
    EXEC disc.usp_Reporte_Designaciones_XML @anio = 2026;
END TRY
BEGIN CATCH
    PRINT 'FALLO R3: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '--- R4 Ocupacion publicitaria (pub.usp_Reporte_OcupacionPublicitaria) ---';
BEGIN TRY
    EXEC pub.usp_Reporte_OcupacionPublicitaria;
END TRY
BEGIN CATCH
    PRINT 'FALLO R4: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '--- R5 Matriz de prime time (pub.usp_Reporte_MatrizPrimeTime) ---';
BEGIN TRY
    EXEC pub.usp_Reporte_MatrizPrimeTime;
END TRY
BEGIN CATCH
    PRINT 'FALLO R5: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '--- R6 Selecciones y plantillas, en XML (comp.usp_Reporte_Plantillas_XML) ---';
BEGIN TRY
    EXEC comp.usp_Reporte_Plantillas_XML @anio = 2026;
END TRY
BEGIN CATCH
    PRINT 'FALLO R6: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '--- R7 Resultados (comp.usp_Reporte_Resultados) ---';
BEGIN TRY
    EXEC comp.usp_Reporte_Resultados @anio = 2026;
END TRY
BEGIN CATCH
    PRINT 'FALLO R7: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '=== FIN E7: en la pestana Messages no tiene que aparecer ningun "FALLO". ===';
GO

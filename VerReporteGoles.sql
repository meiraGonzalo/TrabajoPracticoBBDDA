/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 7 - Ejecucion de reportes
 Grupo 02 - Comision 02-5600
 Objetivo: ver lo que devuelven los reportes
=====================================================================
*/

USE MundialDB;
GO

-- Goleadores--
EXEC disc.usp_Reporte_Goleadores 2026;                      -- todo el torneo
EXEC disc.usp_Reporte_Goleadores 2026, 'Argentina';         -- solo Argentina
EXEC disc.usp_Reporte_Goleadores 2026, 'Argentina', 'Cuartos';

-- Error de validacion
EXEC disc.usp_Reporte_Goleadores 1900, 'Atlantida', 'Cuartitos';


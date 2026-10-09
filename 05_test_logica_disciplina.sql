/*
=====================================================================
 Entrega 5 - Testing de la LOGICA de Disciplina (1:1 con el script 03)
 Grupo 02 - Comision 02-5600 
 Integrante: Miro, Saba.
 Objetivo: testear los SP de logica del modulo disciplina.
=====================================================================
*/
USE MundialDB;
GO
SET NOCOUNT ON;
PRINT '=== TEST LOGICA DISCIPLINA ===';

DECLARE @id_tarjeta int, @id_convocado int;

/* -------- CASO 1 (EXITOSO): la amarilla que COMPLETA el umbral -> suspende -------- */
;WITH am AS (
    SELECT t.id_tarjeta, a.id_convocado, s.id_torneo,
           ROW_NUMBER() OVER (PARTITION BY a.id_convocado
                              ORDER BY p.fecha_hora_utc, t.minuto, t.id_tarjeta) AS nro
    FROM disc.Tarjeta t
    JOIN comp.Alineacion a        ON a.id_alineacion = t.id_alineacion
    JOIN comp.PartidoSeleccion ps ON ps.id_partido_seleccion = a.id_partido_seleccion
    JOIN comp.Partido p           ON p.id_partido = ps.id_partido
    JOIN comp.Convocado c         ON c.id_convocado = a.id_convocado
    JOIN comp.Seleccion s         ON s.id_seleccion = c.id_seleccion
    WHERE t.tipo_tarjeta = 'Amarilla'
)
SELECT TOP 1 @id_tarjeta = am.id_tarjeta, @id_convocado = am.id_convocado
FROM am
JOIN comp.ParametroReglamento pr ON pr.id_torneo = am.id_torneo AND pr.clave = 'AMARILLAS_SUSPENSION'
WHERE am.nro % pr.valor = 0        -- tarjeta numero umbral, 2*umbral, ... (completa el multiplo)
ORDER BY am.id_tarjeta;

IF @id_tarjeta IS NULL
    PRINT 'CASO 1: sin datos (nadie completo el umbral de amarillas).';
ELSE
BEGIN
    EXEC disc.usp_Suspension_CalcularPorTarjeta @id_tarjeta;
    SELECT 'CASO 1 - suspension generada (esperado: 1 PENDIENTE)' AS caso, *
    FROM disc.Suspension WHERE id_tarjeta_origen = @id_tarjeta;

    /* -------- CASO 2 (NO DUPLICA): vuelvo a llamar con la misma tarjeta -------- */
    EXEC disc.usp_Suspension_CalcularPorTarjeta @id_tarjeta;
    SELECT 'CASO 2 - no duplica (esperado: 1)' AS caso, COUNT(*) AS cantidad
    FROM disc.Suspension WHERE id_tarjeta_origen = @id_tarjeta;
END

/* -------- CASO 3 (NO CORRESPONDE): una amarilla que NO completa el umbral -------- */
DECLARE @id_tarjeta_sin int;
;WITH am AS (
    SELECT t.id_tarjeta, a.id_convocado, s.id_torneo,
           ROW_NUMBER() OVER (PARTITION BY a.id_convocado
                              ORDER BY p.fecha_hora_utc, t.minuto, t.id_tarjeta) AS nro
    FROM disc.Tarjeta t
    JOIN comp.Alineacion a        ON a.id_alineacion = t.id_alineacion
    JOIN comp.PartidoSeleccion ps ON ps.id_partido_seleccion = a.id_partido_seleccion
    JOIN comp.Partido p           ON p.id_partido = ps.id_partido
    JOIN comp.Convocado c         ON c.id_convocado = a.id_convocado
    JOIN comp.Seleccion s         ON s.id_seleccion = c.id_seleccion
    WHERE t.tipo_tarjeta = 'Amarilla'
)
SELECT TOP 1 @id_tarjeta_sin = am.id_tarjeta
FROM am
JOIN comp.ParametroReglamento pr ON pr.id_torneo = am.id_torneo AND pr.clave = 'AMARILLAS_SUSPENSION'
WHERE am.nro % pr.valor <> 0       -- no completa el multiplo
ORDER BY am.id_tarjeta;

IF @id_tarjeta_sin IS NULL
    PRINT 'CASO 3: sin datos (no hay amarillas que no completen el umbral).';
ELSE
BEGIN
    EXEC disc.usp_Suspension_CalcularPorTarjeta @id_tarjeta_sin;
    SELECT 'CASO 3 - no suspende (esperado: 0)' AS caso, COUNT(*) AS suspensiones
    FROM disc.Suspension WHERE id_tarjeta_origen = @id_tarjeta_sin;
END
GO
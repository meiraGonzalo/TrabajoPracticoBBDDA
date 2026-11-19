/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Seed (Criterios de aceptacion, seccion IV) - Script 10: Datos de Disciplina y Arbitros
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 2026-11-19
 Objetivo: cargar, solo con los SP de la Entrega 5 (ningun INSERT directo), los datos de disciplina
           que exige la seccion IV:
             PARTE 1 (este bloque): "asignacion completa en cada partido": los 5 roles (principal,
                     asistente 1, asistente 2, cuarto arbitro y VAR) de los 104 partidos del torneo 2026,
                     con los arbitros importados, respetando el conflicto de nacionalidad.
             Las partes siguientes (conflicto de nacionalidad rechazado, expulsiones y suspendido)
             se agregan a continuacion.
 Se puede ejecutar varias veces: no repite una designacion que ya existe.
 Orden:    00 -> 01 -> 02 -> 03 (todos) -> importaciones (partidos, arbitros) -> este script
=====================================================================
*/
USE MundialDB;
GO
SET NOCOUNT ON;

/* =================================================================
   PARTE 1: designaciones completas de todos los partidos
   Cada partido recibe 5 arbitros distintos, tomados en rotacion de los arbitros importados,
   salteando a los que son del pais de alguna de las dos selecciones que juegan.
   ================================================================= */
DECLARE @anio smallint = 2026;
DECLARE @id_torneo int = (SELECT id_torneo FROM comp.Torneo WHERE anio = @anio);
DECLARE @fecha date = '2026-06-01';          -- fecha de designacion (anterior al inicio del torneo)

-- Controles previos: si falta algo, se corta con un mensaje claro
IF @id_torneo IS NULL
    THROW 50920, 'Seed de disciplina: no existe el torneo 2026. Ejecutar antes las importaciones.', 1;
IF (SELECT COUNT(*) FROM disc.Arbitro) < 15
    THROW 50921, 'Seed de disciplina: hacen falta al menos 15 arbitros. Ejecutar antes la importacion de arbitros.', 1;

-- Arbitros disponibles, numerados para poder rotar entre ellos
IF OBJECT_ID('tempdb..#arb') IS NOT NULL DROP TABLE #arb;
SELECT ROW_NUMBER() OVER (ORDER BY a.id_arbitro) AS n, a.id_arbitro, pe.id_pais_nacionalidad AS id_pais
INTO #arb
FROM disc.Arbitro a
JOIN comp.Persona pe ON pe.id_persona = a.id_arbitro;

-- Partidos del torneo con el pais de cada seleccion
IF OBJECT_ID('tempdb..#partidos') IS NOT NULL DROP TABLE #partidos;
SELECT ROW_NUMBER() OVER (ORDER BY p.nro_partido) AS n, p.id_partido, p.nro_partido,
       sl.id_pais AS pais_local, sv.id_pais AS pais_visitante
INTO #partidos
FROM comp.Partido p
JOIN comp.PartidoSeleccion psl ON psl.id_partido = p.id_partido AND psl.condicion = 'L'
JOIN comp.Seleccion sl         ON sl.id_seleccion = psl.id_seleccion
JOIN comp.PartidoSeleccion psv ON psv.id_partido = p.id_partido AND psv.condicion = 'V'
JOIN comp.Seleccion sv         ON sv.id_seleccion = psv.id_seleccion
WHERE p.id_torneo = @id_torneo;

DECLARE @n_arb int = (SELECT COUNT(*) FROM #arb);
DECLARE @max_partidos int = (SELECT ISNULL(MAX(n), 0) FROM #partidos);
DECLARE @i int = 1, @j int, @intentos int, @ptr int = 0;
DECLARE @id_partido int, @pais_local int, @pais_visitante int, @nro_partido smallint;
DECLARE @rol varchar(20), @id_arbitro int, @candidato int, @pais_candidato int;
DECLARE @creadas int = 0, @ya_existian int = 0, @sin_arbitro int = 0, @fallidas int = 0;

WHILE @i <= @max_partidos
BEGIN
    SELECT @id_partido = id_partido, @nro_partido = nro_partido,
           @pais_local = pais_local, @pais_visitante = pais_visitante
    FROM #partidos WHERE n = @i;

    SET @j = 1;
    WHILE @j <= 5
    BEGIN
        SET @rol = CASE @j WHEN 1 THEN 'Principal'
                           WHEN 2 THEN 'Asistente 1'
                           WHEN 3 THEN 'Asistente 2'
                           WHEN 4 THEN 'Cuarto Arbitro'
                           ELSE 'VAR' END;

        IF EXISTS (SELECT 1 FROM disc.Designacion WHERE id_partido = @id_partido AND rol = @rol)
            SET @ya_existian += 1;
        ELSE
        BEGIN
            -- siguiente arbitro de la rotacion que no sea de ninguno de los dos paises y no este ya en el partido
            SET @id_arbitro = NULL;
            SET @intentos = 0;
            WHILE @id_arbitro IS NULL AND @intentos < @n_arb
            BEGIN
                SET @ptr = (@ptr % @n_arb) + 1;
                SELECT @candidato = id_arbitro, @pais_candidato = id_pais FROM #arb WHERE n = @ptr;

                IF @pais_candidato NOT IN (@pais_local, @pais_visitante)
                   AND NOT EXISTS (SELECT 1 FROM disc.Designacion
                                   WHERE id_partido = @id_partido AND id_arbitro = @candidato)
                    SET @id_arbitro = @candidato;

                SET @intentos += 1;
            END

            IF @id_arbitro IS NULL
            BEGIN
                SET @sin_arbitro += 1;
                PRINT CONCAT('Partido ', @nro_partido, ' (', @rol, '): no hay arbitro disponible sin conflicto de nacionalidad.');
            END
            ELSE
            BEGIN
                BEGIN TRY
                    EXEC disc.usp_Designacion_Registrar @id_partido, @id_arbitro, @rol, @fecha;
                    SET @creadas += 1;
                END TRY
                BEGIN CATCH
                    SET @fallidas += 1;
                    PRINT CONCAT('Partido ', @nro_partido, ' (', @rol, '): ', ERROR_MESSAGE());
                END CATCH;
            END
        END

        SET @j += 1;
    END

    SET @i += 1;
END

SELECT @max_partidos AS partidos, @creadas AS designaciones_creadas, @ya_existian AS ya_existian,
       @sin_arbitro AS sin_arbitro_disponible, @fallidas AS fallidas;
GO

/* ---------- Verificacion de la parte 1 ---------- */
SELECT 'partidos del torneo 2026' AS control, COUNT(*) AS cantidad
FROM comp.Partido p JOIN comp.Torneo t ON t.id_torneo = p.id_torneo AND t.anio = 2026
UNION ALL
SELECT 'partidos con las 5 designaciones', COUNT(*)
FROM (SELECT d.id_partido
      FROM disc.Designacion d
      JOIN comp.Partido p ON p.id_partido = d.id_partido
      JOIN comp.Torneo t  ON t.id_torneo = p.id_torneo AND t.anio = 2026
      GROUP BY d.id_partido
      HAVING COUNT(*) = 5 AND COUNT(DISTINCT d.rol) = 5) x
UNION ALL
SELECT 'designaciones con conflicto de nacionalidad', COUNT(*)
FROM disc.Designacion d
JOIN comp.Partido p            ON p.id_partido = d.id_partido
JOIN comp.Torneo t             ON t.id_torneo = p.id_torneo AND t.anio = 2026
JOIN comp.PartidoSeleccion ps  ON ps.id_partido = p.id_partido
JOIN comp.Seleccion s          ON s.id_seleccion = ps.id_seleccion
JOIN comp.Persona pe           ON pe.id_persona = d.id_arbitro AND pe.id_pais_nacionalidad = s.id_pais
UNION ALL
SELECT 'designaciones con advertencia de cruce', COUNT(*)
FROM disc.Designacion d
JOIN comp.Partido p ON p.id_partido = d.id_partido
JOIN comp.Torneo t  ON t.id_torneo = p.id_torneo AND t.anio = 2026
WHERE d.advertencia IS NOT NULL;
/* Esperado con los 104 partidos del 2026 importados:
     partidos del torneo 2026                      104
     partidos con las 5 designaciones              104   (520 designaciones en total)
     designaciones con conflicto de nacionalidad     0
     designaciones con advertencia de cruce         lo que de la regla (solo en eliminatorias con la seleccion del pais del arbitro todavia en carrera)
*/
GO

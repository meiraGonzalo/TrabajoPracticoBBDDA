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
             PARTE 1: "asignacion completa en cada partido": los 5 roles (principal, asistente 1,
                      asistente 2, cuarto arbitro y VAR) de los 104 partidos del torneo 2026, con los
                      arbitros importados, respetando el conflicto de nacionalidad.
             PARTE 2: una designacion rechazada por conflicto de nacionalidad.
             PARTE 3: una expulsion por doble amonestacion, una roja directa en otro partido y un
                      jugador suspendido por acumulacion de amarillas que no puede ser alineado en el
                      partido siguiente.
 Se puede ejecutar varias veces: no repite designaciones ni vuelve a cargar las tarjetas de la parte 3.
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


/* =================================================================
   PARTE 2: designacion rechazada por conflicto de nacionalidad (caso obligatorio)
   Se busca un partido y un arbitro cuyo pais coincide con el de una de las selecciones que lo juegan,
   y se intenta designarlo. El ABM tiene que rechazarlo y el partido sigue con sus 5 designaciones.
   (Como la parte 1 ya completo los roles, el mensaje agrupa tambien el rol repetido: lo que interesa
   es la linea de "Conflicto de nacionalidad".)
   ================================================================= */
DECLARE @anio smallint = 2026;
DECLARE @id_torneo int = (SELECT id_torneo FROM comp.Torneo WHERE anio = @anio);
DECLARE @fecha date = '2026-06-01';
DECLARE @id_partido int, @nro_partido smallint, @id_arbitro int, @pais varchar(100);

IF @id_torneo IS NULL
    THROW 50924, 'Seed de disciplina: no existe el torneo 2026. Ejecutar antes las importaciones.', 1;

SELECT TOP 1 @id_partido = p.id_partido, @nro_partido = p.nro_partido,
             @id_arbitro = a.id_arbitro, @pais = pa.nombre
FROM comp.Partido p
JOIN comp.PartidoSeleccion ps ON ps.id_partido = p.id_partido
JOIN comp.Seleccion s         ON s.id_seleccion = ps.id_seleccion
JOIN cat.Pais pa              ON pa.id_pais = s.id_pais
JOIN comp.Persona pe          ON pe.id_pais_nacionalidad = s.id_pais
JOIN disc.Arbitro a           ON a.id_arbitro = pe.id_persona
WHERE p.id_torneo = @id_torneo
ORDER BY p.nro_partido, a.id_arbitro;

IF @id_partido IS NULL
    PRINT 'Parte 2: no hay ningun arbitro del pais de una seleccion; no se puede mostrar el conflicto de nacionalidad.';
ELSE
BEGIN
    SELECT 'ANTES' AS momento, @nro_partido AS partido, @pais AS pais_del_arbitro,
           (SELECT COUNT(*) FROM disc.Designacion WHERE id_partido = @id_partido) AS designaciones_del_partido;

    BEGIN TRY
        EXEC disc.usp_Designacion_Registrar @id_partido, @id_arbitro, 'Principal', @fecha;
        PRINT 'ATENCION: la designacion no fue rechazada.';
    END TRY
    BEGIN CATCH
        IF ERROR_MESSAGE() LIKE '%Conflicto de nacionalidad%'
            PRINT 'OK, designacion rechazada por conflicto de nacionalidad: ' + ERROR_MESSAGE();
        ELSE
            PRINT 'ATENCION: rechazada por otro motivo: ' + ERROR_MESSAGE();
    END CATCH;

    SELECT 'DESPUES' AS momento, @nro_partido AS partido, @pais AS pais_del_arbitro,
           (SELECT COUNT(*) FROM disc.Designacion WHERE id_partido = @id_partido) AS designaciones_del_partido;
    -- Esperado: designaciones_del_partido = 5 antes y despues (no se agrego nada)
END
GO


/* =================================================================
   PARTE 3: expulsiones y jugador suspendido (casos obligatorios)
   Se elige por codigo una seleccion con al menos 3 partidos y 3 convocados; sus tres primeros
   partidos (por fecha) son M1, M2 y M3 y sus tres primeros convocados (por dorsal) J1, J2 y J3:
     J1: doble amarilla en M1 (roja automatica)            -> suspendido para M2
     J2: roja directa en M2 (otro partido)                 -> suspendido para M3
     J3: amarilla en M1 y amarilla en M2 (acumulacion)     -> suspendido para M3: no se lo puede alinear
   Todo con disc.usp_Tarjeta_Registrar, que genera la roja por doble amarilla y las suspensiones.
   ================================================================= */
DECLARE @anio smallint = 2026;
DECLARE @id_torneo int = (SELECT id_torneo FROM comp.Torneo WHERE anio = @anio);
DECLARE @pt  int = (SELECT id_periodo  FROM comp.Periodo  WHERE nombre = 'Primer tiempo');
DECLARE @st  int = (SELECT id_periodo  FROM comp.Periodo  WHERE nombre = 'Segundo tiempo');
DECLARE @pos int = (SELECT id_posicion FROM comp.Posicion WHERE nombre = 'Delantero');

IF @id_torneo IS NULL OR @pt IS NULL OR @st IS NULL OR @pos IS NULL
    THROW 50922, 'Seed de disciplina: faltan el torneo 2026, los periodos (Primer/Segundo tiempo) o la posicion Delantero.', 1;

-- Seleccion con al menos 3 partidos y 3 convocados
DECLARE @id_sel int =
   (SELECT TOP 1 s.id_seleccion
    FROM comp.Seleccion s
    WHERE s.id_torneo = @id_torneo
      AND (SELECT COUNT(*) FROM comp.PartidoSeleccion ps WHERE ps.id_seleccion = s.id_seleccion) >= 3
      AND (SELECT COUNT(*) FROM comp.Convocado c WHERE c.id_seleccion = s.id_seleccion AND c.fecha_baja IS NULL) >= 3
    ORDER BY s.id_seleccion);
IF @id_sel IS NULL
    THROW 50923, 'Seed de disciplina: no hay una seleccion con 3 partidos y 3 convocados. Ejecutar antes las importaciones de partidos y plantillas.', 1;

-- Sus tres primeros partidos y su participacion en cada uno
DECLARE @ps1 int, @ps2 int, @ps3 int;
SELECT @ps1 = MAX(CASE WHEN r = 1 THEN id_partido_seleccion END),
       @ps2 = MAX(CASE WHEN r = 2 THEN id_partido_seleccion END),
       @ps3 = MAX(CASE WHEN r = 3 THEN id_partido_seleccion END)
FROM (SELECT ps.id_partido_seleccion,
             ROW_NUMBER() OVER (ORDER BY p.fecha_hora_utc, p.nro_partido) AS r
      FROM comp.PartidoSeleccion ps
      JOIN comp.Partido p ON p.id_partido = ps.id_partido
      WHERE p.id_torneo = @id_torneo AND ps.id_seleccion = @id_sel) x
WHERE r <= 3;

-- Sus tres primeros convocados
DECLARE @j1 int, @j2 int, @j3 int;
SELECT @j1 = MAX(CASE WHEN r = 1 THEN id_convocado END),
       @j2 = MAX(CASE WHEN r = 2 THEN id_convocado END),
       @j3 = MAX(CASE WHEN r = 3 THEN id_convocado END)
FROM (SELECT c.id_convocado, ROW_NUMBER() OVER (ORDER BY c.dorsal, c.id_convocado) AS r
      FROM comp.Convocado c
      WHERE c.id_seleccion = @id_sel AND c.fecha_baja IS NULL) y
WHERE r <= 3;

-- Alineaciones que hacen falta (si ya existen no se repiten; si no hay lugar de titular, quedan en el banco)
IF OBJECT_ID('tempdb..#al') IS NOT NULL DROP TABLE #al;
CREATE TABLE #al (n int IDENTITY(1,1), id_convocado int, id_ps int);
INSERT INTO #al (id_convocado, id_ps) VALUES (@j1, @ps1), (@j2, @ps2), (@j3, @ps1), (@j3, @ps2);

DECLARE @i int = 1, @c int, @ps int;
WHILE @i <= 4
BEGIN
    SELECT @c = id_convocado, @ps = id_ps FROM #al WHERE n = @i;
    IF NOT EXISTS (SELECT 1 FROM comp.Alineacion WHERE id_partido_seleccion = @ps AND id_convocado = @c)
    BEGIN
        BEGIN TRY
            EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @pos;
        END TRY
        BEGIN CATCH
            EXEC comp.usp_Alineacion_Alta @ps, @c, 0, NULL;
        END CATCH;
    END
    SET @i += 1;
END

DECLARE @a1   int = (SELECT id_alineacion FROM comp.Alineacion WHERE id_partido_seleccion = @ps1 AND id_convocado = @j1);
DECLARE @a2   int = (SELECT id_alineacion FROM comp.Alineacion WHERE id_partido_seleccion = @ps2 AND id_convocado = @j2);
DECLARE @a3m1 int = (SELECT id_alineacion FROM comp.Alineacion WHERE id_partido_seleccion = @ps1 AND id_convocado = @j3);
DECLARE @a3m2 int = (SELECT id_alineacion FROM comp.Alineacion WHERE id_partido_seleccion = @ps2 AND id_convocado = @j3);

IF EXISTS (SELECT 1 FROM disc.Tarjeta WHERE id_alineacion = @a1)
    PRINT 'Parte 3: las tarjetas ya estaban cargadas; no se repite.';
ELSE
BEGIN
    -- J1: doble amarilla en M1 (la segunda genera sola la roja por doble amarilla)
    EXEC disc.usp_Tarjeta_Registrar @a1,   'Amarilla',     'Falta tactica',    @pt, 20;
    EXEC disc.usp_Tarjeta_Registrar @a1,   'Amarilla',     'Falta por detras', @st, 70;
    -- J2: roja directa en M2
    EXEC disc.usp_Tarjeta_Registrar @a2,   'Roja directa', 'Agresion',         @st, 55;
    -- J3: amarillas en dos partidos distintos (acumulacion)
    EXEC disc.usp_Tarjeta_Registrar @a3m1, 'Amarilla',     'Juego brusco',     @pt, 35;
    EXEC disc.usp_Tarjeta_Registrar @a3m2, 'Amarilla',     'Protesta',         @st, 60;
END

-- Resultado: tarjetas y suspensiones de los tres jugadores
SELECT pa.nombre AS seleccion, pe.apellido, pe.nombre, po.nro_partido AS partido, t.tipo_tarjeta, t.minuto
FROM disc.Tarjeta t
JOIN comp.Alineacion a         ON a.id_alineacion = t.id_alineacion
JOIN comp.PartidoSeleccion ps  ON ps.id_partido_seleccion = a.id_partido_seleccion
JOIN comp.Partido po           ON po.id_partido = ps.id_partido
JOIN comp.Convocado c          ON c.id_convocado = a.id_convocado
JOIN comp.Persona pe           ON pe.id_persona = c.id_jugador
JOIN comp.Seleccion s          ON s.id_seleccion = c.id_seleccion
JOIN cat.Pais pa               ON pa.id_pais = s.id_pais
WHERE a.id_convocado IN (@j1, @j2, @j3)
ORDER BY pe.apellido, po.nro_partido, t.id_tarjeta;

SELECT pe.apellido, pe.nombre, su.estado,
       CASE t.tipo_tarjeta WHEN 'Amarilla' THEN 'Acumulacion de amarillas'
                           WHEN 'Roja directa' THEN 'Roja directa'
                           ELSE 'Roja por doble amarilla' END AS motivo,
       pc.nro_partido AS cumple_en_partido
FROM disc.Suspension su
JOIN disc.Tarjeta t   ON t.id_tarjeta = su.id_tarjeta_origen
JOIN comp.Convocado c ON c.id_convocado = su.id_convocado
JOIN comp.Persona pe  ON pe.id_persona = c.id_jugador
LEFT JOIN comp.Partido pc ON pc.id_partido = su.id_partido_cumple
WHERE su.id_convocado IN (@j1, @j2, @j3)
ORDER BY pe.apellido, su.id_suspension;

-- El suspendido por acumulacion (J3) no puede ser alineado en el partido siguiente (M3)
SELECT 'ANTES' AS momento, COUNT(*) AS alineaciones_del_jugador_en_M3
FROM comp.Alineacion WHERE id_partido_seleccion = @ps3 AND id_convocado = @j3;

BEGIN TRY
    EXEC comp.usp_Alineacion_Alta @ps3, @j3, 1, @pos;
    PRINT 'ATENCION: se pudo alinear a un jugador suspendido.';
END TRY
BEGIN CATCH
    PRINT 'OK, el suspendido quedo afuera de la formacion: ' + ERROR_MESSAGE();
END CATCH;

SELECT 'DESPUES' AS momento, COUNT(*) AS alineaciones_del_jugador_en_M3
FROM comp.Alineacion WHERE id_partido_seleccion = @ps3 AND id_convocado = @j3;
/* Esperado (base nueva con las importaciones hechas):
   tarjetas:     J1: Amarilla (20), Amarilla (70) y Roja por doble amarilla (70) en M1
                 J2: Roja directa (55) en M2
                 J3: Amarilla (35) en M1 y Amarilla (60) en M2
   suspensiones: J1 PENDIENTE por doble amarilla, cumple en M2 | J2 PENDIENTE por roja directa, cumple en M3
                 J3 PENDIENTE por acumulacion de amarillas, cumple en M3
   alineacion:   J3 en M3: 0 antes y 0 despues (rechazado por suspension) */
GO

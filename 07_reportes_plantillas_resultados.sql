/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 7 - Reportes de plantillas y resultados
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 19/11/2026
 Objetivo: reporte
   R6  comp.usp_Reporte_Plantillas_XML      @anio, @seleccion          (XML)
   R7  comp.usp_Reporte_Resultados          @anio, @fase, @seleccion
 
   - Si un parametro esta mal se juntan todos los problemas en un
     mensaje y se lanza THROW 5100N (R1 = 51001 ... R7 = 51007).
 Orden: 00 -> 01 -> 02 -> 03 -> 06 (importaciones) -> este script
=====================================================================
*/

USE MundialDB;
GO

/* =====================================================================
   R6. comp.usp_Reporte_Plantillas_XML 
   Cada seleccion del torneo con su cuerpo tecnico y el vector anidado de
   convocados activos (dorsal, nombre, posicion, fecha de nacimiento,
   club)
   ===================================================================== */
CREATE OR ALTER PROCEDURE comp.usp_Reporte_Plantillas_XML
    @anio      smallint,
    @seleccion varchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @err nvarchar(2000), @id_torneo int, @id_seleccion int;
    SET @err = '';

    SELECT @id_torneo = id_torneo FROM comp.Torneo WHERE anio = @anio;
    IF @id_torneo IS NULL
        SET @err = @err + ' - No existe el torneo del año ' + ISNULL(CAST(@anio AS varchar(4)), 'vacio') + '.';

    IF @seleccion IS NOT NULL
    BEGIN
        SELECT @id_seleccion = s.id_seleccion
        FROM comp.Seleccion s
        JOIN cat.Pais pa ON pa.id_pais = s.id_pais
        WHERE s.id_torneo = @id_torneo AND pa.nombre = @seleccion;
        IF @id_seleccion IS NULL
            SET @err = @err + ' - La seleccion ' + @seleccion + ' no participa del torneo.';
    END

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Reporte_Plantillas_XML:' + @err;
        THROW 51006, @err, 1;
    END

    SELECT (
        SELECT pa.nombre        AS '@nombre',
               pa.confederacion AS '@confederacion',
               g.letra          AS '@grupo',
               (SELECT COUNT(*) FROM comp.Convocado cc
                WHERE cc.id_seleccion = s.id_seleccion AND cc.fecha_baja IS NULL) AS '@convocados',
               (   -- Cuerpo tecnico
                   SELECT ct.rol AS '@rol', pe.apellido AS '@apellido', pe.nombre AS '@nombre'
                   FROM comp.CuerpoTecnico ct
                   JOIN comp.Persona pe ON pe.id_persona = ct.id_persona
                   WHERE ct.id_seleccion = s.id_seleccion
                   ORDER BY ct.rol, pe.apellido
                   FOR XML PATH('Miembro'), TYPE
               ) AS 'CuerpoTecnico',
               (   -- Convocados activos (vector anidado)
                   SELECT c.dorsal     AS '@dorsal',
                          pe.apellido  AS '@apellido',
                          pe.nombre    AS '@nombre',
                          po.nombre    AS '@posicion',
                          CONVERT(varchar(10), pe.fecha_nacimiento, 23) AS '@fecha_nacimiento',
                          cl.nombre    AS '@club',
                          pc.nombre    AS '@pais_club'
                   FROM comp.Convocado c
                   JOIN comp.Jugador j   ON j.id_jugador = c.id_jugador
                   JOIN comp.Persona pe  ON pe.id_persona = j.id_jugador
                   JOIN comp.Posicion po ON po.id_posicion = j.id_posicion_habitual
                   LEFT JOIN comp.Club cl ON cl.id_club = c.id_club
                   LEFT JOIN cat.Pais pc  ON pc.id_pais = cl.id_pais
                   WHERE c.id_seleccion = s.id_seleccion AND c.fecha_baja IS NULL
                   ORDER BY c.dorsal
                   FOR XML PATH('Convocado'), TYPE
               ) AS 'Convocados'
        FROM comp.Seleccion s
        JOIN cat.Pais pa      ON pa.id_pais = s.id_pais
        LEFT JOIN comp.Grupo g ON g.id_grupo = s.id_grupo
        WHERE s.id_torneo = @id_torneo
          AND (@id_seleccion IS NULL OR s.id_seleccion = @id_seleccion)
        ORDER BY g.letra, pa.nombre
        FOR XML PATH('Seleccion'), ROOT('Plantillas'), TYPE
    ) AS plantillas_xml;
END
GO


/* =====================================================================
   R7. comp.usp_Reporte_Resultados
   Tabla 1: partidos con resultado, penales y ganador (los no jugados
            aparecen sin resultado; si el rival no esta definido, 'A definir').
   Tabla 2: tabla de posiciones de cada grupo (solo si no se pidio una
            fase eliminatoria). Puntos: 3 por partido ganado, 1 por empate.
            Orden: puntos, diferencia de gol, goles a favor.
            Con @seleccion se muestra solo el grupo de esa seleccion.
   ===================================================================== */
CREATE OR ALTER PROCEDURE comp.usp_Reporte_Resultados
    @anio      smallint,
    @fase      varchar(30)  = NULL,
    @seleccion varchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @err nvarchar(2000), @id_torneo int, @id_fase int, @id_seleccion int;
    DECLARE @fase_eliminatoria bit;
    SET @err = '';

    SELECT @id_torneo = id_torneo FROM comp.Torneo WHERE anio = @anio;
    IF @id_torneo IS NULL
        SET @err = @err + ' - No existe el torneo del año ' + ISNULL(CAST(@anio AS varchar(4)), 'vacio') + '.';

    IF @fase IS NOT NULL
    BEGIN
        SELECT @id_fase = id_fase, @fase_eliminatoria = es_eliminatoria FROM comp.Fase WHERE nombre = @fase;
        IF @id_fase IS NULL
            SET @err = @err + ' - No existe la fase ' + @fase + '.';
    END

    IF @seleccion IS NOT NULL
    BEGIN
        SELECT @id_seleccion = s.id_seleccion
        FROM comp.Seleccion s
        JOIN cat.Pais pa ON pa.id_pais = s.id_pais
        WHERE s.id_torneo = @id_torneo AND pa.nombre = @seleccion;
        IF @id_seleccion IS NULL
            SET @err = @err + ' - La seleccion ' + @seleccion + ' no participa del torneo.';
    END

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Reporte_Resultados:' + @err;
        THROW 51007, @err, 1;
    END

    -- Tabla 1: resultados
    SELECT p.nro_partido,
           f.nombre AS fase,
           g.letra  AS grupo,
           p.fecha_hora_local,
           se.nombre_estadio AS sede,
           ci.nombre AS ciudad,
           ISNULL(pal.nombre, 'A definir') AS local,
           ISNULL(pav.nombre, 'A definir') AS visitante,
           CASE WHEN psl.goles IS NULL OR psv.goles IS NULL THEN NULL
                ELSE CAST(psl.goles AS varchar(3)) + '-' + CAST(psv.goles AS varchar(3))
                     + CASE WHEN psl.goles_penales IS NOT NULL
                            THEN ' (pen. ' + CAST(psl.goles_penales AS varchar(3)) + '-'
                                 + CAST(psv.goles_penales AS varchar(3)) + ')'
                            ELSE '' END
           END AS resultado,
           CASE WHEN psl.goles IS NULL OR psv.goles IS NULL THEN NULL
                WHEN psl.goles > psv.goles THEN pal.nombre
                WHEN psv.goles > psl.goles THEN pav.nombre
                WHEN psl.goles_penales > psv.goles_penales THEN pal.nombre
                WHEN psv.goles_penales > psl.goles_penales THEN pav.nombre
                ELSE 'Empate'
           END AS ganador,
           p.asistencia,
           p.estado
    FROM comp.Partido p
    JOIN comp.Fase f        ON f.id_fase = p.id_fase
    LEFT JOIN comp.Grupo g  ON g.id_grupo = p.id_grupo
    JOIN comp.Sede se       ON se.id_sede = p.id_sede
    JOIN cat.Ciudad ci      ON ci.id_ciudad = se.id_ciudad
    LEFT JOIN comp.PartidoSeleccion psl ON psl.id_partido = p.id_partido AND psl.condicion = 'L'
    LEFT JOIN comp.Seleccion sl         ON sl.id_seleccion = psl.id_seleccion
    LEFT JOIN cat.Pais pal              ON pal.id_pais = sl.id_pais
    LEFT JOIN comp.PartidoSeleccion psv ON psv.id_partido = p.id_partido AND psv.condicion = 'V'
    LEFT JOIN comp.Seleccion sv         ON sv.id_seleccion = psv.id_seleccion
    LEFT JOIN cat.Pais pav              ON pav.id_pais = sv.id_pais
    WHERE p.id_torneo = @id_torneo
      AND (@id_fase IS NULL OR p.id_fase = @id_fase)
      AND (@id_seleccion IS NULL OR psl.id_seleccion = @id_seleccion OR psv.id_seleccion = @id_seleccion)
    ORDER BY f.orden, p.nro_partido;

    -- Tabla 2: posiciones (no tiene sentido si se pidio una fase eliminatoria)
    IF @fase_eliminatoria = 1
        RETURN;

    -- Paso 1: cada partido de grupos jugado, una fila por seleccion (goles a favor y en contra)
    SELECT ps.id_seleccion, ps.goles AS gf, rival.goles AS gc
    INTO #jugados
    FROM comp.Partido p
    JOIN comp.Fase f              ON f.id_fase = p.id_fase AND f.es_eliminatoria = 0
    JOIN comp.PartidoSeleccion ps ON ps.id_partido = p.id_partido
    JOIN comp.PartidoSeleccion rival ON rival.id_partido = p.id_partido
                                    AND rival.id_partido_seleccion <> ps.id_partido_seleccion
    WHERE p.id_torneo = @id_torneo AND ps.goles IS NOT NULL AND rival.goles IS NOT NULL;

    -- Paso 2: totales por seleccion 
    SELECT g.letra AS grupo, pa.nombre AS seleccion,
           COUNT(j.id_seleccion) AS pj,
           SUM(CASE WHEN j.gf > j.gc THEN 1 ELSE 0 END) AS pg,
           SUM(CASE WHEN j.gf = j.gc THEN 1 ELSE 0 END) AS pe,
           SUM(CASE WHEN j.gf < j.gc THEN 1 ELSE 0 END) AS pp,
           ISNULL(SUM(j.gf), 0) AS gf,
           ISNULL(SUM(j.gc), 0) AS gc
    INTO #tabla
    FROM comp.Seleccion s
    JOIN comp.Grupo g    ON g.id_grupo = s.id_grupo
    JOIN cat.Pais pa     ON pa.id_pais = s.id_pais
    LEFT JOIN #jugados j ON j.id_seleccion = s.id_seleccion
    WHERE s.id_torneo = @id_torneo
      AND (@id_seleccion IS NULL
           OR s.id_grupo = (SELECT id_grupo FROM comp.Seleccion WHERE id_seleccion = @id_seleccion))
    GROUP BY g.letra, pa.nombre;

    -- Paso 3: puesto dentro de cada grupo
    SELECT grupo,
           RANK() OVER (PARTITION BY grupo ORDER BY pg * 3 + pe DESC, gf - gc DESC, gf DESC) AS puesto,
           seleccion, pj, pg, pe, pp, gf, gc,
           gf - gc     AS dif,
           pg * 3 + pe AS puntos
    FROM #tabla
    ORDER BY grupo, puesto, seleccion;
END
GO

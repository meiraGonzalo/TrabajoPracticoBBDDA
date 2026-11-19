/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 7 - Script 07: Reportes de Disciplina y Arbitros
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 2026-11-19
 Objetivo: reportes del modulo disciplina.
             R2 = disc.usp_Reporte_Tarjetas: tarjetas por seleccion y por jugador, con el detalle
                  de las suspensiones activas (por acumulacion de amarillas o por expulsion).
             R3 = disc.usp_Reporte_Designaciones_XML: designaciones de cada arbitro (en XML), con
                  las amonestaciones y expulsiones que senalo como arbitro principal.
 Errores:  cada reporte valida sus parametros, junta todos los problemas en un solo mensaje
           y lanza THROW 5100N (R2 = 51002, R3 = 51003).
 Orden:    00 -> 01 -> 02 -> 03 -> datos cargados (importaciones, seed o el test de disciplina) -> este script
=====================================================================
*/
USE MundialDB;
GO

/* =====================================================================
   R2. disc.usp_Reporte_Tarjetas
   Parametros: @anio       anio del torneo (obligatorio)
               @seleccion  nombre del pais (opcional): limita el reporte a esa seleccion
   Devuelve tres tablas:
     1) tarjetas por seleccion (todas las selecciones del torneo, aunque no tengan tarjetas)
     2) tarjetas por jugador
     3) suspensiones activas (estado PENDIENTE) con su motivo y el partido en que se cumplen
   ===================================================================== */
CREATE OR ALTER PROCEDURE disc.usp_Reporte_Tarjetas
    @anio      smallint,
    @seleccion varchar(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @err nvarchar(2000) = '';
    DECLARE @id_torneo int, @id_seleccion int;

    -- Validaciones (todas en un unico mensaje)
    SELECT @id_torneo = id_torneo FROM comp.Torneo WHERE anio = @anio;
    IF @id_torneo IS NULL
        SET @err = @err + ' - No existe el torneo del anio ' + ISNULL(CAST(@anio AS varchar(4)), 'vacio') + '.';

    IF @seleccion IS NOT NULL AND @id_torneo IS NOT NULL
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
        SET @err = 'usp_Reporte_Tarjetas:' + @err;
        THROW 51002, @err, 1;
    END

    -- Base comun: todas las tarjetas del torneo con su seleccion.
    -- Una tarjeta es de un jugador (por su alineacion) o del cuerpo tecnico (por el partido-seleccion).
    SELECT t.id_tarjeta, t.tipo_tarjeta, a.id_convocado, t.id_cuerpo_tecnico,
           COALESCE(psa.id_seleccion, psc.id_seleccion) AS id_seleccion
    INTO #tj
    FROM disc.Tarjeta t
    LEFT JOIN comp.Alineacion a         ON a.id_alineacion = t.id_alineacion
    LEFT JOIN comp.PartidoSeleccion psa ON psa.id_partido_seleccion = a.id_partido_seleccion
    LEFT JOIN comp.PartidoSeleccion psc ON psc.id_partido_seleccion = t.id_partido_seleccion
    JOIN comp.Partido p                 ON p.id_partido = COALESCE(psa.id_partido, psc.id_partido)
    WHERE p.id_torneo = @id_torneo
      AND (@id_seleccion IS NULL OR COALESCE(psa.id_seleccion, psc.id_seleccion) = @id_seleccion);

    -- 1) Por seleccion
    SELECT pa.nombre AS seleccion,
           SUM(CASE WHEN x.tipo_tarjeta = 'Amarilla'                THEN 1 ELSE 0 END) AS amarillas,
           SUM(CASE WHEN x.tipo_tarjeta = 'Roja directa'            THEN 1 ELSE 0 END) AS rojas_directas,
           SUM(CASE WHEN x.tipo_tarjeta = 'Roja por doble amarilla' THEN 1 ELSE 0 END) AS rojas_doble_amarilla,
           COUNT(x.id_tarjeta) AS total,
           SUM(CASE WHEN x.id_cuerpo_tecnico IS NOT NULL THEN 1 ELSE 0 END) AS al_cuerpo_tecnico
    FROM comp.Seleccion s
    JOIN cat.Pais pa ON pa.id_pais = s.id_pais
    LEFT JOIN #tj x  ON x.id_seleccion = s.id_seleccion
    WHERE s.id_torneo = @id_torneo
      AND (@id_seleccion IS NULL OR s.id_seleccion = @id_seleccion)
    GROUP BY pa.nombre
    ORDER BY COUNT(x.id_tarjeta) DESC, pa.nombre;

    -- 2) Por jugador
    SELECT pa.nombre AS seleccion, c.dorsal, pe.apellido, pe.nombre,
           SUM(CASE WHEN x.tipo_tarjeta = 'Amarilla'                THEN 1 ELSE 0 END) AS amarillas,
           SUM(CASE WHEN x.tipo_tarjeta = 'Roja directa'            THEN 1 ELSE 0 END) AS rojas_directas,
           SUM(CASE WHEN x.tipo_tarjeta = 'Roja por doble amarilla' THEN 1 ELSE 0 END) AS rojas_doble_amarilla,
           COUNT(*) AS total
    FROM #tj x
    JOIN comp.Convocado c ON c.id_convocado = x.id_convocado
    JOIN comp.Persona pe  ON pe.id_persona  = c.id_jugador
    JOIN comp.Seleccion s ON s.id_seleccion = c.id_seleccion
    JOIN cat.Pais pa      ON pa.id_pais     = s.id_pais
    GROUP BY pa.nombre, c.dorsal, pe.apellido, pe.nombre
    ORDER BY COUNT(*) DESC, pa.nombre, pe.apellido;

    -- 3) Suspensiones activas de jugadores: motivo y partido en que se cumplen
    SELECT pa.nombre AS seleccion, c.dorsal, pe.apellido, pe.nombre,
           CASE t.tipo_tarjeta WHEN 'Amarilla'     THEN 'Acumulacion de amarillas'
                               WHEN 'Roja directa' THEN 'Roja directa'
                               ELSE 'Roja por doble amarilla' END AS motivo,
           po.nro_partido AS partido_de_la_tarjeta,
           pc.nro_partido AS cumple_en_partido,        -- NULL = todavia sin partido asignado
           su.estado
    FROM disc.Suspension su
    JOIN disc.Tarjeta t   ON t.id_tarjeta   = su.id_tarjeta_origen
    JOIN comp.Convocado c ON c.id_convocado = su.id_convocado
    JOIN comp.Persona pe  ON pe.id_persona  = c.id_jugador
    JOIN comp.Seleccion s ON s.id_seleccion = c.id_seleccion
    JOIN cat.Pais pa      ON pa.id_pais     = s.id_pais
    LEFT JOIN comp.Alineacion a         ON a.id_alineacion = t.id_alineacion
    LEFT JOIN comp.PartidoSeleccion psa ON psa.id_partido_seleccion = a.id_partido_seleccion
    LEFT JOIN comp.Partido po           ON po.id_partido = psa.id_partido
    LEFT JOIN comp.Partido pc           ON pc.id_partido = su.id_partido_cumple
    WHERE su.estado = 'PENDIENTE'
      AND s.id_torneo = @id_torneo
      AND (@id_seleccion IS NULL OR s.id_seleccion = @id_seleccion)
    ORDER BY pa.nombre, pe.apellido;
END
GO

/* =====================================================================
   Ejemplos de ejecucion. Sobre el torneo de prueba 2043, despues de correr completo el
   05_test_logica_disciplina.sql en una base nueva, tiene que dar:

   EXEC disc.usp_Reporte_Tarjetas @anio = 2043;
   -- Tabla 1 (por seleccion):   Argentina  6 amarillas, 0 rojas directas, 1 roja doble, total 7
   --                            Brasil     3 amarillas, 1 roja directa,   1 roja doble, total 5
   --                            Uruguay    1 amarilla,  0, 0,                           total 1
   -- Tabla 2 (por jugador):     BRA03 total 4 | ARG02 total 3 | ARG03 total 2 | ARG04 total 2 | BRA02 total 1 | URU03 total 1
   -- Tabla 3 (suspensiones):    4 filas PENDIENTE:
   --        Argentina 02  Roja por doble amarilla      cumple en el partido 2
   --        Argentina 03  Acumulacion de amarillas     cumple en el partido 4
   --        Brasil 02     Roja directa                 cumple en el partido 3
   --        Brasil 03     Roja por doble amarilla      cumple en el partido 4  (la de acumulacion quedo ANULADA y no se lista)

   EXEC disc.usp_Reporte_Tarjetas @anio = 2043, @seleccion = 'Argentina';   -- solo Argentina
   EXEC disc.usp_Reporte_Tarjetas @anio = 1900;                             -- error 51002: no existe el torneo
   EXEC disc.usp_Reporte_Tarjetas @anio = 2043, @seleccion = 'Peru';        -- error 51002: la seleccion no participa
   ===================================================================== */


/* =====================================================================
   R3. disc.usp_Reporte_Designaciones_XML
   Parametros: @anio      anio del torneo (obligatorio)
               @apellido  apellido de un arbitro (opcional): limita el reporte a ese arbitro
   Devuelve UN XML:
     <Designaciones torneo="...">
       <Arbitro apellido nombre pais categoria partidos amarillas rojas>   -- partidos = todas sus designaciones;
                                                                          -- amarillas/rojas = las que senalo como Principal
         <Partido nro fase fecha_local local visitante rol>
           <Tarjeta tipo minuto jugador seleccion/>                       -- solo si en ese partido fue Principal
   ===================================================================== */
CREATE OR ALTER PROCEDURE disc.usp_Reporte_Designaciones_XML
    @anio     smallint,
    @apellido varchar(80) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @err nvarchar(2000) = '';
    DECLARE @id_torneo int;

    -- Validaciones (todas en un unico mensaje)
    SELECT @id_torneo = id_torneo FROM comp.Torneo WHERE anio = @anio;
    IF @id_torneo IS NULL
        SET @err = @err + ' - No existe el torneo del anio ' + ISNULL(CAST(@anio AS varchar(4)), 'vacio') + '.';

    IF @apellido IS NOT NULL AND @id_torneo IS NOT NULL
       AND NOT EXISTS (SELECT 1
                       FROM disc.Designacion d
                       JOIN comp.Partido p  ON p.id_partido = d.id_partido
                       JOIN comp.Persona pe ON pe.id_persona = d.id_arbitro
                       WHERE p.id_torneo = @id_torneo AND pe.apellido = @apellido)
        SET @err = @err + ' - No hay designaciones del arbitro ' + @apellido + ' en ese torneo.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Reporte_Designaciones_XML:' + @err;
        THROW 51003, @err, 1;
    END

    -- Base: todas las tarjetas de los partidos del torneo, con el partido, el jugador y su seleccion
    SELECT COALESCE(psa.id_partido, psc.id_partido) AS id_partido,
           t.id_tarjeta, t.tipo_tarjeta, t.minuto, per.orden AS orden_periodo,
           ISNULL(pj.nombre + ' ' + pj.apellido, 'Cuerpo tecnico') AS jugador,
           pas.nombre AS seleccion
    INTO #tp
    FROM disc.Tarjeta t
    JOIN comp.Periodo per                ON per.id_periodo = t.id_periodo
    LEFT JOIN comp.Alineacion al         ON al.id_alineacion = t.id_alineacion
    LEFT JOIN comp.PartidoSeleccion psa  ON psa.id_partido_seleccion = al.id_partido_seleccion
    LEFT JOIN comp.PartidoSeleccion psc  ON psc.id_partido_seleccion = t.id_partido_seleccion
    JOIN comp.Partido p                  ON p.id_partido = COALESCE(psa.id_partido, psc.id_partido)
    LEFT JOIN comp.Convocado cv          ON cv.id_convocado = al.id_convocado
    LEFT JOIN comp.Persona pj            ON pj.id_persona = cv.id_jugador
    LEFT JOIN comp.Seleccion sj          ON sj.id_seleccion = COALESCE(psa.id_seleccion, psc.id_seleccion)
    LEFT JOIN cat.Pais pas               ON pas.id_pais = sj.id_pais
    WHERE p.id_torneo = @id_torneo;

    SELECT @anio AS '@torneo',
           (
               SELECT pe.apellido  AS '@apellido',
                      pe.nombre    AS '@nombre',
                      pa.nombre    AS '@pais',
                      a.categoria  AS '@categoria',
                      (SELECT COUNT(*)
                       FROM disc.Designacion d2
                       JOIN comp.Partido p2 ON p2.id_partido = d2.id_partido
                       WHERE d2.id_arbitro = a.id_arbitro AND p2.id_torneo = @id_torneo) AS '@partidos',
                      (SELECT COUNT(*)
                       FROM disc.Designacion dp JOIN #tp x ON x.id_partido = dp.id_partido
                       WHERE dp.id_arbitro = a.id_arbitro AND dp.rol = 'Principal'
                         AND x.tipo_tarjeta = 'Amarilla') AS '@amarillas',
                      (SELECT COUNT(*)
                       FROM disc.Designacion dp JOIN #tp x ON x.id_partido = dp.id_partido
                       WHERE dp.id_arbitro = a.id_arbitro AND dp.rol = 'Principal'
                         AND x.tipo_tarjeta IN ('Roja directa', 'Roja por doble amarilla')) AS '@rojas',
                      (
                          SELECT p.nro_partido AS '@nro',
                                 f.nombre      AS '@fase',
                                 CONVERT(varchar(16), p.fecha_hora_local, 120) AS '@fecha_local',
                                 pl.nombre     AS '@local',
                                 pv.nombre     AS '@visitante',
                                 d.rol         AS '@rol',
                                 (   -- las tarjetas se anexan solo cuando fue el arbitro principal
                                     SELECT tx.tipo_tarjeta AS '@tipo', tx.minuto AS '@minuto',
                                            tx.jugador AS '@jugador', tx.seleccion AS '@seleccion'
                                     FROM #tp tx
                                     WHERE tx.id_partido = p.id_partido AND d.rol = 'Principal'
                                     ORDER BY tx.orden_periodo, tx.minuto, tx.id_tarjeta
                                     FOR XML PATH('Tarjeta'), TYPE
                                 )
                          FROM disc.Designacion d
                          JOIN comp.Partido p  ON p.id_partido = d.id_partido
                          JOIN comp.Fase f     ON f.id_fase = p.id_fase
                          JOIN comp.PartidoSeleccion psl ON psl.id_partido = p.id_partido AND psl.condicion = 'L'
                          JOIN comp.Seleccion sl         ON sl.id_seleccion = psl.id_seleccion
                          JOIN cat.Pais pl               ON pl.id_pais = sl.id_pais
                          JOIN comp.PartidoSeleccion psv ON psv.id_partido = p.id_partido AND psv.condicion = 'V'
                          JOIN comp.Seleccion sv         ON sv.id_seleccion = psv.id_seleccion
                          JOIN cat.Pais pv               ON pv.id_pais = sv.id_pais
                          WHERE d.id_arbitro = a.id_arbitro AND p.id_torneo = @id_torneo
                          ORDER BY p.nro_partido
                          FOR XML PATH('Partido'), TYPE
                      )
               FROM disc.Arbitro a
               JOIN comp.Persona pe ON pe.id_persona = a.id_arbitro
               JOIN cat.Pais pa     ON pa.id_pais = pe.id_pais_nacionalidad
               WHERE EXISTS (SELECT 1
                             FROM disc.Designacion d0
                             JOIN comp.Partido p0 ON p0.id_partido = d0.id_partido
                             WHERE d0.id_arbitro = a.id_arbitro AND p0.id_torneo = @id_torneo)
                 AND (@apellido IS NULL OR pe.apellido = @apellido)
               ORDER BY pe.apellido, pe.nombre
               FOR XML PATH('Arbitro'), TYPE
           )
    FOR XML PATH('Designaciones');
END
GO

/* =====================================================================
   Ejemplos de ejecucion. Sobre el torneo de prueba 2043, con el 05_test_logica_disciplina.sql corrido
   completo y los arbitros y designaciones de prueba cargados (ver el bloque de datos de R3), tiene que dar:

   EXEC disc.usp_Reporte_Designaciones_XML @anio = 2043;
   -- Arbitro "Chile 01": partidos=2 (1 y 3), amarillas=7, rojas=3
   --      partido 1 (Argentina-Brasil, Principal): 5 amarillas y 2 rojas
   --      partido 3 (Brasil-Uruguay, Principal):   2 amarillas y 1 roja
   -- Arbitro "Chile 02": partidos=3 (1, 2 y 4), amarillas=3, rojas=0
   --      partido 1 como Asistente 1 (sin tarjetas anexas), partido 2 y partido 4 como Principal

   EXEC disc.usp_Reporte_Designaciones_XML @anio = 2043, @apellido = 'Chile 01';   -- solo ese arbitro
   EXEC disc.usp_Reporte_Designaciones_XML @anio = 1900;                           -- error 51003: no existe el torneo
   EXEC disc.usp_Reporte_Designaciones_XML @anio = 2043, @apellido = 'Nadie';      -- error 51003: sin designaciones
   ===================================================================== */

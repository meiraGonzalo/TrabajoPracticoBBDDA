/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Seed (Criterios de aceptacion, seccion IV) - Script 10: partidos, publicidad e importacion
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 24/11/2026
 Objetivo: completar lo que pide la seccion IV y no cubren las
   importaciones ni 10_seed_disciplina.sql
 Orden: 00 -> 01 -> 02 -> 03 -> importaciones (sin la de goles) ->
        10_seed_disciplina.sql -> ESTE SCRIPT -> importacion de goles
   - Despues del seed de disciplina: asi el jugador suspendido queda
     afuera de la formacion del partido en que cumple la suspension.
   - Antes de la importacion de goles: asi los goleadores ya estan en la
     formacion (titulares o suplentes) cuando se cargan sus goles.
=====================================================================
*/
USE MundialDB;
GO
SET NOCOUNT ON;

/* =================================================================
   PARTE A: parametros de cambios y periodos
   usp_Sustitucion_Alta necesita MAX_CAMBIOS y MAX_VENTANAS del torneo;
   en el alargue suma los extras. Valores del reglamento FIFA vigente.
   ================================================================= */
DECLARE @t int = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2026);
IF @t IS NULL
    THROW 50930, 'Seed seccion IV: no existe el torneo 2026. Ejecutar antes las importaciones.', 1;

IF NOT EXISTS (SELECT 1 FROM comp.ParametroReglamento WHERE id_torneo = @t AND clave = 'MAX_CAMBIOS')
    EXEC comp.usp_ParametroReglamento_Alta @t, 'MAX_CAMBIOS', 5, 'Cambios por equipo en tiempo reglamentario';
IF NOT EXISTS (SELECT 1 FROM comp.ParametroReglamento WHERE id_torneo = @t AND clave = 'MAX_VENTANAS')
    EXEC comp.usp_ParametroReglamento_Alta @t, 'MAX_VENTANAS', 3, 'Ventanas de cambio (sin contar el entretiempo)';
IF NOT EXISTS (SELECT 1 FROM comp.ParametroReglamento WHERE id_torneo = @t AND clave = 'CAMBIOS_EXTRA_ALARGUE')
    EXEC comp.usp_ParametroReglamento_Alta @t, 'CAMBIOS_EXTRA_ALARGUE', 1, 'Cambio extra en el alargue';
IF NOT EXISTS (SELECT 1 FROM comp.ParametroReglamento WHERE id_torneo = @t AND clave = 'VENTANAS_EXTRA_ALARGUE')
    EXEC comp.usp_ParametroReglamento_Alta @t, 'VENTANAS_EXTRA_ALARGUE', 1, 'Ventana extra en el alargue';

IF NOT EXISTS (SELECT 1 FROM comp.Periodo WHERE nombre = 'Primer tiempo')          EXEC comp.usp_Periodo_Alta 'Primer tiempo', 1;
IF NOT EXISTS (SELECT 1 FROM comp.Periodo WHERE nombre = 'Segundo tiempo')         EXEC comp.usp_Periodo_Alta 'Segundo tiempo', 2;
IF NOT EXISTS (SELECT 1 FROM comp.Periodo WHERE nombre = 'Alargue 1')              EXEC comp.usp_Periodo_Alta 'Alargue 1', 3;
IF NOT EXISTS (SELECT 1 FROM comp.Periodo WHERE nombre = 'Alargue 2')              EXEC comp.usp_Periodo_Alta 'Alargue 2', 4;
IF NOT EXISTS (SELECT 1 FROM comp.Periodo WHERE nombre = 'Definicion por penales') EXEC comp.usp_Periodo_Alta 'Definicion por penales', 5;

PRINT 'Parte A: parametros de cambios y periodos listos.';
GO


/* =================================================================
   PARTE B: formacion titular y banco de suplentes en cada partido
   Para cada seleccion de cada partido del torneo 2026:
     - Titulares (11): 1 arquero, 4 defensores, 4 mediocampistas y
       2 delanteros (un 4-4-2), por su posicion habitual y en orden de
       dorsal. Si faltan jugadores de alguna posicion, se completa con
       otros (nunca un segundo arquero).
     - Banco: el resto de los convocados activos.
     - No entran los suspendidos para ese partido (la misma regla que
       controla usp_Alineacion_Alta). Asi el suspendido por acumulacion
       del seed de disciplina queda afuera de la formacion.
     - Los que ya estaban en la alineacion (los que cargo el seed de
       disciplina) se respetan y cuentan para los 11.
   Primero se arma la lista en una tabla temporal (set-based) y despues
   se recorre con WHILE llamando a comp.usp_Alineacion_Alta (sin cursores).
   ================================================================= */
DECLARE @t int = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2026);
DECLARE @arq int = (SELECT id_posicion FROM comp.Posicion WHERE nombre = 'Arquero');
DECLARE @def int = (SELECT id_posicion FROM comp.Posicion WHERE nombre = 'Defensor');
DECLARE @med int = (SELECT id_posicion FROM comp.Posicion WHERE nombre = 'Mediocampista');
DECLARE @del int = (SELECT id_posicion FROM comp.Posicion WHERE nombre = 'Delantero');

IF @t IS NULL OR @arq IS NULL OR @def IS NULL OR @med IS NULL OR @del IS NULL
    THROW 50931, 'Seed seccion IV (parte B): faltan el torneo 2026 o las posiciones.', 1;

-- 1) Candidatos: convocados activos, que todavia no estan en la alineacion y no estan suspendidos
IF OBJECT_ID('tempdb..#cand') IS NOT NULL DROP TABLE #cand;
SELECT ps.id_partido_seleccion AS id_ps, c.id_convocado, c.dorsal, j.id_posicion_habitual AS id_pos,
       CAST(0 AS bit) AS es_titular
INTO #cand
FROM comp.Partido p
JOIN comp.PartidoSeleccion ps ON ps.id_partido = p.id_partido
JOIN comp.Convocado c         ON c.id_seleccion = ps.id_seleccion AND c.fecha_baja IS NULL
JOIN comp.Jugador j           ON j.id_jugador = c.id_jugador
WHERE p.id_torneo = @t
  AND NOT EXISTS (SELECT 1 FROM comp.Alineacion a
                  WHERE a.id_partido_seleccion = ps.id_partido_seleccion AND a.id_convocado = c.id_convocado)
  AND NOT EXISTS (SELECT 1 FROM disc.Suspension su
                  WHERE su.id_convocado = c.id_convocado AND su.estado = 'PENDIENTE'
                    AND (su.id_partido_cumple = p.id_partido OR su.id_partido_cumple IS NULL));

-- 2) Titulares que ya habia, por participacion y posicion
IF OBJECT_ID('tempdb..#ya') IS NOT NULL DROP TABLE #ya;
SELECT id_partido_seleccion AS id_ps, id_posicion_cancha AS id_pos, COUNT(*) AS cant
INTO #ya
FROM comp.Alineacion
WHERE es_titular = 1
GROUP BY id_partido_seleccion, id_posicion_cancha;

-- 3) Titulares por posicion (cupo del 4-4-2 menos los que ya estaban)
UPDATE c
SET es_titular = 1
FROM #cand c
JOIN (SELECT id_ps, id_convocado,
             ROW_NUMBER() OVER (PARTITION BY id_ps, id_pos ORDER BY dorsal) AS rn
      FROM #cand) r ON r.id_ps = c.id_ps AND r.id_convocado = c.id_convocado
LEFT JOIN #ya y ON y.id_ps = c.id_ps AND y.id_pos = c.id_pos
WHERE r.rn <= CASE c.id_pos WHEN @arq THEN 1 WHEN @def THEN 4 WHEN @med THEN 4 WHEN @del THEN 2 ELSE 0 END
             - ISNULL(y.cant, 0);

-- 4) Si no se llego a 11, completar con jugadores de campo (nunca otro arquero)
UPDATE c
SET es_titular = 1
FROM #cand c
JOIN (SELECT id_ps, id_convocado,
             ROW_NUMBER() OVER (PARTITION BY id_ps ORDER BY dorsal) AS rn
      FROM #cand
      WHERE es_titular = 0 AND id_pos <> @arq) r ON r.id_ps = c.id_ps AND r.id_convocado = c.id_convocado
WHERE r.rn <= 11 - (SELECT COUNT(*) FROM #cand c2 WHERE c2.id_ps = c.id_ps AND c2.es_titular = 1)
              - ISNULL((SELECT SUM(cant) FROM #ya y WHERE y.id_ps = c.id_ps), 0);

-- 5) Lista final numerada: primero los titulares de cada participacion, despues el banco
IF OBJECT_ID('tempdb..#carga') IS NOT NULL DROP TABLE #carga;
CREATE TABLE #carga (n int IDENTITY(1,1), id_ps int, id_convocado int, es_titular bit, id_pos int);
INSERT INTO #carga (id_ps, id_convocado, es_titular, id_pos)
SELECT id_ps, id_convocado, es_titular, CASE WHEN es_titular = 1 THEN id_pos END
FROM #cand
ORDER BY id_ps, es_titular DESC, dorsal;

IF OBJECT_ID('tempdb..#err_formacion') IS NOT NULL DROP TABLE #err_formacion;
CREATE TABLE #err_formacion (id_ps int, id_convocado int, mensaje nvarchar(2000));

-- 6) Alta de cada uno con el SP de la Entrega 5
DECLARE @i int = 1, @max int = (SELECT COUNT(*) FROM #carga);
DECLARE @ps int, @conv int, @tit bit, @pos int, @ok int = 0;
PRINT 'Parte B: cargando ' + CAST(@max AS varchar(10)) + ' jugadores en las formaciones (puede tardar un poco)...';

WHILE @i <= @max
BEGIN
    SELECT @ps = id_ps, @conv = id_convocado, @tit = es_titular, @pos = id_pos FROM #carga WHERE n = @i;
    BEGIN TRY
        EXEC comp.usp_Alineacion_Alta @ps, @conv, @tit, @pos;
        SET @ok += 1;
    END TRY
    BEGIN CATCH
        INSERT INTO #err_formacion (id_ps, id_convocado, mensaje) VALUES (@ps, @conv, ERROR_MESSAGE());
    END CATCH;
    SET @i += 1;
END

SELECT @max AS jugadores_a_cargar, @ok AS cargados, (SELECT COUNT(*) FROM #err_formacion) AS con_error;
SELECT TOP 20 * FROM #err_formacion;      -- esperado: vacio

-- Verificacion: partidos con las dos formaciones completas (11 titulares y banco)
SELECT COUNT(*) AS partidos_con_formacion_completa
FROM (SELECT ps.id_partido
      FROM comp.PartidoSeleccion ps
      JOIN comp.Partido p ON p.id_partido = ps.id_partido AND p.id_torneo = @t
      WHERE (SELECT COUNT(*) FROM comp.Alineacion a WHERE a.id_partido_seleccion = ps.id_partido_seleccion AND a.es_titular = 1) = 11
        AND (SELECT COUNT(*) FROM comp.Alineacion a WHERE a.id_partido_seleccion = ps.id_partido_seleccion AND a.es_titular = 0) > 0
      GROUP BY ps.id_partido
      HAVING COUNT(*) = 2) x;
/* Esperado: todos los partidos importados (104 si se cargaron las 48 selecciones); la seccion IV pide al menos 24. */

-- Los suspendidos que quedaron afuera (el seed de disciplina deja al menos uno por acumulacion)
SELECT pe.apellido, pe.nombre, pc.nro_partido AS partido_en_que_cumple,
       CASE WHEN EXISTS (SELECT 1 FROM comp.Alineacion a
                         JOIN comp.PartidoSeleccion ps ON ps.id_partido_seleccion = a.id_partido_seleccion
                         WHERE a.id_convocado = su.id_convocado AND ps.id_partido = su.id_partido_cumple)
            THEN 'ATENCION: esta en la formacion' ELSE 'Afuera de la formacion (correcto)' END AS situacion
FROM disc.Suspension su
JOIN comp.Convocado c ON c.id_convocado = su.id_convocado
JOIN comp.Persona pe  ON pe.id_persona = c.id_jugador
LEFT JOIN comp.Partido pc ON pc.id_partido = su.id_partido_cumple
WHERE su.estado = 'PENDIENTE';
GO


/* =================================================================
   PARTE C: cambio por lesion dentro de los primeros 20 minutos
   En el primer partido del torneo (por numero) que tenga formacion, un
   titular de campo de la seleccion local sale lesionado a los 18 minutos
   del primer tiempo y entra un suplente de su misma posicion.
   ================================================================= */
DECLARE @t int = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2026);
DECLARE @pt int = (SELECT id_periodo FROM comp.Periodo WHERE nombre = 'Primer tiempo');
DECLARE @arq int = (SELECT id_posicion FROM comp.Posicion WHERE nombre = 'Arquero');
DECLARE @ps int, @sale int, @entra int, @nro smallint;

-- Control: el ABM de sustituciones tenia el nombre de la tabla de periodos mal escrito
IF OBJECT_DEFINITION(OBJECT_ID('comp.usp_Sustitucion_Alta')) LIKE '%disc.Periodo%'
    THROW 50932, 'Parte C: comp.usp_Sustitucion_Alta lee disc.Periodo, que no existe. En 02_crear_sp_ABM.sql (linea 2005) cambiar disc.Periodo por comp.Periodo, ejecutar de nuevo ese SP y volver a correr esta parte.', 1;

IF EXISTS (SELECT 1
           FROM comp.Sustitucion s
           JOIN comp.Alineacion a        ON a.id_alineacion = s.id_alineacion_sale
           JOIN comp.PartidoSeleccion ps ON ps.id_partido_seleccion = a.id_partido_seleccion
           JOIN comp.Partido p           ON p.id_partido = ps.id_partido AND p.id_torneo = @t
           WHERE s.motivo = 'Lesion' AND s.id_periodo = @pt AND s.minuto <= 20)
    PRINT 'Parte C: el cambio por lesion ya estaba cargado; no se repite.';
ELSE
BEGIN
    -- Titular de campo (sin tarjeta roja ni cambio previo) y suplente de la misma posicion
    SELECT TOP 1 @ps = sal.id_partido_seleccion, @sale = sal.id_alineacion, @entra = ent.id_alineacion, @nro = p.nro_partido
    FROM comp.Partido p
    JOIN comp.PartidoSeleccion ps ON ps.id_partido = p.id_partido AND ps.condicion = 'L'
    JOIN comp.Alineacion sal      ON sal.id_partido_seleccion = ps.id_partido_seleccion AND sal.es_titular = 1
    JOIN comp.Alineacion ent      ON ent.id_partido_seleccion = ps.id_partido_seleccion AND ent.es_titular = 0
    JOIN comp.Convocado cs        ON cs.id_convocado = sal.id_convocado
    JOIN comp.Jugador js          ON js.id_jugador = cs.id_jugador
    JOIN comp.Convocado ce        ON ce.id_convocado = ent.id_convocado
    JOIN comp.Jugador je          ON je.id_jugador = ce.id_jugador
    WHERE p.id_torneo = @t
      AND sal.id_posicion_cancha <> @arq
      AND je.id_posicion_habitual = sal.id_posicion_cancha
      AND NOT EXISTS (SELECT 1 FROM disc.Tarjeta tj WHERE tj.id_alineacion IN (sal.id_alineacion, ent.id_alineacion))
      AND NOT EXISTS (SELECT 1 FROM comp.Sustitucion s
                      WHERE s.id_alineacion_sale = sal.id_alineacion OR s.id_alineacion_entra = ent.id_alineacion)
    ORDER BY p.nro_partido, cs.dorsal, ce.dorsal;

    IF @sale IS NULL
        PRINT 'Parte C: no hay ningun partido con formacion cargada (ejecutar antes la parte B).';
    ELSE
    BEGIN
        EXEC comp.usp_Sustitucion_Alta @sale, @entra, @pt, 18, 0, 1, 'Lesion';
        PRINT 'Parte C: cambio por lesion cargado en el partido ' + CAST(@nro AS varchar(5)) + ' (minuto 18).';
    END
END

-- Resultado: el cambio
SELECT p.nro_partido, pa.nombre AS seleccion, pr.nombre AS periodo, s.minuto, s.motivo,
       ps_.apellido + ', ' + ps_.nombre AS sale, pe_.apellido + ', ' + pe_.nombre AS entra
FROM comp.Sustitucion s
JOIN comp.Periodo pr            ON pr.id_periodo = s.id_periodo
JOIN comp.Alineacion asal       ON asal.id_alineacion = s.id_alineacion_sale
JOIN comp.Alineacion aent       ON aent.id_alineacion = s.id_alineacion_entra
JOIN comp.Convocado cs          ON cs.id_convocado = asal.id_convocado
JOIN comp.Persona ps_           ON ps_.id_persona = cs.id_jugador
JOIN comp.Convocado ce          ON ce.id_convocado = aent.id_convocado
JOIN comp.Persona pe_           ON pe_.id_persona = ce.id_jugador
JOIN comp.PartidoSeleccion pse  ON pse.id_partido_seleccion = asal.id_partido_seleccion
JOIN comp.Seleccion se          ON se.id_seleccion = pse.id_seleccion
JOIN cat.Pais pa                ON pa.id_pais = se.id_pais
JOIN comp.Partido p             ON p.id_partido = pse.id_partido
WHERE s.motivo = 'Lesion' AND s.minuto <= 20 AND pr.nombre = 'Primer tiempo';

-- Equipo en cancha al minuto 30 de ese partido: titulares, menos el que salio, mas el que entro (11 jugadores)
SELECT pe.apellido, pe.nombre, po.nombre AS posicion,
       CASE WHEN a.es_titular = 1 THEN 'Titular' ELSE 'Entro por lesion' END AS situacion
FROM comp.Alineacion a
JOIN comp.Convocado c  ON c.id_convocado = a.id_convocado
JOIN comp.Persona pe   ON pe.id_persona = c.id_jugador
JOIN comp.Jugador j    ON j.id_jugador = c.id_jugador
JOIN comp.Posicion po  ON po.id_posicion = j.id_posicion_habitual
WHERE a.id_partido_seleccion = (SELECT TOP 1 asal.id_partido_seleccion
                                FROM comp.Sustitucion s
                                JOIN comp.Alineacion asal ON asal.id_alineacion = s.id_alineacion_sale
                                WHERE s.motivo = 'Lesion' AND s.minuto <= 20)
  AND (   (a.es_titular = 1 AND NOT EXISTS (SELECT 1 FROM comp.Sustitucion s
                                            WHERE s.id_alineacion_sale = a.id_alineacion AND s.minuto <= 30))
       OR EXISTS (SELECT 1 FROM comp.Sustitucion s WHERE s.id_alineacion_entra = a.id_alineacion AND s.minuto <= 30))
ORDER BY situacion DESC, posicion, pe.apellido;
GO


/* =================================================================
   PARTE D: partido en prime time en mas de 4 mercados
   Candidatos de un partido = piezas de campanias activas ese dia; cada
   pieza apunta a un mercado (pais). Se busca un partido cuya hora local
   cae en la franja prime time en mas de 4 de esos mercados y se le
   asigna la publicidad con pub.usp_AsignarPublicidadPartido, que tiene
   solo 4 espacios: tiene que aplicar el criterio de priorizacion.
   ================================================================= */
DECLARE @t int = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2026);
DECLARE @id_partido int, @nro smallint, @mercados_prime int;

IF OBJECT_ID('tempdb..#cand_pub') IS NOT NULL DROP TABLE #cand_pub;
SELECT p.id_partido, p.nro_partido, pz.id_pieza_publicitaria, pz.titulo AS pieza,
       pm.id_pais, pm.nombre AS mercado, hl.hora_local,
       CASE WHEN EXISTS (SELECT 1 FROM pub.FranjaHoraria fh
                         WHERE fh.es_prime_time = 1
                           AND ((fh.hora_desde <= fh.hora_hasta
                                 AND hl.hora_local >= fh.hora_desde AND hl.hora_local <= fh.hora_hasta)
                             OR (fh.hora_desde > fh.hora_hasta
                                 AND (hl.hora_local >= fh.hora_desde OR hl.hora_local <= fh.hora_hasta))))
            THEN 1 ELSE 0 END AS es_prime
INTO #cand_pub
FROM comp.Partido p
CROSS JOIN pub.PiezaPublicitaria pz
JOIN pub.Campania ca ON ca.id_campania = pz.id_campania
JOIN cat.Pais pm     ON pm.id_pais = pz.id_pais_mercado
CROSS APPLY pub.ufn_ObtenerHoraLocalYFranja(p.fecha_hora_utc, pm.huso_horario) hl
WHERE p.id_torneo = @t
  AND (ca.fecha_desde IS NULL OR ca.fecha_desde <= CAST(p.fecha_hora_utc AS date))
  AND (ca.fecha_hasta IS NULL OR ca.fecha_hasta >= CAST(p.fecha_hora_utc AS date));

-- El partido con mas mercados en prime time (tiene que ser mas de 4)
SELECT TOP 1 @id_partido = id_partido, @nro = nro_partido,
             @mercados_prime = COUNT(DISTINCT CASE WHEN es_prime = 1 THEN id_pais END)
FROM #cand_pub
GROUP BY id_partido, nro_partido
HAVING COUNT(DISTINCT CASE WHEN es_prime = 1 THEN id_pais END) > 4
ORDER BY COUNT(DISTINCT CASE WHEN es_prime = 1 THEN id_pais END) DESC, nro_partido;

IF @id_partido IS NULL
    PRINT 'Parte D: ningun partido cae en prime time en mas de 4 mercados. Revisar que las horas de los partidos esten en formato 24 h (scraper corregido) y que la publicidad este importada.';
ELSE
BEGIN
    PRINT 'Parte D: el partido ' + CAST(@nro AS varchar(5)) + ' cae en prime time en '
          + CAST(@mercados_prime AS varchar(5)) + ' mercados y tiene solo 4 espacios.';

    -- Los candidatos y si el partido cae en prime time en su mercado
    SELECT nro_partido, mercado, hora_local, CASE es_prime WHEN 1 THEN 'SI' ELSE 'no' END AS prime_time, pieza
    FROM #cand_pub
    WHERE id_partido = @id_partido
    ORDER BY es_prime DESC, mercado;

    -- Asignacion con priorizacion (si el partido todavia no tenia publicidad)
    IF NOT EXISTS (SELECT 1 FROM pub.ExhibicionPublicitaria WHERE id_partido = @id_partido)
        EXEC pub.usp_AsignarPublicidadPartido @id_partido;
    ELSE
        PRINT 'Parte D: el partido ya tenia la publicidad asignada; se muestra la que quedo.';

    -- Los 4 elegidos, con su puntaje de prioridad
    SELECT e.nro_espacio, pm.nombre AS mercado, pz.titulo AS pieza, e.puntaje_prioridad, e.monto_aplicado, mo.codigo_iso AS moneda
    FROM pub.ExhibicionPublicitaria e
    JOIN pub.PiezaPublicitaria pz ON pz.id_pieza_publicitaria = e.id_pieza_publicitaria
    JOIN cat.Pais pm              ON pm.id_pais = pz.id_pais_mercado
    JOIN cat.Moneda mo            ON mo.id_moneda = e.id_moneda
    WHERE e.id_partido = @id_partido
    ORDER BY e.nro_espacio;
    /* Esperado: 4 filas (no mas), aunque haya mas de 4 mercados en prime time. Quedan los de mayor
       puntaje: mercado de una seleccion que juega, prime time, feriado y poder adquisitivo. */
END
GO


/* =================================================================
   PARTE E: importacion con errores parciales
   Se importa prueba_errores_parciales_plantillas.csv con la importacion
   de plantillas (imp.usp_Importar_Plantillas). Tiene 6 filas:
     2 correctas (dos jugadores de Argentina que ya estan: se actualizan,
       sin cambiar nada)
     4 con errores: seleccion inexistente, posicion invalida, fecha de
       nacimiento invalida y dorsal que no es un numero.
   La importacion carga las correctas, registra las otras 4 en
   imp.ErrorImportacion y sigue: eso es la importacion parcial.
   ================================================================= */
EXEC imp.usp_Importar_Plantillas 'C:\MundialDB\prueba_errores_parciales_plantillas.csv', 2026;
/* Esperado (las dos grillas que devuelve el SP):
   filas_leidas 6, jugadores_nuevos 0, jugadores_actualizados 2, filas_con_error 4
   lineas 4 a 7 con su mensaje: "Pais de la seleccion desconocido (Atlantida)", "Posicion invalida (XX...)",
   "Fecha de nacimiento invalida (fecha desconocida)" y "Dorsal invalido (abc)" */

-- Queda registrada en el log como importacion parcial (filas OK y filas con error)
SELECT TOP 1 id_log_importacion, nombre_archivo, filas_leidas, filas_ok, filas_error
FROM imp.LogImportacion
WHERE nombre_archivo LIKE '%prueba_errores_parciales%'
ORDER BY id_log_importacion DESC;
GO
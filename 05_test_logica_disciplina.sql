/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - Testing de la LOGICA de Disciplina (1:1 con el script 03)
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella         nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa             nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo            nickGithub: meiraGonzalo
              Miro, Saba Alejandro                      nickGithub: SabaM10
 Fecha: 2026-11-12
 Objetivo: testear los SP de logica del modulo disciplina:
             disc.usp_Suspension_CalcularPorTarjeta
             disc.usp_Tarjeta_Registrar
           y el bloqueo de un jugador suspendido en usp_Alineacion_Alta.
           Cada caso muestra la tabla ANTES, ejecuta, y muestra la tabla DESPUES.

 COMO CORRERLO: 00 -> 01 -> 02 -> 03 (logica de selecciones y partidos, y logica de
 disciplina) -> este script, de principio a fin.
 Los casos van en orden y dependen de los anteriores. Los tests dejan tarjetas y
 suspensiones en la base: para repetirlos hay que recrear la base con el 00.
=====================================================================
*/
USE MundialDB;
GO
SET NOCOUNT ON;
PRINT '=== TEST LOGICA DISCIPLINA ===';
GO

/* =================================================================
   PREPARACION: "Mundial de prueba disciplina 2043"
   ================================================================= */

-- Paises, ciudad y sede
IF NOT EXISTS (SELECT 1 FROM cat.Pais WHERE nombre = 'Argentina')
    EXEC cat.usp_Pais_Alta 'Argentina', 'CONMEBOL', NULL, 'Argentina Standard Time';
IF NOT EXISTS (SELECT 1 FROM cat.Pais WHERE nombre = 'Brasil')
    EXEC cat.usp_Pais_Alta 'Brasil', 'CONMEBOL', NULL, 'E. South America Standard Time';
IF NOT EXISTS (SELECT 1 FROM cat.Pais WHERE nombre = 'Uruguay')
    EXEC cat.usp_Pais_Alta 'Uruguay', 'CONMEBOL', NULL, 'Montevideo Standard Time';
IF NOT EXISTS (SELECT 1 FROM cat.Pais WHERE nombre = 'Chile')
    EXEC cat.usp_Pais_Alta 'Chile', 'CONMEBOL', NULL, 'Pacific SA Standard Time';
GO

DECLARE @arg int, @ciudad int;
SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
IF NOT EXISTS (SELECT 1 FROM cat.Ciudad WHERE nombre = N'Ciudad prueba disciplina' AND id_pais = @arg)
    EXEC cat.usp_Ciudad_Alta N'Ciudad prueba disciplina', @arg, 'Argentina Standard Time';
SELECT @ciudad = id_ciudad FROM cat.Ciudad WHERE nombre = N'Ciudad prueba disciplina' AND id_pais = @arg;

IF NOT EXISTS (SELECT 1 FROM comp.Sede WHERE nombre_estadio = N'Estadio prueba disciplina')
    EXEC comp.usp_Sede_Alta N'Estadio prueba disciplina', @ciudad, 60000, NULL, NULL;
GO

-- Catalogos: fases, periodos y posiciones
IF NOT EXISTS (SELECT 1 FROM comp.Fase WHERE nombre = 'Grupos')  EXEC comp.usp_Fase_Alta 'Grupos', 1, 0;
IF NOT EXISTS (SELECT 1 FROM comp.Fase WHERE nombre = 'Octavos') EXEC comp.usp_Fase_Alta 'Octavos', 3, 1;

IF NOT EXISTS (SELECT 1 FROM comp.Periodo WHERE nombre = 'Primer tiempo')  EXEC comp.usp_Periodo_Alta 'Primer tiempo', 1;
IF NOT EXISTS (SELECT 1 FROM comp.Periodo WHERE nombre = 'Segundo tiempo') EXEC comp.usp_Periodo_Alta 'Segundo tiempo', 2;

IF NOT EXISTS (SELECT 1 FROM comp.Posicion WHERE nombre = 'Arquero')       EXEC comp.usp_Posicion_Alta 'Arquero';
IF NOT EXISTS (SELECT 1 FROM comp.Posicion WHERE nombre = 'Defensor')      EXEC comp.usp_Posicion_Alta 'Defensor';
IF NOT EXISTS (SELECT 1 FROM comp.Posicion WHERE nombre = 'Mediocampista') EXEC comp.usp_Posicion_Alta 'Mediocampista';
IF NOT EXISTS (SELECT 1 FROM comp.Posicion WHERE nombre = 'Delantero')     EXEC comp.usp_Posicion_Alta 'Delantero';
GO

-- Torneo y reglamento
IF NOT EXISTS (SELECT 1 FROM comp.Torneo WHERE anio = 2043)
    EXEC comp.usp_Torneo_Alta 'Mundial de prueba disciplina 2043', 2043, '2043-06-01', '2043-07-31';
GO

DECLARE @t int, @orden_grupos int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2043;
SELECT @orden_grupos = orden FROM comp.Fase WHERE nombre = 'Grupos';

-- 2 amarillas en partidos distintos suspenden; las amarillas se limpian al terminar la fase de grupos
IF NOT EXISTS (SELECT 1 FROM comp.ParametroReglamento WHERE id_torneo = @t AND clave = 'AMARILLAS_SUSPENSION')
    EXEC comp.usp_ParametroReglamento_Alta @t, 'AMARILLAS_SUSPENSION', 2, 'Amarillas en partidos distintos para suspender';
IF NOT EXISTS (SELECT 1 FROM comp.ParametroReglamento WHERE id_torneo = @t AND clave = 'FASE_LIMPIA_AMARILLAS')
    EXEC comp.usp_ParametroReglamento_Alta @t, 'FASE_LIMPIA_AMARILLAS', @orden_grupos, 'Orden de la fase tras la cual se borran las amarillas';
GO

-- Grupo A y selecciones: Argentina, Brasil y Uruguay
DECLARE @t int, @gA int, @arg int, @bra int, @uru int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2043;

IF NOT EXISTS (SELECT 1 FROM comp.Grupo WHERE id_torneo = @t AND letra = 'A')
    EXEC comp.usp_Grupo_Alta @t, 'A';
SELECT @gA = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'A';

SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
SELECT @bra = id_pais FROM cat.Pais WHERE nombre = 'Brasil';
SELECT @uru = id_pais FROM cat.Pais WHERE nombre = 'Uruguay';

IF NOT EXISTS (SELECT 1 FROM comp.Seleccion WHERE id_torneo = @t AND id_pais = @arg) EXEC comp.usp_Seleccion_Alta @t, @arg, @gA;
IF NOT EXISTS (SELECT 1 FROM comp.Seleccion WHERE id_torneo = @t AND id_pais = @bra) EXEC comp.usp_Seleccion_Alta @t, @bra, @gA;
IF NOT EXISTS (SELECT 1 FROM comp.Seleccion WHERE id_torneo = @t AND id_pais = @uru) EXEC comp.usp_Seleccion_Alta @t, @uru, @gA;
GO

-- Planteles: 4 jugadores por seleccion (01 arquero, 02 defensor, 03 mediocampista, 04 delantero)
DECLARE @t int, @arq int, @def int, @med int, @del int, @pais int, @sel int;
SELECT @t   = id_torneo   FROM comp.Torneo   WHERE anio = 2043;
SELECT @arq = id_posicion FROM comp.Posicion WHERE nombre = 'Arquero';
SELECT @def = id_posicion FROM comp.Posicion WHERE nombre = 'Defensor';
SELECT @med = id_posicion FROM comp.Posicion WHERE nombre = 'Mediocampista';
SELECT @del = id_posicion FROM comp.Posicion WHERE nombre = 'Delantero';

-- Argentina
SELECT @pais = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
SELECT @sel  = id_seleccion FROM comp.Seleccion WHERE id_torneo = @t AND id_pais = @pais;
IF NOT EXISTS (SELECT 1 FROM comp.Persona WHERE nro_documento = 'D3-ARG01') EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Argentina 01', '1998-01-01', @pais, 'DNI', 'D3-ARG01', @arq, @sel, 1, NULL, '2043-05-20';
IF NOT EXISTS (SELECT 1 FROM comp.Persona WHERE nro_documento = 'D3-ARG02') EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Argentina 02', '1998-01-01', @pais, 'DNI', 'D3-ARG02', @def, @sel, 2, NULL, '2043-05-20';
IF NOT EXISTS (SELECT 1 FROM comp.Persona WHERE nro_documento = 'D3-ARG03') EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Argentina 03', '1998-01-01', @pais, 'DNI', 'D3-ARG03', @med, @sel, 3, NULL, '2043-05-20';
IF NOT EXISTS (SELECT 1 FROM comp.Persona WHERE nro_documento = 'D3-ARG04') EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Argentina 04', '1998-01-01', @pais, 'DNI', 'D3-ARG04', @del, @sel, 4, NULL, '2043-05-20';

-- Brasil
SELECT @pais = id_pais FROM cat.Pais WHERE nombre = 'Brasil';
SELECT @sel  = id_seleccion FROM comp.Seleccion WHERE id_torneo = @t AND id_pais = @pais;
IF NOT EXISTS (SELECT 1 FROM comp.Persona WHERE nro_documento = 'D3-BRA01') EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Brasil 01', '1998-01-01', @pais, 'DNI', 'D3-BRA01', @arq, @sel, 1, NULL, '2043-05-20';
IF NOT EXISTS (SELECT 1 FROM comp.Persona WHERE nro_documento = 'D3-BRA02') EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Brasil 02', '1998-01-01', @pais, 'DNI', 'D3-BRA02', @def, @sel, 2, NULL, '2043-05-20';
IF NOT EXISTS (SELECT 1 FROM comp.Persona WHERE nro_documento = 'D3-BRA03') EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Brasil 03', '1998-01-01', @pais, 'DNI', 'D3-BRA03', @med, @sel, 3, NULL, '2043-05-20';
IF NOT EXISTS (SELECT 1 FROM comp.Persona WHERE nro_documento = 'D3-BRA04') EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Brasil 04', '1998-01-01', @pais, 'DNI', 'D3-BRA04', @del, @sel, 4, NULL, '2043-05-20';

-- Uruguay
SELECT @pais = id_pais FROM cat.Pais WHERE nombre = 'Uruguay';
SELECT @sel  = id_seleccion FROM comp.Seleccion WHERE id_torneo = @t AND id_pais = @pais;
IF NOT EXISTS (SELECT 1 FROM comp.Persona WHERE nro_documento = 'D3-URU01') EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Uruguay 01', '1998-01-01', @pais, 'DNI', 'D3-URU01', @arq, @sel, 1, NULL, '2043-05-20';
IF NOT EXISTS (SELECT 1 FROM comp.Persona WHERE nro_documento = 'D3-URU02') EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Uruguay 02', '1998-01-01', @pais, 'DNI', 'D3-URU02', @def, @sel, 2, NULL, '2043-05-20';
IF NOT EXISTS (SELECT 1 FROM comp.Persona WHERE nro_documento = 'D3-URU03') EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Uruguay 03', '1998-01-01', @pais, 'DNI', 'D3-URU03', @med, @sel, 3, NULL, '2043-05-20';
IF NOT EXISTS (SELECT 1 FROM comp.Persona WHERE nro_documento = 'D3-URU04') EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Uruguay 04', '1998-01-01', @pais, 'DNI', 'D3-URU04', @del, @sel, 4, NULL, '2043-05-20';
GO

-- Partidos: 1 Argentina-Brasil (10/06), 2 Argentina-Uruguay (15/06), 3 Brasil-Uruguay (20/06), 4 octavos Argentina-Brasil (25/06)
DECLARE @t int, @gA int, @fg int, @fo int, @sede int, @arg int, @bra int, @uru int;
SELECT @t   = id_torneo FROM comp.Torneo WHERE anio = 2043;
SELECT @gA  = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'A';
SELECT @fg  = id_fase FROM comp.Fase WHERE nombre = 'Grupos';
SELECT @fo  = id_fase FROM comp.Fase WHERE nombre = 'Octavos';
SELECT @sede = id_sede FROM comp.Sede WHERE nombre_estadio = N'Estadio prueba disciplina';
SELECT @arg = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Argentina';
SELECT @bra = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Brasil';
SELECT @uru = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Uruguay';

IF NOT EXISTS (SELECT 1 FROM comp.Partido WHERE id_torneo = @t AND nro_partido = 1) EXEC comp.usp_Partido_Registrar @t, 1, @fg, @gA,  @sede, '2043-06-10 19:00', @arg, @bra;
IF NOT EXISTS (SELECT 1 FROM comp.Partido WHERE id_torneo = @t AND nro_partido = 2) EXEC comp.usp_Partido_Registrar @t, 2, @fg, @gA,  @sede, '2043-06-15 19:00', @arg, @uru;
IF NOT EXISTS (SELECT 1 FROM comp.Partido WHERE id_torneo = @t AND nro_partido = 3) EXEC comp.usp_Partido_Registrar @t, 3, @fg, @gA,  @sede, '2043-06-20 19:00', @bra, @uru;
IF NOT EXISTS (SELECT 1 FROM comp.Partido WHERE id_torneo = @t AND nro_partido = 4) EXEC comp.usp_Partido_Registrar @t, 4, @fo, NULL, @sede, '2043-06-25 19:00', @arg, @bra;
GO

-- Alineaciones: solo los jugadores que van a recibir tarjetas (todos titulares)
DECLARE @t int, @del int, @i int = 1, @max int, @doc varchar(30), @nro smallint, @c int, @ps int;
SELECT @t   = id_torneo FROM comp.Torneo WHERE anio = 2043;
SELECT @del = id_posicion FROM comp.Posicion WHERE nombre = 'Delantero';

IF OBJECT_ID('tempdb..#ali_pares') IS NOT NULL DROP TABLE #ali_pares;
CREATE TABLE #ali_pares (n int IDENTITY(1,1), doc varchar(30), nro smallint);
INSERT INTO #ali_pares (doc, nro) VALUES
    ('D3-ARG02', 1), ('D3-ARG03', 1), ('D3-ARG04', 1), ('D3-BRA02', 1), ('D3-BRA03', 1),   -- partido 1
    ('D3-ARG03', 2), ('D3-URU03', 2),                                                       -- partido 2
    ('D3-BRA03', 3),                                                                        -- partido 3
    ('D3-ARG04', 4);                                                                        -- partido 4 (octavos)
SELECT @max = MAX(n) FROM #ali_pares;

WHILE @i <= @max
BEGIN
    SELECT @doc = doc, @nro = nro FROM #ali_pares WHERE n = @i;
    SELECT @c = c.id_convocado
    FROM comp.Convocado c JOIN comp.Persona pe ON pe.id_persona = c.id_jugador
    WHERE pe.nro_documento = @doc;
    SELECT @ps = ps.id_partido_seleccion
    FROM comp.PartidoSeleccion ps
    JOIN comp.Partido p   ON p.id_partido = ps.id_partido
    JOIN comp.Convocado c ON c.id_seleccion = ps.id_seleccion
    WHERE p.id_torneo = @t AND p.nro_partido = @nro AND c.id_convocado = @c;

    IF NOT EXISTS (SELECT 1 FROM comp.Alineacion WHERE id_partido_seleccion = @ps AND id_convocado = @c)
        EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @del;
    SET @i += 1;
END
GO

-- Mapa de consulta (solo lectura): documento del jugador + nro de partido -> alineacion
IF OBJECT_ID('tempdb..#ali') IS NOT NULL DROP TABLE #ali;
SELECT pe.nro_documento AS doc, p.nro_partido AS nro, a.id_alineacion, a.id_convocado
INTO #ali
FROM comp.Alineacion a
JOIN comp.Convocado c         ON c.id_convocado = a.id_convocado
JOIN comp.Persona pe          ON pe.id_persona = c.id_jugador
JOIN comp.PartidoSeleccion ps ON ps.id_partido_seleccion = a.id_partido_seleccion
JOIN comp.Partido p           ON p.id_partido = ps.id_partido
JOIN comp.Torneo t            ON t.id_torneo = p.id_torneo AND t.anio = 2043;
GO

-- Helper de los tests: muestra las tarjetas y suspensiones de un jugador (procedimiento temporal, solo en esta sesion)
IF OBJECT_ID('tempdb..#ver_jugador') IS NOT NULL DROP PROCEDURE #ver_jugador;
GO
CREATE PROCEDURE #ver_jugador @doc varchar(30), @momento varchar(20)
AS
BEGIN
    SELECT @momento + ' - tarjetas' AS tabla, a.nro AS partido, t.id_tarjeta, t.tipo_tarjeta, t.minuto
    FROM #ali a
    LEFT JOIN disc.Tarjeta t ON t.id_alineacion = a.id_alineacion
    WHERE a.doc = @doc
    ORDER BY a.nro, t.id_tarjeta;

    SELECT @momento + ' - suspensiones' AS tabla, s.id_suspension, s.id_tarjeta_origen,
           p.nro_partido AS cumple_en_partido, s.estado
    FROM disc.Suspension s
    LEFT JOIN comp.Partido p ON p.id_partido = s.id_partido_cumple
    WHERE s.id_convocado = (SELECT TOP 1 id_convocado FROM #ali WHERE doc = @doc)
    ORDER BY s.id_suspension;
END
GO

-- Verificacion de la preparacion
SELECT p.nro_partido, COUNT(*) AS alineaciones
FROM #ali a
JOIN comp.PartidoSeleccion ps ON ps.id_partido_seleccion = (SELECT id_partido_seleccion FROM comp.Alineacion WHERE id_alineacion = a.id_alineacion)
JOIN comp.Partido p ON p.id_partido = ps.id_partido
GROUP BY p.nro_partido ORDER BY p.nro_partido;
/* Esperado: partido 1 = 5, partido 2 = 2, partido 3 = 1, partido 4 = 1. */
GO


/* =================================================================
   1. usp_Tarjeta_Registrar (y, a traves de el, usp_Suspension_CalcularPorTarjeta)
   ================================================================= */

/* TR1 (EXITOSO): amarilla simple, la primera del jugador -> no suspende.
   Jugador Argentina 03, partido 1. */
EXEC #ver_jugador 'D3-ARG03', 'ANTES';

DECLARE @al int = (SELECT id_alineacion FROM #ali WHERE doc = 'D3-ARG03' AND nro = 1);
DECLARE @pt int = (SELECT id_periodo FROM comp.Periodo WHERE nombre = 'Primer tiempo');
EXEC disc.usp_Tarjeta_Registrar @al, 'Amarilla', 'Juego brusco', @pt, 30;

EXEC #ver_jugador 'D3-ARG03', 'DESPUES';
/* Esperado: tarjetas: partido 1 con 1 Amarilla (minuto 30). Suspensiones: ninguna. */
GO

/* TR2 (EXITOSO, ACUMULACION ENTRE PARTIDOS): segunda amarilla en un partido DISTINTO -> suspende.
   Jugador Argentina 03, partido 2. */
EXEC #ver_jugador 'D3-ARG03', 'ANTES';

DECLARE @al int = (SELECT id_alineacion FROM #ali WHERE doc = 'D3-ARG03' AND nro = 2);
DECLARE @st int = (SELECT id_periodo FROM comp.Periodo WHERE nombre = 'Segundo tiempo');
EXEC disc.usp_Tarjeta_Registrar @al, 'Amarilla', 'Protesta', @st, 60;

EXEC #ver_jugador 'D3-ARG03', 'DESPUES';
/* Esperado: tarjetas: 1 Amarilla en el partido 1 y 1 Amarilla en el partido 2.
   Suspensiones: 1 PENDIENTE que cumple en el partido 4 (el proximo de Argentina). */
GO

/* TR3 (EXITOSO, DOBLE AMARILLA): dos amarillas en el MISMO partido -> el sistema genera la roja por doble amarilla.
   Jugador Argentina 02, partido 1. Las dos amarillas del mismo partido NO suman 2 para la acumulacion. */
EXEC #ver_jugador 'D3-ARG02', 'ANTES';

DECLARE @al int = (SELECT id_alineacion FROM #ali WHERE doc = 'D3-ARG02' AND nro = 1);
DECLARE @pt int = (SELECT id_periodo FROM comp.Periodo WHERE nombre = 'Primer tiempo');
DECLARE @st int = (SELECT id_periodo FROM comp.Periodo WHERE nombre = 'Segundo tiempo');
EXEC disc.usp_Tarjeta_Registrar @al, 'Amarilla', 'Falta tactica', @pt, 20;
EXEC disc.usp_Tarjeta_Registrar @al, 'Amarilla', 'Falta por detras', @st, 70;

EXEC #ver_jugador 'D3-ARG02', 'DESPUES';
/* Esperado: tarjetas del partido 1: Amarilla (min 20), Amarilla (min 70) y Roja por doble amarilla (min 70).
   Suspensiones: 1 PENDIENTE que cumple en el partido 4, originada por la roja. */
GO

/* TR4 (EXITOSO, ROJA DIRECTA): expulsion directa -> suspension para el proximo partido.
   Jugador Brasil 02, partido 1. */
EXEC #ver_jugador 'D3-BRA02', 'ANTES';

DECLARE @al int = (SELECT id_alineacion FROM #ali WHERE doc = 'D3-BRA02' AND nro = 1);
DECLARE @st int = (SELECT id_periodo FROM comp.Periodo WHERE nombre = 'Segundo tiempo');
EXEC disc.usp_Tarjeta_Registrar @al, 'Roja directa', 'Agresion', @st, 55;

EXEC #ver_jugador 'D3-BRA02', 'DESPUES';
/* Esperado: tarjetas: 1 Roja directa en el partido 1 (min 55).
   Suspensiones: 1 PENDIENTE que cumple en el partido 3 (el proximo de Brasil). */
GO

/* TR5 (EXITOSO, DOBLE AMARILLA ANULA LA SUSPENSION POR ACUMULACION).
   Jugador Brasil 03: amarilla en el partido 1, amarilla en el partido 3 (completa la acumulacion y suspende);
   despues una segunda amarilla en el partido 3 -> roja por doble amarilla: la suspension por acumulacion se
   anula y queda solo la de la roja. */
EXEC #ver_jugador 'D3-BRA03', 'ANTES';

DECLARE @al1 int = (SELECT id_alineacion FROM #ali WHERE doc = 'D3-BRA03' AND nro = 1);
DECLARE @al3 int = (SELECT id_alineacion FROM #ali WHERE doc = 'D3-BRA03' AND nro = 3);
DECLARE @pt int = (SELECT id_periodo FROM comp.Periodo WHERE nombre = 'Primer tiempo');
DECLARE @st int = (SELECT id_periodo FROM comp.Periodo WHERE nombre = 'Segundo tiempo');
EXEC disc.usp_Tarjeta_Registrar @al1, 'Amarilla', 'Juego brusco', @st, 80;
EXEC disc.usp_Tarjeta_Registrar @al3, 'Amarilla', 'Protesta', @pt, 15;

EXEC #ver_jugador 'D3-BRA03', 'DESPUES (acumulacion)';
/* Esperado: Amarilla en el partido 1 y Amarilla en el partido 3.
   Suspensiones: 1 PENDIENTE que cumple en el partido 4 (por acumulacion). */

EXEC disc.usp_Tarjeta_Registrar @al3, 'Amarilla', 'Falta por detras', @st, 60;

EXEC #ver_jugador 'D3-BRA03', 'DESPUES (doble amarilla)';
/* Esperado: partido 3 con Amarilla (min 15), Amarilla (min 60) y Roja por doble amarilla (min 60).
   Suspensiones: 2 filas para el partido 4: la primera ANULADA (la de acumulacion) y la segunda PENDIENTE (la de la roja). */
GO

/* TR6 (EXITOSO, LIMPIEZA DE AMARILLAS ENTRE FASES): una amarilla en grupos y otra en octavos NO se acumulan.
   Jugador Argentina 04: partido 1 (grupos) y partido 4 (octavos). */
EXEC #ver_jugador 'D3-ARG04', 'ANTES';

DECLARE @al1 int = (SELECT id_alineacion FROM #ali WHERE doc = 'D3-ARG04' AND nro = 1);
DECLARE @al4 int = (SELECT id_alineacion FROM #ali WHERE doc = 'D3-ARG04' AND nro = 4);
DECLARE @pt int = (SELECT id_periodo FROM comp.Periodo WHERE nombre = 'Primer tiempo');
EXEC disc.usp_Tarjeta_Registrar @al1, 'Amarilla', 'Juego brusco', @pt, 40;
EXEC disc.usp_Tarjeta_Registrar @al4, 'Amarilla', 'Protesta', @pt, 30;

EXEC #ver_jugador 'D3-ARG04', 'DESPUES';
/* Esperado: Amarilla en el partido 1 y Amarilla en el partido 4. Suspensiones: ninguna
   (la amarilla de la fase de grupos ya se limpio, FASE_LIMPIA_AMARILLAS = orden de Grupos). */
GO

/* TR7 (VALIDACION): tipo de tarjeta invalido y alineacion inexistente -> un solo mensaje, no se registra nada. */
SELECT 'ANTES' AS momento, COUNT(*) AS tarjetas_del_torneo
FROM disc.Tarjeta t JOIN #ali a ON a.id_alineacion = t.id_alineacion;

DECLARE @pt int = (SELECT id_periodo FROM comp.Periodo WHERE nombre = 'Primer tiempo');
BEGIN TRY
    EXEC disc.usp_Tarjeta_Registrar 0, 'Roja por doble amarilla', 'Prueba', @pt, 10;
END TRY
BEGIN CATCH
    PRINT 'TR7 - error esperado: ' + ERROR_MESSAGE();
END CATCH;

SELECT 'DESPUES' AS momento, COUNT(*) AS tarjetas_del_torneo
FROM disc.Tarjeta t JOIN #ali a ON a.id_alineacion = t.id_alineacion;
/* Esperado, error 50908:
   usp_Tarjeta_Registrar: - Tipo invalido (Amarilla / Roja directa). La roja por doble amarilla la genera el sistema.
   - La alineacion no existe.
   Las tarjetas del torneo son las mismas antes y despues. */
GO

/* TR8 (VALIDACION): jugador ya expulsado en el partido.
   Jugador Argentina 02, partido 1 (ya tiene la roja por doble amarilla de TR3). */
EXEC #ver_jugador 'D3-ARG02', 'ANTES';

DECLARE @al int = (SELECT id_alineacion FROM #ali WHERE doc = 'D3-ARG02' AND nro = 1);
DECLARE @st int = (SELECT id_periodo FROM comp.Periodo WHERE nombre = 'Segundo tiempo');
BEGIN TRY
    EXEC disc.usp_Tarjeta_Registrar @al, 'Amarilla', 'Otra falta', @st, 85;
END TRY
BEGIN CATCH
    PRINT 'TR8 - error esperado: ' + ERROR_MESSAGE();
END CATCH;

EXEC #ver_jugador 'D3-ARG02', 'DESPUES';
/* Esperado, error 50908: usp_Tarjeta_Registrar: - El jugador ya fue expulsado en este partido.
   Las tablas ANTES y DESPUES son iguales. */
GO

/* TR9 (VALIDACION): la segunda amarilla no puede ser anterior a la primera.
   Jugador Uruguay 03, partido 2: primera amarilla en el segundo tiempo (min 80), segunda en el primer tiempo (min 10). */
DECLARE @al int = (SELECT id_alineacion FROM #ali WHERE doc = 'D3-URU03' AND nro = 2);
DECLARE @pt int = (SELECT id_periodo FROM comp.Periodo WHERE nombre = 'Primer tiempo');
DECLARE @st int = (SELECT id_periodo FROM comp.Periodo WHERE nombre = 'Segundo tiempo');
EXEC disc.usp_Tarjeta_Registrar @al, 'Amarilla', 'Juego brusco', @st, 80;   -- preparacion del caso

EXEC #ver_jugador 'D3-URU03', 'ANTES';

BEGIN TRY
    EXEC disc.usp_Tarjeta_Registrar @al, 'Amarilla', 'Protesta', @pt, 10;
END TRY
BEGIN CATCH
    PRINT 'TR9 - error esperado: ' + ERROR_MESSAGE();
END CATCH;

EXEC #ver_jugador 'D3-URU03', 'DESPUES';
/* Esperado, error 50908: usp_Tarjeta_Registrar: - La segunda amarilla no puede ser anterior a la primera.
   Las tablas ANTES y DESPUES son iguales: 1 sola Amarilla (min 80), sin roja y sin suspensiones. */
GO


/* =================================================================
   2. usp_Suspension_CalcularPorTarjeta
   ================================================================= */

/* SC1 (NO DUPLICA): volver a calcular sobre la tarjeta que ya genero suspension no crea otra.
   Jugador Argentina 03: la amarilla del partido 2 (TR2) ya genero su suspension. */
EXEC #ver_jugador 'D3-ARG03', 'ANTES';

DECLARE @id_tarjeta int = (SELECT TOP 1 t.id_tarjeta FROM disc.Tarjeta t
                           WHERE t.id_alineacion = (SELECT id_alineacion FROM #ali WHERE doc = 'D3-ARG03' AND nro = 2));
EXEC disc.usp_Suspension_CalcularPorTarjeta @id_tarjeta;

EXEC #ver_jugador 'D3-ARG03', 'DESPUES';
/* Esperado: las tablas ANTES y DESPUES son iguales: sigue habiendo 1 sola suspension PENDIENTE. */
GO

/* SC2 (VALIDACION): calcular sobre una tarjeta que no existe. */
SELECT 'ANTES' AS momento, COUNT(*) AS suspensiones_del_torneo
FROM disc.Suspension s JOIN #ali a ON a.id_convocado = s.id_convocado;

BEGIN TRY
    EXEC disc.usp_Suspension_CalcularPorTarjeta 0;
END TRY
BEGIN CATCH
    PRINT 'SC2 - error esperado: ' + ERROR_MESSAGE();
END CATCH;

SELECT 'DESPUES' AS momento, COUNT(*) AS suspensiones_del_torneo
FROM disc.Suspension s JOIN #ali a ON a.id_convocado = s.id_convocado;
/* Esperado, error 50907: usp_Suspension_CalcularPorTarjeta: - La tarjeta no existe.
   La cantidad de suspensiones es la misma antes y despues. */
GO


/* =================================================================
   3. Jugador suspendido: queda afuera de la alineacion del partido siguiente (usp_Alineacion_Alta)
   ================================================================= */

/* AL1 (VALIDACION): Argentina 03 quedo suspendido para el partido 4 (TR2); no se lo puede alinear. */
SELECT 'ANTES' AS momento, COUNT(*) AS alineaciones_del_jugador
FROM comp.Alineacion
WHERE id_convocado = (SELECT TOP 1 id_convocado FROM #ali WHERE doc = 'D3-ARG03');

DECLARE @t int = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2043);
DECLARE @c int = (SELECT TOP 1 id_convocado FROM #ali WHERE doc = 'D3-ARG03');
DECLARE @ps int = (SELECT ps.id_partido_seleccion
                   FROM comp.PartidoSeleccion ps
                   JOIN comp.Partido p   ON p.id_partido = ps.id_partido
                   JOIN comp.Convocado c ON c.id_seleccion = ps.id_seleccion
                   WHERE p.id_torneo = @t AND p.nro_partido = 4 AND c.id_convocado = @c);
DECLARE @del int = (SELECT id_posicion FROM comp.Posicion WHERE nombre = 'Delantero');
BEGIN TRY
    EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @del;
END TRY
BEGIN CATCH
    PRINT 'AL1 - error esperado: ' + ERROR_MESSAGE();
END CATCH;

SELECT 'DESPUES' AS momento, COUNT(*) AS alineaciones_del_jugador
FROM comp.Alineacion
WHERE id_convocado = (SELECT TOP 1 id_convocado FROM #ali WHERE doc = 'D3-ARG03');
/* Esperado, error 50171: usp_Alineacion_Alta: - El jugador esta suspendido para este partido.
   El jugador tiene 2 alineaciones antes y despues (partidos 1 y 2): la del partido 4 no se creo. */
GO

PRINT '=== FIN TEST LOGICA DISCIPLINA ===';
GO
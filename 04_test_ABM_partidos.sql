/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - 04: Testing de los SP de ABM - Partidos y juego
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella         nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa             nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo            nickGithub: meiraGonzalo
              Miro, Saba Alejandro                      nickGithub: SabaM10
 Fecha: 11/10/2026
 Objetivo: probar todos los SP de ABM. Por cada SP hay
           casos OK y casos que disparan las validaciones

 COMO CORRERLO:
   1) Ejecutar 00 y 01 (base recien creada, vacia).
   2) Ejecutar el script 02 de SP de ABM 
   3) Ejecutar este script completo 

=====================================================================*/

use MundialDB;
go

/* =================================================================
   1. PERIODO
   ================================================================= */

--ALTA OK: los 5 periodos (solo los que falten)
IF (SELECT COUNT(*) FROM disc.Periodo WHERE orden = 1) = 0 EXEC comp.usp_Periodo_Alta 'Primer tiempo', 1;
IF (SELECT COUNT(*) FROM disc.Periodo WHERE orden = 2) = 0 EXEC comp.usp_Periodo_Alta 'Segundo tiempo', 2;
IF (SELECT COUNT(*) FROM disc.Periodo WHERE orden = 3) = 0 EXEC comp.usp_Periodo_Alta 'Alargue 1', 3;
IF (SELECT COUNT(*) FROM disc.Periodo WHERE orden = 4) = 0 EXEC comp.usp_Periodo_Alta 'Alargue 2', 4;
IF (SELECT COUNT(*) FROM disc.Periodo WHERE orden = 5) = 0 EXEC comp.usp_Periodo_Alta 'Definicion por penales', 5;
SELECT * FROM disc.Periodo ORDER BY orden;
-- Esperado: 5 filas con orden 1 a 5
GO

--ALTA ERROR: nombre vacio y orden repetido
EXEC comp.usp_Periodo_Alta '', 1;
/* usp_Periodo_Alta: - El nombre es obligatorio. - Ya existe un periodo con ese orden. */
GO

--ALTA ERROR: nombre repetido y orden fuera de rango
EXEC comp.usp_Periodo_Alta 'Primer tiempo', 9;
/*usp_Periodo_Alta: - Ya existe un periodo con ese nombre. - El orden debe estar entre 1 y 5. */
GO

--MODIFICACION OK: Alargue 2 pasa a llamarse Segundo alargue
DECLARE @id int;
SELECT @id = id_periodo FROM disc.Periodo WHERE orden = 4;
EXEC comp.usp_Periodo_Modificacion @id, 'Segundo alargue', 4;
SELECT * FROM disc.Periodo WHERE id_periodo = @id;
-- Esperado: 1 fila con nombre 'Segundo alargue'
GO

--MODIFICACION ERROR: periodo inexistente y orden de otro periodo
EXEC comp.usp_Periodo_Modificacion 9999, 'Otro', 2;
/* usp_Periodo_Modificacion: - El periodo no existe. - Otro periodo ya usa ese orden. */
GO


/* =================================================================
   2. SEDE
   ================================================================= */

-- ALTA OK: dos sedes reales (husos distintos) y una de prueba para borrar despues
DECLARE @cdmx int, @tor int;
SELECT @cdmx = id_ciudad FROM cat.Ciudad WHERE nombre = N'Ciudad de Mexico';
SELECT @tor  = id_ciudad FROM cat.Ciudad WHERE nombre = N'Toronto';
EXEC comp.usp_Sede_Alta N'Estadio Azteca', @cdmx, 83000, 19.302900, -99.150500;
EXEC comp.usp_Sede_Alta N'BMO Field', @tor, 45000, 43.633200, -79.418600;
EXEC comp.usp_Sede_Alta N'Estadio Prueba', @cdmx, 1000, NULL, NULL;
SELECT * FROM comp.Sede;
-- Esperado: (al menos) 3 filas: Estadio Azteca, BMO Field y Estadio Prueba
GO

--ALTA ERROR: cuatro reglas rotas a la vez
EXEC comp.usp_Sede_Alta N'', 9999, 0, 95, 10;
/* Esperado usp_Sede_Alta: - El nombre del estadio es obligatorio. - La ciudad no existe.
   - La capacidad debe ser mayor a cero. - La latitud debe estar entre -90 y 90. */
GO


--ALTA ERROR: estadio repetido en la misma ciudad
DECLARE @cdmx int;
SELECT @cdmx = id_ciudad FROM cat.Ciudad WHERE nombre = N'Ciudad de Mexico';
EXEC comp.usp_Sede_Alta N'Estadio Azteca', @cdmx, 83000, NULL, NULL;
/* Esperado:
   usp_Sede_Alta: - Ya existe ese estadio en la ciudad. */
GO

--MODIFICACION OK: cambio de capacidad
DECLARE @cdmx int, @s int;
SELECT @cdmx = id_ciudad FROM cat.Ciudad WHERE nombre = N'Ciudad de Mexico';
SELECT @s = id_sede FROM comp.Sede WHERE nombre_estadio = N'Estadio Azteca';
EXEC comp.usp_Sede_Modificacion @s, N'Estadio Azteca', @cdmx, 87523, 19.302900, -99.150500;
SELECT * FROM comp.Sede WHERE id_sede = @s;
-- Esperado: 1 fila con capacidad 87523
GO

--MODIFICACION ERROR: sede inexistente con el nombre de otra sede de la misma ciudad
DECLARE @cdmx int;
SELECT @cdmx = id_ciudad FROM cat.Ciudad WHERE nombre = N'Ciudad de Mexico';
EXEC comp.usp_Sede_Modificacion 9999, N'Estadio Azteca', @cdmx, 1000, NULL, NULL;
/* Esperado:
   usp_Sede_Modificacion: - La sede no existe. - Ya existe otro estadio con ese nombre en la ciudad. */
GO


/* =================================================================
   PARTIDO
   Horas locales esperadas:
     Ciudad de Mexico = UTC-6 todo el anio  /  Toronto en junio = UTC-4
   ================================================================= */

--ALTA OK: un partido de grupos y dos de octavos
DECLARE @t int, @gA int, @fg int, @fo int, @azt int, @bmo int;
SELECT @t   = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @gA  = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'A';
SELECT @fg  = id_fase FROM comp.Fase WHERE nombre = 'Grupos';
SELECT @fo  = id_fase FROM comp.Fase WHERE nombre = 'Octavos';
SELECT @azt = id_sede FROM comp.Sede WHERE nombre_estadio = N'Estadio Azteca';
SELECT @bmo = id_sede FROM comp.Sede WHERE nombre_estadio = N'BMO Field';
EXEC comp.usp_Partido_Alta @t, 1, @fg, @gA,  @azt, '2034-06-10 19:00';
EXEC comp.usp_Partido_Alta @t, 2, @fo, NULL, @bmo, '2034-06-20 23:00';
EXEC comp.usp_Partido_Alta @t, 3, @fo, NULL, @azt, '2034-06-25 20:00';
SELECT nro_partido, fecha_hora_utc, fecha_hora_local, estado FROM comp.Partido WHERE id_torneo = @t;
/* Esperado: 3 filas en estado PROGRAMADO
   1 | 2034-06-10 19:00 | 2034-06-10 13:00
   2 | 2034-06-20 23:00 | 2034-06-20 19:00
   3 | 2034-06-25 20:00 | 2034-06-25 14:00 */
GO

--ALTA ERROR: sede inexistente, numero repetido y partido de grupos sin grupo
DECLARE @t int, @fg int;
SELECT @t  = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @fg = id_fase FROM comp.Fase WHERE nombre = 'Grupos';
EXEC comp.usp_Partido_Alta @t, 1, @fg, NULL, 9999, '2034-06-11 19:00';
/* Esperado:
   usp_Partido_Alta: - La sede no existe. - Ya existe ese numero de partido en el torneo.
   - Un partido de fase de grupos debe indicar el grupo. */
GO

--ALTA ERROR: partido de octavos con grupo, en una sede que ya tiene partido ese dia
DECLARE @t int, @gA int, @fo int, @azt int;
SELECT @t   = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @gA  = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'A';
SELECT @fo  = id_fase FROM comp.Fase WHERE nombre = 'Octavos';
SELECT @azt = id_sede FROM comp.Sede WHERE nombre_estadio = N'Estadio Azteca';
EXEC comp.usp_Partido_Alta @t, 4, @fo, @gA, @azt, '2034-06-10 22:00';
/* Esperado:
   usp_Partido_Alta: - Un partido de eliminacion directa no lleva grupo.
   - La sede ya tiene un partido ese dia. */
GO

-- ALTA ERROR: fecha fuera del torneo
DECLARE @t int, @fo int, @bmo int;
SELECT @t   = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @fo  = id_fase FROM comp.Fase WHERE nombre = 'Octavos';
SELECT @bmo = id_sede FROM comp.Sede WHERE nombre_estadio = N'BMO Field';
EXEC comp.usp_Partido_Alta @t, 5, @fo, NULL, @bmo, '2035-01-01 20:00';
/* Esperado:
   usp_Partido_Alta: - La fecha del partido esta fuera de las fechas del torneo. */
GO

-- MODIFICACION OK: el partido 2 se pasa un dia (se recalcula la hora local)
DECLARE @t int, @p2 int, @bmo int;
SELECT @t   = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @p2  = id_partido FROM comp.Partido WHERE id_torneo = @t AND nro_partido = 2;
SELECT @bmo = id_sede FROM comp.Sede WHERE nombre_estadio = N'BMO Field';
EXEC comp.usp_Partido_Modificacion @p2, @bmo, '2034-06-21 23:00', 'PROGRAMADO', NULL;
SELECT nro_partido, fecha_hora_utc, fecha_hora_local FROM comp.Partido WHERE id_partido = @p2;
-- Esperado: 2 | 2034-06-21 23:00 | 2034-06-21 19:00
GO

-- MODIFICACION ERROR: estado invalido y el partido como su propio siguiente
DECLARE @t int, @p1 int, @azt int;
SELECT @t   = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @p1  = id_partido FROM comp.Partido WHERE id_torneo = @t AND nro_partido = 1;
SELECT @azt = id_sede FROM comp.Sede WHERE nombre_estadio = N'Estadio Azteca';
EXEC comp.usp_Partido_Modificacion @p1, @azt, '2034-06-10 19:00', 'JUGANDO', @p1;
/* Esperado:
   usp_Partido_Modificacion: - Estado invalido (PROGRAMADO / EN_JUEGO / FINALIZADO / SUSPENDIDO).
   - El partido no puede ser su propio siguiente. */
GO

-- MODIFICACION ERROR: partido y sede inexistentes
EXEC comp.usp_Partido_Modificacion 9999, 9999, '2034-06-10 19:00', 'PROGRAMADO', NULL;
/* Esperado:
   usp_Partido_Modificacion: - El partido no existe. - La sede no existe.
   - No se pudo calcular la hora local (hora UTC o huso invalido). */
GO


/* =================================================================
   PARTIDO SELECCION
   ================================================================= */

--ALTA OK: Mexico (L) vs Canada (V) en los partidos 1 y 2
DECLARE @t int, @p1 int, @p2 int, @s_mex int, @s_can int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @p1 = id_partido FROM comp.Partido WHERE id_torneo = @t AND nro_partido = 1;
SELECT @p2 = id_partido FROM comp.Partido WHERE id_torneo = @t AND nro_partido = 2;
SELECT @s_mex = s.id_seleccion FROM comp.Seleccion s INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE s.id_torneo = @t AND pa.nombre = 'Mexico';
SELECT @s_can = s.id_seleccion FROM comp.Seleccion s INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE s.id_torneo = @t AND pa.nombre = 'Canada';
EXEC comp.usp_PartidoSeleccion_Alta @p1, @s_mex, 'L';
EXEC comp.usp_PartidoSeleccion_Alta @p1, @s_can, 'V';
EXEC comp.usp_PartidoSeleccion_Alta @p2, @s_mex, 'L';
EXEC comp.usp_PartidoSeleccion_Alta @p2, @s_can, 'V';
SELECT * FROM comp.PartidoSeleccion WHERE id_partido IN (@p1, @p2);
-- Esperado: 4 filas
GO

-- PS2. ALTA ERROR: Chile (sin grupo) quiere ser local en el partido 1 (de grupo A, lugar ocupado)
DECLARE @t int, @p1 int, @s_chi int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @p1 = id_partido FROM comp.Partido WHERE id_torneo = @t AND nro_partido = 1;
SELECT @s_chi = s.id_seleccion FROM comp.Seleccion s INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE s.id_torneo = @t AND pa.nombre = 'Chile';
EXEC comp.usp_PartidoSeleccion_Alta @p1, @s_chi, 'L';
/* Esperado:
   usp_PartidoSeleccion_Alta: - Ese lugar (local o visitante) ya esta ocupado.
   - La seleccion no pertenece al grupo del partido. */
GO

-- ALTA ERROR: partido inexistente y condicion invalida
DECLARE @t int, @s_mex int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @s_mex = s.id_seleccion FROM comp.Seleccion s INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE s.id_torneo = @t AND pa.nombre = 'Mexico';
EXEC comp.usp_PartidoSeleccion_Alta 9999, @s_mex, 'X';
/* Esperado:
   usp_PartidoSeleccion_Alta: - El partido no existe. - La seleccion no existe o es de otro torneo.
   - La condicion debe ser L o V. */
GO

--MODIFICACION OK: esquema tactico de Mexico en el partido 1
DECLARE @t int, @ps int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @ps = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
INNER JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = @t AND p.nro_partido = 1 AND pa.nombre = 'Mexico';
EXEC comp.usp_PartidoSeleccion_Modificacion @ps, '4-3-3';
SELECT * FROM comp.PartidoSeleccion WHERE id_partido_seleccion = @ps;
-- Esperado: 1 fila con esquema_tactico '4-3-3'
GO

--MODIFICACION ERROR: esquema sin guiones
DECLARE @t int, @ps int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @ps = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
INNER JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = @t AND p.nro_partido = 1 AND pa.nombre = 'Mexico';
EXEC comp.usp_PartidoSeleccion_Modificacion @ps, '433';
/* Esperado:
   usp_PartidoSeleccion_Modificacion: - El esquema tactico debe tener el formato 4-3-3 o 3-4-1-2. */
GO


/* =================================================================
   ALINEACION (Mexico en el partido 1)
   ================================================================= */

-- AL1. ALTA OK: M1 arquero titular, M2 defensor titular; M3, M4 y M5 al banco
DECLARE @t int, @ps int, @arq int, @def int, @c int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @ps = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
INNER JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = @t AND p.nro_partido = 1 AND pa.nombre = 'Mexico';
SELECT @arq = id_posicion FROM comp.Posicion WHERE nombre = 'Arquero';
SELECT @def = id_posicion FROM comp.Posicion WHERE nombre = 'Defensor';

SELECT @c = c.id_convocado FROM comp.Convocado c INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE pe.nro_documento = 'P2-M1';
EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @arq;
SELECT @c = c.id_convocado FROM comp.Convocado c INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE pe.nro_documento = 'P2-M2';
EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @def;
SELECT @c = c.id_convocado FROM comp.Convocado c INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE pe.nro_documento = 'P2-M3';
EXEC comp.usp_Alineacion_Alta @ps, @c, 0, NULL;
SELECT @c = c.id_convocado FROM comp.Convocado c INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE pe.nro_documento = 'P2-M4';
EXEC comp.usp_Alineacion_Alta @ps, @c, 0, NULL;
SELECT @c = c.id_convocado FROM comp.Convocado c INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE pe.nro_documento = 'P2-M5';
EXEC comp.usp_Alineacion_Alta @ps, @c, 0, NULL;

SELECT * FROM comp.Alineacion WHERE id_partido_seleccion = @ps;
-- Esperado: 5 filas: 2 titulares (con posicion) y 3 suplentes (posicion NULL)
GO

-- AL2. ALTA ERROR: un jugador de Canada en la alineacion de Mexico, titular sin posicion
DECLARE @t int, @ps int, @c int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @ps = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
INNER JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = @t AND p.nro_partido = 1 AND pa.nombre = 'Mexico';
SELECT @c = c.id_convocado FROM comp.Convocado c INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE pe.nro_documento = 'P2-C1';
EXEC comp.usp_Alineacion_Alta @ps, @c, 1, NULL;
/* Esperado:
   usp_Alineacion_Alta: - El jugador no es convocado de esta seleccion.
   - Un titular debe tener posicion en cancha. */
GO

-- ALTA ERROR: M1 otra vez, y ya hay un arquero titular
DECLARE @t int, @ps int, @c int, @arq int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @ps = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
INNER JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = @t AND p.nro_partido = 1 AND pa.nombre = 'Mexico';
SELECT @arq = id_posicion FROM comp.Posicion WHERE nombre = 'Arquero';
SELECT @c = c.id_convocado FROM comp.Convocado c INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE pe.nro_documento = 'P2-M1';
EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @arq;
/* Esperado:
   usp_Alineacion_Alta: - El jugador ya esta en la alineacion. - Ya hay un arquero titular. */
GO

--ALTA ERROR: suplente con posicion
DECLARE @t int, @ps int, @c int, @def int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @ps = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
INNER JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = @t AND p.nro_partido = 1 AND pa.nombre = 'Mexico';
SELECT @def = id_posicion FROM comp.Posicion WHERE nombre = 'Defensor';
SELECT @c = c.id_convocado FROM comp.Convocado c INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE pe.nro_documento = 'P2-M6';
EXEC comp.usp_Alineacion_Alta @ps, @c, 0, @def;
/* Esperado:
   usp_Alineacion_Alta: - Un suplente no lleva posicion en cancha. */
GO

/* se usa un INSERT de
   respaldo SOLO para poder probar; deja de ejecutarse solo en cuanto
   existan los SP.(disc.usp_Tarjeta_Alta y disc.usp_Suspension_Alta)
   Si usp_Tarjeta_Alta ya genera la suspension por su cuenta, no se
   crea una segunda (se pregunta antes si ya existe).
    */
DECLARE @t int, @ps int, @a int, @c int, @p1t int, @p2 int, @tarjeta int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @ps = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
INNER JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = @t AND p.nro_partido = 1 AND pa.nombre = 'Mexico';
SELECT @c = c.id_convocado FROM comp.Convocado c INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE pe.nro_documento = 'P2-M5';
SELECT @a = id_alineacion FROM comp.Alineacion WHERE id_partido_seleccion = @ps AND id_convocado = @c;
SELECT @p1t = id_periodo FROM disc.Periodo WHERE orden = 1;
SELECT @p2 = id_partido FROM comp.Partido WHERE id_torneo = @t AND nro_partido = 2;


-- 1) Tarjeta roja directa a M5 en el partido 1 (solo si no la tiene)
IF (SELECT COUNT(*) FROM disc.Tarjeta WHERE id_alineacion = @a AND tipo_tarjeta = 'Roja directa') = 0
BEGIN
    IF OBJECT_ID('disc.usp_Tarjeta_Alta') IS NOT NULL
        EXEC disc.usp_Tarjeta_Alta @id_alineacion = @a, @id_cuerpo_tecnico = NULL,
                                   @id_partido_seleccion = NULL, @tipo_tarjeta = 'Roja directa',
                                   @motivo = 'Insultos desde el banco', @id_periodo = @p1t,
                                   @minuto = 30, @minuto_adicional = 0;
    ELSE
        INSERT INTO disc.Tarjeta (id_alineacion, tipo_tarjeta, motivo, id_periodo, minuto)
        VALUES (@a, 'Roja directa', 'Insultos desde el banco', @p1t, 30);
END

SELECT @tarjeta = id_tarjeta FROM disc.Tarjeta
WHERE id_alineacion = @a AND tipo_tarjeta = 'Roja directa';

-- 2) Suspension de M5 para el partido 2 (solo si todavia no existe)
IF (SELECT COUNT(*) FROM disc.Suspension WHERE id_convocado = @c AND estado = 'PENDIENTE') = 0
BEGIN
    IF OBJECT_ID('disc.usp_Suspension_Alta') IS NOT NULL
        EXEC disc.usp_Suspension_Alta @id_convocado = @c, @id_cuerpo_tecnico = NULL,
                                      @id_tarjeta_origen = @tarjeta, @id_partido_cumple = @p2;
    ELSE
        INSERT INTO disc.Suspension (id_convocado, id_tarjeta_origen, id_partido_cumple)
        VALUES (@c, @tarjeta, @p2);
END

-- Evidencia: la tarjeta y la suspension de M5
SELECT t.id_tarjeta, t.tipo_tarjeta, t.minuto, su.id_suspension, su.id_partido_cumple, su.estado
FROM disc.Tarjeta t
INNER JOIN disc.Suspension su ON su.id_tarjeta_origen = t.id_tarjeta
WHERE t.id_alineacion = @a;
-- Esperado: 1 fila, Roja directa, minuto 30, estado PENDIENTE
GO

-- ALTA ERROR (caso obligatorio): M5 esta suspendido para el partido 2
DECLARE @t int, @ps2 int, @c int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @ps2 = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
INNER JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = @t AND p.nro_partido = 2 AND pa.nombre = 'Mexico';
SELECT @c = c.id_convocado FROM comp.Convocado c INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE pe.nro_documento = 'P2-M5';
EXEC comp.usp_Alineacion_Alta @ps2, @c, 0, NULL;
/* Esperado:
   usp_Alineacion_Alta: - El jugador esta suspendido para este partido. */
GO

--MODIFICACION OK: M4 pasa a ser titular como defensor
DECLARE @t int, @ps int, @a int, @def int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @ps = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
INNER JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = @t AND p.nro_partido = 1 AND pa.nombre = 'Mexico';
SELECT @def = id_posicion FROM comp.Posicion WHERE nombre = 'Defensor';
SELECT @a = a.id_alineacion FROM comp.Alineacion a
INNER JOIN comp.Convocado c ON c.id_convocado = a.id_convocado
INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador
WHERE a.id_partido_seleccion = @ps AND pe.nro_documento = 'P2-M4';
EXEC comp.usp_Alineacion_Modificacion @a, 1, @def;
SELECT * FROM comp.Alineacion WHERE id_alineacion = @a;
-- Esperado: 1 fila con es_titular = 1 y la posicion de Defensor
GO

--MODIFICACION ERROR: M5 ya tiene una tarjeta en el partido
DECLARE @t int, @ps int, @a int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @ps = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
INNER JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = @t AND p.nro_partido = 1 AND pa.nombre = 'Mexico';
SELECT @a = a.id_alineacion FROM comp.Alineacion a
INNER JOIN comp.Convocado c ON c.id_convocado = a.id_convocado
INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador
WHERE a.id_partido_seleccion = @ps AND pe.nro_documento = 'P2-M5';
EXEC comp.usp_Alineacion_Modificacion @a, 0, NULL;
/* Esperado:
   usp_Alineacion_Modificacion: - El jugador ya tiene tarjetas. */
GO


/* =================================================================
   SUSTITUCION (Mexico en el partido 1; MAX_CAMBIOS = 1, MAX_VENTANAS = 1)
   ================================================================= */

-- SU1. ALTA OK (caso obligatorio): cambio por lesion a los 18 minutos, sale M2 y entra M3
DECLARE @t int, @ps int, @sale int, @entra int, @p1t int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @ps = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
INNER JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = @t AND p.nro_partido = 1 AND pa.nombre = 'Mexico';
SELECT @sale = a.id_alineacion FROM comp.Alineacion a INNER JOIN comp.Convocado c ON c.id_convocado = a.id_convocado
INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE a.id_partido_seleccion = @ps AND pe.nro_documento = 'P2-M2';
SELECT @entra = a.id_alineacion FROM comp.Alineacion a INNER JOIN comp.Convocado c ON c.id_convocado = a.id_convocado
INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE a.id_partido_seleccion = @ps AND pe.nro_documento = 'P2-M3';
SELECT @p1t = id_periodo FROM disc.Periodo WHERE orden = 1;
EXEC comp.usp_Sustitucion_Alta @sale, @entra, @p1t, 18, 0, 1, 'Lesion';
SELECT * FROM comp.Sustitucion WHERE id_alineacion_sale = @sale;
-- Esperado: 1 fila, minuto 18, ventana 1, motivo 'Lesion'
GO

--ALTA ERROR: M2 ya salio, M1 fue titular, motivo invalido y ya se uso el unico cambio
DECLARE @t int, @ps int, @sale int, @entra int, @p1t int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @ps = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
INNER JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = @t AND p.nro_partido = 1 AND pa.nombre = 'Mexico';
SELECT @sale = a.id_alineacion FROM comp.Alineacion a INNER JOIN comp.Convocado c ON c.id_convocado = a.id_convocado
INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE a.id_partido_seleccion = @ps AND pe.nro_documento = 'P2-M2';
SELECT @entra = a.id_alineacion FROM comp.Alineacion a INNER JOIN comp.Convocado c ON c.id_convocado = a.id_convocado
INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE a.id_partido_seleccion = @ps AND pe.nro_documento = 'P2-M1';
SELECT @p1t = id_periodo FROM disc.Periodo WHERE orden = 1;
EXEC comp.usp_Sustitucion_Alta @sale, @entra, @p1t, 30, 0, 1, 'Cansancio';
/* Esperado:
   usp_Sustitucion_Alta: - Motivo invalido (Tactico / Lesion / Precaucion).
   - El que sale ya habia salido antes. - El que entra fue titular: no puede entrar como suplente.
   - Se supera la cantidad maxima de cambios. */
GO

--ALTA ERROR: entra M5 (expulsado), ya no quedan cambios y la ventana 2 supera el maximo
DECLARE @t int, @ps int, @sale int, @entra int, @p2t int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @ps = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
INNER JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = @t AND p.nro_partido = 1 AND pa.nombre = 'Mexico';
SELECT @sale = a.id_alineacion FROM comp.Alineacion a INNER JOIN comp.Convocado c ON c.id_convocado = a.id_convocado
INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE a.id_partido_seleccion = @ps AND pe.nro_documento = 'P2-M1';
SELECT @entra = a.id_alineacion FROM comp.Alineacion a INNER JOIN comp.Convocado c ON c.id_convocado = a.id_convocado
INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE a.id_partido_seleccion = @ps AND pe.nro_documento = 'P2-M5';
SELECT @p2t = id_periodo FROM disc.Periodo WHERE orden = 2;
EXEC comp.usp_Sustitucion_Alta @sale, @entra, @p2t, 60, 0, 2, 'Tactico';
/* Esperado:
   usp_Sustitucion_Alta: - El que entra fue expulsado. - Se supera la cantidad maxima de cambios.
   - Se supera la cantidad maxima de ventanas de cambio. */
GO

--MODIFICACION OK: el motivo pasa a 'Precaucion'
DECLARE @id int;
SELECT @id = s.id_sustitucion FROM comp.Sustitucion s
INNER JOIN comp.Alineacion a ON a.id_alineacion = s.id_alineacion_sale
INNER JOIN comp.Convocado c ON c.id_convocado = a.id_convocado
INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador
WHERE pe.nro_documento = 'P2-M2';
EXEC comp.usp_Sustitucion_Modificacion @id, 'Precaucion';
SELECT * FROM comp.Sustitucion WHERE id_sustitucion = @id;
-- Esperado: 1 fila con motivo 'Precaucion'
GO

--MODIFICACION ERROR: cambio inexistente y motivo invalido
EXEC comp.usp_Sustitucion_Modificacion 9999, 'X';
/* Esperado:
   usp_Sustitucion_Modificacion: - El cambio no existe. - Motivo invalido (Tactico / Lesion / Precaucion). */
GO


/* =================================================================
   BAJAS 
   ================================================================= */

-- ALINEACION BAJA ERROR: M3 entro en un cambio
DECLARE @t int, @ps int, @a int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @ps = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
INNER JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = @t AND p.nro_partido = 1 AND pa.nombre = 'Mexico';
SELECT @a = a.id_alineacion FROM comp.Alineacion a INNER JOIN comp.Convocado c ON c.id_convocado = a.id_convocado
INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE a.id_partido_seleccion = @ps AND pe.nro_documento = 'P2-M3';
EXEC comp.usp_Alineacion_Baja @a;
/* Esperado:
   usp_Alineacion_Baja: - El jugador participo de un cambio. */
GO

--ALINEACION BAJA OK: se agrega C1 al banco de Canada y se lo saca
DECLARE @t int, @ps int, @c int, @a int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @ps = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
INNER JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = @t AND p.nro_partido = 1 AND pa.nombre = 'Canada';
SELECT @c = c.id_convocado FROM comp.Convocado c INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador WHERE pe.nro_documento = 'P2-C1';
EXEC comp.usp_Alineacion_Alta @ps, @c, 0, NULL;
SELECT @a = id_alineacion FROM comp.Alineacion WHERE id_partido_seleccion = @ps AND id_convocado = @c;
EXEC comp.usp_Alineacion_Baja @a;
SELECT * FROM comp.Alineacion WHERE id_partido_seleccion = @ps;
-- Esperado: 0 filas
GO

--SUSTITUCION BAJA ERROR: cambio inexistente
EXEC comp.usp_Sustitucion_Baja 9999;
/* Esperado:
   usp_Sustitucion_Baja: - El cambio no existe. */
GO

--SUSTITUCION BAJA OK: el que entro (M3) no tuvo eventos despues
DECLARE @id int;
SELECT @id = s.id_sustitucion FROM comp.Sustitucion s
INNER JOIN comp.Alineacion a ON a.id_alineacion = s.id_alineacion_sale
INNER JOIN comp.Convocado c ON c.id_convocado = a.id_convocado
INNER JOIN comp.Persona pe ON pe.id_persona = c.id_jugador
WHERE pe.nro_documento = 'P2-M2';
EXEC comp.usp_Sustitucion_Baja @id;
SELECT * FROM comp.Sustitucion WHERE id_sustitucion = @id;
-- Esperado: 0 filas
GO

--PERIODO BAJA ERROR: el primer tiempo tiene una tarjeta
DECLARE @id int;
SELECT @id = id_periodo FROM disc.Periodo WHERE orden = 1;
EXEC comp.usp_Periodo_Baja @id;
/* Esperado:
   usp_Periodo_Baja: - Tiene tarjetas. */
GO

--PERIODO BAJA OK: se borra la definicion por penales (sin uso) y se vuelve a crear
DECLARE @id int;
SELECT @id = id_periodo FROM disc.Periodo WHERE orden = 5;
EXEC comp.usp_Periodo_Baja @id;
SELECT * FROM disc.Periodo WHERE orden = 5;
-- Esperado: 0 filas
EXEC comp.usp_Periodo_Alta 'Definicion por penales', 5;
GO

--PARTIDO SELECCION BAJA ERROR: Mexico tiene alineacion en el partido 1
DECLARE @t int, @ps int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @ps = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
INNER JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = @t AND p.nro_partido = 1 AND pa.nombre = 'Mexico';
EXEC comp.usp_PartidoSeleccion_Baja @ps;
/* Esperado:
   usp_PartidoSeleccion_Baja: - Tiene alineacion cargada. */
GO

--PARTIDO SELECCION BAJA OK: se asigna Canada al partido 3 y se la saca
DECLARE @t int, @p3 int, @s_can int, @ps int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @p3 = id_partido FROM comp.Partido WHERE id_torneo = @t AND nro_partido = 3;
SELECT @s_can = s.id_seleccion FROM comp.Seleccion s INNER JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE s.id_torneo = @t AND pa.nombre = 'Canada';
EXEC comp.usp_PartidoSeleccion_Alta @p3, @s_can, 'L';
SELECT @ps = id_partido_seleccion FROM comp.PartidoSeleccion WHERE id_partido = @p3 AND id_seleccion = @s_can;
EXEC comp.usp_PartidoSeleccion_Baja @ps;
SELECT * FROM comp.PartidoSeleccion WHERE id_partido = @p3;
-- Esperado: 0 filas
GO

--PARTIDO BAJA ERROR: el partido 2 tiene selecciones y una suspension que se cumple ahi
DECLARE @t int, @p2 int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @p2 = id_partido FROM comp.Partido WHERE id_torneo = @t AND nro_partido = 2;
EXEC comp.usp_Partido_Baja @p2;
/* Esperado:
   usp_Partido_Baja: - Tiene selecciones asignadas. - Hay suspensiones que se cumplen en este partido. */
GO

--PARTIDO BAJA OK: el partido 3 quedo vacio
DECLARE @t int, @p3 int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @p3 = id_partido FROM comp.Partido WHERE id_torneo = @t AND nro_partido = 3;
EXEC comp.usp_Partido_Baja @p3;
SELECT * FROM comp.Partido WHERE id_torneo = @t;
-- Esperado: 2 filas (partidos 1 y 2)
GO

-- PARTIDO BAJA ERROR: partido inexistente
EXEC comp.usp_Partido_Baja 9999;
/* Esperado:
   usp_Partido_Baja: - El partido no existe. */
GO

--SEDE BAJA ERROR: el Estadio Azteca tiene partidos
DECLARE @s int;
SELECT @s = id_sede FROM comp.Sede WHERE nombre_estadio = N'Estadio Azteca';
EXEC comp.usp_Sede_Baja @s;
/* Esperado:
   usp_Sede_Baja: - La sede tiene partidos asignados. */
GO

--SEDE BAJA OK: el Estadio Prueba no tiene partidos
DECLARE @s int;
SELECT @s = id_sede FROM comp.Sede WHERE nombre_estadio = N'Estadio Prueba';
EXEC comp.usp_Sede_Baja @s;
SELECT * FROM comp.Sede WHERE nombre_estadio = N'Estadio Prueba';
-- Esperado: 0 filas
GO
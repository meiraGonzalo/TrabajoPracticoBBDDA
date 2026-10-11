/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - Script 91 (Parte 2): Testing de los SP de logica - Partidos y juego
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 11/10/2026
 Objetivo: probar los SP de logica de partidos:
             PR = usp_Partido_Registrar
             RR = usp_Partido_RegistrarResultado
             FO = usp_Partido_RegistrarFormaciones

 COMO CORRERLO: 00 -> 01 -> SP de ABM -> SP de logica selecciones ->
 este script
=====================================================================
*/

USE MundialDB;
GO

/* =================================================================
   PREPARACION
   ================================================================= */

-- Paises
IF NOT EXISTS (SELECT 1 FROM cat.Pais WHERE nombre = 'Mexico')
BEGIN
    IF OBJECT_ID('cat.usp_Pais_Alta') IS NOT NULL EXEC cat.usp_Pais_Alta 'Mexico', 'CONCACAF', NULL, 'Central Standard Time (Mexico)';
    ELSE INSERT INTO cat.Pais (nombre, confederacion, huso_horario) VALUES ('Mexico', 'CONCACAF', 'Central Standard Time (Mexico)');
END
IF NOT EXISTS (SELECT 1 FROM cat.Pais WHERE nombre = 'Canada')
BEGIN
    IF OBJECT_ID('cat.usp_Pais_Alta') IS NOT NULL EXEC cat.usp_Pais_Alta 'Canada', 'CONCACAF', NULL, 'Eastern Standard Time';
    ELSE INSERT INTO cat.Pais (nombre, confederacion, huso_horario) VALUES ('Canada', 'CONCACAF', 'Eastern Standard Time');
END
IF NOT EXISTS (SELECT 1 FROM cat.Pais WHERE nombre = 'Chile')
BEGIN
    IF OBJECT_ID('cat.usp_Pais_Alta') IS NOT NULL EXEC cat.usp_Pais_Alta 'Chile', 'CONMEBOL', NULL, 'Pacific SA Standard Time';
    ELSE INSERT INTO cat.Pais (nombre, confederacion, huso_horario) VALUES ('Chile', 'CONMEBOL', 'Pacific SA Standard Time');
END
GO

-- Ciudades
DECLARE @mex int, @can int;
SELECT @mex = id_pais FROM cat.Pais WHERE nombre = 'Mexico';
SELECT @can = id_pais FROM cat.Pais WHERE nombre = 'Canada';
IF NOT EXISTS (SELECT 1 FROM cat.Ciudad WHERE nombre = N'Ciudad de Mexico')
BEGIN
    IF OBJECT_ID('cat.usp_Ciudad_Alta') IS NOT NULL EXEC cat.usp_Ciudad_Alta N'Ciudad de Mexico', @mex, 'Central Standard Time (Mexico)';
    ELSE INSERT INTO cat.Ciudad (nombre, id_pais, huso_horario) VALUES (N'Ciudad de Mexico', @mex, 'Central Standard Time (Mexico)');
END
IF NOT EXISTS (SELECT 1 FROM cat.Ciudad WHERE nombre = N'Toronto')
BEGIN
    IF OBJECT_ID('cat.usp_Ciudad_Alta') IS NOT NULL EXEC cat.usp_Ciudad_Alta N'Toronto', @can, 'Eastern Standard Time';
    ELSE INSERT INTO cat.Ciudad (nombre, id_pais, huso_horario) VALUES (N'Toronto', @can, 'Eastern Standard Time');
END
GO

-- Catalogos
IF NOT EXISTS (SELECT 1 FROM comp.Fase WHERE nombre = 'Grupos')  EXEC comp.usp_Fase_Alta 'Grupos', 1, 0;
IF NOT EXISTS (SELECT 1 FROM comp.Fase WHERE nombre = 'Octavos') EXEC comp.usp_Fase_Alta 'Octavos', 3, 1;
IF NOT EXISTS (SELECT 1 FROM comp.Posicion WHERE nombre = 'Arquero')       EXEC comp.usp_Posicion_Alta 'Arquero';
IF NOT EXISTS (SELECT 1 FROM comp.Posicion WHERE nombre = 'Defensor')      EXEC comp.usp_Posicion_Alta 'Defensor';
IF NOT EXISTS (SELECT 1 FROM comp.Posicion WHERE nombre = 'Mediocampista') EXEC comp.usp_Posicion_Alta 'Mediocampista';
IF NOT EXISTS (SELECT 1 FROM comp.Posicion WHERE nombre = 'Delantero')     EXEC comp.usp_Posicion_Alta 'Delantero';
GO

-- Torneo 2042: Mexico y Canada en el grupo A, Chile sin grupo (juega octavos)
EXEC comp.usp_Torneo_Alta 'Mundial de prueba logica 2042', 2042, '2042-06-01', '2042-07-31';
GO

DECLARE @t int, @gA int, @mex int, @can int, @chi int, @cdmx int, @tor int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2042;
EXEC comp.usp_Grupo_Alta @t, 'A';
SELECT @gA = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'A';
SELECT @mex = id_pais FROM cat.Pais WHERE nombre = 'Mexico';
SELECT @can = id_pais FROM cat.Pais WHERE nombre = 'Canada';
SELECT @chi = id_pais FROM cat.Pais WHERE nombre = 'Chile';
EXEC comp.usp_Seleccion_Alta @t, @mex, @gA;
EXEC comp.usp_Seleccion_Alta @t, @can, @gA;
EXEC comp.usp_Seleccion_Alta @t, @chi, NULL;

-- Sedes propias, la de Mexico con capacidad baja a proposito
SELECT @cdmx = id_ciudad FROM cat.Ciudad WHERE nombre = N'Ciudad de Mexico';
SELECT @tor = id_ciudad FROM cat.Ciudad WHERE nombre = N'Toronto';
EXEC comp.usp_Sede_Alta N'Estadio Logica Mexico',  @cdmx, 1000,  NULL, NULL;
EXEC comp.usp_Sede_Alta N'Estadio Logica Toronto', @tor,  45000, NULL, NULL;
EXEC comp.usp_Sede_Alta N'Estadio Logica Extra',   @cdmx, 5000,  NULL, NULL;
GO

-- Plantel de Mexico: 01 arquero, 02-05 defensores, 06-08 mediocampistas, 09-11 delanteros, 12 suplente
DECLARE @t int, @pais int, @sel int, @arq int, @def int, @med int, @del int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2042;
SELECT @pais = id_pais FROM cat.Pais WHERE nombre = 'Mexico';
SELECT @sel = id_seleccion FROM comp.Seleccion WHERE id_torneo = @t AND id_pais = @pais;
SELECT @arq = id_posicion FROM comp.Posicion WHERE nombre = 'Arquero';
SELECT @def = id_posicion FROM comp.Posicion WHERE nombre = 'Defensor';
SELECT @med = id_posicion FROM comp.Posicion WHERE nombre = 'Mediocampista';
SELECT @del = id_posicion FROM comp.Posicion WHERE nombre = 'Delantero';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Mexico 01', '1998-01-01', @pais, 'DNI', 'L2-M01', @arq, @sel,  1, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Mexico 02', '1998-01-01', @pais, 'DNI', 'L2-M02', @def, @sel,  2, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Mexico 03', '1998-01-01', @pais, 'DNI', 'L2-M03', @def, @sel,  3, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Mexico 04', '1998-01-01', @pais, 'DNI', 'L2-M04', @def, @sel,  4, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Mexico 05', '1998-01-01', @pais, 'DNI', 'L2-M05', @def, @sel,  5, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Mexico 06', '1998-01-01', @pais, 'DNI', 'L2-M06', @med, @sel,  6, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Mexico 07', '1998-01-01', @pais, 'DNI', 'L2-M07', @med, @sel,  7, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Mexico 08', '1998-01-01', @pais, 'DNI', 'L2-M08', @med, @sel,  8, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Mexico 09', '1998-01-01', @pais, 'DNI', 'L2-M09', @del, @sel,  9, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Mexico 10', '1998-01-01', @pais, 'DNI', 'L2-M10', @del, @sel, 10, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Mexico 11', '1998-01-01', @pais, 'DNI', 'L2-M11', @del, @sel, 11, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Mexico 12', '1998-01-01', @pais, 'DNI', 'L2-M12', @med, @sel, 12, NULL, '2042-05-20';
GO
-- Plantel de Canada: 01 arquero, 02-05 defensores, 06-08 mediocampistas, 09-11 delanteros, 12 suplente
DECLARE @t int, @pais int, @sel int, @arq int, @def int, @med int, @del int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2042;
SELECT @pais = id_pais FROM cat.Pais WHERE nombre = 'Canada';
SELECT @sel = id_seleccion FROM comp.Seleccion WHERE id_torneo = @t AND id_pais = @pais;
SELECT @arq = id_posicion FROM comp.Posicion WHERE nombre = 'Arquero';
SELECT @def = id_posicion FROM comp.Posicion WHERE nombre = 'Defensor';
SELECT @med = id_posicion FROM comp.Posicion WHERE nombre = 'Mediocampista';
SELECT @del = id_posicion FROM comp.Posicion WHERE nombre = 'Delantero';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Canada 01', '1998-01-01', @pais, 'DNI', 'L2-C01', @arq, @sel,  1, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Canada 02', '1998-01-01', @pais, 'DNI', 'L2-C02', @def, @sel,  2, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Canada 03', '1998-01-01', @pais, 'DNI', 'L2-C03', @def, @sel,  3, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Canada 04', '1998-01-01', @pais, 'DNI', 'L2-C04', @def, @sel,  4, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Canada 05', '1998-01-01', @pais, 'DNI', 'L2-C05', @def, @sel,  5, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Canada 06', '1998-01-01', @pais, 'DNI', 'L2-C06', @med, @sel,  6, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Canada 07', '1998-01-01', @pais, 'DNI', 'L2-C07', @med, @sel,  7, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Canada 08', '1998-01-01', @pais, 'DNI', 'L2-C08', @med, @sel,  8, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Canada 09', '1998-01-01', @pais, 'DNI', 'L2-C09', @del, @sel,  9, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Canada 10', '1998-01-01', @pais, 'DNI', 'L2-C10', @del, @sel, 10, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Canada 11', '1998-01-01', @pais, 'DNI', 'L2-C11', @del, @sel, 11, NULL, '2042-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Jugador', 'Canada 12', '1998-01-01', @pais, 'DNI', 'L2-C12', @med, @sel, 12, NULL, '2042-05-20';
GO


/* =================================================================
   1. usp_Partido_Registrar
   ================================================================= */

-- PR1. OK: partido 1 de grupos (Mexico - Canada) y partido 2 de octavos (Mexico - Chile)
DECLARE @t int, @gA int, @fg int, @fo int, @mex int, @can int, @chi int, @s_mex int, @s_can int, @s_chi int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2042;
SELECT @gA = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'A';
SELECT @fg = id_fase FROM comp.Fase WHERE nombre = 'Grupos';
SELECT @fo = id_fase FROM comp.Fase WHERE nombre = 'Octavos';
SELECT @s_mex = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Mexico';
SELECT @s_can = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Canada';
SELECT @s_chi = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Chile';
DECLARE @sm int, @st int;
SELECT @sm = id_sede FROM comp.Sede WHERE nombre_estadio = N'Estadio Logica Mexico';
SELECT @st = id_sede FROM comp.Sede WHERE nombre_estadio = N'Estadio Logica Toronto';
EXEC comp.usp_Partido_Registrar @t, 1, @fg, @gA, @sm, '2042-06-10 19:00', @s_mex, @s_can;
EXEC comp.usp_Partido_Registrar @t, 2, @fo, NULL, @st, '2042-06-20 20:00', @s_mex, @s_chi;

SELECT p.nro_partido, p.id_grupo, p.fecha_hora_local, p.estado, ps.condicion, pa.nombre AS seleccion
FROM comp.Partido p
JOIN comp.PartidoSeleccion ps ON ps.id_partido = p.id_partido
JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = @t ORDER BY p.nro_partido, ps.condicion;
/* Esperado: 4 filas, PROGRAMADO
   1 | grupo A | 2042-06-10 13:00 | L Mexico / V Canada
   2 | NULL    | 2042-06-20 16:00 | L Mexico / V Chile */
GO

-- PR2. ERROR (validaciones propias): Mexico contra Mexico, y Mexico ya juega el 2042-06-10
DECLARE @t int, @gA int, @fg int, @fo int, @mex int, @can int, @chi int, @s_mex int, @s_can int, @s_chi int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2042;
SELECT @gA = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'A';
SELECT @fg = id_fase FROM comp.Fase WHERE nombre = 'Grupos';
SELECT @fo = id_fase FROM comp.Fase WHERE nombre = 'Octavos';
SELECT @s_mex = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Mexico';
SELECT @s_can = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Canada';
SELECT @s_chi = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Chile';
DECLARE @se int;
SELECT @se = id_sede FROM comp.Sede WHERE nombre_estadio = N'Estadio Logica Extra';
EXEC comp.usp_Partido_Registrar @t, 3, @fg, @gA, @se, '2042-06-10 23:00', @s_mex, @s_mex;
/* Esperado, error 50904:
   usp_Partido_Registrar: - Local y visitante no pueden ser la misma seleccion.
   - La seleccion local ya juega otro partido ese dia.
   - La seleccion visitante ya juega otro partido ese dia. */
GO

-- PR3. ERROR (lo lanza usp_Partido_Alta): sede inexistente, numero repetido, grupos sin grupo
DECLARE @t int, @gA int, @fg int, @fo int, @mex int, @can int, @chi int, @s_mex int, @s_can int, @s_chi int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2042;
SELECT @gA = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'A';
SELECT @fg = id_fase FROM comp.Fase WHERE nombre = 'Grupos';
SELECT @fo = id_fase FROM comp.Fase WHERE nombre = 'Octavos';
SELECT @s_mex = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Mexico';
SELECT @s_can = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Canada';
SELECT @s_chi = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Chile';
EXEC comp.usp_Partido_Registrar @t, 1, @fg, NULL, 9999, '2042-06-11 19:00', @s_mex, @s_can;
/* Esperado, error 50151 (lo lanza el ABM):
   usp_Partido_Alta: - La sede no existe. - Ya existe ese numero de partido en el torneo.
   - Un partido de fase de grupos debe indicar el grupo. */
GO

-- PR4. ERROR DENTRO DE LA TRANSACCION (lo lanza usp_PartidoSeleccion_Alta): partido 3
--      del grupo A con Chile, que no es del grupo. El partido 3 se llega a crear,
--      falla la asignacion de Chile y la transaccion deshace el partido.
DECLARE @t int, @gA int, @fg int, @fo int, @mex int, @can int, @chi int, @s_mex int, @s_can int, @s_chi int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2042;
SELECT @gA = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'A';
SELECT @fg = id_fase FROM comp.Fase WHERE nombre = 'Grupos';
SELECT @fo = id_fase FROM comp.Fase WHERE nombre = 'Octavos';
SELECT @s_mex = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Mexico';
SELECT @s_can = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Canada';
SELECT @s_chi = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Chile';
DECLARE @se int;
SELECT @se = id_sede FROM comp.Sede WHERE nombre_estadio = N'Estadio Logica Extra';
EXEC comp.usp_Partido_Registrar @t, 3, @fg, @gA, @se, '2042-06-15 19:00', @s_chi, @s_can;
/* Esperado, error 50161 (lo lanza el ABM):
   usp_PartidoSeleccion_Alta: - La seleccion no pertenece al grupo del partido. */
GO

SELECT COUNT(*) AS partido_3 FROM comp.Partido
WHERE nro_partido = 3 AND id_torneo = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2042);
-- Esperado: 0 (el partido no quedo creado)
GO


/* =================================================================
   2. usp_Partido_RegistrarResultado
   Partido 1: grupos, sede con capacidad 1000. Partido 2: octavos.
   ================================================================= */

-- RR1. OK: partido 1, Mexico 2 - Canada 1, 950 espectadores
DECLARE @p int;
SELECT @p = id_partido FROM comp.Partido WHERE nro_partido = 1 AND id_torneo = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2042);
EXEC comp.usp_Partido_RegistrarResultado @p, 2, 1, NULL, NULL, 950;
SELECT p.estado, p.asistencia, ps.condicion, ps.goles, ps.goles_penales
FROM comp.Partido p JOIN comp.PartidoSeleccion ps ON ps.id_partido = p.id_partido
WHERE p.id_partido = @p ORDER BY ps.condicion;
-- Esperado: FINALIZADO, 950: L 2 / V 1 (penales NULL)
GO

-- RR2. ERROR: partido 1 ya finalizado, asistencia mayor a la capacidad y penales en grupos
DECLARE @p int;
SELECT @p = id_partido FROM comp.Partido WHERE nro_partido = 1 AND id_torneo = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2042);
EXEC comp.usp_Partido_RegistrarResultado @p, 1, 1, 4, 3, 5000;
/* Esperado, error 50905:
   usp_Partido_RegistrarResultado: - El partido ya tiene el resultado cargado.
   - La asistencia debe estar entre 0 y la capacidad de la sede.
   - En fase de grupos no hay penales. */
GO

-- RR3. ERROR: partido de eliminacion empatado sin penales
DECLARE @p int;
SELECT @p = id_partido FROM comp.Partido WHERE nro_partido = 2 AND id_torneo = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2042);
EXEC comp.usp_Partido_RegistrarResultado @p, 1, 1, NULL, NULL, 30000;
/* Esperado, error 50905:
   usp_Partido_RegistrarResultado: - Un partido eliminatorio empatado necesita el resultado de los penales */
GO

-- RR4. ERROR: penales con un ganador en el partido, y penales empatados
DECLARE @p int;
SELECT @p = id_partido FROM comp.Partido WHERE nro_partido = 2 AND id_torneo = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2042);
EXEC comp.usp_Partido_RegistrarResultado @p, 2, 1, 3, 3, 30000;
/* Esperado, error 50905:
   usp_Partido_RegistrarResultado: - Solo hay penales si el partido termino empatado
   - Los penales no pueden terminar empatados. */
GO

-- RR5. ERROR: partido inexistente y falta un resultado
EXEC comp.usp_Partido_RegistrarResultado 9999, NULL, 1, NULL, NULL, NULL;
/* Esperado, error 50905:
   usp_Partido_RegistrarResultado: - El partido no existe.
   - Los goles de los dos equipos son obligatorios */
GO

-- RR6. OK: partido 2, Mexico 1 (4) - Chile 1 (2), 40000 espectadores
DECLARE @p int;
SELECT @p = id_partido FROM comp.Partido WHERE nro_partido = 2 AND id_torneo = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2042);
EXEC comp.usp_Partido_RegistrarResultado @p, 1, 1, 4, 2, 40000;
SELECT p.estado, p.asistencia, ps.condicion, ps.goles, ps.goles_penales
FROM comp.Partido p JOIN comp.PartidoSeleccion ps ON ps.id_partido = p.id_partido
WHERE p.id_partido = @p ORDER BY ps.condicion;
-- Esperado: FINALIZADO, 40000: L 1 (4) / V 1 (2)
GO


/* =================================================================
   3. usp_Partido_RegistrarFormaciones + FLUJO COMPLETO
   Partido 4: Mexico - Canada, grupo A
   ================================================================= */

-- Se registra el partido 4
DECLARE @t int, @gA int, @fg int, @fo int, @mex int, @can int, @chi int, @s_mex int, @s_can int, @s_chi int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2042;
SELECT @gA = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'A';
SELECT @fg = id_fase FROM comp.Fase WHERE nombre = 'Grupos';
SELECT @fo = id_fase FROM comp.Fase WHERE nombre = 'Octavos';
SELECT @s_mex = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Mexico';
SELECT @s_can = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Canada';
SELECT @s_chi = s.id_seleccion FROM comp.Seleccion s JOIN cat.Pais pa ON pa.id_pais = s.id_pais WHERE s.id_torneo = @t AND pa.nombre = 'Chile';
DECLARE @se int;
SELECT @se = id_sede FROM comp.Sede WHERE nombre_estadio = N'Estadio Logica Extra';
EXEC comp.usp_Partido_Registrar @t, 4, @fg, @gA, @se, '2042-06-14 19:00', @s_mex, @s_can;
GO

-- FO1. ERROR: todavia no se cargo ningun jugador y el esquema del visitante suma 11
DECLARE @p int;
SELECT @p = id_partido FROM comp.Partido WHERE nro_partido = 4 AND id_torneo = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2042);
EXEC comp.usp_Partido_RegistrarFormaciones @p, '4-3-3', '4-4-3';
/* Esperado, error 50906:
   usp_Partido_RegistrarFormaciones: - El local no tiene 11 titulares.
   - El local debe tener exactamente un arquero titular. - El local no tiene suplentes en el banco.
   - El esquema del visitante debe sumar 10 jugadores de campo. - El visitante no tiene 11 titulares.
   - El visitante debe tener exactamente un arquero titular. - El visitante no tiene suplentes en el banco. */
GO

-- Alineacion de Mexico en el partido 4: 11 titulares en 4-3-3 y 1 suplente
DECLARE @t int, @ps int, @c int, @arq int, @def int, @med int, @del int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2042;
SELECT @ps = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
JOIN comp.Partido p ON p.id_partido = ps.id_partido JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
WHERE p.id_torneo = @t AND p.nro_partido = 4 AND s.id_pais = (SELECT id_pais FROM cat.Pais WHERE nombre = 'Mexico');
SELECT @arq = id_posicion FROM comp.Posicion WHERE nombre = 'Arquero';
SELECT @def = id_posicion FROM comp.Posicion WHERE nombre = 'Defensor';
SELECT @med = id_posicion FROM comp.Posicion WHERE nombre = 'Mediocampista';
SELECT @del = id_posicion FROM comp.Posicion WHERE nombre = 'Delantero';
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-M01'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @arq;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-M02'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @def;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-M03'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @def;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-M04'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @def;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-M05'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @def;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-M06'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @med;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-M07'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @med;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-M08'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @med;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-M09'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @del;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-M10'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @del;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-M11'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @del;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-M12'; EXEC comp.usp_Alineacion_Alta @ps, @c, 0, NULL;
GO

-- Alineacion de Canada en el partido 4: 11 titulares en 4-3-3 y 1 suplente
DECLARE @t int, @ps int, @c int, @arq int, @def int, @med int, @del int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2042;
SELECT @ps = ps.id_partido_seleccion FROM comp.PartidoSeleccion ps
JOIN comp.Partido p ON p.id_partido = ps.id_partido JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
WHERE p.id_torneo = @t AND p.nro_partido = 4 AND s.id_pais = (SELECT id_pais FROM cat.Pais WHERE nombre = 'Canada');
SELECT @arq = id_posicion FROM comp.Posicion WHERE nombre = 'Arquero';
SELECT @def = id_posicion FROM comp.Posicion WHERE nombre = 'Defensor';
SELECT @med = id_posicion FROM comp.Posicion WHERE nombre = 'Mediocampista';
SELECT @del = id_posicion FROM comp.Posicion WHERE nombre = 'Delantero';
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-C01'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @arq;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-C02'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @def;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-C03'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @def;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-C04'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @def;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-C05'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @def;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-C06'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @med;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-C07'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @med;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-C08'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @med;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-C09'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @del;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-C10'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @del;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-C11'; EXEC comp.usp_Alineacion_Alta @ps, @c, 1, @del;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L2-C12'; EXEC comp.usp_Alineacion_Alta @ps, @c, 0, NULL;
GO

-- FO2. ERROR: el local dice 3-5-2 pero puso 4-3-3; el esquema del visitante esta mal escrito
DECLARE @p int;
SELECT @p = id_partido FROM comp.Partido WHERE nro_partido = 4 AND id_torneo = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2042);
EXEC comp.usp_Partido_RegistrarFormaciones @p, '3-5-2', '433';
/* Esperado, error 50906:
   usp_Partido_RegistrarFormaciones: - Los titulares del local no coinciden con el esquema (defensores, mediocampistas, delanteros).
   - El esquema del visitante tiene un formato invalido (ej: 4-3-3 o 3-4-1-2). */
GO

-- FO3. OK: Mexico 4-3-3 y Canada 4-2-1-3 (4 defensores, 2+1 medios, 3 delanteros)
DECLARE @p int;
SELECT @p = id_partido FROM comp.Partido WHERE nro_partido = 4 AND id_torneo = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2042);
EXEC comp.usp_Partido_RegistrarFormaciones @p, '4-3-3', '4-2-1-3';
SELECT p.estado, ps.condicion, ps.esquema_tactico,
       (SELECT COUNT(*) FROM comp.Alineacion a WHERE a.id_partido_seleccion = ps.id_partido_seleccion AND a.es_titular = 1) AS titulares,
       (SELECT COUNT(*) FROM comp.Alineacion a WHERE a.id_partido_seleccion = ps.id_partido_seleccion AND a.es_titular = 0) AS suplentes
FROM comp.Partido p JOIN comp.PartidoSeleccion ps ON ps.id_partido = p.id_partido
WHERE p.id_partido = @p ORDER BY ps.condicion;
-- Esperado: EN_JUEGO: L 4-3-3 (11 titulares, 1 suplente) / V 4-2-1-3 (11, 1)
GO

-- FO4. ERROR: el partido 4 ya esta EN_JUEGO
DECLARE @p int;
SELECT @p = id_partido FROM comp.Partido WHERE nro_partido = 4 AND id_torneo = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2042);
EXEC comp.usp_Partido_RegistrarFormaciones @p, '4-4-2', '4-4-2';
/* Esperado, error 50906:
   usp_Partido_RegistrarFormaciones: - Solo se registran formaciones de un partido PROGRAMADO. */
GO

-- FLUJO COMPLETO: el partido 4 termina 0 - 0 con 4500 espectadores
DECLARE @p int;
SELECT @p = id_partido FROM comp.Partido WHERE nro_partido = 4 AND id_torneo = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2042);
EXEC comp.usp_Partido_RegistrarResultado @p, 0, 0, NULL, NULL, 4500;
GO


/* =================================================================
   RESUMEN FINAL: partidos del torneo 2042
   ================================================================= */
SELECT p.nro_partido, f.nombre AS fase, p.estado, p.asistencia,
       ps.condicion, pa.nombre AS seleccion, ps.esquema_tactico, ps.goles, ps.goles_penales
FROM comp.Partido p
JOIN comp.Fase f ON f.id_fase = p.id_fase
JOIN comp.PartidoSeleccion ps ON ps.id_partido = p.id_partido
JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
JOIN cat.Pais pa ON pa.id_pais = s.id_pais
WHERE p.id_torneo = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2042)
ORDER BY p.nro_partido, ps.condicion;
/* Esperado: 6 filas
   1 Grupos  FINALIZADO 950    L Mexico 2 / V Canada 1
   2 Octavos FINALIZADO 40000  L Mexico 1 (4) / V Chile 1 (2)
   4 Grupos  FINALIZADO 4500   L Mexico 4-3-3 0 / V Canada 4-2-1-3 0 */
GO
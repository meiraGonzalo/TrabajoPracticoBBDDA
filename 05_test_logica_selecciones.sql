/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - Testing de los SP de logica - Selecciones y convocatoria
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 11/10/2026
 Objetivo: probar los SP de logica relacionados a las tablas de selecciones y convocatoria
=====================================================================
*/

USE MundialDB;
GO

/* =================================================================
   PREPARACION
   ================================================================= */

IF NOT EXISTS (SELECT 1 FROM cat.Pais WHERE nombre = 'Argentina')
BEGIN
    IF OBJECT_ID('cat.usp_Pais_Alta') IS NOT NULL
        EXEC cat.usp_Pais_Alta 'Argentina', 'CONMEBOL', NULL, 'Argentina Standard Time';
    ELSE
        INSERT INTO cat.Pais (nombre, confederacion, huso_horario) VALUES ('Argentina', 'CONMEBOL', 'Argentina Standard Time');
END
IF NOT EXISTS (SELECT 1 FROM cat.Pais WHERE nombre = 'Brasil')
BEGIN
    IF OBJECT_ID('cat.usp_Pais_Alta') IS NOT NULL
        EXEC cat.usp_Pais_Alta 'Brasil', 'CONMEBOL', NULL, 'E. South America Standard Time';
    ELSE
        INSERT INTO cat.Pais (nombre, confederacion, huso_horario) VALUES ('Brasil', 'CONMEBOL', 'E. South America Standard Time');
END
IF NOT EXISTS (SELECT 1 FROM comp.Posicion WHERE nombre = 'Defensor')
    EXEC comp.usp_Posicion_Alta 'Defensor';
GO

-- Torneo 2038 con MIN = 2 y MAX = 3 convocados (valores bajos para probar limites)
EXEC comp.usp_Torneo_Alta 'Mundial de prueba logica 2038', 2038, '2038-06-10', '2038-07-20';
GO
DECLARE @t int, @arg int, @bra int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2038;
SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
SELECT @bra = id_pais FROM cat.Pais WHERE nombre = 'Brasil';
EXEC comp.usp_ParametroReglamento_Alta @t, 'MIN_CONVOCADOS', 2, NULL;
EXEC comp.usp_ParametroReglamento_Alta @t, 'MAX_CONVOCADOS', 3, NULL;
EXEC comp.usp_Seleccion_Alta @t, @arg, NULL;
EXEC comp.usp_Seleccion_Alta @t, @bra, NULL;
GO

-- Jugadores (con el SP de logica que se prueba en usp_Jugador_AltaCompleta):
-- AR1, AR2, AR3 convocados a Argentina; AR4 sin convocar; BR1 convocado a Brasil
DECLARE @t int, @arg int, @bra int, @s_arg int, @s_bra int, @def int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2038;
SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
SELECT @bra = id_pais FROM cat.Pais WHERE nombre = 'Brasil';
SELECT @s_arg = id_seleccion FROM comp.Seleccion WHERE id_torneo = @t AND id_pais = @arg;
SELECT @s_bra = id_seleccion FROM comp.Seleccion WHERE id_torneo = @t AND id_pais = @bra;
SELECT @def = id_posicion FROM comp.Posicion WHERE nombre = 'Defensor';
EXEC comp.usp_Jugador_AltaCompleta 'Argentino', 'Uno',    '1996-03-01', @arg, 'DNI', 'L1-AR1', @def, @s_arg, 1,    NULL, '2038-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Argentino', 'Dos',    '1996-03-01', @arg, 'DNI', 'L1-AR2', @def, @s_arg, 2,    NULL, '2038-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Argentino', 'Tres',   '1996-03-01', @arg, 'DNI', 'L1-AR3', @def, @s_arg, 3,    NULL, '2038-05-20';
EXEC comp.usp_Jugador_AltaCompleta 'Argentino', 'Cuatro', '1996-03-01', @arg, 'DNI', 'L1-AR4', @def, NULL,   NULL, NULL, NULL;
EXEC comp.usp_Jugador_AltaCompleta 'Brasileno', 'Uno',    '1996-03-01', @bra, 'DNI', 'L1-BR1', @def, @s_bra, 1,    NULL, '2038-05-20';
GO


/* =================================================================
   1. usp_Convocatoria_Reemplazar
   ================================================================= */

--1. usp_Convocatoria_Reemplazar. OK: AR3 se lesiona y lo reemplaza AR4 con el mismo dorsal (3)
DECLARE @c int, @j int;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L1-AR3';
SELECT @j = id_persona FROM comp.Persona WHERE nro_documento = 'L1-AR4';
EXEC comp.usp_Convocatoria_Reemplazar @c, @j, 3, NULL, 'Lesion', '2038-06-05', 'Desgarro';

SELECT p.nro_documento, c.dorsal, c.fecha_alta, c.fecha_baja
FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador
WHERE p.nro_documento IN ('L1-AR3', 'L1-AR4');
-- Esperado: L1-AR3 dorsal 3 con fecha_baja 2038-06-05 / L1-AR4 dorsal 3, alta 2038-06-05, sin baja
SELECT id_convocado_baja, id_convocado_alta, motivo, fecha, observacion
FROM comp.CambioConvocatoria WHERE id_convocado_baja = @c;
-- Esperado: 1 fila con los dos convocados, Lesion, 2038-06-05, Desgarro
GO

-- 2.usp_Convocatoria_Reemplazar. ERROR (validaciones propias): el que sale (AR3) ya tiene baja, motivo
--invalido y fecha posterior al fin del torneo
DECLARE @c int, @j int;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L1-AR3';
SELECT @j = id_persona FROM comp.Persona WHERE nro_documento = 'L1-BR1';
EXEC comp.usp_Convocatoria_Reemplazar @c, @j, 1, NULL, 'Cansancio', '2038-08-01', NULL;
/* Esperado:
   usp_Convocatoria_Reemplazar: - El convocado que sale ya estaba dado de baja.
   - Motivo invalido (Lesion / Enfermedad / Decision tecnica / Sancion).
   - La fecha del cambio no puede ser posterior al fin del torneo. */
GO

-- 3.usp_Convocatoria_Reemplazar. ERROR DENTRO DE LA TRANSACCION: AR2 sale bien, pero el que entra (BR1)
--esta en Brasil y el dorsal 1 lo usa AR1. Lo rechaza usp_Convocado_Alta
--despues de que AR2 ya tenia la baja -> la transaccion la deshace.
DECLARE @c int, @j int;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L1-AR2';
SELECT @j = id_persona FROM comp.Persona WHERE nro_documento = 'L1-BR1';
EXEC comp.usp_Convocatoria_Reemplazar @c, @j, 1, NULL, 'Lesion', '2038-06-06', NULL;
/* Esperado:
   usp_Convocado_Alta: - El dorsal ya lo usa otro convocado.
   - El jugador ya esta convocado en otra seleccion. */
GO
SELECT p.nro_documento, c.fecha_baja
FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador
WHERE p.nro_documento = 'L1-AR2';
-- Esperado: fecha_baja NULL (la baja se deshizo)
GO


/* =================================================================
   2. usp_CambioConvocatoria_Modificacion (ABM): caso OK
   ================================================================= */

-- 1.usp_CambioConvocatoria_Modificacion. OK: se corrige la observacion del cambio de RE1
DECLARE @cambio int;
SELECT @cambio = cc.id_cambio_convocatoria FROM comp.CambioConvocatoria cc
JOIN comp.Convocado c ON c.id_convocado = cc.id_convocado_baja
JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L1-AR3';
EXEC comp.usp_CambioConvocatoria_Modificacion @cambio, 'Lesion', 'Desgarro confirmado';
SELECT motivo, observacion FROM comp.CambioConvocatoria WHERE id_cambio_convocatoria = @cambio;
-- Esperado: Lesion, Desgarro confirmado
GO


/* =================================================================
   3. usp_Convocatoria_Baja
   Activos de Argentina: AR1, AR2, AR4 (3). Minimo = 2.
   ================================================================= */

-- 1.usp_Convocatoria_Baja. OK: baja de AR4 (quedan 2 activos = minimo)
DECLARE @c int;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L1-AR4';
EXEC comp.usp_Convocatoria_Baja @c, 'Decision tecnica', '2038-06-07', NULL;
SELECT fecha_baja FROM comp.Convocado WHERE id_convocado = @c;
-- Esperado: 2038-06-07
SELECT id_convocado_alta, motivo, fecha FROM comp.CambioConvocatoria WHERE id_convocado_baja = @c;
-- Esperado: 1 fila, id_convocado_alta NULL (baja sin reemplazo), Decision tecnica
GO

-- 2.usp_Convocatoria_Baja. ERROR: baja de AR1 dejaria a Argentina con 1 (minimo 2) y el motivo es invalido
DECLARE @c int;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L1-AR1';
EXEC comp.usp_Convocatoria_Baja @c, 'Cansancio', '2038-06-08', NULL;
/* Esperado:
   usp_Convocatoria_Baja: - Motivo invalido (Lesion / Enfermedad / Decision tecnica / Sancion).
   - La seleccion quedaria por debajo del minimo de convocados (usar el reemplazo). */
GO

-- 3.usp_Convocatoria_Baja. ERROR: AR4 ya tenia baja y no se indica fecha
DECLARE @c int;
SELECT @c = c.id_convocado FROM comp.Convocado c JOIN comp.Persona p ON p.id_persona = c.id_jugador WHERE p.nro_documento = 'L1-AR4';
EXEC comp.usp_Convocatoria_Baja @c, 'Lesion', NULL, NULL;
/* Esperado:
   usp_Convocatoria_Baja: - El convocado ya estaba dado de baja. - La fecha es obligatoria. */
GO


/* =================================================================
   4. usp_Jugador_AltaCompleta
   (los casos OK ya se ejecutaron en la PREPARACION: con y sin convocar)
   Activos de Argentina: AR1, AR2 (2). Maximo = 3.
   ================================================================= */

-- 1.usp_Jugador_AltaCompleta. Evidencia de la PREPARACION: persona + jugador (+ convocado si corresponde)
SELECT p.nro_documento, j.id_jugador, c.dorsal, c.fecha_baja
FROM comp.Persona p
JOIN comp.Jugador j ON j.id_jugador = p.id_persona
LEFT JOIN comp.Convocado c ON c.id_jugador = j.id_jugador
WHERE p.nro_documento LIKE 'L1-%' ORDER BY p.nro_documento;
-- Esperado: 5 filas (AR1..AR4 y BR1); id_jugador = id_persona
GO

-- 2.usp_Jugador_AltaCompleta. OK: jugador nuevo convocado a Argentina con el dorsal 6 (pasa a 3 activos)
DECLARE @t int, @arg int, @s_arg int, @def int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2038;
SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
SELECT @s_arg = id_seleccion FROM comp.Seleccion WHERE id_torneo = @t AND id_pais = @arg;
SELECT @def = id_posicion FROM comp.Posicion WHERE nombre = 'Defensor';
EXEC comp.usp_Jugador_AltaCompleta 'Argentino', 'Seis', '2001-02-02', @arg, 'DNI', 'L1-AR6', @def, @s_arg, 6, NULL, '2038-06-08';
SELECT p.nro_documento, c.dorsal, c.fecha_alta
FROM comp.Persona p JOIN comp.Convocado c ON c.id_jugador = p.id_persona WHERE p.nro_documento = 'L1-AR6';
-- Esperado: 1 fila, dorsal 6, alta 2038-06-08
GO

-- 3.usp_Jugador_AltaCompleta. ERROR DENTRO DE LA TRANSACCION: Argentina ya tiene el maximo (3) y el dorsal 1
--      lo usa AR1. La persona se llega a crear, falla la convocatoria y se deshace todo.
DECLARE @t int, @arg int, @s_arg int, @def int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2038;
SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
SELECT @s_arg = id_seleccion FROM comp.Seleccion WHERE id_torneo = @t AND id_pais = @arg;
SELECT @def = id_posicion FROM comp.Posicion WHERE nombre = 'Defensor';
EXEC comp.usp_Jugador_AltaCompleta 'Argentino', 'Siete', '2001-02-02', @arg, 'DNI', 'L1-AR7', @def, @s_arg, 1, NULL, '2038-06-09';
/* Esperado, error 50111 (lo lanza el ABM):
   usp_Convocado_Alta: - El dorsal ya lo usa otro convocado.
   - La seleccion ya tiene el maximo de convocados. */
GO
SELECT COUNT(*) AS personas_AR7 FROM comp.Persona WHERE nro_documento = 'L1-AR7';
-- Esperado: 0 (la persona no quedo creada)
GO

--4.usp_Jugador_AltaCompleta. ERROR (lo lanza usp_Persona_Alta): datos de la persona invalidos
EXEC comp.usp_Jugador_AltaCompleta '', NULL, '2099-01-01', 9999, 'DNI', NULL, 9999, NULL, NULL, NULL, NULL;
/* Esperado, error 50051:
   usp_Persona_Alta: - El nombre es obligatorio. - El apellido es obligatorio.
   - La fecha de nacimiento no puede ser futura. - El pais de nacionalidad no existe.
   - Tipo y numero de documento van juntos (los dos o ninguno). */
GO

-- 5.usp_Jugador_AltaCompleta. ERROR (validacion propia): dorsal y fecha de alta sin seleccion
EXEC comp.usp_Jugador_AltaCompleta 'Argentino', 'Ocho', '2000-01-01', 9999, 'DNI', 'L1-AR8', 9999, NULL, 8, NULL, '2038-06-09';
/* Esperado, error 50903:
   usp_Jugador_AltaCompleta: - Se indicaron datos de convocatoria (dorsal, club o fecha) pero no la seleccion. */
GO


/* =================================================================
   RESUMEN FINAL: convocatoria del torneo 2038
   ================================================================= */
SELECT pa.nombre AS seleccion, p.nro_documento, c.dorsal, c.fecha_baja
FROM comp.Convocado c
JOIN comp.Seleccion s ON s.id_seleccion = c.id_seleccion
JOIN cat.Pais pa ON pa.id_pais = s.id_pais
JOIN comp.Persona p ON p.id_persona = c.id_jugador
WHERE s.id_torneo = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2038)
ORDER BY pa.nombre, c.fecha_baja, c.dorsal;
/* Esperado: 6 filas
   Argentina activos: L1-AR1 (1), L1-AR2 (2), L1-AR6 (6)
   Argentina con baja: L1-AR3 (2038-06-05), L1-AR4 (2038-06-07)
   Brasil: L1-BR1 (1) */
GO
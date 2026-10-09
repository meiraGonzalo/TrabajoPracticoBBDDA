/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - 03: Testing de los SP de ABM - Selecciones y convocatoria
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana (nickGithub: tatimendez)
              Rocha Escalera, Sheila Belisa nickGithub: sheilarocha02
 Fecha: 08/10/2026
 Objetivo: probar todos los SP de ABM. Por cada SP hay
           casos OK y casos que disparan las validaciones

 COMO CORRERLO:
   1) Ejecutar 00 y 01 (base recien creada, vacia).
   2) Ejecutar el script de SP de ABM 
   3) Ejecutar este script completo 

=====================================================================
*/

USE MundialDB;
GO

/* 
   PREPARACION: PAISES. 
   cat.Pais: uso un INSERT de respaldo SOLO para poder probar. Ese respaldo deja de
   ejecutarse automaticamente en cuanto exista cat.usp_Pais_Alta
   (OBJECT_ID devuelve NULL si el SP no existe).

*/

 ---Alta----

IF (SELECT COUNT(*) FROM cat.Pais WHERE nombre = 'Argentina') = 0
BEGIN
    IF OBJECT_ID('cat.usp_Pais_Alta') IS NOT NULL
        EXEC cat.usp_Pais_Alta @nombre = 'Argentina', @confederacion = 'CONMEBOL',
                               @id_moneda = NULL, @huso_horario = 'Argentina Standard Time';
    ELSE
        INSERT INTO cat.Pais (nombre, confederacion, huso_horario) VALUES ('Argentina', 'CONMEBOL', 'Argentina Standard Time');
END
GO

IF (SELECT COUNT(*) FROM cat.Pais WHERE nombre = 'Brasil') = 0
BEGIN
    IF OBJECT_ID('cat.usp_Pais_Alta') IS NOT NULL
        EXEC cat.usp_Pais_Alta @nombre = 'Brasil', @confederacion = 'CONMEBOL',
                               @id_moneda = NULL, @huso_horario = 'E. South America Standard Time';
    ELSE
        INSERT INTO cat.Pais (nombre, confederacion, huso_horario) VALUES ('Brasil', 'CONMEBOL', 'E. South America Standard Time');
END
GO

IF (SELECT COUNT(*) FROM cat.Pais WHERE nombre = 'Uruguay') = 0
BEGIN
    IF OBJECT_ID('cat.usp_Pais_Alta') IS NOT NULL
        EXEC cat.usp_Pais_Alta @nombre = 'Uruguay', @confederacion = 'CONMEBOL',
                               @id_moneda = NULL, @huso_horario = 'Montevideo Standard Time';
    ELSE
        INSERT INTO cat.Pais (nombre, confederacion, huso_horario) VALUES ('Uruguay', 'CONMEBOL', 'Montevideo Standard Time');
END
GO

select * from cat.Pais

IF (SELECT COUNT(*) FROM cat.Pais WHERE nombre = 'Pais Sin Confederacion') = 0
BEGIN
    IF OBJECT_ID('cat.usp_Pais_Alta') IS NOT NULL
        EXEC cat.usp_Pais_Alta @nombre = 'Pais Sin Confederacion', @confederacion = NULL,
                               @id_moneda = NULL, @huso_horario = 'UTC';
    ELSE
        INSERT INTO cat.Pais (nombre, confederacion, huso_horario) VALUES ('Pais Sin Confederacion', NULL, 'UTC');
END
GO



-- Se cargaron 4 paises antes
SELECT id_pais, nombre, confederacion, huso_horario
FROM cat.Pais
WHERE nombre IN ('Argentina', 'Brasil', 'Uruguay', 'Pais Sin Confederacion');
-- Se espera: 4 filas
GO


/* =================================================================
   1. POSICION
   ================================================================= */

-- Alta ok
EXEC comp.usp_Posicion_Alta 'Arquero';
EXEC comp.usp_Posicion_Alta 'Defensor';
EXEC comp.usp_Posicion_Alta 'Mediocampista';
EXEC comp.usp_Posicion_Alta 'Delantero';

SELECT * FROM comp.Posicion;
-- Esperado: 4 filas (Arquero, Defensor, Mediocampista, Delantero)
GO

-- Alta ERROR: nombre vacio
EXEC comp.usp_Posicion_Alta '';
/* usp_Posicion_Alta: - El nombre es obligatorio. */
GO

-- ALTA ERROR: posicion repetida
EXEC comp.usp_Posicion_Alta 'Arquero';
/* usp_Posicion_Alta: - Ya existe esa posicion. */
GO

-- MODIFICACION OK: Mediocampista pasa a llamarse Volante
DECLARE @id int;
SELECT @id = id_posicion FROM comp.Posicion WHERE nombre = 'Mediocampista';
EXEC comp.usp_Posicion_Modificacion @id, 'Volante';

SELECT * FROM comp.Posicion WHERE id_posicion = @id;
-- Esperado: 1 fila con nombre 'Volante'
GO

-- MODIFICACION ERROR: posicion inexistente y nombre de otra posicion
EXEC comp.usp_Posicion_Modificacion 9999, 'Arquero';
/*  usp_Posicion_Modificacion: - La posicion no existe. - Otra posicion ya usa ese nombre. */
GO


/* =================================================================
   2. FASE
   ================================================================= */

-- ALTA OK: las 7 fases del torneo
EXEC comp.usp_Fase_Alta 'Grupos',        1, 0;
EXEC comp.usp_Fase_Alta 'Dieciseisavos', 2, 1;
EXEC comp.usp_Fase_Alta 'Octavos',       3, 1;
EXEC comp.usp_Fase_Alta 'Cuartos',       4, 1;
EXEC comp.usp_Fase_Alta 'Semifinal',     5, 1;
EXEC comp.usp_Fase_Alta 'Tercer puesto', 6, 1;
EXEC comp.usp_Fase_Alta 'Final',         7, 1;
SELECT * FROM comp.Fase ORDER BY orden;
-- Esperado: 7 filas, Grupos con es_eliminatoria = 0 y el resto con 1
GO

-- ALTA ERROR: nombre repetido, orden fuera de rango y sin indicar si es eliminatoria
EXEC comp.usp_Fase_Alta 'Grupos', 0, NULL;
/* usp_Fase_Alta: - Ya existe una fase con ese nombre. - El orden debe estar entre 1 y 20.
   - Hay que indicar si la fase es eliminatoria. */
GO

--MODIFICACION OK: cambio de nombre
DECLARE @id int;
SELECT @id = id_fase FROM comp.Fase WHERE nombre = 'Dieciseisavos';
EXEC comp.usp_Fase_Modificacion @id, 'Dieciseisavos de final', 2, 1;
SELECT * FROM comp.Fase WHERE id_fase = @id;
-- Esperado: 1 fila con nombre 'Dieciseisavos de final'
GO

-- MODIFICACION ERROR: la Final quiere el orden 1 (lo tiene Grupos)
DECLARE @id int;
SELECT @id = id_fase FROM comp.Fase WHERE nombre = 'Final';
EXEC comp.usp_Fase_Modificacion @id, 'Final', 1, 1;

/* usp_Fase_Modificacion: - Otra fase ya usa ese orden. */
GO


/* =================================================================
   3. TORNEO
   ================================================================= */

-- ALTA OK
EXEC comp.usp_Torneo_Alta 'Copa Mundial FIFA 2026', 2026, '2026-06-11', '2026-07-19';
SELECT * FROM comp.Torneo WHERE anio = 2026;
-- Esperado: 1 fila: Copa Mundial FIFA 2026 | 2026 | 2026-06-11 | 2026-07-19
GO

-- ALTA ERROR: tres reglas rotas a la vez
EXEC comp.usp_Torneo_Alta '', 1800, '2026-07-19', '2026-06-11';
/* usp_Torneo_Alta: - El nombre es obligatorio. - El anio debe estar entre 1930 y 2100.
   - La fecha de fin es anterior a la de inicio. */
GO

-- ALTA ERROR: anio repetido
EXEC comp.usp_Torneo_Alta 'Otro torneo', 2026, '2026-06-11', '2026-07-19';
/* Esperado:
   usp_Torneo_Alta: - Ya existe un torneo para ese anio. */
GO

-- MODIFICACION OK: cambio de nombre
DECLARE @id int;
SELECT @id = id_torneo FROM comp.Torneo WHERE anio = 2026;
EXEC comp.usp_Torneo_Modificacion @id, 'Mundial 2026', 2026, '2026-06-11', '2026-07-19';
SELECT * FROM comp.Torneo WHERE anio = 2026;
-- Esperado: 1 fila con nombre 'Mundial 2026'
GO

--MODIFICACION ERROR: torneo inexistente y nombre vacio
EXEC comp.usp_Torneo_Modificacion 9999, '', 2027, '2027-01-01', '2027-02-01';
/* Esperado, error 51012:
   usp_Torneo_Modificacion: - El torneo no existe. - El nombre es obligatorio. */
GO

--MODIFICACION ERROR: ponerle a un torneo el anio de otro
EXEC comp.usp_Torneo_Alta 'Mundial 2030', 2030, '2030-06-08', '2030-07-21';
DECLARE @id int;
SELECT @id = id_torneo FROM comp.Torneo WHERE anio = 2030;
EXEC comp.usp_Torneo_Modificacion @id, 'Mundial 2030', 2026, '2030-06-08', '2030-07-21';
/* Esperado:
   usp_Torneo_Modificacion: - Otro torneo ya usa ese anio. */
GO

-- BAJA OK: el torneo 2030 no tiene nada asociado
DECLARE @id int;
SELECT @id = id_torneo FROM comp.Torneo WHERE anio = 2030;
EXEC comp.usp_Torneo_Baja @id;
SELECT * FROM comp.Torneo WHERE anio = 2030;
-- Esperado: 0 filas
GO

-- BAJA ERROR: torneo inexistente
EXEC comp.usp_Torneo_Baja 9999;
/* Esperado: usp_Torneo_Baja: - El torneo no existe. */
GO



/* =================================================================
   4. PARAMETRO REGLAMENTO
   MAX_CONVOCADOS = 2 y MAX_SELECCIONES_GRUPO = 2 a proposito,
   para poder probar los maximos sin cargar 26 jugadores.
   ================================================================= */

-- ALTA OK
DECLARE @t int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
EXEC comp.usp_ParametroReglamento_Alta @t, 'MIN_CONVOCADOS', 1, 'Minimo de convocados';
EXEC comp.usp_ParametroReglamento_Alta @t, 'MAX_CONVOCADOS', 2, 'Maximo de convocados';
EXEC comp.usp_ParametroReglamento_Alta @t, 'MAX_SELECCIONES_GRUPO', 2, 'Selecciones por grupo';
SELECT * FROM comp.ParametroReglamento WHERE id_torneo = @t;
-- Esperado: 3 filas
GO

--ALTA ERROR: torneo inexistente, clave vacia y valor negativo
EXEC comp.usp_ParametroReglamento_Alta 9999, '', -1, NULL;
/* Esperado: usp_ParametroReglamento_Alta: - El torneo no existe. - La clave es obligatoria.
   - El valor debe ser cero o mayor. */
GO

-- ALTA ERROR: parametro repetido
DECLARE @t int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
EXEC comp.usp_ParametroReglamento_Alta @t, 'MAX_CONVOCADOS', 3, NULL;
/* Esperado: usp_ParametroReglamento_Alta: - Ya existe ese parametro para el torneo. */
GO

-- MODIFICACION OK: cambio de descripcion
DECLARE @t int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
EXEC comp.usp_ParametroReglamento_Modificacion @t, 'MAX_CONVOCADOS', 2, 'Valor bajo solo para test';
SELECT * FROM comp.ParametroReglamento WHERE id_torneo = @t AND clave = 'MAX_CONVOCADOS';
-- Esperado: 1 fila con descripcion 'Valor bajo solo para test'
GO

--MODIFICACION ERROR: el minimo (5) superaria al maximo (2)
DECLARE @t int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
EXEC comp.usp_ParametroReglamento_Modificacion @t, 'MIN_CONVOCADOS', 5, NULL;
/* Esperado:
   usp_ParametroReglamento_Modificacion: - El minimo de convocados no puede superar al maximo. */
GO

-- MODIFICACION ERROR: parametro inexistente y valor negativo
DECLARE @t int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
EXEC comp.usp_ParametroReglamento_Modificacion @t, 'NO_EXISTE', -5, NULL;
/* Esperado:
   usp_ParametroReglamento_Modificacion: - El parametro no existe. - El valor debe ser cero o mayor. */
GO

-- BAJA OK: se crea un parametro de prueba y se borra
DECLARE @t int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
EXEC comp.usp_ParametroReglamento_Alta @t, 'PRUEBA', 1, NULL;
EXEC comp.usp_ParametroReglamento_Baja @t, 'PRUEBA';
SELECT * FROM comp.ParametroReglamento WHERE clave = 'PRUEBA';
-- Esperado: 0 filas
GO

-- BAJA ERROR: parametro inexistente
DECLARE @t int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
EXEC comp.usp_ParametroReglamento_Baja @t, 'NO_EXISTE';
/* Esperado:
   usp_ParametroReglamento_Baja: - El parametro no existe. */
GO


/* =================================================================
   5. GRUPO
   ================================================================= */

-- ALTA OK
DECLARE @t int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
EXEC comp.usp_Grupo_Alta @t, 'A';
EXEC comp.usp_Grupo_Alta @t, 'B';
SELECT * FROM comp.Grupo WHERE id_torneo = @t;
-- Esperado: 2 filas (A y B)
GO

-- ALTA ERROR: torneo inexistente y letra invalida
EXEC comp.usp_Grupo_Alta 9999, '1';
/* Esperado:
   usp_Grupo_Alta: - El torneo no existe. - La letra del grupo debe ser una letra de la A a la Z. */
GO

-- ALTA ERROR: grupo repetido
DECLARE @t int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
EXEC comp.usp_Grupo_Alta @t, 'A';
/* Esperado:
   usp_Grupo_Alta: - Ya existe ese grupo en el torneo. */
GO

--MODIFICACION OK: el grupo B pasa a ser C
DECLARE @t int, @g int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @g = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'B';
EXEC comp.usp_Grupo_Modificacion @g, 'C';
SELECT * FROM comp.Grupo WHERE id_grupo = @g;
-- Esperado: 1 fila con letra 'C'
GO

-- MODIFICACION ERROR: el grupo C quiere la letra A (ya existe)
DECLARE @t int, @g int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @g = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'C';
EXEC comp.usp_Grupo_Modificacion @g, 'A';
/* Esperado:
   usp_Grupo_Modificacion: - Otro grupo del torneo ya usa esa letra. */
GO


/* =================================================================
   6. PERSONA
   ================================================================= */

--ALTA OK: 3 futuros jugadores y 2 futuros integrantes de cuerpo tecnico
DECLARE @arg int;
SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
EXEC comp.usp_Persona_Alta 'Jugador', 'Uno',  '1995-01-01', @arg, 'DNI', 'T-0001';
EXEC comp.usp_Persona_Alta 'Jugador', 'Dos',  '1996-01-01', @arg, 'DNI', 'T-0002';
EXEC comp.usp_Persona_Alta 'Jugador', 'Tres', '1997-01-01', @arg, 'DNI', 'T-0003';
EXEC comp.usp_Persona_Alta 'Tecnico', 'Uno',  '1970-01-01', @arg, 'DNI', 'T-0101';
EXEC comp.usp_Persona_Alta 'Tecnico', 'Dos',  '1975-01-01', @arg, 'DNI', 'T-0102';
SELECT * FROM comp.Persona WHERE nro_documento LIKE 'T-%';
-- Esperado: 5 filas
GO

-- ALTA ERROR: nombre vacio, fecha futura, pais inexistente y documento a medias
EXEC comp.usp_Persona_Alta '', 'Apellido', '2099-01-01', 9999, 'DNI', NULL;
/* Esperado:
   usp_Persona_Alta: - El nombre es obligatorio. - La fecha de nacimiento no puede ser futura.
   - El pais de nacionalidad no existe. - Tipo y numero de documento van juntos (los dos o ninguno). */
GO

-- ALTA ERROR: documento repetido
DECLARE @arg int;
SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
EXEC comp.usp_Persona_Alta 'Otro', 'Jugador', '1990-01-01', @arg, 'DNI', 'T-0001';
/* Esperado, error 51051:
   usp_Persona_Alta: - Ya existe una persona con ese documento. */
GO

-- MODIFICACION OK: cambio de apellido
DECLARE @arg int, @p int;
SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
SELECT @p = id_persona FROM comp.Persona WHERE nro_documento = 'T-0003';
EXEC comp.usp_Persona_Modificacion @p, 'Jugador', 'Tres Modificado', '1997-01-01', @arg, 'DNI', 'T-0003';
SELECT * FROM comp.Persona WHERE id_persona = @p;
-- Esperado: 1 fila con apellido 'Tres Modificado'
GO

-- MODIFICACION ERROR: le quiere poner el documento de otra persona
DECLARE @arg int, @p int;
SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
SELECT @p = id_persona FROM comp.Persona WHERE nro_documento = 'T-0003';
EXEC comp.usp_Persona_Modificacion @p, 'Jugador', 'Tres', '1997-01-01', @arg, 'DNI', 'T-0001';
/* Esperado:
   usp_Persona_Modificacion: - Otra persona ya tiene ese documento. */
GO

-- MODIFICACION ERROR: persona inexistente
DECLARE @arg int;
SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
EXEC comp.usp_Persona_Modificacion 9999, 'Nadie', 'Nadie', '1990-01-01', @arg, NULL, NULL;
/* Esperado, error 51052:
   usp_Persona_Modificacion: - La persona no existe. */
GO


/* =================================================================
   7. JUGADOR
   ================================================================= */

--ALTA OK: las 3 personas "Jugador" pasan a ser jugadores
DECLARE @p1 int, @p2 int, @p3 int, @arq int, @def int;
SELECT @p1 = id_persona FROM comp.Persona WHERE nro_documento = 'T-0001';
SELECT @p2 = id_persona FROM comp.Persona WHERE nro_documento = 'T-0002';
SELECT @p3 = id_persona FROM comp.Persona WHERE nro_documento = 'T-0003';
SELECT @arq = id_posicion FROM comp.Posicion WHERE nombre = 'Arquero';
SELECT @def = id_posicion FROM comp.Posicion WHERE nombre = 'Defensor';
EXEC comp.usp_Jugador_Alta @p1, @arq;
EXEC comp.usp_Jugador_Alta @p2, @def;
EXEC comp.usp_Jugador_Alta @p3, @def;
SELECT * FROM comp.Jugador;
-- Esperado: 3 filas (mismos ids que las personas)
GO

-- JU2. ALTA ERROR: persona y posicion inexistentes
EXEC comp.usp_Jugador_Alta 9999, 9999;
/* Esperado:
   usp_Jugador_Alta: - La persona no existe. - La posicion no existe. */
GO

-- JU3. ALTA ERROR: la persona ya es jugador
DECLARE @p1 int, @arq int;
SELECT @p1 = id_persona FROM comp.Persona WHERE nro_documento = 'T-0001';
SELECT @arq = id_posicion FROM comp.Posicion WHERE nombre = 'Arquero';
EXEC comp.usp_Jugador_Alta @p1, @arq;
/* Esperado:
   usp_Jugador_Alta: - La persona ya esta registrada como jugador. */
GO

-- MODIFICACION OK: Jugador Dos pasa a Delantero
DECLARE @p2 int, @del int;
SELECT @p2 = id_persona FROM comp.Persona WHERE nro_documento = 'T-0002';
SELECT @del = id_posicion FROM comp.Posicion WHERE nombre = 'Delantero';
EXEC comp.usp_Jugador_Modificacion @p2, @del;
SELECT * FROM comp.Jugador WHERE id_jugador = @p2;
-- Esperado: 1 fila con la posicion de Delantero
GO

-- JU5. MODIFICACION ERROR: jugador y posicion inexistentes
EXEC comp.usp_Jugador_Modificacion 9999, 9999;
/* Esperado:
   usp_Jugador_Modificacion: - El jugador no existe. - La posicion no existe. */
GO


/* =================================================================
   8. CLUB
   ================================================================= */

-- ALTA OK
DECLARE @arg int;
SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
EXEC comp.usp_Club_Alta 'River Plate', @arg;
EXEC comp.usp_Club_Alta 'Boca Juniors', @arg;
SELECT * FROM comp.Club;
-- Esperado: 2 filas
GO

-- ALTA ERROR: nombre vacio y pais inexistente
EXEC comp.usp_Club_Alta '', 9999;
/* Esperado:
   usp_Club_Alta: - El nombre es obligatorio. - El pais no existe. */
GO

--ALTA ERROR: club repetido en el mismo pais
DECLARE @arg int;
SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
EXEC comp.usp_Club_Alta 'River Plate', @arg;
/* Esperado:
   usp_Club_Alta: - Ya existe ese club en el pais. */
GO

--MODIFICACION OK: cambio de nombre
DECLARE @arg int, @c int;
SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
SELECT @c = id_club FROM comp.Club WHERE nombre = 'Boca Juniors';
EXEC comp.usp_Club_Modificacion @c, 'Boca Jrs', @arg;
SELECT * FROM comp.Club WHERE id_club = @c;
-- Esperado: 1 fila con nombre 'Boca Jrs'
GO

-- CL5. MODIFICACION ERROR: le quiere poner el nombre de otro club del mismo pais
DECLARE @arg int, @c int;
SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
SELECT @c = id_club FROM comp.Club WHERE nombre = 'Boca Jrs';
EXEC comp.usp_Club_Modificacion @c, 'River Plate', @arg;
/* Esperado:
   usp_Club_Modificacion: - Otro club del pais ya usa ese nombre. */
GO


/* =================================================================
   9. SELECCION
   ================================================================= */

-- ALTA OK: Argentina y Brasil en el grupo A, Uruguay sin grupo
DECLARE @t int, @gA int, @arg int, @bra int, @uru int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @gA = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'A';
SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
SELECT @bra = id_pais FROM cat.Pais WHERE nombre = 'Brasil';
SELECT @uru = id_pais FROM cat.Pais WHERE nombre = 'Uruguay';
EXEC comp.usp_Seleccion_Alta @t, @arg, @gA;
EXEC comp.usp_Seleccion_Alta @t, @bra, @gA;
EXEC comp.usp_Seleccion_Alta @t, @uru, NULL;
SELECT * FROM comp.Seleccion WHERE id_torneo = @t;
-- Esperado: 3 filas (Argentina y Brasil con grupo A, Uruguay con grupo NULL)
GO

--ALTA ERROR: torneo inexistente, pais sin confederacion y grupo de otro torneo
DECLARE @t int, @gA int, @sc int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @gA = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'A';
SELECT @sc = id_pais FROM cat.Pais WHERE nombre = 'Pais Sin Confederacion';
EXEC comp.usp_Seleccion_Alta 9999, @sc, @gA;
/* Esperado:
   usp_Seleccion_Alta: - El torneo no existe. - El pais no tiene confederacion cargada.
   - El grupo no existe o es de otro torneo. */
GO

--ALTA ERROR: Argentina ya tiene seleccion en el torneo
DECLARE @t int, @arg int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
EXEC comp.usp_Seleccion_Alta @t, @arg, NULL;
/* Esperado, error 51091:
   usp_Seleccion_Alta: - Ese pais ya tiene seleccion en el torneo. */
GO

-- ALTA ERROR: pais sin confederacion y grupo A completo (MAX_SELECCIONES_GRUPO = 2)
DECLARE @t int, @gA int, @sc int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @gA = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'A';
SELECT @sc = id_pais FROM cat.Pais WHERE nombre = 'Pais Sin Confederacion';
EXEC comp.usp_Seleccion_Alta @t, @sc, @gA;
/* Esperado
   usp_Seleccion_Alta: - El pais no tiene confederacion cargada. - El grupo ya esta completo. */
GO

-- MODIFICACION OK: Uruguay pasa al grupo C
DECLARE @t int, @gC int, @s int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @gC = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'C';
SELECT @s = s.id_seleccion FROM comp.Seleccion s INNER JOIN cat.Pais p ON p.id_pais = s.id_pais
WHERE p.nombre = 'Uruguay' AND s.id_torneo = @t;
EXEC comp.usp_Seleccion_Modificacion @s, @gC;
SELECT * FROM comp.Seleccion WHERE id_seleccion = @s;
-- Esperado: 1 fila con el grupo C
GO

-- MODIFICACION ERROR: Uruguay quiere pasar al grupo A (completo)
DECLARE @t int, @gA int, @s int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @gA = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'A';
SELECT @s = s.id_seleccion FROM comp.Seleccion s INNER JOIN cat.Pais p ON p.id_pais = s.id_pais
WHERE p.nombre = 'Uruguay' AND s.id_torneo = @t;
EXEC comp.usp_Seleccion_Modificacion @s, @gA;
/* Esperado:
   usp_Seleccion_Modificacion: - El grupo ya esta completo. */
GO

--MODIFICACION ERROR: seleccion inexistente
EXEC comp.usp_Seleccion_Modificacion 9999, NULL;
/* Esperado:
   usp_Seleccion_Modificacion: - La seleccion no existe. */
GO


/* =================================================================
   10. CUERPO TECNICO
   ================================================================= */

--ALTA OK: Tecnico Uno es DT de Argentina y Tecnico Dos es ayudante
DECLARE @t int, @s int, @dt1 int, @dt2 int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @s = s.id_seleccion FROM comp.Seleccion s INNER JOIN cat.Pais p ON p.id_pais = s.id_pais
WHERE p.nombre = 'Argentina' AND s.id_torneo = @t;
SELECT @dt1 = id_persona FROM comp.Persona WHERE nro_documento = 'T-0101';
SELECT @dt2 = id_persona FROM comp.Persona WHERE nro_documento = 'T-0102';
EXEC comp.usp_CuerpoTecnico_Alta @s, @dt1, 'Director Tecnico';
EXEC comp.usp_CuerpoTecnico_Alta @s, @dt2, 'Ayudante de Campo';
SELECT * FROM comp.CuerpoTecnico WHERE id_seleccion = @s;
-- Esperado: 2 filas
GO

--ALTA ERROR: Tecnico Dos ya esta en Argentina y ademas ya hay DT
DECLARE @t int, @s int, @dt2 int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @s = s.id_seleccion FROM comp.Seleccion s INNER JOIN cat.Pais p ON p.id_pais = s.id_pais
WHERE p.nombre = 'Argentina' AND s.id_torneo = @t;
SELECT @dt2 = id_persona FROM comp.Persona WHERE nro_documento = 'T-0102';
EXEC comp.usp_CuerpoTecnico_Alta @s, @dt2, 'Director Tecnico';
/* Esperado:
   usp_CuerpoTecnico_Alta: - La persona ya integra el cuerpo tecnico de esta seleccion.
   - La seleccion ya tiene director tecnico. */
GO

-- ALTA ERROR: seleccion y persona inexistentes, rol invalido
EXEC comp.usp_CuerpoTecnico_Alta 9999, 9999, 'Utilero';
/* Esperado, error 51101:
   usp_CuerpoTecnico_Alta: - La seleccion no existe. - La persona no existe.
   - Rol invalido (Director Tecnico / Ayudante de Campo / Preparador Fisico). */
GO

-- ALTA ERROR: Tecnico Uno (DT de Argentina) no puede estar tambien en Brasil
DECLARE @t int, @s int, @dt1 int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @s = s.id_seleccion FROM comp.Seleccion s INNER JOIN cat.Pais p ON p.id_pais = s.id_pais
WHERE p.nombre = 'Brasil' AND s.id_torneo = @t;
SELECT @dt1 = id_persona FROM comp.Persona WHERE nro_documento = 'T-0101';
EXEC comp.usp_CuerpoTecnico_Alta @s, @dt1, 'Ayudante de Campo';
/* Esperado:
   usp_CuerpoTecnico_Alta: - La persona ya integra el cuerpo tecnico de otra seleccion del torneo. */
GO

-- MODIFICACION OK: Tecnico Dos pasa a Preparador Fisico
DECLARE @ct int;
SELECT @ct = ct.id_cuerpo_tecnico FROM comp.CuerpoTecnico ct
INNER JOIN comp.Persona p ON p.id_persona = ct.id_persona WHERE p.nro_documento = 'T-0102';
EXEC comp.usp_CuerpoTecnico_Modificacion @ct, 'Preparador Fisico';
SELECT * FROM comp.CuerpoTecnico WHERE id_cuerpo_tecnico = @ct;
-- Esperado: 1 fila con rol 'Preparador Fisico'
GO

-- MODIFICACION ERROR: Tecnico Dos no puede ser DT (ya hay uno)
DECLARE @ct int;
SELECT @ct = ct.id_cuerpo_tecnico FROM comp.CuerpoTecnico ct
INNER JOIN comp.Persona p ON p.id_persona = ct.id_persona WHERE p.nro_documento = 'T-0102';
EXEC comp.usp_CuerpoTecnico_Modificacion @ct, 'Director Tecnico';
/* Esperado, error 51102:
   usp_CuerpoTecnico_Modificacion: - La seleccion ya tiene director tecnico. */
GO


/* =================================================================
   11. CONVOCADO (MAX_CONVOCADOS = 2)
   ================================================================= */

-- ALTA OK: Jugador Uno a Argentina con el dorsal 10 y club River
DECLARE @t int, @s int, @j1 int, @club int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @s = s.id_seleccion FROM comp.Seleccion s INNER JOIN cat.Pais p ON p.id_pais = s.id_pais
WHERE p.nombre = 'Argentina' AND s.id_torneo = @t;
SELECT @j1 = id_persona FROM comp.Persona WHERE nro_documento = 'T-0001';
SELECT @club = id_club FROM comp.Club WHERE nombre = 'River Plate';
EXEC comp.usp_Convocado_Alta @s, @j1, 10, @club, '2026-06-01';
SELECT * FROM comp.Convocado WHERE id_seleccion = @s;
-- Esperado: 1 fila: Jugador Uno, dorsal 10, fecha_baja NULL
GO

-- ALTA ERROR: mismo jugador, mismo dorsal y club inexistente
DECLARE @t int, @s int, @j1 int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @s = s.id_seleccion FROM comp.Seleccion s INNER JOIN cat.Pais p ON p.id_pais = s.id_pais
WHERE p.nombre = 'Argentina' AND s.id_torneo = @t;
SELECT @j1 = id_persona FROM comp.Persona WHERE nro_documento = 'T-0001';
EXEC comp.usp_Convocado_Alta @s, @j1, 10, 9999, '2026-06-01';
/* Esperado:
   usp_Convocado_Alta: - El dorsal ya lo usa otro convocado. - El jugador ya esta en esta seleccion.
   - El club no existe. */
GO

-- ALTA ERROR: Jugador Uno ya esta en Argentina, no puede ir a Brasil
DECLARE @t int, @s int, @j1 int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @s = s.id_seleccion FROM comp.Seleccion s INNER JOIN cat.Pais p ON p.id_pais = s.id_pais
WHERE p.nombre = 'Brasil' AND s.id_torneo = @t;
SELECT @j1 = id_persona FROM comp.Persona WHERE nro_documento = 'T-0001';
EXEC comp.usp_Convocado_Alta @s, @j1, 10, NULL, '2026-06-01';
/* Esperado:
   usp_Convocado_Alta: - El jugador ya esta convocado en otra seleccion. */
GO

--ALTA ERROR: seleccion y jugador inexistentes, dorsal 0, sin fecha
EXEC comp.usp_Convocado_Alta 9999, 9999, 0, NULL, NULL;
/* Esperado, error 51111:
   usp_Convocado_Alta: - La seleccion no existe. - El jugador no existe.
   - El dorsal debe estar entre 1 y 99. - La fecha de alta es obligatoria. */
GO

--ALTA OK: Jugador Dos a Argentina (llega al maximo de 2)
DECLARE @t int, @s int, @j2 int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @s = s.id_seleccion FROM comp.Seleccion s INNER JOIN cat.Pais p ON p.id_pais = s.id_pais
WHERE p.nombre = 'Argentina' AND s.id_torneo = @t;
SELECT @j2 = id_persona FROM comp.Persona WHERE nro_documento = 'T-0002';
EXEC comp.usp_Convocado_Alta @s, @j2, 7, NULL, '2026-06-01';
SELECT * FROM comp.Convocado WHERE id_seleccion = @s;
-- Esperado: 2 filas (dorsales 10 y 7)
GO

--ALTA ERROR: Jugador Tres supera el maximo de convocados (2)
DECLARE @t int, @s int, @j3 int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @s = s.id_seleccion FROM comp.Seleccion s INNER JOIN cat.Pais p ON p.id_pais = s.id_pais
WHERE p.nombre = 'Argentina' AND s.id_torneo = @t;
SELECT @j3 = id_persona FROM comp.Persona WHERE nro_documento = 'T-0003';
EXEC comp.usp_Convocado_Alta @s, @j3, 9, NULL, '2026-06-01';
/* Esperado:
   usp_Convocado_Alta: - La seleccion ya tiene el maximo de convocados. */
GO

-- MODIFICACION OK: Jugador Dos pasa del 7 al 8
DECLARE @c int;
SELECT @c = c.id_convocado FROM comp.Convocado c INNER JOIN comp.Persona p ON p.id_persona = c.id_jugador
WHERE p.nro_documento = 'T-0002';
EXEC comp.usp_Convocado_Modificacion @c, 8, NULL;
SELECT * FROM comp.Convocado WHERE id_convocado = @c;
-- Esperado: 1 fila con dorsal 8
GO

--  MODIFICACION ERROR: Jugador Dos quiere el 10 (lo tiene Jugador Uno) y un club inexistente
DECLARE @c int;
SELECT @c = c.id_convocado FROM comp.Convocado c INNER JOIN comp.Persona p ON p.id_persona = c.id_jugador
WHERE p.nro_documento = 'T-0002';
EXEC comp.usp_Convocado_Modificacion @c, 10, 9999;
/* Esperado:
   usp_Convocado_Modificacion: - El dorsal ya lo usa otro convocado. - El club no existe. */
GO

-- MODIFICACION ERROR: convocado inexistente
EXEC comp.usp_Convocado_Modificacion 9999, 5, NULL;
/* Esperado:
   usp_Convocado_Modificacion: - El convocado no existe. */
GO

-- BAJA OK: se borra a Jugador Dos (no fue alineado ni tiene cambios)
DECLARE @c int;
SELECT @c = c.id_convocado FROM comp.Convocado c INNER JOIN comp.Persona p ON p.id_persona = c.id_jugador
WHERE p.nro_documento = 'T-0002';
EXEC comp.usp_Convocado_Baja @c;
SELECT * FROM comp.Convocado;
-- Esperado: 1 fila (solo Jugador Uno)
GO

-- BAJA ERROR: convocado inexistente
EXEC comp.usp_Convocado_Baja 9999;
/* Esperado, error 51113:
   usp_Convocado_Baja: - El convocado no existe. */
GO


/* =================================================================
   12. CAMBIO CONVOCATORIA
   ================================================================= */

-- MODIFICACION ERROR: cambio inexistente y motivo invalido
EXEC comp.usp_CambioConvocatoria_Modificacion 9999, 'Cansancio', NULL;
/* Esperado:
   usp_CambioConvocatoria_Modificacion: - El cambio de convocatoria no existe.
   - Motivo invalido (Lesion / Enfermedad / Decision tecnica / Sancion). */
GO


/* =================================================================
   13. BAJAS
   ================================================================= */

-- POSICION BAJA ERROR: Arquero es la posicion de Jugador Uno
DECLARE @id int;
SELECT @id = id_posicion FROM comp.Posicion WHERE nombre = 'Arquero';
EXEC comp.usp_Posicion_Baja @id;
/* Esperado:
   usp_Posicion_Baja: - Es la posicion habitual de algun jugador. */
GO

--POSICION BAJA OK: Volante no la usa nadie
DECLARE @id int;
SELECT @id = id_posicion FROM comp.Posicion WHERE nombre = 'Volante';
EXEC comp.usp_Posicion_Baja @id;
SELECT * FROM comp.Posicion WHERE nombre = 'Volante';
-- Esperado: 0 filas
GO

-- FASE BAJA ERROR: fase inexistente
EXEC comp.usp_Fase_Baja 9999;
/* Esperado:
   usp_Fase_Baja: - La fase no existe. */
GO

-- FASE BAJA OK: Tercer puesto no tiene partidos
DECLARE @id int;
SELECT @id = id_fase FROM comp.Fase WHERE nombre = 'Tercer puesto';
EXEC comp.usp_Fase_Baja @id;
SELECT * FROM comp.Fase WHERE nombre = 'Tercer puesto';
-- Esperado: 0 filas
GO

-- PERSONA BAJA ERROR: Jugador Uno esta registrado como jugador
DECLARE @p int;
SELECT @p = id_persona FROM comp.Persona WHERE nro_documento = 'T-0001';
EXEC comp.usp_Persona_Baja @p;
/* Esperado:
   usp_Persona_Baja: - Esta registrada como jugador. */
GO

--PERSONA BAJA OK: se crea una persona sin vinculos y se borra
DECLARE @arg int, @p int;
SELECT @arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
EXEC comp.usp_Persona_Alta 'Persona', 'Borrar', '1990-01-01', @arg, 'DNI', 'T-9999';
SELECT @p = id_persona FROM comp.Persona WHERE nro_documento = 'T-9999';
EXEC comp.usp_Persona_Baja @p;
SELECT * FROM comp.Persona WHERE nro_documento = 'T-9999';
-- Esperado: 0 filas
GO

-- JUGADOR BAJA ERROR: Jugador Uno fue convocado
DECLARE @p int;
SELECT @p = id_persona FROM comp.Persona WHERE nro_documento = 'T-0001';
EXEC comp.usp_Jugador_Baja @p;
/* Esperado:
   usp_Jugador_Baja: - Fue convocado por alguna seleccion. */
GO

-- JUGADOR BAJA OK: Jugador Tres nunca fue convocado
DECLARE @p int;
SELECT @p = id_persona FROM comp.Persona WHERE nro_documento = 'T-0003';
EXEC comp.usp_Jugador_Baja @p;
SELECT * FROM comp.Jugador WHERE id_jugador = @p;
SELECT * FROM comp.Persona WHERE id_persona = @p;
-- Esperado: 0 filas en Jugador y 1 fila en Persona (la persona queda)
GO

-- CLUB BAJA ERROR: River es el club de Jugador Uno
DECLARE @c int;
SELECT @c = id_club FROM comp.Club WHERE nombre = 'River Plate';
EXEC comp.usp_Club_Baja @c;
/* Esperado:
   usp_Club_Baja: - Es el club de origen de algun convocado. */
GO

-- CLUB BAJA OK: Boca Jrs no tiene convocados
DECLARE @c int;
SELECT @c = id_club FROM comp.Club WHERE nombre = 'Boca Jrs';
EXEC comp.usp_Club_Baja @c;
SELECT * FROM comp.Club WHERE nombre = 'Boca Jrs';
-- Esperado: 0 filas
GO

-- CUERPO TECNICO BAJA OK: Tecnico Dos
DECLARE @ct int;
SELECT @ct = ct.id_cuerpo_tecnico FROM comp.CuerpoTecnico ct
INNER JOIN comp.Persona p ON p.id_persona = ct.id_persona WHERE p.nro_documento = 'T-0102';
EXEC comp.usp_CuerpoTecnico_Baja @ct;
SELECT * FROM comp.CuerpoTecnico WHERE id_cuerpo_tecnico = @ct;
-- Esperado: 0 filas
GO

-- CUERPO TECNICO BAJA ERROR: inexistente
EXEC comp.usp_CuerpoTecnico_Baja 9999;
/* Esperado:
   usp_CuerpoTecnico_Baja: - El integrante del cuerpo tecnico no existe. */
GO

-- SELECCION BAJA ERROR: Argentina tiene convocados y cuerpo tecnico
DECLARE @t int, @s int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @s = s.id_seleccion FROM comp.Seleccion s INNER JOIN cat.Pais p ON p.id_pais = s.id_pais
WHERE p.nombre = 'Argentina' AND s.id_torneo = @t;
EXEC comp.usp_Seleccion_Baja @s;
/* Esperado:
   usp_Seleccion_Baja: - Tiene convocados. - Tiene cuerpo tecnico. */
GO

--SELECCION BAJA OK: Uruguay no tiene nada asociado
DECLARE @t int, @s int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @s = s.id_seleccion FROM comp.Seleccion s INNER JOIN cat.Pais p ON p.id_pais = s.id_pais
WHERE p.nombre = 'Uruguay' AND s.id_torneo = @t;
EXEC comp.usp_Seleccion_Baja @s;
SELECT * FROM comp.Seleccion WHERE id_seleccion = @s;
-- Esperado: 0 filas
GO

--GRUPO BAJA ERROR: el grupo A tiene selecciones
DECLARE @t int, @g int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @g = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'A';
EXEC comp.usp_Grupo_Baja @g;
/* Esperado:
   usp_Grupo_Baja: - Tiene selecciones asignadas. */
GO

-- GRUPO BAJA OK: el grupo C quedo vacio (se borro Uruguay)
DECLARE @t int, @g int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @g = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'C';
EXEC comp.usp_Grupo_Baja @g;
SELECT * FROM comp.Grupo WHERE id_torneo = @t;
-- Esperado: 1 fila (solo el grupo A)
GO

-- TORNEO BAJA ERROR: el torneo 2026 tiene selecciones, grupos y parametros
DECLARE @t int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
EXEC comp.usp_Torneo_Baja @t;
/* Esperado:
   usp_Torneo_Baja: - Tiene selecciones. - Tiene grupos. - Tiene parametros de reglamento. */
GO
-- PREPARACION
IF (SELECT COUNT(*) FROM cat.Pais WHERE nombre = 'Mexico') = 0
BEGIN
    IF OBJECT_ID('cat.usp_Pais_Alta') IS NOT NULL
        EXEC cat.usp_Pais_Alta @nombre = 'Mexico', @confederacion = 'CONCACAF',
                               @id_moneda = NULL, @huso_horario = 'Central Standard Time (Mexico)';
    ELSE
        INSERT INTO cat.Pais (nombre, confederacion, huso_horario) VALUES ('Mexico', 'CONCACAF', 'Central Standard Time (Mexico)');
END
GO

IF (SELECT COUNT(*) FROM cat.Pais WHERE nombre = 'Canada') = 0
BEGIN
    IF OBJECT_ID('cat.usp_Pais_Alta') IS NOT NULL
        EXEC cat.usp_Pais_Alta @nombre = 'Canada', @confederacion = 'CONCACAF',
                               @id_moneda = NULL, @huso_horario = 'Eastern Standard Time';
    ELSE
        INSERT INTO cat.Pais (nombre, confederacion, huso_horario) VALUES ('Canada', 'CONCACAF', 'Eastern Standard Time');
END
GO

IF (SELECT COUNT(*) FROM cat.Pais WHERE nombre = 'Chile') = 0
BEGIN
    IF OBJECT_ID('cat.usp_Pais_Alta') IS NOT NULL
        EXEC cat.usp_Pais_Alta @nombre = 'Chile', @confederacion = 'CONMEBOL',
                               @id_moneda = NULL, @huso_horario = 'Pacific SA Standard Time';
    ELSE
        INSERT INTO cat.Pais (nombre, confederacion, huso_horario) VALUES ('Chile', 'CONMEBOL', 'Pacific SA Standard Time');
END
GO

DECLARE @id_pais int;
SELECT @id_pais = id_pais FROM cat.Pais WHERE nombre = 'Mexico';
IF (SELECT COUNT(*) FROM cat.Ciudad WHERE nombre = N'Ciudad de Mexico') = 0
BEGIN
    IF OBJECT_ID('cat.usp_Ciudad_Alta') IS NOT NULL
        EXEC cat.usp_Ciudad_Alta @nombre = N'Ciudad de Mexico', @id_pais = @id_pais,
                                 @huso_horario = 'Central Standard Time (Mexico)';
    ELSE
        INSERT INTO cat.Ciudad (nombre, id_pais, huso_horario) VALUES (N'Ciudad de Mexico', @id_pais, 'Central Standard Time (Mexico)');
END
GO

DECLARE @id_pais int;
SELECT @id_pais = id_pais FROM cat.Pais WHERE nombre = 'Canada';
IF (SELECT COUNT(*) FROM cat.Ciudad WHERE nombre = N'Toronto') = 0
BEGIN
    IF OBJECT_ID('cat.usp_Ciudad_Alta') IS NOT NULL
        EXEC cat.usp_Ciudad_Alta @nombre = N'Toronto', @id_pais = @id_pais,
                                 @huso_horario = 'Eastern Standard Time';
    ELSE
        INSERT INTO cat.Ciudad (nombre, id_pais, huso_horario) VALUES (N'Toronto', @id_pais, 'Eastern Standard Time');
END
GO

--paises y ciudades cargados
SELECT c.id_ciudad, c.nombre AS ciudad, p.nombre AS pais, c.huso_horario
FROM cat.Ciudad c
INNER JOIN cat.Pais p ON p.id_pais = c.id_pais
WHERE c.nombre IN (N'Ciudad de Mexico', N'Toronto');
-- Esperado: 2 filas
GO

-- Datos de la Parte 1, cargados con sus SP (solo si no existen)
IF (SELECT COUNT(*) FROM comp.Posicion WHERE nombre = 'Arquero') = 0  EXEC comp.usp_Posicion_Alta 'Arquero';
IF (SELECT COUNT(*) FROM comp.Posicion WHERE nombre = 'Defensor') = 0 EXEC comp.usp_Posicion_Alta 'Defensor';
IF (SELECT COUNT(*) FROM comp.Fase WHERE nombre = 'Grupos') = 0       EXEC comp.usp_Fase_Alta 'Grupos', 1, 0;
IF (SELECT COUNT(*) FROM comp.Fase WHERE nombre = 'Octavos') = 0      EXEC comp.usp_Fase_Alta 'Octavos', 3, 1;
IF (SELECT COUNT(*) FROM comp.Torneo WHERE anio = 2034) = 0
    EXEC comp.usp_Torneo_Alta 'Mundial de prueba 2034', 2034, '2034-06-01', '2034-07-31';
GO

-- Parametros: MAX_CAMBIOS = 1 y MAX_VENTANAS = 1 a proposito, para probar los maximos rapido
DECLARE @t int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
EXEC comp.usp_ParametroReglamento_Alta @t, 'MAX_CONVOCADOS', 26, NULL;
EXEC comp.usp_ParametroReglamento_Alta @t, 'MAX_CAMBIOS', 1, 'Valor bajo solo para test';
EXEC comp.usp_ParametroReglamento_Alta @t, 'MAX_VENTANAS', 1, 'Valor bajo solo para test';
EXEC comp.usp_ParametroReglamento_Alta @t, 'CAMBIOS_EXTRA_ALARGUE', 1, NULL;
EXEC comp.usp_ParametroReglamento_Alta @t, 'VENTANAS_EXTRA_ALARGUE', 1, NULL;
EXEC comp.usp_Grupo_Alta @t, 'A';
GO

-- Selecciones: Mexico y Canada en el grupo A, Chile sin grupo
DECLARE @t int, @gA int, @mex int, @can int, @chi int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @gA = id_grupo FROM comp.Grupo WHERE id_torneo = @t AND letra = 'A';
SELECT @mex = id_pais FROM cat.Pais WHERE nombre = 'Mexico';
SELECT @can = id_pais FROM cat.Pais WHERE nombre = 'Canada';
SELECT @chi = id_pais FROM cat.Pais WHERE nombre = 'Chile';
EXEC comp.usp_Seleccion_Alta @t, @mex, @gA;
EXEC comp.usp_Seleccion_Alta @t, @can, @gA;
EXEC comp.usp_Seleccion_Alta @t, @chi, NULL;
GO

-- Jugadores: 6 de Mexico (M1 arquero, el resto defensores) y 1 de Canada
DECLARE @t int, @mex int, @can int, @s_mex int, @s_can int, @arq int, @def int, @p int;
SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2034;
SELECT @mex = id_pais FROM cat.Pais WHERE nombre = 'Mexico';
SELECT @can = id_pais FROM cat.Pais WHERE nombre = 'Canada';
SELECT @s_mex = id_seleccion FROM comp.Seleccion WHERE id_torneo = @t AND id_pais = @mex;
SELECT @s_can = id_seleccion FROM comp.Seleccion WHERE id_torneo = @t AND id_pais = @can;
SELECT @arq = id_posicion FROM comp.Posicion WHERE nombre = 'Arquero';
SELECT @def = id_posicion FROM comp.Posicion WHERE nombre = 'Defensor';

EXEC comp.usp_Persona_Alta 'Mexicano', 'Uno', '1995-01-01', @mex, 'DNI', 'P2-M1';
SELECT @p = id_persona FROM comp.Persona WHERE nro_documento = 'P2-M1';
EXEC comp.usp_Jugador_Alta @p, @arq;
EXEC comp.usp_Convocado_Alta @s_mex, @p, 1, NULL, '2034-05-20';

EXEC comp.usp_Persona_Alta 'Mexicano', 'Dos', '1995-01-01', @mex, 'DNI', 'P2-M2';
SELECT @p = id_persona FROM comp.Persona WHERE nro_documento = 'P2-M2';
EXEC comp.usp_Jugador_Alta @p, @def;
EXEC comp.usp_Convocado_Alta @s_mex, @p, 2, NULL, '2034-05-20';

EXEC comp.usp_Persona_Alta 'Mexicano', 'Tres', '1995-01-01', @mex, 'DNI', 'P2-M3';
SELECT @p = id_persona FROM comp.Persona WHERE nro_documento = 'P2-M3';
EXEC comp.usp_Jugador_Alta @p, @def;
EXEC comp.usp_Convocado_Alta @s_mex, @p, 3, NULL, '2034-05-20';

EXEC comp.usp_Persona_Alta 'Mexicano', 'Cuatro', '1995-01-01', @mex, 'DNI', 'P2-M4';
SELECT @p = id_persona FROM comp.Persona WHERE nro_documento = 'P2-M4';
EXEC comp.usp_Jugador_Alta @p, @def;
EXEC comp.usp_Convocado_Alta @s_mex, @p, 4, NULL, '2034-05-20';

EXEC comp.usp_Persona_Alta 'Mexicano', 'Cinco', '1995-01-01', @mex, 'DNI', 'P2-M5';
SELECT @p = id_persona FROM comp.Persona WHERE nro_documento = 'P2-M5';
EXEC comp.usp_Jugador_Alta @p, @def;
EXEC comp.usp_Convocado_Alta @s_mex, @p, 5, NULL, '2034-05-20';

EXEC comp.usp_Persona_Alta 'Mexicano', 'Seis', '1995-01-01', @mex, 'DNI', 'P2-M6';
SELECT @p = id_persona FROM comp.Persona WHERE nro_documento = 'P2-M6';
EXEC comp.usp_Jugador_Alta @p, @def;
EXEC comp.usp_Convocado_Alta @s_mex, @p, 6, NULL, '2034-05-20';

EXEC comp.usp_Persona_Alta 'Canadiense', 'Uno', '1995-01-01', @can, 'DNI', 'P2-C1';
SELECT @p = id_persona FROM comp.Persona WHERE nro_documento = 'P2-C1';
EXEC comp.usp_Jugador_Alta @p, @arq;
EXEC comp.usp_Convocado_Alta @s_can, @p, 1, NULL, '2034-05-20';
GO


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

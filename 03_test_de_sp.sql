/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - 03: Testing de los SP de ABM - Selecciones y convocatoria
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana (nickGithub: tatimendez)

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

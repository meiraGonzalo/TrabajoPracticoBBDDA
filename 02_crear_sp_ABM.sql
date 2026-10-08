/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - Script 02: Creacion de Stored Procedure
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana
 Objetivo: crear stored procedures de ABM
=====================================================================


Formato de errores (Throw) : 5 - TT A
     5  = fijo (los errores propios empiezan en 50000)
     -
     TT = tabla (01, 02, 03...)
     A  = accion (1 = Alta, 2 = Modificacion, 3 = Baja)
*/



/*------------------1. TORNEO ----------------*/ 

CREATE OR ALTER PROCEDURE comp.usp_Torneo_Alta
    @nombre       varchar(100),
    @anio         smallint,
    @fecha_inicio date,
    @fecha_fin    date
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF @nombre IS NULL OR @nombre = ''
        SET @err = @err + ' - El nombre es obligatorio.';

    IF @anio IS NULL OR @anio < 1930 OR @anio > 2100
        SET @err = @err + ' - El anio debe estar entre 1930 y 2100.';

    IF EXISTS (SELECT 1 FROM comp.Torneo WHERE anio = @anio) 
        SET @err = @err + ' - Ya existe un torneo para ese anio.';

    IF @fecha_fin < @fecha_inicio
        SET @err = @err + ' - La fecha de fin es anterior a la de inicio.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Torneo_Alta:' + @err;
        THROW 50011, @err, 1;
    END

    INSERT INTO comp.Torneo (nombre, anio, fecha_inicio, fecha_fin)
    VALUES (@nombre, @anio, @fecha_inicio, @fecha_fin);
END
GO



CREATE OR ALTER PROCEDURE comp.usp_Torneo_Modificacion
    @id_torneo    int,
    @nombre       varchar(100),
    @anio         smallint,
    @fecha_inicio date,
    @fecha_fin    date
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS(SELECT 1 FROM comp.Torneo WHERE id_torneo = @id_torneo)
        SET @err = @err + ' - El torneo no existe.';

    IF @nombre IS NULL OR @nombre = ''
        SET @err = @err + ' - El nombre es obligatorio.';

    IF @anio IS NULL OR @anio < 1930 OR @anio > 2100
        SET @err = @err + ' - El anio debe estar entre 1930 y 2100.';

    IF EXISTS(SELECT 1 FROM comp.Torneo WHERE anio = @anio AND id_torneo <> @id_torneo)
        SET @err = @err + ' - Otro torneo ya usa ese anio.';

    IF @fecha_fin < @fecha_inicio
        SET @err = @err + ' - La fecha de fin es anterior a la de inicio.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Torneo_Modificacion:' + @err;
        THROW 50012, @err, 1;
    END

    UPDATE comp.Torneo
    SET nombre = @nombre, anio = @anio, fecha_inicio = @fecha_inicio, fecha_fin = @fecha_fin
    WHERE id_torneo = @id_torneo;
END
GO



CREATE OR ALTER PROCEDURE comp.usp_Torneo_Baja
    @id_torneo int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS(SELECT COUNT(*) FROM comp.Torneo WHERE id_torneo = @id_torneo)
        SET @err = @err + ' - El torneo no existe.';

    IF EXISTS(SELECT 1 FROM comp.Seleccion WHERE id_torneo = @id_torneo)
        SET @err = @err + ' - Tiene selecciones.';

    IF EXISTS(SELECT 1 FROM comp.Partido WHERE id_torneo = @id_torneo)
        SET @err = @err + ' - Tiene partidos.';

    IF EXISTS(SELECT 1 FROM comp.Grupo WHERE id_torneo = @id_torneo)
        SET @err = @err + ' - Tiene grupos.';

    IF EXISTS(SELECT 1 FROM comp.ParametroReglamento WHERE id_torneo = @id_torneo) 
        SET @err = @err + ' - Tiene parametros de reglamento.';

    IF EXISTS(SELECT 1 FROM pub.Tarifa WHERE id_torneo = @id_torneo)
        SET @err = @err + ' - Tiene tarifas.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Torneo_Baja:' + @err;
        THROW 50013, @err, 1;
    END

    DELETE FROM comp.Torneo WHERE id_torneo = @id_torneo;
END
GO


/*-----------------2. PARAMETRO REGLAMENTO--------------- */

CREATE OR ALTER PROCEDURE comp.usp_ParametroReglamento_Alta
    @id_torneo   int,
    @clave       varchar(50),
    @valor       int,
    @descripcion varchar(200)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF not EXISTS(SELECT 1 FROM comp.Torneo WHERE id_torneo = @id_torneo)
        SET @err = @err + ' - El torneo no existe.';

    IF @clave IS NULL OR @clave = ''
        SET @err = @err + ' - La clave es obligatoria.';

    IF EXISTS (SELECT 1 FROM comp.ParametroReglamento WHERE id_torneo = @id_torneo AND clave = @clave)
        SET @err = @err + ' - Ya existe ese parametro para el torneo.';

    IF @valor IS NULL OR @valor < 0
        SET @err = @err + ' - El valor debe ser cero o mayor.';

    -- Coherencia entre minimo y maximo de convocados
    IF @clave = 'MIN_CONVOCADOS'
       AND EXISTS(SELECT COUNT(*) FROM comp.ParametroReglamento
            WHERE id_torneo = @id_torneo AND clave = 'MAX_CONVOCADOS' AND valor < @valor)
        SET @err = @err + ' - El minimo de convocados no puede superar al maximo.';

    IF @clave = 'MAX_CONVOCADOS'
       AND EXISTS(SELECT 1 FROM comp.ParametroReglamento
            WHERE id_torneo = @id_torneo AND clave = 'MIN_CONVOCADOS' AND valor > @valor)
        SET @err = @err + ' - El maximo de convocados no puede ser menor al minimo.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_ParametroReglamento_Alta:' + @err;
        THROW 50021, @err, 1;
    END

    INSERT INTO comp.ParametroReglamento (id_torneo, clave, valor, descripcion)
    VALUES (@id_torneo, @clave, @valor, @descripcion);
END
GO



CREATE OR ALTER PROCEDURE comp.usp_ParametroReglamento_Modificacion
    @id_torneo   int,
    @clave       varchar(50),
    @valor       int,
    @descripcion varchar(200)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS(SELECT 1 FROM comp.ParametroReglamento WHERE id_torneo = @id_torneo AND clave = @clave)
        SET @err = @err + ' - El parametro no existe.';

    IF @valor IS NULL OR @valor < 0
        SET @err = @err + ' - El valor debe ser cero o mayor.';

    IF @clave = 'MIN_CONVOCADOS'
       AND EXISTS(SELECT 1 FROM comp.ParametroReglamento
            WHERE id_torneo = @id_torneo AND clave = 'MAX_CONVOCADOS' AND valor < @valor)
        SET @err = @err + ' - El minimo de convocados no puede superar al maximo.';

    IF @clave = 'MAX_CONVOCADOS'
       AND EXISTS(SELECT 1 FROM comp.ParametroReglamento
            WHERE id_torneo = @id_torneo AND clave = 'MIN_CONVOCADOS' AND valor > @valor) 
        SET @err = @err + ' - El maximo de convocados no puede ser menor al minimo.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_ParametroReglamento_Modificacion:' + @err;
        THROW 50022, @err, 1;
    END

    UPDATE comp.ParametroReglamento
    SET valor = @valor, descripcion = @descripcion
    WHERE id_torneo = @id_torneo AND clave = @clave;
END
GO




CREATE OR ALTER PROCEDURE comp.usp_ParametroReglamento_Baja
    @id_torneo int,
    @clave     varchar(50)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM comp.ParametroReglamento WHERE id_torneo = @id_torneo AND clave = @clave)
        SET @err = @err + ' - El parametro no existe.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_ParametroReglamento_Baja:' + @err;
        THROW 50023, @err, 1;
    END

    DELETE FROM comp.ParametroReglamento WHERE id_torneo = @id_torneo AND clave = @clave;
END
GO


/*------------------3. FASE ---------------- */

CREATE OR ALTER PROCEDURE comp.usp_Fase_Alta
    @nombre          varchar(30),
    @orden           tinyint,
    @es_eliminatoria bit
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF @nombre IS NULL OR @nombre = ''
        SET @err = @err + ' - El nombre es obligatorio.';

    IF EXISTS (SELECT 1 FROM comp.Fase WHERE nombre = @nombre)
        SET @err = @err + ' - Ya existe una fase con ese nombre.';

    IF @orden IS NULL OR @orden < 1 OR @orden > 20
        SET @err = @err + ' - El orden debe estar entre 1 y 20.';

    IF EXISTS(SELECT 1 FROM comp.Fase WHERE orden = @orden)
        SET @err = @err + ' - Ya existe una fase con ese orden.';

    IF @es_eliminatoria IS NULL
        SET @err = @err + ' - Hay que indicar si la fase es eliminatoria.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Fase_Alta:' + @err;
        THROW 50031, @err, 1;
    END

    INSERT INTO comp.Fase (nombre, orden, es_eliminatoria)
    VALUES (@nombre, @orden, @es_eliminatoria);
END
GO



CREATE OR ALTER PROCEDURE comp.usp_Fase_Modificacion
    @id_fase         int,
    @nombre          varchar(30),
    @orden           tinyint,
    @es_eliminatoria bit
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF (SELECT 1 FROM comp.Fase WHERE id_fase = @id_fase) = 0
        SET @err = @err + ' - La fase no existe.';

    IF @nombre IS NULL OR @nombre = ''
        SET @err = @err + ' - El nombre es obligatorio.';

    IF EXISTS (SELECT 1 FROM comp.Fase WHERE nombre = @nombre AND id_fase <> @id_fase) 
        SET @err = @err + ' - Otra fase ya usa ese nombre.';

    IF @orden IS NULL OR @orden < 1 OR @orden > 20
        SET @err = @err + ' - El orden debe estar entre 1 y 20.';

    IF EXISTS(SELECT 1 FROM comp.Fase WHERE orden = @orden AND id_fase <> @id_fase) 
        SET @err = @err + ' - Otra fase ya usa ese orden.';

    IF @es_eliminatoria IS NULL
        SET @err = @err + ' - Hay que indicar si la fase es eliminatoria.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Fase_Modificacion:' + @err;
        THROW 50032, @err, 1;
    END

    UPDATE comp.Fase
    SET nombre = @nombre, orden = @orden, es_eliminatoria = @es_eliminatoria
    WHERE id_fase = @id_fase;
END
GO



CREATE OR ALTER PROCEDURE comp.usp_Fase_Baja
    @id_fase int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF not EXISTS(SELECT 1 FROM comp.Fase WHERE id_fase = @id_fase)
        SET @err = @err + ' - La fase no existe.';

    IF EXISTS (SELECT 1 FROM comp.Partido WHERE id_fase = @id_fase)
        SET @err = @err + ' - Tiene partidos.';

    IF EXISTS(SELECT 1 FROM pub.Tarifa WHERE id_fase = @id_fase)
        SET @err = @err + ' - Tiene tarifas.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Fase_Baja:' + @err;
        THROW 50033, @err, 1;
    END

    DELETE FROM comp.Fase WHERE id_fase = @id_fase;
END
GO


/* ----------------4. GRUPO -------------------*/

CREATE OR ALTER PROCEDURE comp.usp_Grupo_Alta
    @id_torneo int,
    @letra     char(1)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF not EXISTS (SELECT 1 FROM comp.Torneo WHERE id_torneo = @id_torneo)
        SET @err = @err + ' - El torneo no existe.';

    -- Una sola letra (patron con LIKE, como el CHECK de la diap. 21)
    IF @letra IS NULL OR @letra NOT LIKE '[A-Z]'
        SET @err = @err + ' - La letra del grupo debe ser una letra de la A a la Z.';

    IF EXISTS(SELECT 1 FROM comp.Grupo WHERE id_torneo = @id_torneo AND letra = @letra)
        SET @err = @err + ' - Ya existe ese grupo en el torneo.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Grupo_Alta:' + @err;
        THROW 50041, @err, 1;
    END

    INSERT INTO comp.Grupo (id_torneo, letra) VALUES (@id_torneo, @letra);
END
GO



CREATE OR ALTER PROCEDURE comp.usp_Grupo_Modificacion
    @id_grupo int,
    @letra    char(1)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @id_torneo int;
    SET @err = '';

    SELECT @id_torneo = id_torneo FROM comp.Grupo WHERE id_grupo = @id_grupo;

    IF @id_torneo IS NULL
        SET @err = @err + ' - El grupo no existe.';

    IF @letra IS NULL OR @letra NOT LIKE '[A-Z]'
        SET @err = @err + ' - La letra del grupo debe ser una letra de la A a la Z.';

    IF EXISTS(SELECT 1 FROM comp.Grupo
        WHERE id_torneo = @id_torneo AND letra = @letra AND id_grupo <> @id_grupo)
        SET @err = @err + ' - Otro grupo del torneo ya usa esa letra.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Grupo_Modificacion:' + @err;
        THROW 50042, @err, 1;
    END

    UPDATE comp.Grupo SET letra = @letra WHERE id_grupo = @id_grupo;
END
GO



CREATE OR ALTER PROCEDURE comp.usp_Grupo_Baja
    @id_grupo int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF not EXISTS(SELECT 1 FROM comp.Grupo WHERE id_grupo = @id_grupo)
        SET @err = @err + ' - El grupo no existe.';

    IF EXISTS(SELECT 1 FROM comp.Seleccion WHERE id_grupo = @id_grupo)
        SET @err = @err + ' - Tiene selecciones asignadas.';

    IF EXISTS(SELECT 1 FROM comp.Partido WHERE id_grupo = @id_grupo)
        SET @err = @err + ' - Tiene partidos.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Grupo_Baja:' + @err;
        THROW 50043, @err, 1;
    END

    DELETE FROM comp.Grupo WHERE id_grupo = @id_grupo;
END
GO


/* ----------------- 5.PERSONA --------------- */

CREATE OR ALTER PROCEDURE comp.usp_Persona_Alta
    @nombre               nvarchar(80),
    @apellido             nvarchar(80),
    @fecha_nacimiento     date,
    @id_pais_nacionalidad int,
    @tipo_documento       varchar(15),
    @nro_documento        varchar(30)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF @nombre IS NULL OR @nombre = ''
        SET @err = @err + ' - El nombre es obligatorio.';

    IF @apellido IS NULL OR @apellido = ''
        SET @err = @err + ' - El apellido es obligatorio.';

    IF @fecha_nacimiento > GETDATE()
        SET @err = @err + ' - La fecha de nacimiento no puede ser futura.';

    IF not EXISTS(SELECT 1 FROM cat.Pais WHERE id_pais = @id_pais_nacionalidad)
        SET @err = @err + ' - El pais de nacionalidad no existe.';

    IF (@tipo_documento IS NULL AND @nro_documento IS NOT NULL)
       OR (@tipo_documento IS NOT NULL AND @nro_documento IS NULL)
        SET @err = @err + ' - Tipo y numero de documento van juntos (los dos o ninguno).';

    IF EXISTS(SELECT 1 FROM comp.Persona
        WHERE tipo_documento = @tipo_documento AND nro_documento = @nro_documento
          AND id_pais_nacionalidad = @id_pais_nacionalidad)
        SET @err = @err + ' - Ya existe una persona con ese documento.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Persona_Alta:' + @err;
        THROW 50051, @err, 1;
    END

    INSERT INTO comp.Persona (nombre, apellido, fecha_nacimiento, id_pais_nacionalidad, tipo_documento, nro_documento)
    VALUES (@nombre, @apellido, @fecha_nacimiento, @id_pais_nacionalidad, @tipo_documento, @nro_documento);
END
GO



CREATE OR ALTER PROCEDURE comp.usp_Persona_Modificacion
    @id_persona           int,
    @nombre               nvarchar(80),
    @apellido             nvarchar(80),
    @fecha_nacimiento     date,
    @id_pais_nacionalidad int,
    @tipo_documento       varchar(15),
    @nro_documento        varchar(30)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF not EXISTS (SELECT 1 FROM comp.Persona WHERE id_persona = @id_persona) 
        SET @err = @err + ' - La persona no existe.';

    IF @nombre IS NULL OR @nombre = ''
        SET @err = @err + ' - El nombre es obligatorio.';

    IF @apellido IS NULL OR @apellido = ''
        SET @err = @err + ' - El apellido es obligatorio.';

    IF @fecha_nacimiento > GETDATE()
        SET @err = @err + ' - La fecha de nacimiento no puede ser futura.';

    IF not EXISTS (SELECT 1 FROM cat.Pais WHERE id_pais = @id_pais_nacionalidad)
        SET @err = @err + ' - El pais de nacionalidad no existe.';

    IF (@tipo_documento IS NULL AND @nro_documento IS NOT NULL)
       OR (@tipo_documento IS NOT NULL AND @nro_documento IS NULL)
        SET @err = @err + ' - Tipo y numero de documento van juntos (los dos o ninguno).';

    IF EXISTS(SELECT 1 FROM comp.Persona
        WHERE tipo_documento = @tipo_documento AND nro_documento = @nro_documento
          AND id_pais_nacionalidad = @id_pais_nacionalidad AND id_persona <> @id_persona)
        SET @err = @err + ' - Otra persona ya tiene ese documento.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Persona_Modificacion:' + @err;
        THROW 50052, @err, 1;
    END

    UPDATE comp.Persona
    SET nombre = @nombre, apellido = @apellido, fecha_nacimiento = @fecha_nacimiento,
        id_pais_nacionalidad = @id_pais_nacionalidad,
        tipo_documento = @tipo_documento, nro_documento = @nro_documento
    WHERE id_persona = @id_persona;
END
GO




CREATE OR ALTER PROCEDURE comp.usp_Persona_Baja
    @id_persona int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF not EXISTS (SELECT 1 FROM comp.Persona WHERE id_persona = @id_persona)
        SET @err = @err + ' - La persona no existe.';

    IF EXISTS (SELECT 1 FROM comp.Jugador WHERE id_jugador = @id_persona) 
        SET @err = @err + ' - Esta registrada como jugador.';

    IF EXISTS(SELECT 1 FROM disc.Arbitro WHERE id_arbitro = @id_persona)
        SET @err = @err + ' - Esta registrada como arbitro.';

    IF EXISTS(SELECT 1 FROM comp.CuerpoTecnico WHERE id_persona = @id_persona) 
        SET @err = @err + ' - Integra un cuerpo tecnico.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Persona_Baja:' + @err;
        THROW 50053, @err, 1;
    END

    DELETE FROM comp.Persona WHERE id_persona = @id_persona;
END
GO


/*-----------------6. POSICION ---------------------*/

CREATE OR ALTER PROCEDURE comp.usp_Posicion_Alta
    @nombre varchar(30)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF @nombre IS NULL OR @nombre = ''
        SET @err = @err + ' - El nombre es obligatorio.';

    IF EXISTS (SELECT 1 FROM comp.Posicion WHERE nombre = @nombre) 
        SET @err = @err + ' - Ya existe esa posicion.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Posicion_Alta:' + @err;
        THROW 50061, @err, 1;
    END

    INSERT INTO comp.Posicion (nombre) VALUES (@nombre);
END
GO



CREATE OR ALTER PROCEDURE comp.usp_Posicion_Modificacion
    @id_posicion int,
    @nombre      varchar(30)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF not EXISTS(SELECT 1 FROM comp.Posicion WHERE id_posicion = @id_posicion) 
        SET @err = @err + ' - La posicion no existe.';

    IF @nombre IS NULL OR @nombre = ''
        SET @err = @err + ' - El nombre es obligatorio.';

    IF EXISTS(SELECT 1 FROM comp.Posicion WHERE nombre = @nombre AND id_posicion <> @id_posicion) 
        SET @err = @err + ' - Otra posicion ya usa ese nombre.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Posicion_Modificacion:' + @err;
        THROW 50062, @err, 1;
    END

    UPDATE comp.Posicion SET nombre = @nombre WHERE id_posicion = @id_posicion;
END
GO



CREATE OR ALTER PROCEDURE comp.usp_Posicion_Baja
    @id_posicion int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF not EXISTS(SELECT 1 FROM comp.Posicion WHERE id_posicion = @id_posicion) 
        SET @err = @err + ' - La posicion no existe.';

    IF EXISTS(SELECT 1 FROM comp.Jugador WHERE id_posicion_habitual = @id_posicion)
        SET @err = @err + ' - Es la posicion habitual de algun jugador.';

    IF EXISTS(SELECT 1 FROM comp.Alineacion WHERE id_posicion_cancha = @id_posicion) 
        SET @err = @err + ' - Se uso en alguna alineacion.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Posicion_Baja:' + @err;
        THROW 50063, @err, 1;
    END

    DELETE FROM comp.Posicion WHERE id_posicion = @id_posicion;
END
GO


/* ------------------7. JUGADOR --------------------*/

CREATE OR ALTER PROCEDURE comp.usp_Jugador_Alta
    @id_jugador           int,
    @id_posicion_habitual int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF not EXISTS(SELECT 1 FROM comp.Persona WHERE id_persona = @id_jugador)
        SET @err = @err + ' - La persona no existe.';

    IF EXISTS(SELECT 1 FROM comp.Jugador WHERE id_jugador = @id_jugador)
        SET @err = @err + ' - La persona ya esta registrada como jugador.';

    IF not EXISTS (SELECT 1 FROM comp.Posicion WHERE id_posicion = @id_posicion_habitual)
        SET @err = @err + ' - La posicion no existe.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Jugador_Alta:' + @err;
        THROW 50071, @err, 1;
    END

    INSERT INTO comp.Jugador (id_jugador, id_posicion_habitual)
    VALUES (@id_jugador, @id_posicion_habitual);
END
GO



CREATE OR ALTER PROCEDURE comp.usp_Jugador_Modificacion
    @id_jugador           int,
    @id_posicion_habitual int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF not EXISTS(SELECT 1 FROM comp.Jugador WHERE id_jugador = @id_jugador)
        SET @err = @err + ' - El jugador no existe.';

    IF not EXISTS(SELECT 1 FROM comp.Posicion WHERE id_posicion = @id_posicion_habitual)
        SET @err = @err + ' - La posicion no existe.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Jugador_Modificacion:' + @err;
        THROW 50072, @err, 1;
    END

    UPDATE comp.Jugador
    SET id_posicion_habitual = @id_posicion_habitual
    WHERE id_jugador = @id_jugador;
END
GO




CREATE OR ALTER PROCEDURE comp.usp_Jugador_Baja
    @id_jugador int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF not EXISTS (SELECT 1 FROM comp.Jugador WHERE id_jugador = @id_jugador) 
        SET @err = @err + ' - El jugador no existe.';

    IF EXISTS(SELECT 1 FROM comp.Convocado WHERE id_jugador = @id_jugador)
        SET @err = @err + ' - Fue convocado por alguna seleccion.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Jugador_Baja:' + @err;
        THROW 50073, @err, 1;
    END

    -- Se borra solo el subtipo: la Persona queda
    DELETE FROM comp.Jugador WHERE id_jugador = @id_jugador;
END
GO


/* -------------8. CLUB -------------------*/

CREATE OR ALTER PROCEDURE comp.usp_Club_Alta
    @nombre  nvarchar(100),
    @id_pais int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF @nombre IS NULL OR @nombre = ''
        SET @err = @err + ' - El nombre es obligatorio.';

    IF not EXISTS(SELECT 1 FROM cat.Pais WHERE id_pais = @id_pais)
        SET @err = @err + ' - El pais no existe.';

    IF EXISTS(SELECT 1 FROM comp.Club WHERE nombre = @nombre AND id_pais = @id_pais) 
        SET @err = @err + ' - Ya existe ese club en el pais.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Club_Alta:' + @err;
        THROW 50081, @err, 1;
    END

    INSERT INTO comp.Club (nombre, id_pais) VALUES (@nombre, @id_pais);
END
GO




CREATE OR ALTER PROCEDURE comp.usp_Club_Modificacion
    @id_club int,
    @nombre  nvarchar(100),
    @id_pais int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF not EXISTS (SELECT 1 FROM comp.Club WHERE id_club = @id_club) 
        SET @err = @err + ' - El club no existe.';

    IF @nombre IS NULL OR @nombre = ''
        SET @err = @err + ' - El nombre es obligatorio.';

    IF not EXISTS(SELECT 1 FROM cat.Pais WHERE id_pais = @id_pais)
        SET @err = @err + ' - El pais no existe.';

    IF EXISTS(SELECT 1 FROM comp.Club
        WHERE nombre = @nombre AND id_pais = @id_pais AND id_club <> @id_club) 
        SET @err = @err + ' - Otro club del pais ya usa ese nombre.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Club_Modificacion:' + @err;
        THROW 50082, @err, 1;
    END

    UPDATE comp.Club SET nombre = @nombre, id_pais = @id_pais WHERE id_club = @id_club;
END
GO




CREATE OR ALTER PROCEDURE comp.usp_Club_Baja
    @id_club int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF not EXISTS(SELECT 1 FROM comp.Club WHERE id_club = @id_club)
        SET @err = @err + ' - El club no existe.';

    IF EXISTS (SELECT 1 FROM comp.Convocado WHERE id_club = @id_club) 
        SET @err = @err + ' - Es el club de origen de algun convocado.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Club_Baja:' + @err;
        THROW 50083, @err, 1;
    END

    DELETE FROM comp.Club WHERE id_club = @id_club;
END
GO


/* --------------------9. SELECCION ------------------ */

CREATE OR ALTER PROCEDURE comp.usp_Seleccion_Alta
    @id_torneo int,
    @id_pais   int,
    @id_grupo  int              -- puede ir NULL
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @max_grupo int;
    SET @err = '';

    SELECT @max_grupo = valor FROM comp.ParametroReglamento
    WHERE id_torneo = @id_torneo AND clave = 'MAX_SELECCIONES_GRUPO';

    IF not EXISTS(SELECT 1 FROM comp.Torneo WHERE id_torneo = @id_torneo)
        SET @err = @err + ' - El torneo no existe.';

    IF not EXISTS (SELECT 1 FROM cat.Pais WHERE id_pais = @id_pais) 
        SET @err = @err + ' - El pais no existe.';

    IF EXISTS(SELECT 1 FROM cat.Pais WHERE id_pais = @id_pais AND confederacion IS NULL)
        SET @err = @err + ' - El pais no tiene confederacion cargada.';

    IF EXISTS(SELECT 1 FROM comp.Seleccion WHERE id_torneo = @id_torneo AND id_pais = @id_pais)
        SET @err = @err + ' - Ese pais ya tiene seleccion en el torneo.';

    IF @id_grupo IS NOT NULL
       AND not EXISTS(SELECT 1 FROM comp.Grupo WHERE id_grupo = @id_grupo AND id_torneo = @id_torneo) 
        SET @err = @err + ' - El grupo no existe o es de otro torneo.';

    IF @id_grupo IS NOT NULL AND @max_grupo IS NOT NULL
       AND (SELECT COUNT(*) FROM comp.Seleccion WHERE id_grupo = @id_grupo) >= @max_grupo
        SET @err = @err + ' - El grupo ya esta completo.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Seleccion_Alta:' + @err;
        THROW 50091, @err, 1;
    END

    INSERT INTO comp.Seleccion (id_torneo, id_pais, id_grupo)
    VALUES (@id_torneo, @id_pais, @id_grupo);
END
GO



/* Modificacion: solo se puede cambiar el grupo */
CREATE OR ALTER PROCEDURE comp.usp_Seleccion_Modificacion
    @id_seleccion int,
    @id_grupo     int              -- puede ir NULL
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @id_torneo int;
    DECLARE @max_grupo int;
    SET @err = '';

    SELECT @id_torneo = id_torneo FROM comp.Seleccion WHERE id_seleccion = @id_seleccion;

    SELECT @max_grupo = valor FROM comp.ParametroReglamento
    WHERE id_torneo = @id_torneo AND clave = 'MAX_SELECCIONES_GRUPO';

    IF @id_torneo IS NULL
        SET @err = @err + ' - La seleccion no existe.';

    IF @id_grupo IS NOT NULL
       AND not EXISTS(SELECT 1 FROM comp.Grupo WHERE id_grupo = @id_grupo AND id_torneo = @id_torneo)
        SET @err = @err + ' - El grupo no existe o es de otro torneo.';

    IF @id_grupo IS NOT NULL AND @max_grupo IS NOT NULL
       AND (SELECT COUNT(*) FROM comp.Seleccion
            WHERE id_grupo = @id_grupo AND id_seleccion <> @id_seleccion) >= @max_grupo
        SET @err = @err + ' - El grupo ya esta completo.';

    -- No cambiar de grupo si ya jugo partidos de fase de grupos
    IF EXISTS(SELECT 1
        FROM comp.PartidoSeleccion ps
        INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
        WHERE ps.id_seleccion = @id_seleccion AND p.id_grupo IS NOT NULL) 
        SET @err = @err + ' - La seleccion ya tiene partidos de fase de grupos.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Seleccion_Modificacion:' + @err;
        THROW 50092, @err, 1;
    END

    UPDATE comp.Seleccion SET id_grupo = @id_grupo WHERE id_seleccion = @id_seleccion;
END
GO




CREATE OR ALTER PROCEDURE comp.usp_Seleccion_Baja
    @id_seleccion int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF not EXISTS (SELECT 1 FROM comp.Seleccion WHERE id_seleccion = @id_seleccion) 
        SET @err = @err + ' - La seleccion no existe.';

    IF EXISTS(SELECT 1 FROM comp.Convocado WHERE id_seleccion = @id_seleccion) 
        SET @err = @err + ' - Tiene convocados.';

    IF EXISTS(SELECT 1 FROM comp.CuerpoTecnico WHERE id_seleccion = @id_seleccion) 
        SET @err = @err + ' - Tiene cuerpo tecnico.';

    IF EXISTS(SELECT 1 FROM comp.PartidoSeleccion WHERE id_seleccion = @id_seleccion) 
        SET @err = @err + ' - Tiene partidos.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Seleccion_Baja:' + @err;
        THROW 50093, @err, 1;
    END

    DELETE FROM comp.Seleccion WHERE id_seleccion = @id_seleccion;
END
GO


/* ----------------------10. CUERPO TECNICO ------------------- */

CREATE OR ALTER PROCEDURE comp.usp_CuerpoTecnico_Alta
    @id_seleccion int,
    @id_persona   int,
    @rol          varchar(40)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @id_torneo int;
    SET @err = '';

    SELECT @id_torneo = id_torneo FROM comp.Seleccion WHERE id_seleccion = @id_seleccion;

    IF @id_torneo IS NULL
        SET @err = @err + ' - La seleccion no existe.';

    IF not EXISTS(SELECT 1 FROM comp.Persona WHERE id_persona = @id_persona)  
        SET @err = @err + ' - La persona no existe.';

    IF @rol IS NULL OR @rol NOT IN ('Director Tecnico', 'Ayudante de Campo', 'Preparador Fisico')
        SET @err = @err + ' - Rol invalido (Director Tecnico / Ayudante de Campo / Preparador Fisico).';

    IF EXISTS(SELECT 1 FROM comp.CuerpoTecnico
        WHERE id_seleccion = @id_seleccion AND id_persona = @id_persona) 
        SET @err = @err + ' - La persona ya integra el cuerpo tecnico de esta seleccion.';

    IF @rol = 'Director Tecnico'
       AND EXISTS(SELECT 1 FROM comp.CuerpoTecnico
            WHERE id_seleccion = @id_seleccion AND rol = 'Director Tecnico')  
        SET @err = @err + ' - La seleccion ya tiene director tecnico.';

    -- No puede estar en el cuerpo tecnico de otra seleccion del mismo torneo
    IF EXISTS(SELECT 1
        FROM comp.CuerpoTecnico ct
        INNER JOIN comp.Seleccion s ON s.id_seleccion = ct.id_seleccion
        WHERE ct.id_persona = @id_persona
          AND s.id_torneo = @id_torneo
          AND s.id_seleccion <> @id_seleccion) 
        SET @err = @err + ' - La persona ya integra el cuerpo tecnico de otra seleccion del torneo.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_CuerpoTecnico_Alta:' + @err;
        THROW 50101, @err, 1;
    END

    INSERT INTO comp.CuerpoTecnico (id_seleccion, id_persona, rol)
    VALUES (@id_seleccion, @id_persona, @rol);
END
GO



/* Modificacion: solo se puede cambiar el rol */
CREATE OR ALTER PROCEDURE comp.usp_CuerpoTecnico_Modificacion
    @id_cuerpo_tecnico int,
    @rol               varchar(40)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @id_seleccion int;
    SET @err = '';

    SELECT @id_seleccion = id_seleccion FROM comp.CuerpoTecnico WHERE id_cuerpo_tecnico = @id_cuerpo_tecnico;

    IF @id_seleccion IS NULL
        SET @err = @err + ' - El integrante del cuerpo tecnico no existe.';

    IF @rol IS NULL OR @rol NOT IN ('Director Tecnico', 'Ayudante de Campo', 'Preparador Fisico')
        SET @err = @err + ' - Rol invalido (Director Tecnico / Ayudante de Campo / Preparador Fisico).';

    IF @rol = 'Director Tecnico'
       AND EXISTS(SELECT 1 FROM comp.CuerpoTecnico
            WHERE id_seleccion = @id_seleccion AND rol = 'Director Tecnico'
              AND id_cuerpo_tecnico <> @id_cuerpo_tecnico)
        SET @err = @err + ' - La seleccion ya tiene director tecnico.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_CuerpoTecnico_Modificacion:' + @err;
        THROW 50102, @err, 1;
    END

    UPDATE comp.CuerpoTecnico SET rol = @rol WHERE id_cuerpo_tecnico = @id_cuerpo_tecnico;
END
GO

CREATE OR ALTER PROCEDURE comp.usp_CuerpoTecnico_Baja
    @id_cuerpo_tecnico int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF not EXISTS(SELECT 1 FROM comp.CuerpoTecnico WHERE id_cuerpo_tecnico = @id_cuerpo_tecnico) 
        SET @err = @err + ' - El integrante del cuerpo tecnico no existe.';

    IF EXISTS(SELECT 1 FROM disc.Tarjeta WHERE id_cuerpo_tecnico = @id_cuerpo_tecnico)
        SET @err = @err + ' - Tiene tarjetas registradas.';

    IF EXISTS(SELECT 1 FROM disc.Suspension WHERE id_cuerpo_tecnico = @id_cuerpo_tecnico)
        SET @err = @err + ' - Tiene suspensiones.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_CuerpoTecnico_Baja:' + @err;
        THROW 50103, @err, 1;
    END

    DELETE FROM comp.CuerpoTecnico WHERE id_cuerpo_tecnico = @id_cuerpo_tecnico;
END
GO


/* ------------------11. CONVOCADO ------------

   El Alta registra la convocatoria (una llamada por jugador).
   La baja "deportiva" (lesion, etc.) NO se hace aca: va por el SP de
   logica usp_Convocatoria_Baja, que ademas registra el CambioConvocatoria.
    */

CREATE OR ALTER PROCEDURE comp.usp_Convocado_Alta
    @id_seleccion int,
    @id_jugador   int,
    @dorsal       tinyint,
    @id_club      int,          -- puede ir NULL
    @fecha_alta   date
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @id_torneo int;
    DECLARE @max int;
    DECLARE @activos int;
    SET @err = '';

    -- Datos que vamos a necesitar (si no encuentra nada, la variable queda NULL)
    SELECT @id_torneo = id_torneo FROM comp.Seleccion WHERE id_seleccion = @id_seleccion;

    SELECT @max = valor FROM comp.ParametroReglamento
    WHERE id_torneo = @id_torneo AND clave = 'MAX_CONVOCADOS';

    SET @activos = (SELECT COUNT(*) FROM comp.Convocado
                    WHERE id_seleccion = @id_seleccion AND fecha_baja IS NULL);

    IF @id_torneo IS NULL
        SET @err = @err + ' - La seleccion no existe.';

    IF not EXISTS(SELECT 1 FROM comp.Jugador WHERE id_jugador = @id_jugador) 
        SET @err = @err + ' - El jugador no existe.';

    IF @dorsal IS NULL OR @dorsal < 1 OR @dorsal > 99
        SET @err = @err + ' - El dorsal debe estar entre 1 y 99.';

    IF EXISTS(SELECT 1 FROM comp.Convocado
        WHERE id_seleccion = @id_seleccion AND dorsal = @dorsal AND fecha_baja IS NULL)  
        SET @err = @err + ' - El dorsal ya lo usa otro convocado.';

    IF EXISTS(SELECT 1 FROM comp.Convocado
        WHERE id_seleccion = @id_seleccion AND id_jugador = @id_jugador)  
        SET @err = @err + ' - El jugador ya esta en esta seleccion.';

    -- No puede estar activo en otra seleccion del mismo torneo
    IF EXISTS(SELECT 1
        FROM comp.Convocado c
        INNER JOIN comp.Seleccion s ON s.id_seleccion = c.id_seleccion
        WHERE c.id_jugador = @id_jugador
          AND c.fecha_baja IS NULL
          AND s.id_torneo = @id_torneo
          AND s.id_seleccion <> @id_seleccion)  
        SET @err = @err + ' - El jugador ya esta convocado en otra seleccion.';

    IF @id_club IS NOT NULL AND not EXISTS (SELECT 1 FROM comp.Club WHERE id_club = @id_club) 
        SET @err = @err + ' - El club no existe.';

    IF @fecha_alta IS NULL
        SET @err = @err + ' - La fecha de alta es obligatoria.';

    IF @activos >= @max
        SET @err = @err + ' - La seleccion ya tiene el maximo de convocados.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Convocado_Alta:' + @err;
        THROW 50111, @err, 1;
    END

    INSERT INTO comp.Convocado (id_seleccion, id_jugador, dorsal, id_club, fecha_alta)
    VALUES (@id_seleccion, @id_jugador, @dorsal, @id_club, @fecha_alta);
END
GO



/* Modificacion: solo dorsal y club */
CREATE OR ALTER PROCEDURE comp.usp_Convocado_Modificacion
    @id_convocado int,
    @dorsal       tinyint,
    @id_club      int           -- puede ir NULL
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @id_seleccion int;
    SET @err = '';

    SELECT @id_seleccion = id_seleccion FROM comp.Convocado WHERE id_convocado = @id_convocado;

    IF @id_seleccion IS NULL
        SET @err = @err + ' - El convocado no existe.';

    IF @dorsal IS NULL OR @dorsal < 1 OR @dorsal > 99
        SET @err = @err + ' - El dorsal debe estar entre 1 y 99.';

    IF EXISTS(SELECT 1 FROM comp.Convocado
        WHERE id_seleccion = @id_seleccion AND dorsal = @dorsal
          AND fecha_baja IS NULL AND id_convocado <> @id_convocado) 
        SET @err = @err + ' - El dorsal ya lo usa otro convocado.';

    IF @id_club IS NOT NULL AND not EXISTS(SELECT 1 FROM comp.Club WHERE id_club = @id_club) 
        SET @err = @err + ' - El club no existe.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Convocado_Modificacion:' + @err;
        THROW 50112, @err, 1;
    END

    UPDATE comp.Convocado
    SET dorsal = @dorsal, id_club = @id_club
    WHERE id_convocado = @id_convocado;
END
GO




CREATE OR ALTER PROCEDURE comp.usp_Convocado_Baja
    @id_convocado int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF not EXISTS(SELECT 1 FROM comp.Convocado WHERE id_convocado = @id_convocado) 
        SET @err = @err + ' - El convocado no existe.';

    IF EXISTS(SELECT 1 FROM comp.Alineacion WHERE id_convocado = @id_convocado)
        SET @err = @err + ' - Ya fue alineado en algun partido.';

    IF EXISTS(SELECT 1 FROM comp.CambioConvocatoria
        WHERE id_convocado_baja = @id_convocado OR id_convocado_alta = @id_convocado) 
        SET @err = @err + ' - Participa de un cambio de convocatoria.';

    IF EXISTS(SELECT 1 FROM disc.Suspension WHERE id_convocado = @id_convocado) 
        SET @err = @err + ' - Tiene suspensiones.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Convocado_Baja:' + @err;
        THROW 50113, @err, 1;
    END

    DELETE FROM comp.Convocado WHERE id_convocado = @id_convocado;
END
GO


/* --------------12. CAMBIO CONVOCATORIA ----------------*/

CREATE OR ALTER PROCEDURE comp.usp_CambioConvocatoria_Modificacion
    @id_cambio_convocatoria int,
    @motivo                 varchar(40),
    @observacion            varchar(200)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM comp.CambioConvocatoria WHERE id_cambio_convocatoria = @id_cambio_convocatoria) 
        SET @err = @err + ' - El cambio de convocatoria no existe.';

    IF @motivo IS NULL OR @motivo NOT IN ('Lesion', 'Enfermedad', 'Decision tecnica', 'Sancion')
        SET @err = @err + ' - Motivo invalido (Lesion / Enfermedad / Decision tecnica / Sancion).';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_CambioConvocatoria_Modificacion:' + @err;
        THROW 50122, @err, 1;
    END

    UPDATE comp.CambioConvocatoria
    SET motivo = @motivo, observacion = @observacion
    WHERE id_cambio_convocatoria = @id_cambio_convocatoria;
END
GO


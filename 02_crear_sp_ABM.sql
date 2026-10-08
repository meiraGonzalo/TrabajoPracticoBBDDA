/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - Script 02: Creacion de Stored Procedure
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana
			Rocha Escalera, Sheila nickGithub: sheilarocha02
 Objetivo: crear stored procedures de ABM
=====================================================================
*/

USE MundialDB;
GO

/* =====================================================================
   SEDE
   ===================================================================== */

CREATE OR ALTER PROCEDURE comp.usp_Sede_Alta
    @nombre_estadio nvarchar(100),
    @id_ciudad      int,
    @capacidad      int,
    @latitud        decimal(9,6),     -- puede ir NULL
    @longitud       decimal(9,6)      -- puede ir NULL
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @huso varchar(50);
    SET @err = '';

    -- Huso de la ciudad (si la ciudad no existe, queda NULL)
    SELECT @huso = huso_horario FROM cat.Ciudad WHERE id_ciudad = @id_ciudad;

    IF @nombre_estadio IS NULL OR @nombre_estadio = ''
        SET @err = @err + ' - El nombre del estadio es obligatorio.';

    IF @huso IS NULL
        SET @err = @err + ' - La ciudad no existe.';

    IF @huso IS NOT NULL AND NOT EXISTS(SELECT 1 FROM sys.time_zone_info WHERE name = @huso)
        SET @err = @err + ' - El huso horario de la ciudad no es valido.';

    IF @capacidad IS NULL OR @capacidad <= 0
        SET @err = @err + ' - La capacidad debe ser mayor a cero.';

    IF @latitud < -90 OR @latitud > 90
        SET @err = @err + ' - La latitud debe estar entre -90 y 90.';

    IF @longitud < -180 OR @longitud > 180
        SET @err = @err + ' - La longitud debe estar entre -180 y 180.';

    IF EXISTS(SELECT 1 FROM comp.Sede WHERE nombre_estadio = @nombre_estadio AND id_ciudad = @id_ciudad)
        SET @err = @err + ' - Ya existe ese estadio en la ciudad.';

    IF @err <> ''
    BEGIN
	SET @err = 'usp_Sede_Alta:' + @err;
	THROW 50131, @err, 1;
    END

    INSERT INTO comp.Sede (nombre_estadio, id_ciudad, capacidad, latitud, longitud)
    VALUES (@nombre_estadio, @id_ciudad, @capacidad, @latitud, @longitud);
END
GO

CREATE OR ALTER PROCEDURE comp.usp_Sede_Modificacion
    @id_sede        int,
    @nombre_estadio nvarchar(100),
    @id_ciudad      int,
    @capacidad      int,
    @latitud        decimal(9,6),
    @longitud       decimal(9,6)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @huso varchar(50);
    SET @err = '';

    SELECT @huso = huso_horario FROM cat.Ciudad WHERE id_ciudad = @id_ciudad;

    IF NOT EXISTS(SELECT 1 FROM comp.Sede WHERE id_sede = @id_sede) 
        SET @err = @err + ' - La sede no existe.';

    IF @nombre_estadio IS NULL OR @nombre_estadio = ''
        SET @err = @err + ' - El nombre del estadio es obligatorio.';

    IF @huso IS NULL
        SET @err = @err + ' - La ciudad no existe.';

    IF @huso IS NOT NULL AND NOT EXISTS(SELECT 1 FROM sys.time_zone_info WHERE name = @huso) 
        SET @err = @err + ' - El huso horario de la ciudad no es valido.';

    IF @capacidad IS NULL OR @capacidad <= 0
        SET @err = @err + ' - La capacidad debe ser mayor a cero.';

    -- No achicar la capacidad por debajo de una asistencia ya registrada
    IF EXISTS(SELECT 1 FROM comp.Partido WHERE id_sede = @id_sede AND asistencia > @capacidad) 
        SET @err = @err + ' - Hay partidos con asistencia mayor a la nueva capacidad.';

    -- Cambiar de ciudad cambia el huso: no se permite si ya tiene partidos
    IF EXISTS(SELECT 1 FROM comp.Sede WHERE id_sede = @id_sede AND id_ciudad <> @id_ciudad)
       AND EXISTS(SELECT 1 FROM comp.Partido WHERE id_sede = @id_sede)
        SET @err = @err + ' - No se puede cambiar la ciudad de una sede con partidos.';

    IF @latitud < -90 OR @latitud > 90
        SET @err = @err + ' - La latitud debe estar entre -90 y 90.';

    IF @longitud < -180 OR @longitud > 180
        SET @err = @err + ' - La longitud debe estar entre -180 y 180.';

    IF EXISTS(SELECT 1 FROM comp.Sede
        WHERE nombre_estadio = @nombre_estadio AND id_ciudad = @id_ciudad AND id_sede <> @id_sede)
        SET @err = @err + ' - Ya existe otro estadio con ese nombre en la ciudad.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Sede_Modificacion:' + @err;
        THROW 50132, @err, 1;
    END

    UPDATE comp.Sede
    SET nombre_estadio = @nombre_estadio, id_ciudad = @id_ciudad, capacidad = @capacidad,
        latitud = @latitud, longitud = @longitud
    WHERE id_sede = @id_sede;
END
GO

CREATE OR ALTER PROCEDURE comp.usp_Sede_Baja
    @id_sede int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS(SELECT 1 FROM comp.Sede WHERE id_sede = @id_sede)
        SET @err = @err + ' - La sede no existe.';

    IF EXISTS(SELECT 1 FROM comp.Partido WHERE id_sede = @id_sede)
        SET @err = @err + ' - La sede tiene partidos asignados.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Sede_Baja:' + @err;
        THROW 50133, @err, 1;
    END

    DELETE FROM comp.Sede WHERE id_sede = @id_sede;
END
GO


/* =====================================================================
   PERIODO
     1 Primer tiempo, 2 Segundo tiempo, 3 Alargue 1, 4 Alargue 2,
     5 Definicion por penales
   ===================================================================== */

CREATE OR ALTER PROCEDURE comp.usp_Periodo_Alta
    @nombre varchar(30),
    @orden  tinyint
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF @nombre IS NULL OR @nombre = ''
        SET @err = @err + ' - El nombre es obligatorio.';

    IF EXISTS(SELECT 1 FROM disc.Periodo WHERE nombre = @nombre)
        SET @err = @err + ' - Ya existe un periodo con ese nombre.';

    IF @orden IS NULL OR @orden < 1 OR @orden > 5
        SET @err = @err + ' - El orden debe estar entre 1 y 5.';

    IF EXISTS(SELECT 1 FROM disc.Periodo WHERE orden = @orden)
        SET @err = @err + ' - Ya existe un periodo con ese orden.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Periodo_Alta:' + @err;
        THROW 50141, @err, 1;
    END

    INSERT INTO disc.Periodo (nombre, orden) VALUES (@nombre, @orden);
END
GO

CREATE OR ALTER PROCEDURE comp.usp_Periodo_Modificacion
    @id_periodo int,
    @nombre     varchar(30),
    @orden      tinyint
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS(SELECT 1 FROM disc.Periodo WHERE id_periodo = @id_periodo)
        SET @err = @err + ' - El periodo no existe.';

    IF @nombre IS NULL OR @nombre = ''
        SET @err = @err + ' - El nombre es obligatorio.';

    IF EXISTS(SELECT 1 FROM disc.Periodo WHERE nombre = @nombre AND id_periodo <> @id_periodo)
        SET @err = @err + ' - Otro periodo ya usa ese nombre.';

    IF @orden IS NULL OR @orden < 1 OR @orden > 5
        SET @err = @err + ' - El orden debe estar entre 1 y 5.';

    IF EXISTS(SELECT 1 FROM disc.Periodo WHERE orden = @orden AND id_periodo <> @id_periodo) 
        SET @err = @err + ' - Otro periodo ya usa ese orden.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Periodo_Modificacion:' + @err;
        THROW 50142, @err, 1;
    END

    UPDATE disc.Periodo SET nombre = @nombre, orden = @orden WHERE id_periodo = @id_periodo;
END
GO

CREATE OR ALTER PROCEDURE comp.usp_Periodo_Baja
    @id_periodo int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS(SELECT 1 FROM disc.Periodo WHERE id_periodo = @id_periodo) 
        SET @err = @err + ' - El periodo no existe.';

    IF EXISTS(SELECT 1 FROM comp.Sustitucion WHERE id_periodo = @id_periodo) 
        SET @err = @err + ' - Tiene sustituciones.';

    IF EXISTS(SELECT 1 FROM disc.Gol WHERE id_periodo = @id_periodo)
        SET @err = @err + ' - Tiene goles.';

    IF EXISTS(SELECT 1 FROM disc.Tarjeta WHERE id_periodo = @id_periodo)
        SET @err = @err + ' - Tiene tarjetas.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Periodo_Baja:' + @err;
        THROW 50143, @err, 1;
    END

    DELETE FROM disc.Periodo WHERE id_periodo = @id_periodo;
END
GO


/* =====================================================================
   PARTIDO
   ===================================================================== */

CREATE OR ALTER PROCEDURE comp.usp_Partido_Alta
    @id_torneo      int,
    @nro_partido    smallint,
    @id_fase        int,
    @id_grupo       int,               -- NULL si es eliminacion directa
    @id_sede        int,
    @fecha_hora_utc datetime2(0)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @huso varchar(50);
    DECLARE @fecha_local datetime2(0);
    SET @err = '';

    SELECT @huso = c.huso_horario
    FROM comp.Sede s
    INNER JOIN cat.Ciudad c ON c.id_ciudad = s.id_ciudad
    WHERE s.id_sede = @id_sede;

    -- Calcular la hora local SOLO si el huso es valido y vino la hora UTC
    IF EXISTS(SELECT 1 FROM sys.time_zone_info WHERE name = @huso) AND @fecha_hora_utc IS NOT NULL
        SET @fecha_local = CAST((@fecha_hora_utc AT TIME ZONE 'UTC') AT TIME ZONE @huso AS datetime2(0));

    IF NOT EXISTS(SELECT 1 FROM comp.Torneo WHERE id_torneo = @id_torneo)
        SET @err = @err + ' - El torneo no existe.';

    IF NOT EXISTS(SELECT 1 FROM comp.Fase WHERE id_fase = @id_fase)
        SET @err = @err + ' - La fase no existe.';

    IF @huso IS NULL
        SET @err = @err + ' - La sede no existe.';

    IF @huso IS NOT NULL AND NOT EXISTS(SELECT 1 FROM sys.time_zone_info WHERE name = @huso) 
        SET @err = @err + ' - El huso horario de la sede no es valido.';

    IF @fecha_hora_utc IS NULL
        SET @err = @err + ' - La fecha y hora UTC es obligatoria.';

    IF @nro_partido IS NULL OR @nro_partido <= 0
        SET @err = @err + ' - El numero de partido debe ser mayor a cero.';

    IF EXISTS(SELECT 1 FROM comp.Partido WHERE id_torneo = @id_torneo AND nro_partido = @nro_partido) 
        SET @err = @err + ' - Ya existe ese numero de partido en el torneo.';

    -- Grupo segun la fase
    IF EXISTS(SELECT 1 FROM comp.Fase WHERE id_fase = @id_fase AND es_eliminatoria = 0) 
       AND @id_grupo IS NULL
        SET @err = @err + ' - Un partido de fase de grupos debe indicar el grupo.';

    IF EXISTS(SELECT 1 FROM comp.Fase WHERE id_fase = @id_fase AND es_eliminatoria = 1)
       AND @id_grupo IS NOT NULL
        SET @err = @err + ' - Un partido de eliminacion directa no lleva grupo.';

    IF @id_grupo IS NOT NULL
       AND NOT EXISTS(SELECT 1 FROM comp.Grupo WHERE id_grupo = @id_grupo AND id_torneo = @id_torneo)
        SET @err = @err + ' - El grupo no existe o es de otro torneo.';

    -- Dentro de las fechas del torneo
    IF EXISTS(SELECT 1 FROM comp.Torneo
        WHERE id_torneo = @id_torneo
          AND (CAST(@fecha_local AS date) < fecha_inicio OR CAST(@fecha_local AS date) > fecha_fin)) 
        SET @err = @err + ' - La fecha del partido esta fuera de las fechas del torneo.';

    -- Un solo partido por dia en cada sede
    IF EXISTS(SELECT 1 FROM comp.Partido
        WHERE id_sede = @id_sede AND CAST(fecha_hora_local AS date) = CAST(@fecha_local AS date)) 
        SET @err = @err + ' - La sede ya tiene un partido ese dia.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Partido_Alta:' + @err;
        THROW 50151, @err, 1;
    END

    INSERT INTO comp.Partido (id_torneo, nro_partido, id_fase, id_grupo, id_sede, fecha_hora_utc, fecha_hora_local)
    VALUES (@id_torneo, @nro_partido, @id_fase, @id_grupo, @id_sede, @fecha_hora_utc, @fecha_local);
    -- estado queda en 'PROGRAMADO' por el DEFAULT de la tabla
END
GO

/* Modificacion: sede, horario, estado y partido siguiente.
   Si cambia la sede o la hora UTC, se vuelve a calcular la hora local. */
CREATE OR ALTER PROCEDURE comp.usp_Partido_Modificacion
    @id_partido           int,
    @id_sede              int,
    @fecha_hora_utc       datetime2(0),
    @estado               varchar(15),
    @id_partido_siguiente int            -- NULL si no tiene
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @huso varchar(50);
    DECLARE @fecha_local datetime2(0);
    DECLARE @id_torneo int;
    SET @err = '';

    SELECT @id_torneo = id_torneo FROM comp.Partido WHERE id_partido = @id_partido;

    SELECT @huso = c.huso_horario
    FROM comp.Sede s
    INNER JOIN cat.Ciudad c ON c.id_ciudad = s.id_ciudad
    WHERE s.id_sede = @id_sede;

    IF EXISTS(SELECT 1 FROM sys.time_zone_info WHERE name = @huso)  AND @fecha_hora_utc IS NOT NULL
        SET @fecha_local = CAST((@fecha_hora_utc AT TIME ZONE 'UTC') AT TIME ZONE @huso AS datetime2(0));

    IF @id_torneo IS NULL
        SET @err = @err + ' - El partido no existe.';

    IF @huso IS NULL
        SET @err = @err + ' - La sede no existe.';

    IF @fecha_local IS NULL
        SET @err = @err + ' - No se pudo calcular la hora local (hora UTC o huso invalido).';

    IF @estado IS NULL OR @estado NOT IN ('PROGRAMADO', 'EN_JUEGO', 'FINALIZADO', 'SUSPENDIDO')
        SET @err = @err + ' - Estado invalido (PROGRAMADO / EN_JUEGO / FINALIZADO / SUSPENDIDO).';

    IF EXISTS(SELECT 1 FROM comp.Torneo
        WHERE id_torneo = @id_torneo
          AND (CAST(@fecha_local AS date) < fecha_inicio OR CAST(@fecha_local AS date) > fecha_fin)) 
        SET @err = @err + ' - La fecha del partido esta fuera de las fechas del torneo.';

    IF EXISTS(SELECT 1 FROM comp.Partido
        WHERE id_sede = @id_sede AND CAST(fecha_hora_local AS date) = CAST(@fecha_local AS date)
          AND id_partido <> @id_partido)
        SET @err = @err + ' - La sede ya tiene otro partido ese dia.';

    IF @id_partido_siguiente = @id_partido
        SET @err = @err + ' - El partido no puede ser su propio siguiente.';

    IF @id_partido_siguiente IS NOT NULL
       AND NOT EXISTS(SELECT 1 FROM comp.Partido
            WHERE id_partido = @id_partido_siguiente AND id_torneo = @id_torneo) 
        SET @err = @err + ' - El partido siguiente no existe o es de otro torneo.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Partido_Modificacion:' + @err;
        THROW 50152, @err, 1;
    END

    UPDATE comp.Partido
    SET id_sede = @id_sede, fecha_hora_utc = @fecha_hora_utc, fecha_hora_local = @fecha_local,
        estado = @estado, id_partido_siguiente = @id_partido_siguiente
    WHERE id_partido = @id_partido;
END
GO

CREATE OR ALTER PROCEDURE comp.usp_Partido_Baja
    @id_partido int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS(SELECT 1 FROM comp.Partido WHERE id_partido = @id_partido)
        SET @err = @err + ' - El partido no existe.';

    IF EXISTS(SELECT 1 FROM comp.PartidoSeleccion WHERE id_partido = @id_partido)
        SET @err = @err + ' - Tiene selecciones asignadas.';

    IF EXISTS(SELECT 1 FROM disc.Designacion WHERE id_partido = @id_partido) 
        SET @err = @err + ' - Tiene arbitros designados.';

    IF EXISTS(SELECT 1 FROM pub.ExhibicionPublicitaria WHERE id_partido = @id_partido)
        SET @err = @err + ' - Tiene publicidades asignadas.';

    IF EXISTS(SELECT 1 FROM disc.Suspension WHERE id_partido_cumple = @id_partido) 
        SET @err = @err + ' - Hay suspensiones que se cumplen en este partido.';

    IF EXISTS(SELECT 1 FROM comp.Partido WHERE id_partido_siguiente = @id_partido)
        SET @err = @err + ' - Otro partido lo tiene como partido siguiente.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Partido_Baja:' + @err;
        THROW 50153, @err, 1;
    END

    DELETE FROM comp.Partido WHERE id_partido = @id_partido;
END
GO


/* =====================================================================
   PARTIDO SELECCION
   ===================================================================== */

CREATE OR ALTER PROCEDURE comp.usp_PartidoSeleccion_Alta
    @id_partido   int,
    @id_seleccion int,
    @condicion    char(1)            -- 'L' o 'V'
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @id_torneo int;
    DECLARE @id_grupo int;
    SET @err = '';

    SELECT @id_torneo = id_torneo, @id_grupo = id_grupo FROM comp.Partido WHERE id_partido = @id_partido;

    IF @id_torneo IS NULL
        SET @err = @err + ' - El partido no existe.';

    IF NOT EXISTS(SELECT 1 FROM comp.Seleccion WHERE id_seleccion = @id_seleccion AND id_torneo = @id_torneo) 
        SET @err = @err + ' - La seleccion no existe o es de otro torneo.';

    IF @condicion IS NULL OR @condicion NOT IN ('L', 'V')
        SET @err = @err + ' - La condicion debe ser L o V.';

    IF EXISTS(SELECT 1 FROM comp.PartidoSeleccion WHERE id_partido = @id_partido AND condicion = @condicion) 
        SET @err = @err + ' - Ese lugar (local o visitante) ya esta ocupado.';

    IF EXISTS(SELECT 1 FROM comp.PartidoSeleccion WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion) 
        SET @err = @err + ' - La seleccion ya esta en este partido.';

    -- En fase de grupos, la seleccion tiene que ser del grupo del partido
    IF @id_grupo IS NOT NULL
       AND NOT EXISTS(SELECT 1 FROM comp.Seleccion WHERE id_seleccion = @id_seleccion AND id_grupo = @id_grupo)
        SET @err = @err + ' - La seleccion no pertenece al grupo del partido.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_PartidoSeleccion_Alta:' + @err;
        THROW 50161, @err, 1;
    END

    INSERT INTO comp.PartidoSeleccion (id_partido, id_seleccion, condicion)
    VALUES (@id_partido, @id_seleccion, @condicion);
END
GO

/* Modificacion: esquema tactico (formato 4-3-3 o 3-4-1-2) */
CREATE OR ALTER PROCEDURE comp.usp_PartidoSeleccion_Modificacion
    @id_partido_seleccion int,
    @esquema_tactico      varchar(10)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS(SELECT 1 FROM comp.PartidoSeleccion WHERE id_partido_seleccion = @id_partido_seleccion)
        SET @err = @err + ' - La participacion (partido y seleccion) no existe.';

    IF @esquema_tactico IS NULL
       OR (@esquema_tactico NOT LIKE '[1-9]-[1-9]-[1-9]' AND @esquema_tactico NOT LIKE '[1-9]-[1-9]-[1-9]-[1-9]')
        SET @err = @err + ' - El esquema tactico debe tener el formato 4-3-3 o 3-4-1-2.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_PartidoSeleccion_Modificacion:' + @err;
        THROW 50162, @err, 1;
    END

    UPDATE comp.PartidoSeleccion
    SET esquema_tactico = @esquema_tactico
    WHERE id_partido_seleccion = @id_partido_seleccion;
END
GO

CREATE OR ALTER PROCEDURE comp.usp_PartidoSeleccion_Baja
    @id_partido_seleccion int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS(SELECT 1 FROM comp.PartidoSeleccion WHERE id_partido_seleccion = @id_partido_seleccion)
        SET @err = @err + ' - La participacion (partido y seleccion) no existe.';

    IF EXISTS(SELECT 1 FROM comp.Alineacion WHERE id_partido_seleccion = @id_partido_seleccion)
        SET @err = @err + ' - Tiene alineacion cargada.';

    IF EXISTS(SELECT 1 FROM disc.Tarjeta WHERE id_partido_seleccion = @id_partido_seleccion) 
        SET @err = @err + ' - Tiene tarjetas al cuerpo tecnico.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_PartidoSeleccion_Baja:' + @err;
        THROW 50163, @err, 1;
    END

    DELETE FROM comp.PartidoSeleccion WHERE id_partido_seleccion = @id_partido_seleccion;
END
GO


/* =====================================================================
   ALINEACION
   Un jugador por llamada: titulares con posicion, suplentes sin posicion.
   ===================================================================== */

CREATE OR ALTER PROCEDURE comp.usp_Alineacion_Alta
    @id_partido_seleccion int,
    @id_convocado         int,
    @es_titular           bit,
    @id_posicion_cancha   int           -- NULL para los suplentes
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @id_seleccion int;
    DECLARE @id_partido int;
    DECLARE @titulares int;
    DECLARE @id_arquero int;
    SET @err = '';

    SELECT @id_seleccion = id_seleccion, @id_partido = id_partido
    FROM comp.PartidoSeleccion WHERE id_partido_seleccion = @id_partido_seleccion;

    SET @titulares = (SELECT COUNT(*) FROM comp.Alineacion
                      WHERE id_partido_seleccion = @id_partido_seleccion AND es_titular = 1);

    SELECT @id_arquero = id_posicion FROM comp.Posicion WHERE nombre = 'Arquero';

    IF @id_seleccion IS NULL
        SET @err = @err + ' - La participacion (partido y seleccion) no existe.';

    IF NOT EXISTS(SELECT 1 FROM comp.Convocado WHERE id_convocado = @id_convocado AND id_seleccion = @id_seleccion)
        SET @err = @err + ' - El jugador no es convocado de esta seleccion.';

    IF EXISTS(SELECT 1 FROM comp.Convocado WHERE id_convocado = @id_convocado AND fecha_baja IS NOT NULL)
        SET @err = @err + ' - El jugador fue dado de baja de la convocatoria.';

    IF EXISTS(SELECT 1 FROM comp.Alineacion
        WHERE id_partido_seleccion = @id_partido_seleccion AND id_convocado = @id_convocado)
        SET @err = @err + ' - El jugador ya esta en la alineacion.';

    IF @es_titular IS NULL
        SET @err = @err + ' - Hay que indicar si es titular.';

    IF @es_titular = 1 AND @titulares >= 11
        SET @err = @err + ' - Ya hay 11 titulares.';

    IF @es_titular = 1 AND @id_posicion_cancha IS NULL
        SET @err = @err + ' - Un titular debe tener posicion en cancha.';

    IF @es_titular = 0 AND @id_posicion_cancha IS NOT NULL
        SET @err = @err + ' - Un suplente no lleva posicion en cancha.';

    IF @id_posicion_cancha IS NOT NULL
       AND NOT EXISTS(SELECT 1 FROM comp.Posicion WHERE id_posicion = @id_posicion_cancha)
        SET @err = @err + ' - La posicion no existe.';

    IF @es_titular = 1 AND @id_posicion_cancha = @id_arquero
       AND EXISTS(SELECT 1 FROM comp.Alineacion
            WHERE id_partido_seleccion = @id_partido_seleccion
              AND es_titular = 1 AND id_posicion_cancha = @id_arquero)
        SET @err = @err + ' - Ya hay un arquero titular.';

    -- Suspendido: suspension pendiente para este partido o todavia sin partido asignado
    IF EXISTS(SELECT 1 FROM disc.Suspension
        WHERE id_convocado = @id_convocado
          AND estado = 'PENDIENTE'
          AND (id_partido_cumple = @id_partido OR id_partido_cumple IS NULL))
        SET @err = @err + ' - El jugador esta suspendido para este partido.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Alineacion_Alta:' + @err;
        THROW 50171, @err, 1;
    END

    INSERT INTO comp.Alineacion (id_partido_seleccion, id_convocado, es_titular, id_posicion_cancha)
    VALUES (@id_partido_seleccion, @id_convocado, @es_titular, @id_posicion_cancha);
END
GO

/* Modificacion: titular/suplente y posicion.
   Solo si el jugador todavia no tiene eventos en el partido. */
CREATE OR ALTER PROCEDURE comp.usp_Alineacion_Modificacion
    @id_alineacion      int,
    @es_titular         bit,
    @id_posicion_cancha int           -- NULL para los suplentes
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @id_ps int;
    DECLARE @titulares int;
    DECLARE @id_arquero int;
    SET @err = '';

    SELECT @id_ps = id_partido_seleccion FROM comp.Alineacion WHERE id_alineacion = @id_alineacion;

    SET @titulares = (SELECT COUNT(*) FROM comp.Alineacion
                      WHERE id_partido_seleccion = @id_ps AND es_titular = 1 AND id_alineacion <> @id_alineacion);

    SELECT @id_arquero = id_posicion FROM comp.Posicion WHERE nombre = 'Arquero';

    IF @id_ps IS NULL
        SET @err = @err + ' - La alineacion no existe.';

    IF EXISTS(SELECT 1 FROM comp.Sustitucion
        WHERE id_alineacion_sale = @id_alineacion OR id_alineacion_entra = @id_alineacion)
        SET @err = @err + ' - El jugador ya participo de un cambio.';

    IF EXISTS(SELECT 1 FROM disc.Gol
        WHERE id_alineacion_autor = @id_alineacion OR id_alineacion_asistencia = @id_alineacion)
        SET @err = @err + ' - El jugador ya tiene goles o asistencias.';

    IF EXISTS(SELECT 1 FROM disc.Tarjeta WHERE id_alineacion = @id_alineacion)
        SET @err = @err + ' - El jugador ya tiene tarjetas.';

    IF @es_titular IS NULL
        SET @err = @err + ' - Hay que indicar si es titular.';

    IF @es_titular = 1 AND @titulares >= 11
        SET @err = @err + ' - Ya hay 11 titulares.';

    IF @es_titular = 1 AND @id_posicion_cancha IS NULL
        SET @err = @err + ' - Un titular debe tener posicion en cancha.';

    IF @es_titular = 0 AND @id_posicion_cancha IS NOT NULL
        SET @err = @err + ' - Un suplente no lleva posicion en cancha.';

    IF @id_posicion_cancha IS NOT NULL
       AND NOT EXISTS(SELECT 1 FROM comp.Posicion WHERE id_posicion = @id_posicion_cancha)
        SET @err = @err + ' - La posicion no existe.';

    IF @es_titular = 1 AND @id_posicion_cancha = @id_arquero
       AND EXISTS(SELECT 1 FROM comp.Alineacion
            WHERE id_partido_seleccion = @id_ps AND es_titular = 1
              AND id_posicion_cancha = @id_arquero AND id_alineacion <> @id_alineacion) 
        SET @err = @err + ' - Ya hay un arquero titular.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Alineacion_Modificacion:' + @err;
        THROW 50172, @err, 1;
    END

    UPDATE comp.Alineacion
    SET es_titular = @es_titular, id_posicion_cancha = @id_posicion_cancha
    WHERE id_alineacion = @id_alineacion;
END
GO

CREATE OR ALTER PROCEDURE comp.usp_Alineacion_Baja
    @id_alineacion int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS(SELECT 1 FROM comp.Alineacion WHERE id_alineacion = @id_alineacion) 
        SET @err = @err + ' - La alineacion no existe.';

    IF EXISTS(SELECT 1 FROM comp.Sustitucion
        WHERE id_alineacion_sale = @id_alineacion OR id_alineacion_entra = @id_alineacion)
        SET @err = @err + ' - El jugador participo de un cambio.';

    IF EXISTS(SELECT 1 FROM disc.Gol
        WHERE id_alineacion_autor = @id_alineacion OR id_alineacion_asistencia = @id_alineacion)
        SET @err = @err + ' - El jugador tiene goles o asistencias.';

    IF EXISTS(SELECT 1 FROM disc.Tarjeta WHERE id_alineacion = @id_alineacion)
        SET @err = @err + ' - El jugador tiene tarjetas.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Alineacion_Baja:' + @err;
        THROW 50173, @err, 1;
    END

    DELETE FROM comp.Alineacion WHERE id_alineacion = @id_alineacion;
END
GO


/* =====================================================================
   SUSTITUCION
   Supone que los cambios se cargan en el orden en que ocurrieron.
   ===================================================================== */

CREATE OR ALTER PROCEDURE comp.usp_Sustitucion_Alta
    @id_alineacion_sale  int,
    @id_alineacion_entra int,
    @id_periodo          int,
    @minuto              tinyint,
    @minuto_adicional    tinyint,          -- 0 si no hubo adicional
    @nro_ventana         tinyint,          -- NULL = entretiempo
    @motivo              varchar(20)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @ps_sale int;
    DECLARE @ps_entra int;
    DECLARE @orden tinyint;
    DECLARE @id_torneo int;
    DECLARE @max_cambios int;
    DECLARE @max_ventanas int;
    DECLARE @extra_cambios int;
    DECLARE @extra_ventanas int;
    DECLARE @cambios_usados int;
    DECLARE @ventanas_usadas int;
    SET @err = '';

    /* ----- Datos que vamos a necesitar ----- */
    SELECT @ps_sale  = id_partido_seleccion FROM comp.Alineacion WHERE id_alineacion = @id_alineacion_sale;
    SELECT @ps_entra = id_partido_seleccion FROM comp.Alineacion WHERE id_alineacion = @id_alineacion_entra;
    SELECT @orden    = orden FROM disc.Periodo WHERE id_periodo = @id_periodo;

    SELECT @id_torneo = p.id_torneo
    FROM comp.PartidoSeleccion ps
    INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
    WHERE ps.id_partido_seleccion = @ps_sale;

    SELECT @max_cambios    = valor FROM comp.ParametroReglamento WHERE id_torneo = @id_torneo AND clave = 'MAX_CAMBIOS';
    SELECT @max_ventanas   = valor FROM comp.ParametroReglamento WHERE id_torneo = @id_torneo AND clave = 'MAX_VENTANAS';
    SELECT @extra_cambios  = valor FROM comp.ParametroReglamento WHERE id_torneo = @id_torneo AND clave = 'CAMBIOS_EXTRA_ALARGUE';
    SELECT @extra_ventanas = valor FROM comp.ParametroReglamento WHERE id_torneo = @id_torneo AND clave = 'VENTANAS_EXTRA_ALARGUE';

    -- En el alargue se suman los extras (ISNULL: si el parametro no esta, suma 0)
    IF @orden >= 3
    BEGIN
        SET @max_cambios  = @max_cambios + ISNULL(@extra_cambios, 0);
        SET @max_ventanas = @max_ventanas + ISNULL(@extra_ventanas, 0);
    END

    -- Cambios y ventanas que ya uso el equipo (COUNT DISTINCT no cuenta los NULL del entretiempo)
    SELECT @cambios_usados = COUNT(*), @ventanas_usadas = COUNT(DISTINCT s.nro_ventana)
    FROM comp.Sustitucion s
    INNER JOIN comp.Alineacion a ON a.id_alineacion = s.id_alineacion_sale
    WHERE a.id_partido_seleccion = @ps_sale;

    /* ----- Validaciones generales ----- */
    IF @ps_sale IS NULL OR @ps_entra IS NULL
        SET @err = @err + ' - Alguno de los jugadores no esta en la alineacion.';

    IF @ps_sale <> @ps_entra
        SET @err = @err + ' - Los dos jugadores deben ser del mismo equipo en el mismo partido.';

    IF @motivo IS NULL OR @motivo NOT IN ('Tactico', 'Lesion', 'Precaucion')
        SET @err = @err + ' - Motivo invalido (Tactico / Lesion / Precaucion).';

    IF @orden IS NULL
        SET @err = @err + ' - El periodo no existe.';

    IF @orden = 5
        SET @err = @err + ' - No hay cambios en la definicion por penales.';

    IF @minuto IS NULL OR @minuto < 1 OR @minuto > 120
        SET @err = @err + ' - El minuto debe estar entre 1 y 120.';

    /* ----- El que sale tiene que estar jugando ----- */
    IF NOT EXISTS(SELECT 1 FROM comp.Alineacion WHERE id_alineacion = @id_alineacion_sale AND es_titular = 1)
       AND NOT EXISTS(SELECT 1 FROM comp.Sustitucion WHERE id_alineacion_entra = @id_alineacion_sale)
        SET @err = @err + ' - El que sale no estaba en cancha (no fue titular ni entro).';

    IF EXISTS(SELECT 1 FROM comp.Sustitucion WHERE id_alineacion_sale = @id_alineacion_sale)
        SET @err = @err + ' - El que sale ya habia salido antes.';

    IF EXISTS(SELECT 1 FROM disc.Tarjeta
        WHERE id_alineacion = @id_alineacion_sale
          AND tipo_tarjeta IN ('Roja directa', 'Roja por doble amarilla'))
        SET @err = @err + ' - El que sale fue expulsado.';

    /* ----- El que entra tiene que estar en el banco ----- */
    IF EXISTS(SELECT 1 FROM comp.Alineacion WHERE id_alineacion = @id_alineacion_entra AND es_titular = 1)
        SET @err = @err + ' - El que entra fue titular: no puede entrar como suplente.';

    IF EXISTS(SELECT 1 FROM comp.Sustitucion WHERE id_alineacion_entra = @id_alineacion_entra)
        SET @err = @err + ' - El que entra ya habia entrado antes.';

    IF EXISTS(SELECT 1 FROM disc.Tarjeta
        WHERE id_alineacion = @id_alineacion_entra
          AND tipo_tarjeta IN ('Roja directa', 'Roja por doble amarilla')) 
        SET @err = @err + ' - El que entra fue expulsado.';

    /* ----- Limites del reglamento ----- */
    IF @ps_sale IS NOT NULL AND (@max_cambios IS NULL OR @max_ventanas IS NULL)
        SET @err = @err + ' - Faltan los parametros MAX_CAMBIOS / MAX_VENTANAS del torneo.';

    IF @cambios_usados + 1 > @max_cambios
        SET @err = @err + ' - Se supera la cantidad maxima de cambios.';

    -- Una ventana NUEVA (que el equipo todavia no uso) no puede pasarse del maximo
    IF @nro_ventana IS NOT NULL
       AND NOT EXISTS(SELECT 1 FROM comp.Sustitucion s
            INNER JOIN comp.Alineacion a ON a.id_alineacion = s.id_alineacion_sale
            WHERE a.id_partido_seleccion = @ps_sale AND s.nro_ventana = @nro_ventana)
       AND @ventanas_usadas + 1 > @max_ventanas
        SET @err = @err + ' - Se supera la cantidad maxima de ventanas de cambio.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Sustitucion_Alta:' + @err;
        THROW 50181, @err, 1;
    END

    INSERT INTO comp.Sustitucion (id_alineacion_sale, id_alineacion_entra, id_periodo,
                                  minuto, minuto_adicional, nro_ventana, motivo)
    VALUES (@id_alineacion_sale, @id_alineacion_entra, @id_periodo,
            @minuto, ISNULL(@minuto_adicional, 0), @nro_ventana, @motivo);
END
GO

/* Modificacion: solo el motivo.
   Para cambiar minuto o jugadores: baja y alta de nuevo (asi se revalida todo). */
CREATE OR ALTER PROCEDURE comp.usp_Sustitucion_Modificacion
    @id_sustitucion int,
    @motivo         varchar(20)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS(SELECT 1 FROM comp.Sustitucion WHERE id_sustitucion = @id_sustitucion)
        SET @err = @err + ' - El cambio no existe.';

    IF @motivo IS NULL OR @motivo NOT IN ('Tactico', 'Lesion', 'Precaucion')
        SET @err = @err + ' - Motivo invalido (Tactico / Lesion / Precaucion).';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Sustitucion_Modificacion:' + @err;
        THROW 520182, @err, 1;
    END

    UPDATE comp.Sustitucion SET motivo = @motivo WHERE id_sustitucion = @id_sustitucion;
END
GO

/* Baja: solo si el que entro no tuvo eventos despues (si no, se rompe la historia del partido) */
CREATE OR ALTER PROCEDURE comp.usp_Sustitucion_Baja
    @id_sustitucion int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @entra int;
    SET @err = '';

    SELECT @entra = id_alineacion_entra FROM comp.Sustitucion WHERE id_sustitucion = @id_sustitucion;

    IF @entra IS NULL
        SET @err = @err + ' - El cambio no existe.';

    IF EXISTS(SELECT 1 FROM comp.Sustitucion WHERE id_alineacion_sale = @entra)
        SET @err = @err + ' - El jugador que entro salio despues en otro cambio.';

    IF EXISTS(SELECT 1 FROM disc.Gol WHERE id_alineacion_autor = @entra OR id_alineacion_asistencia = @entra)
        SET @err = @err + ' - El jugador que entro tiene goles o asistencias.';

    IF EXISTS(SELECT 1 FROM disc.Tarjeta WHERE id_alineacion = @entra)
        SET @err = @err + ' - El jugador que entro tiene tarjetas.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Sustitucion_Baja:' + @err;
        THROW 50183, @err, 1;
    END

    DELETE FROM comp.Sustitucion WHERE id_sustitucion = @id_sustitucion;
END
GO

PRINT 'OK: SP de ABM creados.';
GO
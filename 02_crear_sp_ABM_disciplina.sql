/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - Script 02 (modulo Disciplina y Arbitros): SP de ABM
 Grupo 02 - Comision 02-5600
 Integrantes: Miro, Saba.
 Objetivo: crear stored procedures de ABM del modulo disciplina/arbitros
           (schema disc).

 Formato de errores (THROW): 5 - TT - A
      5  = fijo (los errores propios empiezan en 50000)
      TT = tabla: 19 TipoGol, 20 Gol, 21 Tarjeta, 22 Suspension,
                  23 Arbitro, 24 ArbitroIdioma, 25 Designacion, 26 InformeArbitral
      A  = accion (1 = Alta, 2 = Modificacion, 3 = Baja)
=====================================================================
*/


/* ------------------ 19. TIPO GOL ------------------ */

CREATE OR ALTER PROCEDURE disc.usp_TipoGol_Alta
    @nombre varchar(30)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF @nombre IS NULL OR @nombre = ''
        SET @err = @err + ' - El nombre es obligatorio.';

    IF EXISTS (SELECT 1 FROM disc.TipoGol WHERE nombre = @nombre)
        SET @err = @err + ' - Ya existe ese tipo de gol.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_TipoGol_Alta:' + @err;
        THROW 50191, @err, 1;
    END

    INSERT INTO disc.TipoGol (nombre) VALUES (@nombre);
END
GO


CREATE OR ALTER PROCEDURE disc.usp_TipoGol_Modificacion
    @id_tipo_gol int,
    @nombre      varchar(30)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM disc.TipoGol WHERE id_tipo_gol = @id_tipo_gol)
        SET @err = @err + ' - El tipo de gol no existe.';

    IF @nombre IS NULL OR @nombre = ''
        SET @err = @err + ' - El nombre es obligatorio.';

    IF EXISTS (SELECT 1 FROM disc.TipoGol WHERE nombre = @nombre AND id_tipo_gol <> @id_tipo_gol)
        SET @err = @err + ' - Otro tipo de gol ya usa ese nombre.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_TipoGol_Modificacion:' + @err;
        THROW 50192, @err, 1;
    END

    UPDATE disc.TipoGol SET nombre = @nombre WHERE id_tipo_gol = @id_tipo_gol;
END
GO


CREATE OR ALTER PROCEDURE disc.usp_TipoGol_Baja
    @id_tipo_gol int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM disc.TipoGol WHERE id_tipo_gol = @id_tipo_gol)
        SET @err = @err + ' - El tipo de gol no existe.';

    IF EXISTS (SELECT 1 FROM disc.Gol WHERE id_tipo_gol = @id_tipo_gol)
        SET @err = @err + ' - Se uso en algun gol.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_TipoGol_Baja:' + @err;
        THROW 50193, @err, 1;
    END

    DELETE FROM disc.TipoGol WHERE id_tipo_gol = @id_tipo_gol;
END
GO


/* ------------------ 20. GOL ------------------ */

CREATE OR ALTER PROCEDURE disc.usp_Gol_Alta
    @id_alineacion_autor      int,
    @id_alineacion_asistencia int,          -- puede ir NULL
    @id_tipo_gol              int,
    @id_periodo               int,
    @minuto                   tinyint,
    @minuto_adicional         tinyint = 0
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM comp.Alineacion WHERE id_alineacion = @id_alineacion_autor)
        SET @err = @err + ' - La alineacion del autor no existe.';

    IF NOT EXISTS (SELECT 1 FROM disc.TipoGol WHERE id_tipo_gol = @id_tipo_gol)
        SET @err = @err + ' - El tipo de gol no existe.';

    IF NOT EXISTS (SELECT 1 FROM comp.Periodo WHERE id_periodo = @id_periodo)
        SET @err = @err + ' - El periodo no existe.';

    IF @minuto IS NULL OR @minuto > 130
        SET @err = @err + ' - El minuto debe estar entre 0 y 130.';

    -- Asistencia opcional: si viene, debe existir, no ser el mismo autor y ser del mismo equipo
    IF @id_alineacion_asistencia IS NOT NULL
       AND @id_alineacion_asistencia = @id_alineacion_autor
        SET @err = @err + ' - El autor y la asistencia no pueden ser el mismo.';

    IF @id_alineacion_asistencia IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM comp.Alineacion WHERE id_alineacion = @id_alineacion_asistencia)
        SET @err = @err + ' - La alineacion de la asistencia no existe.';

    IF @id_alineacion_asistencia IS NOT NULL
       AND EXISTS (SELECT 1
                   FROM comp.Alineacion a_aut
                   INNER JOIN comp.Alineacion a_asi
                        ON a_aut.id_partido_seleccion <> a_asi.id_partido_seleccion
                   WHERE a_aut.id_alineacion = @id_alineacion_autor
                     AND a_asi.id_alineacion = @id_alineacion_asistencia)
        SET @err = @err + ' - El autor y la asistencia deben ser de la misma seleccion.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Gol_Alta:' + @err;
        THROW 50201, @err, 1;
    END

    INSERT INTO disc.Gol (id_alineacion_autor, id_alineacion_asistencia, id_tipo_gol, id_periodo, minuto, minuto_adicional)
    VALUES (@id_alineacion_autor, @id_alineacion_asistencia, @id_tipo_gol, @id_periodo, @minuto, @minuto_adicional);
END
GO


CREATE OR ALTER PROCEDURE disc.usp_Gol_Modificacion
    @id_gol                   int,
    @id_tipo_gol              int,
    @id_periodo               int,
    @minuto                   tinyint,
    @minuto_adicional         tinyint = 0
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM disc.Gol WHERE id_gol = @id_gol)
        SET @err = @err + ' - El gol no existe.';

    IF NOT EXISTS (SELECT 1 FROM disc.TipoGol WHERE id_tipo_gol = @id_tipo_gol)
        SET @err = @err + ' - El tipo de gol no existe.';

    IF NOT EXISTS (SELECT 1 FROM comp.Periodo WHERE id_periodo = @id_periodo)
        SET @err = @err + ' - El periodo no existe.';

    IF @minuto IS NULL OR @minuto > 130
        SET @err = @err + ' - El minuto debe estar entre 0 y 130.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Gol_Modificacion:' + @err;
        THROW 50202, @err, 1;
    END

    UPDATE disc.Gol
    SET id_tipo_gol = @id_tipo_gol, id_periodo = @id_periodo,
        minuto = @minuto, minuto_adicional = @minuto_adicional
    WHERE id_gol = @id_gol;
END
GO


CREATE OR ALTER PROCEDURE disc.usp_Gol_Baja
    @id_gol int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM disc.Gol WHERE id_gol = @id_gol)
        SET @err = @err + ' - El gol no existe.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Gol_Baja:' + @err;
        THROW 50203, @err, 1;
    END

    DELETE FROM disc.Gol WHERE id_gol = @id_gol;
END
GO


/* ------------------ 21. TARJETA ------------------ */

CREATE OR ALTER PROCEDURE disc.usp_Tarjeta_Alta
    @id_alineacion        int,          -- rama JUGADOR (los otros dos en NULL)
    @id_cuerpo_tecnico    int,          -- rama CUERPO TECNICO (+ id_partido_seleccion)
    @id_partido_seleccion int,
    @tipo_tarjeta         varchar(30),
    @motivo               varchar(200),
    @id_periodo           int,
    @minuto               tinyint,
    @minuto_adicional     tinyint = 0
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    -- Arco exclusivo: jugador O cuerpo tecnico, nunca ambos ni ninguno
    IF NOT ( (@id_alineacion IS NOT NULL AND @id_cuerpo_tecnico IS NULL     AND @id_partido_seleccion IS NULL)
          OR (@id_alineacion IS NULL     AND @id_cuerpo_tecnico IS NOT NULL AND @id_partido_seleccion IS NOT NULL) )
        SET @err = @err + ' - Indicar jugador (alineacion) O cuerpo tecnico (+ partido_seleccion), no ambos.';

    IF @tipo_tarjeta IS NULL OR @tipo_tarjeta NOT IN ('Amarilla','Roja directa','Roja por doble amarilla')
        SET @err = @err + ' - Tipo de tarjeta invalido.';

    IF @motivo IS NULL OR @motivo = ''
        SET @err = @err + ' - El motivo es obligatorio.';

    IF NOT EXISTS (SELECT 1 FROM comp.Periodo WHERE id_periodo = @id_periodo)
        SET @err = @err + ' - El periodo no existe.';

    IF @minuto IS NULL OR @minuto > 130
        SET @err = @err + ' - El minuto debe estar entre 0 y 130.';

    -- Rama jugador
    IF @id_alineacion IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM comp.Alineacion WHERE id_alineacion = @id_alineacion)
        SET @err = @err + ' - La alineacion no existe.';

    -- Rama cuerpo tecnico
    IF @id_cuerpo_tecnico IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM comp.CuerpoTecnico WHERE id_cuerpo_tecnico = @id_cuerpo_tecnico)
        SET @err = @err + ' - El cuerpo tecnico no existe.';

    IF @id_partido_seleccion IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM comp.PartidoSeleccion WHERE id_partido_seleccion = @id_partido_seleccion)
        SET @err = @err + ' - El partido_seleccion no existe.';

    -- Coherencia: el cuerpo tecnico sancionado debe ser de la seleccion que juega ese partido
    IF @id_cuerpo_tecnico IS NOT NULL AND @id_partido_seleccion IS NOT NULL
       AND NOT EXISTS (SELECT 1
                       FROM comp.CuerpoTecnico ct
                       INNER JOIN comp.PartidoSeleccion ps
                            ON ps.id_seleccion = ct.id_seleccion
                       WHERE ct.id_cuerpo_tecnico = @id_cuerpo_tecnico
                         AND ps.id_partido_seleccion = @id_partido_seleccion)
        SET @err = @err + ' - El cuerpo tecnico no pertenece a la seleccion de ese partido.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Tarjeta_Alta:' + @err;
        THROW 50211, @err, 1;
    END

    INSERT INTO disc.Tarjeta (id_alineacion, id_cuerpo_tecnico, id_partido_seleccion,
                              tipo_tarjeta, motivo, id_periodo, minuto, minuto_adicional)
    VALUES (@id_alineacion, @id_cuerpo_tecnico, @id_partido_seleccion,
            @tipo_tarjeta, @motivo, @id_periodo, @minuto, @minuto_adicional);
END
GO


/* Modificacion: solo datos descriptivos (no se cambia el sancionado) */
CREATE OR ALTER PROCEDURE disc.usp_Tarjeta_Modificacion
    @id_tarjeta       int,
    @tipo_tarjeta     varchar(30),
    @motivo           varchar(200),
    @id_periodo       int,
    @minuto           tinyint,
    @minuto_adicional tinyint = 0
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM disc.Tarjeta WHERE id_tarjeta = @id_tarjeta)
        SET @err = @err + ' - La tarjeta no existe.';

    IF @tipo_tarjeta IS NULL OR @tipo_tarjeta NOT IN ('Amarilla','Roja directa','Roja por doble amarilla')
        SET @err = @err + ' - Tipo de tarjeta invalido.';

    IF @motivo IS NULL OR @motivo = ''
        SET @err = @err + ' - El motivo es obligatorio.';

    IF NOT EXISTS (SELECT 1 FROM comp.Periodo WHERE id_periodo = @id_periodo)
        SET @err = @err + ' - El periodo no existe.';

    IF @minuto IS NULL OR @minuto > 130
        SET @err = @err + ' - El minuto debe estar entre 0 y 130.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Tarjeta_Modificacion:' + @err;
        THROW 50212, @err, 1;
    END

    UPDATE disc.Tarjeta
    SET tipo_tarjeta = @tipo_tarjeta, motivo = @motivo,
        id_periodo = @id_periodo, minuto = @minuto, minuto_adicional = @minuto_adicional
    WHERE id_tarjeta = @id_tarjeta;
END
GO


CREATE OR ALTER PROCEDURE disc.usp_Tarjeta_Baja
    @id_tarjeta int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM disc.Tarjeta WHERE id_tarjeta = @id_tarjeta)
        SET @err = @err + ' - La tarjeta no existe.';

    IF EXISTS (SELECT 1 FROM disc.Suspension WHERE id_tarjeta_origen = @id_tarjeta)
        SET @err = @err + ' - Origino una suspension.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Tarjeta_Baja:' + @err;
        THROW 50213, @err, 1;
    END

    DELETE FROM disc.Tarjeta WHERE id_tarjeta = @id_tarjeta;
END
GO


/* ------------------ 22. SUSPENSION ------------------
   El alta "automatica" por acumulacion la hace el SP de logica.
   Este ABM permite el alta/baja manual y cambiar el estado. */

CREATE OR ALTER PROCEDURE disc.usp_Suspension_Alta
    @id_convocado       int,          -- rama JUGADOR (excluyente)
    @id_cuerpo_tecnico  int,          -- rama CUERPO TECNICO (excluyente)
    @id_tarjeta_origen  int,
    @id_partido_cumple  int,          -- puede ir NULL
    @estado             varchar(10) = 'PENDIENTE'
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    -- Arco exclusivo
    IF NOT ( (@id_convocado IS NOT NULL AND @id_cuerpo_tecnico IS NULL)
          OR (@id_convocado IS NULL     AND @id_cuerpo_tecnico IS NOT NULL) )
        SET @err = @err + ' - Indicar jugador (convocado) O cuerpo tecnico, no ambos.';

    IF @id_convocado IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM comp.Convocado WHERE id_convocado = @id_convocado)
        SET @err = @err + ' - El convocado no existe.';

    IF @id_cuerpo_tecnico IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM comp.CuerpoTecnico WHERE id_cuerpo_tecnico = @id_cuerpo_tecnico)
        SET @err = @err + ' - El cuerpo tecnico no existe.';

    IF NOT EXISTS (SELECT 1 FROM disc.Tarjeta WHERE id_tarjeta = @id_tarjeta_origen)
        SET @err = @err + ' - La tarjeta de origen no existe.';

    IF @id_partido_cumple IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM comp.Partido WHERE id_partido = @id_partido_cumple)
        SET @err = @err + ' - El partido en el que cumple no existe.';

    IF @estado IS NULL OR @estado NOT IN ('PENDIENTE','CUMPLIDA','ANULADA')
        SET @err = @err + ' - Estado invalido (PENDIENTE / CUMPLIDA / ANULADA).';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Suspension_Alta:' + @err;
        THROW 50221, @err, 1;
    END

    INSERT INTO disc.Suspension (id_convocado, id_cuerpo_tecnico, id_tarjeta_origen, id_partido_cumple, estado)
    VALUES (@id_convocado, @id_cuerpo_tecnico, @id_tarjeta_origen, @id_partido_cumple, @estado);
END
GO


CREATE OR ALTER PROCEDURE disc.usp_Suspension_Modificacion
    @id_suspension     int,
    @id_partido_cumple int,          -- puede ir NULL
    @estado            varchar(10)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM disc.Suspension WHERE id_suspension = @id_suspension)
        SET @err = @err + ' - La suspension no existe.';

    IF @id_partido_cumple IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM comp.Partido WHERE id_partido = @id_partido_cumple)
        SET @err = @err + ' - El partido en el que cumple no existe.';

    IF @estado IS NULL OR @estado NOT IN ('PENDIENTE','CUMPLIDA','ANULADA')
        SET @err = @err + ' - Estado invalido (PENDIENTE / CUMPLIDA / ANULADA).';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Suspension_Modificacion:' + @err;
        THROW 50222, @err, 1;
    END

    UPDATE disc.Suspension
    SET id_partido_cumple = @id_partido_cumple, estado = @estado
    WHERE id_suspension = @id_suspension;
END
GO


CREATE OR ALTER PROCEDURE disc.usp_Suspension_Baja
    @id_suspension int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM disc.Suspension WHERE id_suspension = @id_suspension)
        SET @err = @err + ' - La suspension no existe.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Suspension_Baja:' + @err;
        THROW 50223, @err, 1;
    END

    DELETE FROM disc.Suspension WHERE id_suspension = @id_suspension;
END
GO


/* ------------------ 23. ARBITRO ------------------ */

CREATE OR ALTER PROCEDURE disc.usp_Arbitro_Alta
    @id_arbitro int,                 -- es una Persona existente (subtipo)
    @categoria  varchar(20)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM comp.Persona WHERE id_persona = @id_arbitro)
        SET @err = @err + ' - La persona no existe.';

    IF EXISTS (SELECT 1 FROM disc.Arbitro WHERE id_arbitro = @id_arbitro)
        SET @err = @err + ' - La persona ya esta registrada como arbitro.';

    IF @categoria IS NULL OR @categoria NOT IN ('FIFA','Confederacion')
        SET @err = @err + ' - Categoria invalida (FIFA / Confederacion).';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Arbitro_Alta:' + @err;
        THROW 50231, @err, 1;
    END

    INSERT INTO disc.Arbitro (id_arbitro, categoria) VALUES (@id_arbitro, @categoria);
END
GO


CREATE OR ALTER PROCEDURE disc.usp_Arbitro_Modificacion
    @id_arbitro int,
    @categoria  varchar(20)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM disc.Arbitro WHERE id_arbitro = @id_arbitro)
        SET @err = @err + ' - El arbitro no existe.';

    IF @categoria IS NULL OR @categoria NOT IN ('FIFA','Confederacion')
        SET @err = @err + ' - Categoria invalida (FIFA / Confederacion).';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Arbitro_Modificacion:' + @err;
        THROW 50232, @err, 1;
    END

    UPDATE disc.Arbitro SET categoria = @categoria WHERE id_arbitro = @id_arbitro;
END
GO


CREATE OR ALTER PROCEDURE disc.usp_Arbitro_Baja
    @id_arbitro int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM disc.Arbitro WHERE id_arbitro = @id_arbitro)
        SET @err = @err + ' - El arbitro no existe.';

    IF EXISTS (SELECT 1 FROM disc.Designacion WHERE id_arbitro = @id_arbitro)
        SET @err = @err + ' - Tiene designaciones.';

    IF EXISTS (SELECT 1 FROM disc.ArbitroIdioma WHERE id_arbitro = @id_arbitro)
        SET @err = @err + ' - Tiene idiomas cargados (darlos de baja primero).';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Arbitro_Baja:' + @err;
        THROW 50233, @err, 1;
    END

    -- Se borra solo el subtipo: la Persona queda
    DELETE FROM disc.Arbitro WHERE id_arbitro = @id_arbitro;
END
GO


/* ------------------ 24. ARBITRO-IDIOMA (tabla de relacion) ------------------ */

CREATE OR ALTER PROCEDURE disc.usp_ArbitroIdioma_Alta
    @id_arbitro int,
    @id_idioma  int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM disc.Arbitro WHERE id_arbitro = @id_arbitro)
        SET @err = @err + ' - El arbitro no existe.';

    IF NOT EXISTS (SELECT 1 FROM cat.Idioma WHERE id_idioma = @id_idioma)
        SET @err = @err + ' - El idioma no existe.';

    IF EXISTS (SELECT 1 FROM disc.ArbitroIdioma WHERE id_arbitro = @id_arbitro AND id_idioma = @id_idioma)
        SET @err = @err + ' - El arbitro ya tiene ese idioma.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_ArbitroIdioma_Alta:' + @err;
        THROW 50241, @err, 1;
    END

    INSERT INTO disc.ArbitroIdioma (id_arbitro, id_idioma) VALUES (@id_arbitro, @id_idioma);
END
GO


CREATE OR ALTER PROCEDURE disc.usp_ArbitroIdioma_Baja
    @id_arbitro int,
    @id_idioma  int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM disc.ArbitroIdioma WHERE id_arbitro = @id_arbitro AND id_idioma = @id_idioma)
        SET @err = @err + ' - El arbitro no tiene ese idioma.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_ArbitroIdioma_Baja:' + @err;
        THROW 50243, @err, 1;
    END

    DELETE FROM disc.ArbitroIdioma WHERE id_arbitro = @id_arbitro AND id_idioma = @id_idioma;
END
GO


/* ------------------ 25. DESIGNACION ------------------ */

CREATE OR ALTER PROCEDURE disc.usp_Designacion_Alta
    @id_partido        int,
    @id_arbitro        int,
    @rol               varchar(20),
    @fecha_designacion date,
    @advertencia       varchar(200) = NULL
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @pais_arbitro int;
    SET @err = '';

    SELECT @pais_arbitro = id_pais_nacionalidad
    FROM comp.Persona WHERE id_persona = @id_arbitro;

    IF NOT EXISTS (SELECT 1 FROM comp.Partido WHERE id_partido = @id_partido)
        SET @err = @err + ' - El partido no existe.';

    IF NOT EXISTS (SELECT 1 FROM disc.Arbitro WHERE id_arbitro = @id_arbitro)
        SET @err = @err + ' - El arbitro no existe.';

    IF @rol IS NULL OR @rol NOT IN ('Principal','Asistente 1','Asistente 2','Cuarto Arbitro','VAR')
        SET @err = @err + ' - Rol invalido (Principal / Asistente 1 / Asistente 2 / Cuarto Arbitro / VAR).';

    IF EXISTS (SELECT 1 FROM disc.Designacion WHERE id_partido = @id_partido AND rol = @rol)
        SET @err = @err + ' - Ese rol ya esta designado para el partido.';

    IF EXISTS (SELECT 1 FROM disc.Designacion WHERE id_partido = @id_partido AND id_arbitro = @id_arbitro)
        SET @err = @err + ' - El arbitro ya esta designado en ese partido.';

    -- Conflicto de nacionalidad: el arbitro no puede ser del pais de ninguna de las dos selecciones
    IF EXISTS (SELECT 1
               FROM comp.PartidoSeleccion ps
               INNER JOIN comp.Seleccion s ON s.id_seleccion = ps.id_seleccion
               WHERE ps.id_partido = @id_partido
                 AND s.id_pais = @pais_arbitro)
        SET @err = @err + ' - Conflicto de nacionalidad: el arbitro es del pais de una de las selecciones.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Designacion_Alta:' + @err;
        THROW 50251, @err, 1;
    END

    INSERT INTO disc.Designacion (id_partido, id_arbitro, rol, fecha_designacion, advertencia)
    VALUES (@id_partido, @id_arbitro, @rol, @fecha_designacion, @advertencia);
END
GO


/* Modificacion: solo rol y advertencia */
CREATE OR ALTER PROCEDURE disc.usp_Designacion_Modificacion
    @id_designacion int,
    @rol            varchar(20),
    @advertencia    varchar(200) = NULL
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @id_partido int;
    SET @err = '';

    SELECT @id_partido = id_partido FROM disc.Designacion WHERE id_designacion = @id_designacion;

    IF @id_partido IS NULL
        SET @err = @err + ' - La designacion no existe.';

    IF @rol IS NULL OR @rol NOT IN ('Principal','Asistente 1','Asistente 2','Cuarto Arbitro','VAR')
        SET @err = @err + ' - Rol invalido (Principal / Asistente 1 / Asistente 2 / Cuarto Arbitro / VAR).';

    IF EXISTS (SELECT 1 FROM disc.Designacion
               WHERE id_partido = @id_partido AND rol = @rol AND id_designacion <> @id_designacion)
        SET @err = @err + ' - Otro arbitro ya tiene ese rol en el partido.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Designacion_Modificacion:' + @err;
        THROW 50252, @err, 1;
    END

    UPDATE disc.Designacion SET rol = @rol, advertencia = @advertencia
    WHERE id_designacion = @id_designacion;
END
GO


CREATE OR ALTER PROCEDURE disc.usp_Designacion_Baja
    @id_designacion int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM disc.Designacion WHERE id_designacion = @id_designacion)
        SET @err = @err + ' - La designacion no existe.';

    IF EXISTS (SELECT 1 FROM disc.InformeArbitral WHERE id_designacion = @id_designacion)
        SET @err = @err + ' - Tiene informes/sanciones cargados.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Designacion_Baja:' + @err;
        THROW 50253, @err, 1;
    END

    DELETE FROM disc.Designacion WHERE id_designacion = @id_designacion;
END
GO


/* ------------------ 26. INFORME ARBITRAL ------------------ */

CREATE OR ALTER PROCEDURE disc.usp_InformeArbitral_Alta
    @id_designacion int,
    @tipo           varchar(10),
    @fecha          date,
    @calificacion   decimal(3,1) = NULL,
    @descripcion    varchar(500) = NULL
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM disc.Designacion WHERE id_designacion = @id_designacion)
        SET @err = @err + ' - La designacion no existe.';

    IF @tipo IS NULL OR @tipo NOT IN ('INFORME','SANCION')
        SET @err = @err + ' - Tipo invalido (INFORME / SANCION).';

    IF @fecha IS NULL
        SET @err = @err + ' - La fecha es obligatoria.';

    IF @calificacion IS NOT NULL AND (@calificacion < 0 OR @calificacion > 10)
        SET @err = @err + ' - La calificacion debe estar entre 0 y 10.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_InformeArbitral_Alta:' + @err;
        THROW 50261, @err, 1;
    END

    INSERT INTO disc.InformeArbitral (id_designacion, tipo, fecha, calificacion, descripcion)
    VALUES (@id_designacion, @tipo, @fecha, @calificacion, @descripcion);
END
GO


CREATE OR ALTER PROCEDURE disc.usp_InformeArbitral_Modificacion
    @id_informe_arbitral int,
    @tipo                varchar(10),
    @calificacion        decimal(3,1) = NULL,
    @descripcion         varchar(500) = NULL
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM disc.InformeArbitral WHERE id_informe_arbitral = @id_informe_arbitral)
        SET @err = @err + ' - El informe no existe.';

    IF @tipo IS NULL OR @tipo NOT IN ('INFORME','SANCION')
        SET @err = @err + ' - Tipo invalido (INFORME / SANCION).';

    IF @calificacion IS NOT NULL AND (@calificacion < 0 OR @calificacion > 10)
        SET @err = @err + ' - La calificacion debe estar entre 0 y 10.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_InformeArbitral_Modificacion:' + @err;
        THROW 50262, @err, 1;
    END

    UPDATE disc.InformeArbitral
    SET tipo = @tipo, calificacion = @calificacion, descripcion = @descripcion
    WHERE id_informe_arbitral = @id_informe_arbitral;
END
GO


CREATE OR ALTER PROCEDURE disc.usp_InformeArbitral_Baja
    @id_informe_arbitral int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM disc.InformeArbitral WHERE id_informe_arbitral = @id_informe_arbitral)
        SET @err = @err + ' - El informe no existe.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_InformeArbitral_Baja:' + @err;
        THROW 50263, @err, 1;
    END

    DELETE FROM disc.InformeArbitral WHERE id_informe_arbitral = @id_informe_arbitral;
END
GO
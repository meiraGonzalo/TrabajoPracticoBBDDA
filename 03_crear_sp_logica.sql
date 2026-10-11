/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - Script 03 (modulo Disciplina y Arbitros): SP de LOGICA
 Grupo 02 - Comision 02-5600
 Integrantes: Miro, Saba.
 Objetivo: procedimientos de logica de negocio del modulo disciplina.
           Afectan varias tablas en transaccion.
=====================================================================
*/

USE MundialDB;
GO

/* ------------------ Suspension por tarjeta (roja o acumulacion) ------------------ */
CREATE OR ALTER PROCEDURE disc.usp_Suspension_CalcularPorTarjeta
    @id_tarjeta int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id_convocado int, @id_partido int, @tipo_tarjeta varchar(30);
    DECLARE @id_seleccion int, @fecha_partido datetime2(0);
    DECLARE @cant_amarillas int, @id_torneo int, @umbral int, @id_partido_cumple int;

    -- 1) Datos de la tarjeta (rama jugador)
    SELECT @id_convocado = a.id_convocado,
           @id_partido   = ps.id_partido,
           @tipo_tarjeta = t.tipo_tarjeta
    FROM disc.Tarjeta t
    INNER JOIN comp.Alineacion a        ON a.id_alineacion = t.id_alineacion
    INNER JOIN comp.PartidoSeleccion ps ON ps.id_partido_seleccion = a.id_partido_seleccion
    WHERE t.id_tarjeta = @id_tarjeta;

    IF @id_convocado IS NULL RETURN;                                                           -- tarjeta a cuerpo tecnico: no acumula automatico
    IF EXISTS (SELECT 1 FROM disc.Suspension WHERE id_tarjeta_origen = @id_tarjeta) RETURN;    -- ya genero suspension

    SELECT @id_seleccion  = id_seleccion   FROM comp.Convocado WHERE id_convocado = @id_convocado;
    SELECT @fecha_partido = fecha_hora_utc FROM comp.Partido   WHERE id_partido   = @id_partido;
    SELECT @id_torneo     = id_torneo      FROM comp.Partido   WHERE id_partido   = @id_partido;

    -- Amarillas del jugador HASTA la fecha de este partido (inclusive).
    -- Asi suspende SOLO la tarjeta que completa el multiplo del umbral,
    -- sin importar cuando se ejecute el SP (no depende del orden de carga).
    SELECT @cant_amarillas = COUNT(*)
    FROM disc.Tarjeta t
    INNER JOIN comp.Alineacion a        ON a.id_alineacion = t.id_alineacion
    INNER JOIN comp.PartidoSeleccion ps ON ps.id_partido_seleccion = a.id_partido_seleccion
    INNER JOIN comp.Partido p           ON p.id_partido = ps.id_partido
    WHERE a.id_convocado = @id_convocado
      AND t.tipo_tarjeta = 'Amarilla'
      AND p.fecha_hora_utc <= @fecha_partido;

    SELECT @umbral = valor FROM comp.ParametroReglamento
    WHERE id_torneo = @id_torneo AND clave = 'AMARILLAS_SUSPENSION';

    -- 2) Decision: roja siempre; amarilla al completar el multiplo del umbral
    IF @tipo_tarjeta IN ('Roja directa','Roja por doble amarilla')
       OR (@tipo_tarjeta = 'Amarilla' AND @umbral > 0 AND @cant_amarillas % @umbral = 0)
    BEGIN
        -- proximo partido de la seleccion, posterior al de la tarjeta
        SELECT TOP 1 @id_partido_cumple = p.id_partido
        FROM comp.Partido p
        INNER JOIN comp.PartidoSeleccion ps ON ps.id_partido = p.id_partido
        WHERE ps.id_seleccion = @id_seleccion AND p.fecha_hora_utc > @fecha_partido
        ORDER BY p.fecha_hora_utc ASC;

        BEGIN TRY
            BEGIN TRAN;
            INSERT INTO disc.Suspension (id_convocado, id_tarjeta_origen, id_partido_cumple, estado)
            VALUES (@id_convocado, @id_tarjeta, @id_partido_cumple, 'PENDIENTE');
            COMMIT;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            THROW;
        END CATCH
    END
END
GO


/* ------------------ Advertencia de cruce arbitral (desde eliminatorias) ------------------ */
CREATE OR ALTER PROCEDURE disc.usp_Designacion_AdvertenciaCruce
    @id_designacion int
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_partido int, @pais_arbitro int, @es_eliminatoria bit;

    SELECT @id_partido      = d.id_partido,
           @pais_arbitro    = pe.id_pais_nacionalidad,
           @es_eliminatoria = f.es_eliminatoria
    FROM disc.Designacion d
    INNER JOIN comp.Persona pe ON pe.id_persona = d.id_arbitro
    INNER JOIN comp.Partido p  ON p.id_partido  = d.id_partido
    INNER JOIN comp.Fase f     ON f.id_fase     = p.id_fase
    WHERE d.id_designacion = @id_designacion;

    -- Solo en fases eliminatorias, si el pais del arbitro tiene seleccion en el torneo
    IF @es_eliminatoria = 1
       AND EXISTS (SELECT 1
                   FROM comp.Seleccion s
                   INNER JOIN comp.Partido p ON p.id_torneo = s.id_torneo
                   WHERE p.id_partido = @id_partido AND s.id_pais = @pais_arbitro)
    BEGIN
        UPDATE disc.Designacion
        SET advertencia = 'Posible cruce: el arbitro proviene de un pais con seleccion en el torneo.'
        WHERE id_designacion = @id_designacion;
    END
END
GO


/* =====================================================================
   usp_Convocatoria_Baja
   Baja de ultimo momento de un convocado, SIN reemplazo.
   ===================================================================== */

CREATE OR ALTER PROCEDURE comp.usp_Convocatoria_Baja
    @id_convocado int,
    @motivo       varchar(40),
    @fecha        date,
    @observacion  varchar(200)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @id_seleccion int;
    DECLARE @id_torneo int;
    DECLARE @fecha_alta date;
    DECLARE @min int;
    DECLARE @activos int;
    SET @err = '';

    -- Datos que vamos a necesitar (si no encuentra nada, la variable queda NULL)
    SELECT @id_seleccion = c.id_seleccion, @id_torneo = s.id_torneo, @fecha_alta = c.fecha_alta
    FROM comp.Convocado c
    INNER JOIN comp.Seleccion s ON s.id_seleccion = c.id_seleccion
    WHERE c.id_convocado = @id_convocado;

    SELECT @min = valor FROM comp.ParametroReglamento
    WHERE id_torneo = @id_torneo AND clave = 'MIN_CONVOCADOS';

    SET @activos = (SELECT COUNT(*) FROM comp.Convocado
                    WHERE id_seleccion = @id_seleccion AND fecha_baja IS NULL);

    /* ----- Validaciones ----- */
    IF NOT EXISTS (SELECT 1 FROM comp.Convocado WHERE id_convocado = @id_convocado)
        SET @err = @err + ' - El convocado no existe.';

    IF EXISTS (SELECT 1 FROM comp.Convocado
               WHERE id_convocado = @id_convocado AND fecha_baja IS NOT NULL)
        SET @err = @err + ' - El convocado ya estaba dado de baja.';

    IF @motivo IS NULL OR @motivo NOT IN ('Lesion', 'Enfermedad', 'Decision tecnica', 'Sancion')
        SET @err = @err + ' - Motivo invalido (Lesion / Enfermedad / Decision tecnica / Sancion).';

    IF @fecha IS NULL
        SET @err = @err + ' - La fecha es obligatoria.';

    IF @fecha < @fecha_alta
        SET @err = @err + ' - La fecha de baja no puede ser anterior a la fecha de alta.';

 
    -- solo se controla si el convocado esta activo; si ya tenia baja, no cuenta en @activos
    IF @min IS NOT NULL AND @activos - 1 < @min
       AND EXISTS (SELECT 1 FROM comp.Convocado
                   WHERE id_convocado = @id_convocado AND fecha_baja IS NULL)
        SET @err = @err + ' - La seleccion quedaria por debajo del minimo de convocados (usar el reemplazo).';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Convocatoria_Baja:' + @err;
        THROW 50901, @err, 1;
    END

    /* ----- Operacion sobre dos tablas ----- */
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;

        -- 1) Baja del convocado (queda en la tabla, con fecha de baja)
        UPDATE comp.Convocado
        SET fecha_baja = @fecha
        WHERE id_convocado = @id_convocado;

        -- 2) Registro del cambio (sin alta)
        INSERT INTO comp.CambioConvocatoria (id_convocado_baja, id_convocado_alta, motivo, fecha, observacion)
        VALUES (@id_convocado, NULL, @motivo, @fecha, @observacion);

    COMMIT TRANSACTION;
END
GO


/* =====================================================================
   usp_Convocatoria_Reemplazar
   Sale un convocado y entra otro jugador en su lugar (por ejemplo,
   por lesion). La cantidad de convocados activos no cambia.
   ===================================================================== */

CREATE OR ALTER PROCEDURE comp.usp_Convocatoria_Reemplazar
    @id_convocado_baja int,
    @id_jugador_alta   int,
    @dorsal            tinyint,
    @id_club           int,           -- club del que entra, puede ir NULL
    @motivo            varchar(40),
    @fecha             date,
    @observacion       varchar(200)   -- puede ir NULL
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @id_seleccion int;
    DECLARE @id_torneo int;
    DECLARE @fecha_alta date;
    DECLARE @fecha_fin date;
    DECLARE @id_nuevo int;
    SET @err = '';

    -- Datos del que sale
    SELECT @id_seleccion = c.id_seleccion, @id_torneo = s.id_torneo, @fecha_alta = c.fecha_alta
    FROM comp.Convocado c
    INNER JOIN comp.Seleccion s ON s.id_seleccion = c.id_seleccion
    WHERE c.id_convocado = @id_convocado_baja;

    SELECT @fecha_fin = fecha_fin FROM comp.Torneo WHERE id_torneo = @id_torneo;

    /* ----- Validaciones propias del reemplazo ----- */
    IF NOT EXISTS (SELECT 1 FROM comp.Convocado WHERE id_convocado = @id_convocado_baja)
        SET @err = @err + ' - El convocado que sale no existe.';

    IF EXISTS (SELECT 1 FROM comp.Convocado
               WHERE id_convocado = @id_convocado_baja AND fecha_baja IS NOT NULL)
        SET @err = @err + ' - El convocado que sale ya estaba dado de baja.';

    IF @motivo IS NULL OR @motivo NOT IN ('Lesion', 'Enfermedad', 'Decision tecnica', 'Sancion')
        SET @err = @err + ' - Motivo invalido (Lesion / Enfermedad / Decision tecnica / Sancion).';

    IF @fecha IS NULL
        SET @err = @err + ' - La fecha es obligatoria.';

    IF @fecha < @fecha_alta
        SET @err = @err + ' - La fecha del cambio no puede ser anterior a la fecha de alta del que sale.';

    IF @fecha > @fecha_fin
        SET @err = @err + ' - La fecha del cambio no puede ser posterior al fin del torneo.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Convocatoria_Reemplazar:' + @err;
        THROW 50902, @err, 1;
    END

    /* ----- Operacion sobre dos tablas, reutilizando el ABM ----- */
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;

        -- 1) Baja del que sale (primero, asi se libera el dorsal y el lugar en la lista)
        UPDATE comp.Convocado
        SET fecha_baja = @fecha
        WHERE id_convocado = @id_convocado_baja;

        -- 2) Alta del que entra (usp_Convocado_Alta valida al jugador, el dorsal, el club...)
        EXEC comp.usp_Convocado_Alta @id_seleccion, @id_jugador_alta, @dorsal, @id_club, @fecha;

        -- 3) Buscar el id del convocado recien creado (seleccion + jugador no se repite)
        SELECT @id_nuevo = id_convocado FROM comp.Convocado
        WHERE id_seleccion = @id_seleccion AND id_jugador = @id_jugador_alta;

        -- 4) Registro del cambio con los dos convocados
        INSERT INTO comp.CambioConvocatoria (id_convocado_baja, id_convocado_alta, motivo, fecha, observacion)
        VALUES (@id_convocado_baja, @id_nuevo, @motivo, @fecha, @observacion);

    COMMIT TRANSACTION;
END
GO


/* =====================================================================
   usp_Jugador_AltaCompleta
   Da de alta a una persona nueva como jugador en un solo paso y, si
   se indica una seleccion, la convoca (alta de ultimo momento de un
   jugador que no estaba cargado en el sistema).
   ===================================================================== */

CREATE OR ALTER PROCEDURE comp.usp_Jugador_AltaCompleta
    @nombre               nvarchar(80),
    @apellido             nvarchar(80),
    @fecha_nacimiento     date,
    @id_pais_nacionalidad int,
    @tipo_documento       varchar(15),   -- puede ir NULL (junto con el numero)
    @nro_documento        varchar(30),
    @id_posicion_habitual int,
    @id_seleccion         int,           -- NULL = solo se crea el jugador, sin convocar
    @dorsal               tinyint,       -- solo si se convoca
    @id_club              int,           -- solo si se convoca, puede ir NULL
    @fecha_alta           date           -- solo si se convoca
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @id_nuevo int;
    SET @err = '';

    /* ----- Validaciones propias ----- */
    -- Datos de convocatoria sin seleccion: no se sabe a que seleccion convocarlo
    IF @id_seleccion IS NULL AND (@dorsal IS NOT NULL OR @id_club IS NOT NULL OR @fecha_alta IS NOT NULL)
        SET @err = @err + ' - Se indicaron datos de convocatoria (dorsal, club o fecha) pero no la seleccion.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Jugador_AltaCompleta:' + @err;
        THROW 50903, @err, 1;
    END

    /* ----- Operacion sobre dos o tres tablas, reutilizando los ABM ----- */
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;

        -- 1) La persona
        EXEC comp.usp_Persona_Alta @nombre, @apellido, @fecha_nacimiento, @id_pais_nacionalidad,
                                   @tipo_documento, @nro_documento;

        -- 2) Buscar el id de la persona recien creada: el id es IDENTITY (creciente), asi que es el mas grande
        SELECT @id_nuevo = MAX(id_persona) FROM comp.Persona;

        -- 3) El jugador usa el mismo id que la persona (es un subtipo)
        EXEC comp.usp_Jugador_Alta @id_nuevo, @id_posicion_habitual;

        -- 4) La convocatoria, solo si se indico seleccion
        IF @id_seleccion IS NOT NULL
            EXEC comp.usp_Convocado_Alta @id_seleccion, @id_nuevo, @dorsal, @id_club, @fecha_alta;

    COMMIT TRANSACTION;
END
GO
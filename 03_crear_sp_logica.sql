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
/*=====================================================================
   usp_Partido_Registrar
   Crea el partido y le asigna las dos selecciones (local y visitante)
   en un solo paso
   ===================================================================== */

CREATE OR ALTER PROCEDURE comp.usp_Partido_Registrar
    @id_torneo          int,
    @nro_partido        smallint,
    @id_fase            int,
    @id_grupo           int,               -- NULL si es eliminacion directa
    @id_sede            int,
    @fecha_hora_utc     datetime2(0),
    @id_seleccion_local int,
    @id_seleccion_visit int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @id_partido int;
    SET @err = '';

    /* ----- Validaciones ----- */
    IF @id_seleccion_local = @id_seleccion_visit
        SET @err = @err + ' - Local y visitante no pueden ser la misma seleccion.';

    -- Una seleccion no puede jugar dos partidos el mismo dia (se compara el dia UTC)
    IF EXISTS (SELECT 1
               FROM comp.PartidoSeleccion ps
               INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
               WHERE ps.id_seleccion = @id_seleccion_local
                 AND CAST(p.fecha_hora_utc AS date) = CAST(@fecha_hora_utc AS date))
        SET @err = @err + ' - La seleccion local ya juega otro partido ese dia.';

    IF EXISTS (SELECT 1
               FROM comp.PartidoSeleccion ps
               INNER JOIN comp.Partido p ON p.id_partido = ps.id_partido
               WHERE ps.id_seleccion = @id_seleccion_visit
                 AND CAST(p.fecha_hora_utc AS date) = CAST(@fecha_hora_utc AS date))
        SET @err = @err + ' - La seleccion visitante ya juega otro partido ese dia.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Partido_Registrar:' + @err;
        THROW 50904, @err, 1;
    END

    /* ----- Operacion sobre dos tablas ----- */
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;

        --El partido 
        EXEC comp.usp_Partido_Alta @id_torneo, @nro_partido, @id_fase, @id_grupo, @id_sede, @fecha_hora_utc;

        --Buscar el id del partido recien creado (torneo + numero no se repite)
        SELECT @id_partido = id_partido FROM comp.Partido
        WHERE id_torneo = @id_torneo AND nro_partido = @nro_partido;

        -- Las dos selecciones 
        -- Si alguna falla, tambien se deshace el partido del inicio
        EXEC comp.usp_PartidoSeleccion_Alta @id_partido, @id_seleccion_local, 'L';
        EXEC comp.usp_PartidoSeleccion_Alta @id_partido, @id_seleccion_visit, 'V';

    COMMIT TRANSACTION;
END
GO


/* =====================================================================
   usp_Partido_RegistrarResultado
   Carga el resultado de un partido: goles de cada equipo, penales (si
   hubo), asistencia, y pasa el partido a FINALIZADO.
   ===================================================================== */

CREATE OR ALTER PROCEDURE comp.usp_Partido_RegistrarResultado
    @id_partido        int,
    @goles_local       tinyint,
    @goles_visitante   tinyint,
    @penales_local     tinyint,       -- NULL si no hubo penales
    @penales_visitante tinyint,       -- NULL si no hubo penales
    @asistencia        int            -- puede ir NULL
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @es_eliminatoria bit;
    DECLARE @capacidad int;
    DECLARE @cant_selecciones int;
    SET @err = '';

    -- Datos
    SELECT @es_eliminatoria = f.es_eliminatoria, @capacidad = s.capacidad
    FROM comp.Partido p
    INNER JOIN comp.Fase f ON f.id_fase = p.id_fase
    INNER JOIN comp.Sede s ON s.id_sede = p.id_sede
    WHERE p.id_partido = @id_partido;

    SET @cant_selecciones = (SELECT COUNT(*) FROM comp.PartidoSeleccion WHERE id_partido = @id_partido);

    /* ----- Validaciones del partido ----- */
    IF NOT EXISTS (SELECT 1 FROM comp.Partido WHERE id_partido = @id_partido)
        SET @err = @err + ' - El partido no existe.';

    IF EXISTS (SELECT 1 FROM comp.Partido WHERE id_partido = @id_partido AND estado = 'FINALIZADO')
        SET @err = @err + ' - El partido ya tiene el resultado cargado.';

    IF EXISTS (SELECT 1 FROM comp.Partido WHERE id_partido = @id_partido AND estado = 'SUSPENDIDO')
        SET @err = @err + ' - El partido esta suspendido.';

    IF EXISTS (SELECT 1 FROM comp.Partido WHERE id_partido = @id_partido)
       AND @cant_selecciones <> 2
        SET @err = @err + ' - El partido no tiene sus dos selecciones.';

    /* ----- Validaciones del resultado ----- */
    IF @goles_local IS NULL OR @goles_visitante IS NULL
        SET @err = @err + ' - Los goles de los dos equipos son obligatorios.';

    IF @asistencia < 0 OR @asistencia > @capacidad
        SET @err = @err + ' - La asistencia debe estar entre 0 y la capacidad de la sede.';

    -- Penales: los dos o ninguno
    IF (@penales_local IS NULL AND @penales_visitante IS NOT NULL)
       OR (@penales_local IS NOT NULL AND @penales_visitante IS NULL)
        SET @err = @err + ' - Los penales se cargan para los dos equipos o para ninguno.';

    IF @penales_local IS NOT NULL AND @es_eliminatoria = 0
        SET @err = @err + ' - En fase de grupos no hay penales.';

    IF @penales_local IS NOT NULL AND @goles_local <> @goles_visitante
        SET @err = @err + ' - Solo hay penales si el partido termino empatado.';

    IF @penales_local IS NOT NULL AND @penales_local = @penales_visitante
        SET @err = @err + ' - Los penales no pueden terminar empatados.';

    IF @es_eliminatoria = 1 AND @goles_local = @goles_visitante
       AND @penales_local IS NULL AND @penales_visitante IS NULL
        SET @err = @err + ' - Un partido eliminatorio empatado necesita el resultado de los penales.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Partido_RegistrarResultado:' + @err;
        THROW 50905, @err, 1;
    END

    /* ----- Operacion sobre dos tablas ----- */
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;

        --Goles del local
        UPDATE comp.PartidoSeleccion
        SET goles = @goles_local, goles_penales = @penales_local
        WHERE id_partido = @id_partido AND condicion = 'L';

        --Goles del visitante
        UPDATE comp.PartidoSeleccion
        SET goles = @goles_visitante, goles_penales = @penales_visitante
        WHERE id_partido = @id_partido AND condicion = 'V';

        --El partido queda finalizado, con su asistencia
        UPDATE comp.Partido
        SET estado = 'FINALIZADO', asistencia = @asistencia
        WHERE id_partido = @id_partido;

    COMMIT TRANSACTION;
END
GO


/* =====================================================================
   usp_Partido_RegistrarFormaciones
   Confirma la formacion de los dos equipos antes de empezar el partido,
   se controla que cada formacion este COMPLETA y sea COHERENTE con el
   esquema tactico, guarda los esquemas y pasa el partido a EN_JUEGO.

   Esquema tactico: 3 o 4 numeros separados por guion (4-3-3, 3-4-1-2).
     - el primer numero son los defensores,
     - el ultimo son los delanteros,
     - los del medio son mediocampistas (en 3-4-1-2: 4 + 1 = 5),
     - tienen que sumar 10
   ===================================================================== */

CREATE OR ALTER PROCEDURE comp.usp_Partido_RegistrarFormaciones
    @id_partido        int,
    @esquema_local     varchar(10),
    @esquema_visitante varchar(10)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    DECLARE @ps_l int, @ps_v int;                  -- participacion del local y del visitante
    -- Lo que dice el esquema
    DECLARE @def_l int, @med_l int, @del_l int;
    DECLARE @def_v int, @med_v int, @del_v int;
    -- Lo que hay cargado en la alineacion
    DECLARE @tit_l int, @arq_l int, @cdef_l int, @cmed_l int, @cdel_l int, @sup_l int, @baj_l int;
    DECLARE @tit_v int, @arq_v int, @cdef_v int, @cmed_v int, @cdel_v int, @sup_v int, @baj_v int;
    SET @err = '';

    SELECT @ps_l = id_partido_seleccion FROM comp.PartidoSeleccion
    WHERE id_partido = @id_partido AND condicion = 'L';

    SELECT @ps_v = id_partido_seleccion FROM comp.PartidoSeleccion
    WHERE id_partido = @id_partido AND condicion = 'V';

    /* ----- Leer los esquemas,si el formato es valido----- */
    IF @esquema_local LIKE '[1-9]-[1-9]-[1-9]' OR @esquema_local LIKE '[1-9]-[1-9]-[1-9]-[1-9]'
    BEGIN
        SET @def_l = CAST(LEFT(@esquema_local, 1) AS int);
        SET @del_l = CAST(RIGHT(@esquema_local, 1) AS int);
        SET @med_l = CAST(SUBSTRING(@esquema_local, 3, 1) AS int);
        IF LEN(@esquema_local) = 7
            SET @med_l = @med_l + CAST(SUBSTRING(@esquema_local, 5, 1) AS int);
    END

    IF @esquema_visitante LIKE '[1-9]-[1-9]-[1-9]' OR @esquema_visitante LIKE '[1-9]-[1-9]-[1-9]-[1-9]'
    BEGIN
        SET @def_v = CAST(LEFT(@esquema_visitante, 1) AS int);
        SET @del_v = CAST(RIGHT(@esquema_visitante, 1) AS int);
        SET @med_v = CAST(SUBSTRING(@esquema_visitante, 3, 1) AS int);
        IF LEN(@esquema_visitante) = 7
            SET @med_v = @med_v + CAST(SUBSTRING(@esquema_visitante, 5, 1) AS int);
    END

    /* ----- Contar lo cargado en cada alineacion ----- */
    SET @tit_l = (SELECT COUNT(*) FROM comp.Alineacion WHERE id_partido_seleccion = @ps_l AND es_titular = 1);
    SET @sup_l = (SELECT COUNT(*) FROM comp.Alineacion WHERE id_partido_seleccion = @ps_l AND es_titular = 0);
    SET @arq_l = (SELECT COUNT(*) FROM comp.Alineacion a INNER JOIN comp.Posicion po ON po.id_posicion = a.id_posicion_cancha
                  WHERE a.id_partido_seleccion = @ps_l AND a.es_titular = 1 AND po.nombre = 'Arquero');
    SET @cdef_l = (SELECT COUNT(*) FROM comp.Alineacion a INNER JOIN comp.Posicion po ON po.id_posicion = a.id_posicion_cancha
                   WHERE a.id_partido_seleccion = @ps_l AND a.es_titular = 1 AND po.nombre = 'Defensor');
    SET @cmed_l = (SELECT COUNT(*) FROM comp.Alineacion a INNER JOIN comp.Posicion po ON po.id_posicion = a.id_posicion_cancha
                   WHERE a.id_partido_seleccion = @ps_l AND a.es_titular = 1 AND po.nombre = 'Mediocampista');
    SET @cdel_l = (SELECT COUNT(*) FROM comp.Alineacion a INNER JOIN comp.Posicion po ON po.id_posicion = a.id_posicion_cancha
                   WHERE a.id_partido_seleccion = @ps_l AND a.es_titular = 1 AND po.nombre = 'Delantero');
    SET @baj_l = (SELECT COUNT(*) FROM comp.Alineacion a INNER JOIN comp.Convocado c ON c.id_convocado = a.id_convocado
                  WHERE a.id_partido_seleccion = @ps_l AND c.fecha_baja IS NOT NULL);

    SET @tit_v = (SELECT COUNT(*) FROM comp.Alineacion WHERE id_partido_seleccion = @ps_v AND es_titular = 1);
    SET @sup_v = (SELECT COUNT(*) FROM comp.Alineacion WHERE id_partido_seleccion = @ps_v AND es_titular = 0);
    SET @arq_v = (SELECT COUNT(*) FROM comp.Alineacion a INNER JOIN comp.Posicion po ON po.id_posicion = a.id_posicion_cancha
                  WHERE a.id_partido_seleccion = @ps_v AND a.es_titular = 1 AND po.nombre = 'Arquero');
    SET @cdef_v = (SELECT COUNT(*) FROM comp.Alineacion a INNER JOIN comp.Posicion po ON po.id_posicion = a.id_posicion_cancha
                   WHERE a.id_partido_seleccion = @ps_v AND a.es_titular = 1 AND po.nombre = 'Defensor');
    SET @cmed_v = (SELECT COUNT(*) FROM comp.Alineacion a INNER JOIN comp.Posicion po ON po.id_posicion = a.id_posicion_cancha
                   WHERE a.id_partido_seleccion = @ps_v AND a.es_titular = 1 AND po.nombre = 'Mediocampista');
    SET @cdel_v = (SELECT COUNT(*) FROM comp.Alineacion a INNER JOIN comp.Posicion po ON po.id_posicion = a.id_posicion_cancha
                   WHERE a.id_partido_seleccion = @ps_v AND a.es_titular = 1 AND po.nombre = 'Delantero');
    SET @baj_v = (SELECT COUNT(*) FROM comp.Alineacion a INNER JOIN comp.Convocado c ON c.id_convocado = a.id_convocado
                  WHERE a.id_partido_seleccion = @ps_v AND c.fecha_baja IS NOT NULL);

    /* ----- Validaciones del partido ----- */
    IF NOT EXISTS (SELECT 1 FROM comp.Partido WHERE id_partido = @id_partido)
        SET @err = @err + ' - El partido no existe.';

    IF EXISTS (SELECT 1 FROM comp.Partido WHERE id_partido = @id_partido AND estado <> 'PROGRAMADO')
        SET @err = @err + ' - Solo se registran formaciones de un partido PROGRAMADO.';

    IF EXISTS (SELECT 1 FROM comp.Partido WHERE id_partido = @id_partido)
       AND (@ps_l IS NULL OR @ps_v IS NULL)
        SET @err = @err + ' - El partido no tiene sus dos selecciones.';

    /* ----- Validaciones del local, si el partido tiene local----- */
    IF @ps_l IS NOT NULL AND @def_l IS NULL
        SET @err = @err + ' - El esquema del local tiene un formato invalido (ej: 4-3-3 o 3-4-1-2).';

    IF @def_l + @med_l + @del_l <> 10
        SET @err = @err + ' - El esquema del local debe sumar 10 jugadores de campo.';

    IF @ps_l IS NOT NULL AND @tit_l <> 11
        SET @err = @err + ' - El local no tiene 11 titulares.';

    IF @ps_l IS NOT NULL AND @arq_l <> 1
        SET @err = @err + ' - El local debe tener exactamente un arquero titular.';

    IF @ps_l IS NOT NULL AND @sup_l = 0
        SET @err = @err + ' - El local no tiene suplentes en el banco.';

    IF @baj_l > 0
        SET @err = @err + ' - El local tiene en la formacion jugadores dados de baja de la convocatoria.';

    -- Coherencia con el esquema: solo si la formacion y el esquema estan completos
    IF @tit_l = 11 AND @def_l + @med_l + @del_l = 10
       AND (@cdef_l <> @def_l OR @cmed_l <> @med_l OR @cdel_l <> @del_l)
        SET @err = @err + ' - Los titulares del local no coinciden con el esquema (defensores, mediocampistas, delanteros).';

    /* ----- Validaciones del visitante----- */
    IF @ps_v IS NOT NULL AND @def_v IS NULL
        SET @err = @err + ' - El esquema del visitante tiene un formato invalido (ej: 4-3-3 o 3-4-1-2).';

    IF @def_v + @med_v + @del_v <> 10
        SET @err = @err + ' - El esquema del visitante debe sumar 10 jugadores de campo.';

    IF @ps_v IS NOT NULL AND @tit_v <> 11
        SET @err = @err + ' - El visitante no tiene 11 titulares.';

    IF @ps_v IS NOT NULL AND @arq_v <> 1
        SET @err = @err + ' - El visitante debe tener exactamente un arquero titular.';

    IF @ps_v IS NOT NULL AND @sup_v = 0
        SET @err = @err + ' - El visitante no tiene suplentes en el banco.';

    IF @baj_v > 0
        SET @err = @err + ' - El visitante tiene en la formacion jugadores dados de baja de la convocatoria.';

    IF @tit_v = 11 AND @def_v + @med_v + @del_v = 10
       AND (@cdef_v <> @def_v OR @cmed_v <> @med_v OR @cdel_v <> @del_v)
        SET @err = @err + ' - Los titulares del visitante no coinciden con el esquema (defensores, mediocampistas, delanteros).';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Partido_RegistrarFormaciones:' + @err;
        THROW 50906, @err, 1;
    END

    /* ----- Operacion sobre dos tablas ----- */
    SET XACT_ABORT ON;
    BEGIN TRANSACTION;

        --Esquema del local
        UPDATE comp.PartidoSeleccion
        SET esquema_tactico = @esquema_local
        WHERE id_partido_seleccion = @ps_l;

        --Esquema del visitante
        UPDATE comp.PartidoSeleccion
        SET esquema_tactico = @esquema_visitante
        WHERE id_partido_seleccion = @ps_v;

        --El partido empieza
        UPDATE comp.Partido
        SET estado = 'EN_JUEGO'
        WHERE id_partido = @id_partido;

    COMMIT TRANSACTION;
END
GO
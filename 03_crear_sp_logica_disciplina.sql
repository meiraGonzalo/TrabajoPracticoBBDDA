/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - Script 03 (modulo Disciplina y Arbitros): SP de LOGICA
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella         nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa             nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo            nickGithub: meiraGonzalo
              Miro, Saba Alejandro                      nickGithub: SabaM10
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

    DECLARE @err nvarchar(2000) = '';
    DECLARE @id_alineacion int, @id_convocado int, @id_partido int, @id_seleccion int,
            @id_torneo int, @tipo_tarjeta varchar(30), @fecha_partido datetime2(0), @orden_fase tinyint;
    DECLARE @umbral int, @orden_limpia int, @cant_amarillas int, @id_partido_cumple int;
    DECLARE @genera bit = 0;

    -- 1) La tarjeta tiene que existir (antes volvia en silencio)
    IF NOT EXISTS (SELECT 1 FROM disc.Tarjeta WHERE id_tarjeta = @id_tarjeta)
    BEGIN
        SET @err = 'usp_Suspension_CalcularPorTarjeta: - La tarjeta no existe.';
        THROW 50907, @err, 1;
    END

    -- 2) Datos de la tarjeta (rama jugador)
    SELECT @id_alineacion = a.id_alineacion, @id_convocado = a.id_convocado,
           @id_partido = p.id_partido, @id_torneo = p.id_torneo,
           @fecha_partido = p.fecha_hora_utc, @orden_fase = f.orden,
           @tipo_tarjeta = t.tipo_tarjeta
    FROM disc.Tarjeta t
    INNER JOIN comp.Alineacion a        ON a.id_alineacion = t.id_alineacion
    INNER JOIN comp.PartidoSeleccion ps ON ps.id_partido_seleccion = a.id_partido_seleccion
    INNER JOIN comp.Partido p           ON p.id_partido = ps.id_partido
    INNER JOIN comp.Fase f              ON f.id_fase = p.id_fase
    WHERE t.id_tarjeta = @id_tarjeta;

    IF @id_convocado IS NULL RETURN;                                                        -- tarjeta a cuerpo tecnico: no acumula
    IF EXISTS (SELECT 1 FROM disc.Suspension WHERE id_tarjeta_origen = @id_tarjeta) RETURN; -- ya genero suspension

    SELECT @id_seleccion = id_seleccion FROM comp.Convocado WHERE id_convocado = @id_convocado;

    -- 3) Parametros del reglamento (si no estan cargados: umbral 2 y sin limpieza de amarillas)
    SELECT @umbral = valor FROM comp.ParametroReglamento
    WHERE id_torneo = @id_torneo AND clave = 'AMARILLAS_SUSPENSION';
    SET @umbral = ISNULL(@umbral, 2);

    SELECT @orden_limpia = valor FROM comp.ParametroReglamento
    WHERE id_torneo = @id_torneo AND clave = 'FASE_LIMPIA_AMARILLAS';   -- orden de la fase tras la cual se borran

    -- 4) Decision
    IF @tipo_tarjeta IN ('Roja directa', 'Roja por doble amarilla')
        SET @genera = 1;
    ELSE IF @tipo_tarjeta = 'Amarilla' AND @umbral > 0
        -- solo cuenta la PRIMERA amarilla del jugador en cada partido
        AND NOT EXISTS (SELECT 1 FROM disc.Tarjeta t2
                        WHERE t2.id_alineacion = @id_alineacion
                          AND t2.tipo_tarjeta = 'Amarilla' AND t2.id_tarjeta < @id_tarjeta)
    BEGIN
        -- Partidos DISTINTOS con amarilla, hasta este partido, dentro de la misma "ventana" de limpieza
        SELECT @cant_amarillas = COUNT(DISTINCT p.id_partido)
        FROM disc.Tarjeta t
        INNER JOIN comp.Alineacion a        ON a.id_alineacion = t.id_alineacion
        INNER JOIN comp.PartidoSeleccion ps ON ps.id_partido_seleccion = a.id_partido_seleccion
        INNER JOIN comp.Partido p           ON p.id_partido = ps.id_partido
        INNER JOIN comp.Fase f              ON f.id_fase = p.id_fase
        WHERE a.id_convocado = @id_convocado
          AND p.id_torneo = @id_torneo
          AND t.tipo_tarjeta = 'Amarilla'
          AND p.fecha_hora_utc <= @fecha_partido
          AND ( @orden_limpia IS NULL
                OR (CASE WHEN f.orden > @orden_limpia THEN 1 ELSE 0 END)
                 = (CASE WHEN @orden_fase > @orden_limpia THEN 1 ELSE 0 END) )
          -- las amarillas de un partido donde termino en roja por doble amarilla no acumulan
          AND NOT EXISTS (SELECT 1 FROM disc.Tarjeta t2
                          WHERE t2.id_alineacion = a.id_alineacion
                            AND t2.tipo_tarjeta = 'Roja por doble amarilla');

        IF @cant_amarillas % @umbral = 0 SET @genera = 1;
    END

    -- 5) Si corresponde, se da de alta por el ABM de la E5
    IF @genera = 1
    BEGIN
        SELECT TOP 1 @id_partido_cumple = p.id_partido     -- proximo partido de su seleccion
        FROM comp.Partido p
        INNER JOIN comp.PartidoSeleccion ps ON ps.id_partido = p.id_partido
        WHERE ps.id_seleccion = @id_seleccion AND p.fecha_hora_utc > @fecha_partido
        ORDER BY p.fecha_hora_utc ASC;

        EXEC disc.usp_Suspension_Alta @id_convocado, NULL, @id_tarjeta, @id_partido_cumple;
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
   disc.usp_Tarjeta_Registrar
   Registra una tarjeta a un jugador y deja consistente todo lo que de ella depende,
   en UNA transaccion:
     - alta de la tarjeta (via disc.usp_Tarjeta_Alta)
     - si es la 2da amarilla del partido: alta de la 'Roja por doble amarilla' y anulacion
       de la suspension por acumulacion que pudo haber generado la 1ra amarilla
     - calculo de la suspension (via disc.usp_Suspension_CalcularPorTarjeta)

   Alcance: solo tarjetas a JUGADORES (el enunciado pide jugador, minuto y motivo).
   Las tarjetas al cuerpo tecnico se registran con disc.usp_Tarjeta_Alta y no generan
   suspension automatica.
   ===================================================================== */
CREATE OR ALTER PROCEDURE disc.usp_Tarjeta_Registrar
    @id_alineacion    int,
    @tipo_tarjeta     varchar(30),      -- 'Amarilla' o 'Roja directa'
    @motivo           varchar(200),
    @id_periodo       int,
    @minuto           tinyint,
    @minuto_adicional tinyint = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @err nvarchar(2000) = '';
    DECLARE @amarillas_previas int = 0;
    DECLARE @id_tarjeta int, @id_tarjeta_roja int, @id_amarilla_1 int;
    DECLARE @id_suspension int, @id_partido_cumple int;

    -- 1) Validaciones (un unico mensaje con todo lo que falla)
    IF @tipo_tarjeta IS NULL OR @tipo_tarjeta NOT IN ('Amarilla', 'Roja directa')
        SET @err = @err + ' - Tipo invalido (Amarilla / Roja directa). La roja por doble amarilla la genera el sistema.';

    IF NOT EXISTS (SELECT 1 FROM comp.Alineacion WHERE id_alineacion = @id_alineacion)
        SET @err = @err + ' - La alineacion no existe.';
    ELSE IF EXISTS (SELECT 1 FROM disc.Tarjeta
                    WHERE id_alineacion = @id_alineacion
                      AND tipo_tarjeta IN ('Roja directa', 'Roja por doble amarilla'))
        SET @err = @err + ' - El jugador ya fue expulsado en este partido.';

    -- La 2da amarilla tiene que ser cronologicamente posterior a la 1ra
    -- (se compara periodo, despues minuto y despues minuto adicional)
    IF @tipo_tarjeta = 'Amarilla'
       AND EXISTS (SELECT 1
                   FROM disc.Tarjeta t
                   INNER JOIN comp.Periodo pe_prev  ON pe_prev.id_periodo  = t.id_periodo
                   INNER JOIN comp.Periodo pe_nuevo ON pe_nuevo.id_periodo = @id_periodo
                   WHERE t.id_alineacion = @id_alineacion
                     AND t.tipo_tarjeta = 'Amarilla'
                     AND ( pe_nuevo.orden < pe_prev.orden
                        OR ( pe_nuevo.orden = pe_prev.orden
                             AND ( @minuto < t.minuto
                                OR (@minuto = t.minuto AND @minuto_adicional < t.minuto_adicional) ) ) ))
        SET @err = @err + ' - La segunda amarilla no puede ser anterior a la primera.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Tarjeta_Registrar:' + @err;
        THROW 50908, @err, 1;
    END

    -- Amarillas que el jugador ya tiene en ESTE partido (y la primera de ellas)
    SELECT @amarillas_previas = COUNT(*)
    FROM disc.Tarjeta
    WHERE id_alineacion = @id_alineacion AND tipo_tarjeta = 'Amarilla';

    SELECT TOP 1 @id_amarilla_1 = id_tarjeta
    FROM disc.Tarjeta
    WHERE id_alineacion = @id_alineacion AND tipo_tarjeta = 'Amarilla'
    ORDER BY id_tarjeta;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 2) Alta de la tarjeta (el ABM no devuelve el id: se busca la ultima de ese jugador y tipo)
        EXEC disc.usp_Tarjeta_Alta @id_alineacion, NULL, NULL, @tipo_tarjeta, @motivo,
                                   @id_periodo, @minuto, @minuto_adicional;

        SELECT TOP 1 @id_tarjeta = id_tarjeta
        FROM disc.Tarjeta
        WHERE id_alineacion = @id_alineacion AND tipo_tarjeta = @tipo_tarjeta
        ORDER BY id_tarjeta DESC;

        IF @tipo_tarjeta = 'Amarilla' AND @amarillas_previas >= 1
        BEGIN
            -- 3) Segunda amarilla del partido: expulsion
            EXEC disc.usp_Tarjeta_Alta @id_alineacion, NULL, NULL, 'Roja por doble amarilla',
                                       'Segunda amarilla en el partido', @id_periodo, @minuto, @minuto_adicional;

            SELECT TOP 1 @id_tarjeta_roja = id_tarjeta
            FROM disc.Tarjeta
            WHERE id_alineacion = @id_alineacion AND tipo_tarjeta = 'Roja por doble amarilla'
            ORDER BY id_tarjeta DESC;

            -- La 1ra amarilla pudo haber completado la acumulacion y generado una suspension:
            -- con la expulsion esa amarilla deja de contar, asi que se anula
            SELECT @id_suspension = id_suspension, @id_partido_cumple = id_partido_cumple
            FROM disc.Suspension
            WHERE id_tarjeta_origen = @id_amarilla_1 AND estado = 'PENDIENTE';

            IF @id_suspension IS NOT NULL
                EXEC disc.usp_Suspension_Modificacion @id_suspension, @id_partido_cumple, 'ANULADA';

            EXEC disc.usp_Suspension_CalcularPorTarjeta @id_tarjeta_roja;
        END
        ELSE
            -- 4) Amarilla simple o roja directa: se calcula sobre la propia tarjeta
            EXEC disc.usp_Suspension_CalcularPorTarjeta @id_tarjeta;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
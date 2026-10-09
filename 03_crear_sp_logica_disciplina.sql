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
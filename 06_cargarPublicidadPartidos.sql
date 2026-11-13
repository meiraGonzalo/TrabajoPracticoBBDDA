USE MundialDB;
GO

CREATE OR ALTER PROCEDURE pub.usp_AsignarPublicidadTodosPartidos
    @id_torneo INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id_log INT;
    DECLARE @total_partidos INT = 0;
    DECLARE @asignados_ok INT = 0;
    DECLARE @errores INT = 0;
    DECLARE @ahora DATETIME2(0) = SYSDATETIME();

    -- 1. Abrir log reutilizando imp.usp_LogImportacion_Alta y el patrón MAX(id_log_importacion) del proyecto
    EXEC imp.usp_LogImportacion_Alta 
        'ASIGNACION_MASIVA_PUBLICIDAD', 
        'pub.usp_AsignarPublicidadPartido', 
        @ahora, 
        NULL, 
        0, 
        0, 
        0;

    SELECT @id_log = MAX(id_log_importacion) 
    FROM imp.LogImportacion;

    -- 2. Obtener partidos pendientes
    DECLARE @PartidosPendientes TABLE (
        nro_fila    INT IDENTITY(1,1),
        id_partido  INT,
        nro_partido SMALLINT
    );

    INSERT INTO @PartidosPendientes (id_partido, nro_partido)
    SELECT p.id_partido, p.nro_partido
    FROM comp.Partido p
    WHERE (@id_torneo IS NULL OR p.id_torneo = @id_torneo)
      AND NOT EXISTS (
          SELECT 1 
          FROM pub.ExhibicionPublicitaria ep 
          WHERE ep.id_partido = p.id_partido
      )
    ORDER BY p.fecha_hora_utc ASC, p.id_partido ASC;

    SET @total_partidos = (SELECT COUNT(*) FROM @PartidosPendientes);

    -- 3. Iterar cada partido delegando en pub.usp_AsignarPublicidadPartido
    DECLARE @i INT = 1;
    DECLARE @id_partido_actual INT;
    DECLARE @nro_partido_actual SMALLINT;
    DECLARE @dato_log NVARCHAR(200);
    DECLARE @msg_error NVARCHAR(500);

    WHILE @i <= @total_partidos
    BEGIN
        SELECT 
            @id_partido_actual  = id_partido,
            @nro_partido_actual = nro_partido
        FROM @PartidosPendientes
        WHERE nro_fila = @i;

        BEGIN TRY
            EXEC pub.usp_AsignarPublicidadPartido @id_partido = @id_partido_actual;
            SET @asignados_ok += 1;
        END TRY
        BEGIN CATCH
            SET @errores += 1;
            SET @dato_log  = CONCAT('id_partido=', @id_partido_actual, ' | nro_partido=', @nro_partido_actual);
            SET @msg_error = LEFT(ERROR_MESSAGE(), 500);

            EXEC imp.usp_ErrorImportacion_Alta @id_log, @i, @dato_log, @msg_error;
        END CATCH;

        SET @i += 1;
    END

    -- 4. Cerrar el log mediante imp.usp_LogImportacion_Modificacion
    SET @ahora = SYSDATETIME();
    EXEC imp.usp_LogImportacion_Modificacion @id_log, @ahora, @total_partidos, @asignados_ok, @errores;

END;
GO

-- Procesar todos los partidos pendientes (o filtrar por @id_torneo = 1)
EXEC pub.usp_AsignarPublicidadTodosPartidos;

-- Verificar las piezas asignadas por partido
SELECT 
    p.nro_partido,
    p.fecha_hora_utc,
    ep.nro_espacio,
    ep.puntaje_prioridad,
    ep.monto_aplicado,
    pp.titulo AS pieza_publicitaria,
    pa.nombre AS mercado_objetivo
FROM pub.ExhibicionPublicitaria ep
INNER JOIN comp.Partido p ON ep.id_partido = p.id_partido
INNER JOIN pub.PiezaPublicitaria pp ON ep.id_pieza_publicitaria = pp.id_pieza_publicitaria
INNER JOIN cat.Pais pa ON pp.id_pais_mercado = pa.id_pais
ORDER BY p.nro_partido ASC, ep.nro_espacio ASC;
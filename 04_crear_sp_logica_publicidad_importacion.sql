/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - Script 04: Lógica de Negocio (Catálogos, Publicidad e Importación)
 Grupo 02 - Comision 02-5600
  Integrantes: 
  Miro, Saba.
  Mendez Camacho, Tatiana Antonella
  Rocha Escalera, Sheila
  Meira Da Cruz Saleiro, Gonzalo
=====================================================================
*/


USE MundialDB;
GO


/* =====================================================================
   1. SIMULACIÓN DE PRIME TIME Y CONVERSIÓN DE HUSOS HORARIOS
   ===================================================================== */

CREATE OR ALTER FUNCTION pub.ufn_ObtenerHoraLocalYFranja (
    @fecha_hora_utc DATETIME2(0),
    @huso_horario VARCHAR(50)
)
RETURNS TABLE
AS
RETURN (
    SELECT 
        CAST((@fecha_hora_utc AT TIME ZONE 'UTC') AT TIME ZONE @huso_horario AS DATETIME2(0)) AS fecha_hora_local,
        CAST(CAST((@fecha_hora_utc AT TIME ZONE 'UTC') AT TIME ZONE @huso_horario AS DATETIME2(0)) AS TIME(0)) AS hora_local
)
GO


/* =====================================================================
   2. CONVERSIÓN DE MONEDAS
   ===================================================================== */

CREATE OR ALTER FUNCTION cat.ufn_ConvertirMoneda (
    @monto DECIMAL(18,2),
    @id_moneda_origen INT,
    @id_moneda_destino INT,
    @fecha DATE
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @tasa_origen DECIMAL(18,6);
    DECLARE @tasa_destino DECIMAL(18,6);
    DECLARE @monto_usd DECIMAL(18,6);
    DECLARE @monto_final DECIMAL(18,2);

    IF @id_moneda_origen = @id_moneda_destino
        RETURN @monto;

    -- Obtener la tasa más reciente a la fecha solicitada para la moneda origen
    SELECT TOP 1 @tasa_origen = tasa_usd 
    FROM cat.TipoCambio 
    WHERE id_moneda = @id_moneda_origen AND fecha <= @fecha 
    ORDER BY fecha DESC;

    -- Obtener la tasa más reciente a la fecha solicitada para la moneda destino
    SELECT TOP 1 @tasa_destino = tasa_usd 
    FROM cat.TipoCambio 
    WHERE id_moneda = @id_moneda_destino AND fecha <= @fecha 
    ORDER BY fecha DESC;

    IF @tasa_origen IS NULL OR @tasa_destino IS NULL
        RETURN NULL; 

    -- Convertir a USD y luego a la moneda destino
    SET @monto_usd = @monto / @tasa_origen;
    SET @monto_final = CAST(@monto_usd * @tasa_destino AS DECIMAL(18,2));

    RETURN @monto_final;
END
GO


/* =====================================================================
   3. ASIGNACIÓN DE EXHIBICIÓN PUBLICITARIA POR PARTIDO
   ===================================================================== */

CREATE OR ALTER PROCEDURE pub.usp_AsignarPublicidadPartido
    @id_partido INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @err NVARCHAR(2000) = '';
    DECLARE @id_torneo INT, @id_fase INT, @fecha_hora_utc DATETIME2(0);
    
    SELECT @id_torneo = id_torneo, @id_fase = id_fase, @fecha_hora_utc = fecha_hora_utc 
    FROM comp.Partido 
    WHERE id_partido = @id_partido;

    IF @id_torneo IS NULL
    BEGIN
        SET @err = 'usp_AsignarPublicidadPartido: - El partido no existe.';
        THROW 50501, @err, 1;
    END

    IF EXISTS (SELECT 1 FROM pub.ExhibicionPublicitaria WHERE id_partido = @id_partido)
    BEGIN
        SET @err = 'usp_AsignarPublicidadPartido: - El partido ya tiene publicidad asignada.';
        THROW 50502, @err, 1;
    END

    -- Obtener países de las selecciones que juegan
    DECLARE @paises_juegan TABLE (id_pais INT);
    INSERT INTO @paises_juegan (id_pais)
    SELECT s.id_pais 
    FROM comp.PartidoSeleccion ps
    INNER JOIN comp.Seleccion s ON ps.id_seleccion = s.id_seleccion
    WHERE ps.id_partido = @id_partido;

    -- Tabla temporal para evaluar las piezas candidatas
    CREATE TABLE #Candidatos (
        id_pieza_publicitaria INT,
        id_pais_mercado INT,
        id_franja_horaria INT,
        puntaje DECIMAL(18,2),
        id_tarifa INT,
        monto DECIMAL(12,2),
        id_moneda INT
    );

    INSERT INTO #Candidatos (id_pieza_publicitaria, id_pais_mercado, id_franja_horaria, puntaje, id_tarifa, monto, id_moneda)
    SELECT 
        pp.id_pieza_publicitaria,
        pp.id_pais_mercado,
        fh.id_franja_horaria,
        (
            -- Puntos por país de selección
            CASE WHEN pp.id_pais_mercado IN (SELECT id_pais FROM @paises_juegan) THEN 500 ELSE 0 END
            +
            -- Puntos por Prime Time
            CASE WHEN fh.es_prime_time = 1 THEN 300 ELSE 0 END
            +
            -- Puntos por Feriado en el mercado destino
            CASE WHEN EXISTS (SELECT 1 FROM cat.Feriado f WHERE f.id_pais = pp.id_pais_mercado AND f.fecha = CAST(hl.fecha_hora_local AS DATE)) THEN 100 ELSE 0 END
            +
            -- Puntos por Poder Adquisitivo (PBI per cápita escalado)
            ISNULL((SELECT TOP 1 valor / 100.0 FROM cat.IndicadorEconomico ie WHERE ie.id_pais = pp.id_pais_mercado AND ie.codigo_indicador = 'NY.GDP.PCAP.CD' ORDER BY anio DESC), 0)
        ) AS puntaje,
        t.id_tarifa,
        t.monto,
        t.id_moneda
    FROM pub.PiezaPublicitaria pp
    INNER JOIN cat.Pais p ON p.id_pais = pp.id_pais_mercado
    CROSS APPLY pub.ufn_ObtenerHoraLocalYFranja(@fecha_hora_utc, p.huso_horario) hl
    -- Match con la franja horaria correspondiente (cubriendo cruces de medianoche)
    INNER JOIN pub.FranjaHoraria fh ON 
        (fh.hora_desde <= fh.hora_hasta AND hl.hora_local >= fh.hora_desde AND hl.hora_local <= fh.hora_hasta)
        OR
        (fh.hora_desde > fh.hora_hasta AND (hl.hora_local >= fh.hora_desde OR hl.hora_local <= fh.hora_hasta))
    -- Match con tarifa (debe existir para que se pueda facturar)
    INNER JOIN pub.Tarifa t ON t.id_franja_horaria = fh.id_franja_horaria AND t.id_torneo = @id_torneo AND t.id_fase = @id_fase
    WHERE EXISTS (
        -- Validar que la campaña está activa
        SELECT 1 FROM pub.Campania c 
        WHERE c.id_campania = pp.id_campania 
        AND (c.fecha_desde IS NULL OR c.fecha_desde <= CAST(@fecha_hora_utc AS DATE))
        AND (c.fecha_hasta IS NULL OR c.fecha_hasta >= CAST(@fecha_hora_utc AS DATE))
    );

    BEGIN TRY
        BEGIN TRAN;
        
        -- Insertar el TOP 4 priorizado
        INSERT INTO pub.ExhibicionPublicitaria (id_partido, nro_espacio, id_pieza_publicitaria, id_tarifa, monto_aplicado, id_moneda, puntaje_prioridad, estado)
        SELECT 
            @id_partido,
            ROW_NUMBER() OVER(ORDER BY puntaje DESC, id_pieza_publicitaria ASC) AS nro_espacio,
            id_pieza_publicitaria,
            id_tarifa,
            monto,
            id_moneda,
            puntaje,
            'PROPUESTA'
        FROM (
            SELECT TOP 4 *
            FROM #Candidatos
            ORDER BY puntaje DESC
        ) AS top_4;

        COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH

    DROP TABLE #Candidatos;
END
GO


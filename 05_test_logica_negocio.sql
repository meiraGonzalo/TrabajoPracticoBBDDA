/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - Script 05: Testing de Lógica de Negocio (Publicidad, Importación, Husos, Monedas)
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

SET NOCOUNT ON;

PRINT '=========================================================================';
PRINT ' TESTING LÓGICA DE NEGOCIO (Script 04)';
PRINT ' Funciones: ufn_ObtenerHoraLocalYFranja, ufn_ConvertirMoneda';
PRINT ' Procedimiento: usp_AsignarPublicidadPartido';
PRINT '=========================================================================';
PRINT '';

-- ==============================================================================
-- 1. PRUEBA: ufn_ObtenerHoraLocalYFranja (Husos Horarios)
-- ==============================================================================
PRINT '--- 1. FUNCION pub.ufn_ObtenerHoraLocalYFranja ---';
BEGIN TRY
    SELECT 
        'Conversion Horaria' AS [Prueba],
        '2026-07-04 20:00:00 UTC' AS [Entrada_UTC],
        'Eastern Standard Time' AS [Huso_Consultado],
        fecha_hora_local AS [Fecha_Hora_Local], 
        hora_local AS [Hora_Local]
    FROM pub.ufn_ObtenerHoraLocalYFranja('2026-07-04 20:00:00', 'Eastern Standard Time');

    PRINT '>> Calculo de huso horario ejecutado.';
END TRY
BEGIN CATCH
    PRINT '>> Falla en ufn_ObtenerHoraLocalYFranja: ' + ERROR_MESSAGE();
END CATCH;
PRINT '';

-- ==============================================================================
-- 2. PRUEBA: cat.ufn_ConvertirMoneda (Conversión de Divisas)
-- ==============================================================================
PRINT '--- 2. FUNCION cat.ufn_ConvertirMoneda ---';
BEGIN TRAN;
BEGIN TRY
    -- Creamos monedas y tipos de cambio temporales aislados en la transacción
    DECLARE @id_m_origen INT, @id_m_destino INT, @id_m_sintasa INT;

    INSERT INTO cat.Moneda (codigo_iso, nombre) VALUES ('TST', 'Moneda Test Origen');
    SET @id_m_origen = SCOPE_IDENTITY();

    INSERT INTO cat.Moneda (codigo_iso, nombre) VALUES ('TSD', 'Moneda Test Destino');
    SET @id_m_destino = SCOPE_IDENTITY();

    INSERT INTO cat.Moneda (codigo_iso, nombre) VALUES ('TSX', 'Moneda Sin Tasa');
    SET @id_m_sintasa = SCOPE_IDENTITY();

    -- Cotizaciones: 1 TST = 2.0 USD (tasa = 2.0), 1 TSD = 0.5 USD (tasa = 0.5)
    -- Formula interna: (Monto / TasaOrigen) * TasaDestino
    -- Ejemplo: 100 TST / 2.0 = 50 USD; 50 USD * 0.5 = 25 TSD
    INSERT INTO cat.TipoCambio (id_moneda, fecha, tasa_usd) VALUES 
    (@id_m_origen, '2026-06-01', 2.000000),
    (@id_m_destino, '2026-06-01', 0.500000);

    SELECT 
        'Misma Moneda' AS [Caso],
        100.00 AS [Monto_Original],
        cat.ufn_ConvertirMoneda(100.00, @id_m_origen, @id_m_origen, '2026-06-15') AS [Monto_Convertido],
        100.00 AS [Esperado]
    UNION ALL
    SELECT 
        'Conversion Cruzada',
        100.00,
        cat.ufn_ConvertirMoneda(100.00, @id_m_origen, @id_m_destino, '2026-06-15'),
        25.00
    UNION ALL
    SELECT 
        'Sin Tasa (Retorna NULL)',
        100.00,
        cat.ufn_ConvertirMoneda(100.00, @id_m_origen, @id_m_sintasa, '2026-06-15'),
        NULL;

    PRINT '>> Casos de conversion de divisas ejecutados.';
    ROLLBACK TRAN;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    PRINT '>> Falla en ufn_ConvertirMoneda: ' + ERROR_MESSAGE();
END CATCH;
PRINT '';

-- ==============================================================================
-- 3. PRUEBA: pub.usp_AsignarPublicidadPartido (Motor de Asignación y TOP 4)
-- ==============================================================================
PRINT '--- 3. PROCEDIMIENTO pub.usp_AsignarPublicidadPartido ---';

-- 3.1 Error controlado por partido inexistente
PRINT '>> Validacion: Partido inexistente';
BEGIN TRY
    EXEC pub.usp_AsignarPublicidadPartido @id_partido = -999;
END TRY
BEGIN CATCH
    PRINT '   Falla capturada por el SP: ' + ERROR_MESSAGE();
END CATCH;
PRINT '';

-- 3.2 Asignación competitiva y descarte de la menor prioridad
PRINT '>> Validacion: Evaluacion de prioridades y asignacion de Top 4 espacios';
BEGIN TRAN;
BEGIN TRY
    DECLARE @id_partido_test INT, @id_torneo INT, @id_fase INT, @utc DATETIME2(0);
    DECLARE @id_pais_local INT, @id_pais_visitante INT;

    SELECT TOP 1 
        @id_partido_test = p.id_partido, 
        @id_torneo = p.id_torneo, 
        @id_fase = p.id_fase, 
        @utc = p.fecha_hora_utc
    FROM comp.Partido p
    WHERE EXISTS (SELECT 1 FROM comp.PartidoSeleccion ps WHERE ps.id_partido = p.id_partido);

    IF @id_partido_test IS NULL
    BEGIN
        PRINT 'ADVERTENCIA: No se encontro un partido con selecciones asignadas.';
        ROLLBACK TRAN;
        RETURN;
    END

    SELECT TOP 1 @id_pais_local = s.id_pais 
    FROM comp.PartidoSeleccion ps 
    JOIN comp.Seleccion s ON ps.id_seleccion = s.id_seleccion 
    WHERE ps.id_partido = @id_partido_test AND ps.condicion = 'L';

    SELECT TOP 1 @id_pais_visitante = s.id_pais 
    FROM comp.PartidoSeleccion ps 
    JOIN comp.Seleccion s ON ps.id_seleccion = s.id_seleccion 
    WHERE ps.id_partido = @id_partido_test AND ps.condicion = 'V';

    -- Limpieza previa en el contexto de esta transacción
    DELETE FROM pub.ExhibicionPublicitaria WHERE id_partido = @id_partido_test;

    -- Catálogos de prueba
    DECLARE @id_moneda INT, @id_idioma INT;
    INSERT INTO cat.Moneda (codigo_iso, nombre) VALUES ('XP', 'Moneda Motor');
    SET @id_moneda = SCOPE_IDENTITY();
    
    INSERT INTO cat.Idioma (codigo_iso, nombre) VALUES ('XP', 'Idioma Motor');
    SET @id_idioma = SCOPE_IDENTITY();

    DECLARE @id_pais_rico INT, @id_pais_medio INT, @id_pais_pobre INT;
    INSERT INTO cat.Pais (nombre, confederacion, id_moneda, huso_horario) VALUES ('Pais Rico', 'UEFA', @id_moneda, 'UTC');
    SET @id_pais_rico = SCOPE_IDENTITY();
    
    INSERT INTO cat.Pais (nombre, confederacion, id_moneda, huso_horario) VALUES ('Pais Medio', 'CONCACAF', @id_moneda, 'UTC');
    SET @id_pais_medio = SCOPE_IDENTITY();
    
    INSERT INTO cat.Pais (nombre, confederacion, id_moneda, huso_horario) VALUES ('Pais Pobre', 'AFC', @id_moneda, 'UTC');
    SET @id_pais_pobre = SCOPE_IDENTITY();

    -- Indicadores de PBI per cápita
    INSERT INTO cat.IndicadorEconomico (id_pais, anio, codigo_indicador, valor) VALUES 
    (@id_pais_local, YEAR(@utc), 'NY.GDP.PCAP.CD', 25000.00),
    (@id_pais_visitante, YEAR(@utc), 'NY.GDP.PCAP.CD', 15000.00),
    (@id_pais_rico, YEAR(@utc), 'NY.GDP.PCAP.CD', 80000.00),
    (@id_pais_medio, YEAR(@utc), 'NY.GDP.PCAP.CD', 10000.00),
    (@id_pais_pobre, YEAR(@utc), 'NY.GDP.PCAP.CD', 2000.00);

    -- Feriado para el país visitante
    INSERT INTO cat.Feriado (id_pais, fecha, nombre) VALUES (@id_pais_visitante, CAST(@utc AS DATE), 'Feriado Test');

    -- Franja horaria y tarifa
    DECLARE @id_franja INT;
    INSERT INTO pub.FranjaHoraria (nombre, hora_desde, hora_hasta, es_prime_time) VALUES ('Franja Total', '00:00', '23:59', 1);
    SET @id_franja = SCOPE_IDENTITY();
    
    INSERT INTO pub.Tarifa (id_torneo, id_fase, id_franja_horaria, monto, id_moneda) VALUES (@id_torneo, @id_fase, @id_franja, 1000.00, @id_moneda);
    
    -- Estructura publicitaria
    DECLARE @id_anunciante INT, @id_marca INT, @id_agencia INT, @id_campania INT;
    INSERT INTO pub.Anunciante (nombre, id_pais) VALUES ('Anunciante Test', @id_pais_rico);
    SET @id_anunciante = SCOPE_IDENTITY();
    
    INSERT INTO pub.Marca (id_anunciante, nombre) VALUES (@id_anunciante, 'Marca Test');
    SET @id_marca = SCOPE_IDENTITY();
    
    INSERT INTO pub.Agencia (nombre) VALUES ('Agencia Test');
    SET @id_agencia = SCOPE_IDENTITY();
    
    INSERT INTO pub.Campania (id_marca, id_agencia, titulo, fecha_desde, fecha_hasta, descripcion)
    VALUES (@id_marca, @id_agencia, 'Campania Motor', DATEADD(DAY, -1, @utc), DATEADD(DAY, 1, @utc), 'Campania Test');
    SET @id_campania = SCOPE_IDENTITY();

    -- Creación de 5 piezas para competir por los 4 espacios
    INSERT INTO pub.PiezaPublicitaria (id_campania, id_idioma, id_pais_mercado, titulo, url_contenido) VALUES 
    (@id_campania, @id_idioma, @id_pais_local, 'Pieza A: Local (Juega, Prime, PBI 25K)', 'url_A'),
    (@id_campania, @id_idioma, @id_pais_visitante, 'Pieza B: Visitante (Juega, Prime, PBI 15K, Feriado)', 'url_B'),
    (@id_campania, @id_idioma, @id_pais_rico, 'Pieza C: Mercado Rico (No Juega, Prime, PBI 80K)', 'url_C'),
    (@id_campania, @id_idioma, @id_pais_medio, 'Pieza D: Mercado Medio (No Juega, Prime, PBI 10K)', 'url_D'),
    (@id_campania, @id_idioma, @id_pais_pobre, 'Pieza E: Mercado Pobre (No Juega, Prime, PBI 2K - Descarta)', 'url_E');

    -- Ejecución del procedimiento
    EXEC pub.usp_AsignarPublicidadPartido @id_partido = @id_partido_test;

    -- Grilla visual de resultados (Top 4 asignadas)
    SELECT 
        ep.nro_espacio AS [Espacio_Asignado],
        ep.puntaje_prioridad AS [Puntaje_Calculado],
        pp.titulo AS [Pieza],
        p.nombre AS [Pais_Mercado],
        CASE 
            WHEN p.id_pais IN (@id_pais_local, @id_pais_visitante) THEN 'SI' 
            ELSE 'NO' 
        END AS [Disputa_Partido]
    FROM pub.ExhibicionPublicitaria ep
    INNER JOIN pub.PiezaPublicitaria pp ON ep.id_pieza_publicitaria = pp.id_pieza_publicitaria
    INNER JOIN cat.Pais p ON pp.id_pais_mercado = p.id_pais
    WHERE ep.id_partido = @id_partido_test
    ORDER BY ep.nro_espacio ASC;

    -- 3.3 Validación de duplicidad sobre el mismo partido
    PRINT '>> Validacion: Rechazo por asignacion previa en el mismo partido';
    BEGIN TRY
        EXEC pub.usp_AsignarPublicidadPartido @id_partido = @id_partido_test;
    END TRY
    BEGIN CATCH
        PRINT '   Falla capturada por el SP: ' + ERROR_MESSAGE();
    END CATCH;

    -- Reversión total de datos creados en el test
    ROLLBACK TRAN;
    PRINT '';
    PRINT '>> Limpieza completada: Los datos de prueba fueron revertidos mediante ROLLBACK.';

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN;
    PRINT '>> Falla critica en la prueba de asignacion: ' + ERROR_MESSAGE();
END CATCH;
GO

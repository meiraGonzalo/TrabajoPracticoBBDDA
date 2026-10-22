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

/*
=====================================================================
PREPARACION DE PRUEBAS DE SP DE PUBLICIDAD Y LOG DE IMPORTACION
=====================================================================
*/

-- 1. Insertar Catálogos Básicos
EXEC cat.usp_Moneda_Alta 'USD', 'Dólar Estadounidense';
EXEC cat.usp_Moneda_Alta 'ARS', 'Peso Argentino';
EXEC cat.usp_Moneda_Alta 'EUR', 'Euro';

DECLARE @id_usd INT, @id_ars INT, @id_eur INT;
SELECT @id_usd = id_moneda FROM cat.Moneda WHERE codigo_iso = 'USD';
SELECT @id_ars = id_moneda FROM cat.Moneda WHERE codigo_iso = 'ARS';
SELECT @id_eur = id_moneda FROM cat.Moneda WHERE codigo_iso = 'EUR';

-- Insertar tipos de cambio (ARS y EUR respecto al USD)
EXEC cat.usp_TipoCambio_Alta @id_ars, '2026-06-01', 1500.00;
EXEC cat.usp_TipoCambio_Alta @id_eur, '2026-06-01', 0.90;

-- Idiomas
EXEC cat.usp_Idioma_Alta 'ES', 'Español';
EXEC cat.usp_Idioma_Alta 'EN', 'Inglés';

DECLARE @id_es INT, @id_en INT;
SELECT @id_es = id_idioma FROM cat.Idioma WHERE codigo_iso = 'ES';
SELECT @id_en = id_idioma FROM cat.Idioma WHERE codigo_iso = 'EN';

-- Países y husos (AT TIME ZONE de SQL Server)
-- Argentina
EXEC cat.usp_Pais_Alta 'Argentina', 'CONMEBOL', @id_ars, 'Argentina Standard Time';
-- España
EXEC cat.usp_Pais_Alta 'España', 'UEFA', @id_eur, 'Romance Standard Time';
-- México (Central)
EXEC cat.usp_Pais_Alta 'México', 'CONCACAF', @id_usd, 'Central Standard Time (Mexico)'; 

DECLARE @id_arg INT, @id_esp INT, @id_mex INT;
SELECT @id_arg = id_pais FROM cat.Pais WHERE nombre = 'Argentina';
SELECT @id_esp = id_pais FROM cat.Pais WHERE nombre = 'España';
SELECT @id_mex = id_pais FROM cat.Pais WHERE nombre = 'México';

-- Feriados
EXEC cat.usp_Feriado_Alta @id_arg, '2026-06-15', 'Feriado de Prueba ARG';
EXEC cat.usp_Feriado_Alta @id_esp, '2026-06-15', 'Feriado de Prueba ESP';

-- Indicadores (Poder adquisitivo de prueba)
EXEC cat.usp_IndicadorEconomico_Alta @id_arg, 2025, 'NY.GDP.PCAP.CD', 13000.50;
EXEC cat.usp_IndicadorEconomico_Alta @id_esp, 2025, 'NY.GDP.PCAP.CD', 30000.00;
EXEC cat.usp_IndicadorEconomico_Alta @id_mex, 2025, 'NY.GDP.PCAP.CD', 11000.00;

-- Franjas Horarias
EXEC pub.usp_FranjaHoraria_Alta 'Tarde', '13:00:00', '18:59:59', 0;
EXEC pub.usp_FranjaHoraria_Alta 'Prime Time', '19:00:00', '23:59:59', 1;
EXEC pub.usp_FranjaHoraria_Alta 'Madrugada', '00:00:00', '12:59:59', 0;

DECLARE @id_tarde INT, @id_prime INT, @id_madrugada INT;
SELECT @id_tarde = id_franja_horaria FROM pub.FranjaHoraria WHERE nombre = 'Tarde';
SELECT @id_prime = id_franja_horaria FROM pub.FranjaHoraria WHERE nombre = 'Prime Time';
SELECT @id_madrugada = id_franja_horaria FROM pub.FranjaHoraria WHERE nombre = 'Madrugada';

-- 2. Torneo, Fases y Partido de Prueba
EXEC comp.usp_Torneo_Alta 'Mundial 2026', 2026, '2026-06-11', '2026-07-19';
DECLARE @id_torneo INT; SELECT @id_torneo = MAX(id_torneo) FROM comp.Torneo;

EXEC comp.usp_Fase_Alta 'Grupos', 1, 0;
DECLARE @id_fase INT; SELECT @id_fase = MAX(id_fase) FROM comp.Fase;

-- Sede en México
EXEC cat.usp_Ciudad_Alta 'Ciudad de México', @id_mex, 'Central Standard Time (Mexico)';
DECLARE @id_ciudad INT; SELECT @id_ciudad = MAX(id_ciudad) FROM cat.Ciudad;
EXEC comp.usp_Sede_Alta 'Estadio Azteca', @id_ciudad, 83000, 19.3029, -99.1505;
DECLARE @id_sede INT; SELECT @id_sede = MAX(id_sede) FROM comp.Sede;

-- Partido (2026-06-15 22:00:00 UTC) -> 16:00 CDMX, 19:00 ARG (Prime), 00:00 ESP (Madrugada del día siguiente)
EXEC comp.usp_Partido_Alta @id_torneo, 1, @id_fase, NULL, @id_sede, '2026-06-15 22:00:00';
DECLARE @id_partido INT; SELECT @id_partido = MAX(id_partido) FROM comp.Partido;

-- Selecciones jugando (Juega Argentina)
EXEC comp.usp_Seleccion_Alta @id_torneo, @id_arg, NULL;
DECLARE @id_sel_arg INT; SELECT @id_sel_arg = MAX(id_seleccion) FROM comp.Seleccion;
EXEC comp.usp_PartidoSeleccion_Alta @id_partido, @id_sel_arg, 'L';

-- 3. Publicidad: Tarifas, Campañas y Piezas
-- Tarifas para el torneo y fase
EXEC pub.usp_Tarifa_Alta @id_torneo, @id_fase, @id_prime, 50000.00, @id_usd;
EXEC pub.usp_Tarifa_Alta @id_torneo, @id_fase, @id_tarde, 20000.00, @id_usd;
EXEC pub.usp_Tarifa_Alta @id_torneo, @id_fase, @id_madrugada, 10000.00, @id_usd;

-- Marcas y Campañas
EXEC pub.usp_Anunciante_Alta 'Anunciante A', @id_arg;
DECLARE @id_anu INT; SELECT @id_anu = MAX(id_anunciante) FROM pub.Anunciante;
EXEC pub.usp_Marca_Alta @id_anu, 'Marca A';
DECLARE @id_mar INT; SELECT @id_mar = MAX(id_marca) FROM pub.Marca;

-- Campaña activa
EXEC pub.usp_Campania_Alta @id_mar, NULL, 'Campaña Activa', '2026-06-01', '2026-07-30', 'Activa';
DECLARE @id_cam_activa INT; SELECT @id_cam_activa = MAX(id_campania) FROM pub.Campania;

-- Campaña vencida
EXEC pub.usp_Campania_Alta @id_mar, NULL, 'Campaña Vencida', '2026-01-01', '2026-05-30', 'Vencida';
DECLARE @id_cam_vencida INT; SELECT @id_cam_vencida = MAX(id_campania) FROM pub.Campania;

-- Piezas publicitarias
-- Pieza 1: España (Alta economía, no juega, sin prime time, con feriado)
EXEC pub.usp_PiezaPublicitaria_Alta @id_cam_activa, @id_es, @id_esp, 'Pieza ESP 1', 'url1';
-- Pieza 2: Argentina (Economía media, sí juega, prime time, con feriado) -> Debería tener más puntos
EXEC pub.usp_PiezaPublicitaria_Alta @id_cam_activa, @id_es, @id_arg, 'Pieza ARG 1', 'url2';
-- Pieza 3: México (Economía baja, no juega, tarde, sin feriado)
EXEC pub.usp_PiezaPublicitaria_Alta @id_cam_activa, @id_es, @id_mex, 'Pieza MEX 1', 'url3';
-- Pieza 4: Argentina (Campaña Vencida, no debería salir)
EXEC pub.usp_PiezaPublicitaria_Alta @id_cam_vencida, @id_es, @id_arg, 'Pieza ARG Vencida', 'url4';
-- Pieza 5: España (Igual a Pieza 1, para ocupar cupos)
EXEC pub.usp_PiezaPublicitaria_Alta @id_cam_activa, @id_en, @id_esp, 'Pieza ESP 2', 'url5';

/*
=====================================================================
'TEST 1: CONVERSIÓN DE HUSOS HORARIOS Y SIMULACIÓN DE PRIME TIME'
=====================================================================
*/

-- Debe mostrar para la hora 22:00:00 UTC:
-- CDMX (México): 16:00:00
-- Buenos Aires (Argentina): 19:00:00 (Prime time)
-- Madrid (España): 00:00:00 del 16-06
SELECT 
    p.nombre AS Pais,
    p.huso_horario,
    fh.fecha_hora_local,
    fh.hora_local
FROM cat.Pais p
CROSS APPLY pub.ufn_ObtenerHoraLocalYFranja('2026-06-15 22:00:00', p.huso_horario) fh
ORDER BY p.nombre;


/*
=====================================================================
 'TEST 2: CONVERSIÓN DE MONEDAS'
=====================================================================
*/

-- Convertir 100 USD a ARS (esperado 150000.00)
DECLARE @monto_ars DECIMAL(18,2) = cat.ufn_ConvertirMoneda(100.00, @id_usd, @id_ars, '2026-06-15');
PRINT '100 USD a ARS: ' + CAST(@monto_ars AS VARCHAR);
IF @monto_ars = 150000.00 PRINT '-> EXITO' ELSE PRINT '-> FALLO';

-- Convertir 100 EUR a USD (100 / 0.90 = 111.11)
DECLARE @monto_usd_conv DECIMAL(18,2) = cat.ufn_ConvertirMoneda(100.00, @id_eur, @id_usd, '2026-06-15');
PRINT '100 EUR a USD: ' + CAST(@monto_usd_conv AS VARCHAR);
IF @monto_usd_conv = 111.11 PRINT '-> EXITO' ELSE PRINT '-> FALLO';


/*
=====================================================================
'TEST 3: ASIGNACIÓN DE PUBLICIDAD POR PARTIDO'
=====================================================================
*/

-- Ejecutar el procedimiento
BEGIN TRY
    EXEC pub.usp_AsignarPublicidadPartido @id_partido;
    PRINT 'Procedimiento de asignación ejecutado correctamente.';
END TRY
BEGIN CATCH
    PRINT 'ERROR en asignación: ' + ERROR_MESSAGE();
END CATCH

-- Verificar resultados. Se espera que:
-- Espacio 1: ARG 1 (juega, prime time, feriado)
-- Espacios siguientes: ESP 1, ESP 2, MEX 1
-- NO debe estar ARG Vencida.
SELECT 
    ep.nro_espacio,
    pp.titulo AS Pieza_Candidata,
    c.titulo AS Campania,
    p.nombre AS Mercado_Destino,
    ep.puntaje_prioridad,
    ep.monto_aplicado,
    mo.codigo_iso AS Moneda_Tarifa
FROM pub.ExhibicionPublicitaria ep
INNER JOIN pub.PiezaPublicitaria pp ON pp.id_pieza_publicitaria = ep.id_pieza_publicitaria
INNER JOIN pub.Campania c ON c.id_campania = pp.id_campania
INNER JOIN cat.Pais p ON p.id_pais = pp.id_pais_mercado
INNER JOIN cat.Moneda mo ON mo.id_moneda = ep.id_moneda
WHERE ep.id_partido = @id_partido
ORDER BY ep.nro_espacio;

-- Validar que no se puede ejecutar dos veces para el mismo partido
PRINT 'Intentando reasignar publicidad al mismo partido (debe fallar):'
BEGIN TRY
    EXEC pub.usp_AsignarPublicidadPartido @id_partido;
    PRINT 'FALLO: No dio error y debió darlo.';
END TRY
BEGIN CATCH
    PRINT 'EXITO. El SP controló la doble ejecución: ' + ERROR_MESSAGE();
END CATCH

/*
=====================================================================
'TEST 4: MOTOR DE IMPORTACIÓN MASIVA CON ERROR HANDLING (UPSERT)'
=====================================================================
*/

-- Limpiar los tipos de cambio anteriores para testear limpio
DELETE FROM cat.TipoCambio;

DECLARE @LoteImportacion imp.TipoCambioType;

-- Caso 1: Nuevo registro (Éxito)
INSERT INTO @LoteImportacion VALUES (1, 'USD', '2026-07-01', 1.000000, '1,USD,2026-07-01,1.0');
-- Caso 2: Nuevo registro ARS (Éxito)
INSERT INTO @LoteImportacion VALUES (2, 'ARS', '2026-07-01', 1600.00000, '2,ARS,2026-07-01,1600.0');
-- Caso 3: Moneda inexistente (Falla controlada)
INSERT INTO @LoteImportacion VALUES (3, 'XXX', '2026-07-01', 50.000000, '3,XXX,2026-07-01,50.0');
-- Caso 4: Monto negativo (Falla controlada)
INSERT INTO @LoteImportacion VALUES (4, 'EUR', '2026-07-01', -0.500000, '4,EUR,2026-07-01,-0.5');
-- Caso 5: Update del registro ARS insertado en línea 2 (Éxito - UPSERT)
INSERT INTO @LoteImportacion VALUES (5, 'ARS', '2026-07-01', 1650.00000, '5,ARS,2026-07-01,1650.0');

EXEC imp.usp_ImportarTipoCambio 'tasas_julio.csv', 'Scraping Banco', @LoteImportacion;

-- Validar que el log registró 3 correctos y 2 errores
SELECT 
    id_log_importacion, nombre_archivo, filas_leidas, filas_ok, filas_error 
FROM imp.LogImportacion 
WHERE nombre_archivo = 'tasas_julio.csv';

-- Validar la tabla de errores
SELECT 
    nro_linea, dato_original, mensaje 
FROM imp.ErrorImportacion
WHERE id_log_importacion = (SELECT MAX(id_log_importacion) FROM imp.LogImportacion);

-- Validar que el upsert actualizó el ARS a 1650
SELECT 
    mo.codigo_iso, tc.fecha, tc.tasa_usd 
FROM cat.TipoCambio tc
INNER JOIN cat.Moneda mo ON mo.id_moneda = tc.id_moneda
ORDER BY tc.fecha, mo.codigo_iso;


/*
=====================================================================
'FIN DEL TESTING'
=====================================================================
*/
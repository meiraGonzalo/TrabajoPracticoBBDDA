/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - 03: Testing de los SP de ABM - Selecciones y convocatoria
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana (nickGithub: tatimendez)
              Rocha Escalera, Sheila Belisa nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo nickGithub: meiraGonzalo
 Fecha: 08/10/2026
 Objetivo: probar todos los SP de ABM. Por cada SP hay
           casos OK y casos que disparan las validaciones

 COMO CORRERLO:
   1) Ejecutar 00 y 01 (base recien creada, vacia).
   2) Ejecutar el script de SP de ABM 
   3) Ejecutar este script completo 

=====================================================================*/


/* =================================================================
   BLOQUE 1: CATÁLOGOS GEOGRÁFICOS Y ECONÓMICOS
   ================================================================= */
DECLARE @id_usa INT, @id_moneda_usd INT, @id_moneda_eur INT;
DECLARE @id_idioma_en INT, @id_idioma_es INT;
DECLARE @id_pais_temp INT, @id_ciudad_temp INT;

-- 1. MONEDA
IF NOT EXISTS (SELECT 1 FROM cat.Moneda WHERE codigo_iso = 'USD')
    EXEC cat.usp_Moneda_Alta 'USD', 'Dolar Estadounidense';
SELECT @id_moneda_usd = id_moneda FROM cat.Moneda WHERE codigo_iso = 'USD';

EXEC cat.usp_Moneda_Alta 'EUR', 'Euro';
SELECT @id_moneda_eur = id_moneda FROM cat.Moneda WHERE codigo_iso = 'EUR';

EXEC cat.usp_Moneda_Alta 'EU', 'Euro Falso'; 
/* Esperado: - El codigo ISO debe tener 3 caracteres. */
EXEC cat.usp_Moneda_Alta 'USD', 'Dolar Duplicado'; 
/* Esperado: - Ya existe una moneda con ese codigo ISO. */

EXEC cat.usp_Moneda_Modificacion @id_moneda_eur, 'EUR', 'Euro Europeo';
EXEC cat.usp_Moneda_Modificacion @id_moneda_eur, 'USD', 'Conflicto ISO'; 
/* Esperado: - Ya existe otra moneda con ese codigo ISO. */

EXEC cat.usp_Moneda_Baja @id_moneda_eur; -- BAJA OK

-- 2. IDIOMA
IF NOT EXISTS (SELECT 1 FROM cat.Idioma WHERE codigo_iso = 'EN')
    EXEC cat.usp_Idioma_Alta 'EN', 'Ingles';
SELECT @id_idioma_en = id_idioma FROM cat.Idioma WHERE codigo_iso = 'EN';

EXEC cat.usp_Idioma_Alta 'ES', 'Espanol';
SELECT @id_idioma_es = id_idioma FROM cat.Idioma WHERE codigo_iso = 'ES';

EXEC cat.usp_Idioma_Alta 'E', 'Invalido'; 
/* Esperado: - El codigo ISO debe tener 2 caracteres. */

EXEC cat.usp_Idioma_Modificacion @id_idioma_es, 'ES', 'Castellano';
EXEC cat.usp_Idioma_Modificacion @id_idioma_es, 'EN', 'Conflicto ISO'; 
/* Esperado: - Ya existe otro idioma con ese codigo ISO. */

EXEC cat.usp_Idioma_Baja @id_idioma_es; -- BAJA OK

-- 3. PAIS
IF NOT EXISTS (SELECT 1 FROM cat.Pais WHERE nombre = 'Estados Unidos')
    EXEC cat.usp_Pais_Alta 'Estados Unidos', 'CONCACAF', @id_moneda_usd, 'Eastern Standard Time';
SELECT @id_usa = id_pais FROM cat.Pais WHERE nombre = 'Estados Unidos';

EXEC cat.usp_Pais_Alta '', 'CONMEBOL', NULL, 'UTC'; 
/* Esperado: - El nombre es obligatorio. */
EXEC cat.usp_Pais_Alta 'Pais Falso', 'FAKE', NULL, 'UTC'; 
/* Esperado: - Confederacion invalida. */

EXEC cat.usp_Pais_Alta 'Pais Temp', 'CONCACAF', NULL, 'UTC';
SELECT @id_pais_temp = id_pais FROM cat.Pais WHERE nombre = 'Pais Temp';

EXEC cat.usp_Pais_Modificacion @id_pais_temp, 'Pais Temp', 'CONMEBOL', NULL, 'UTC';
EXEC cat.usp_Pais_Modificacion @id_pais_temp, 'Estados Unidos', 'CONMEBOL', NULL, 'UTC'; 
/* Esperado: - Ya existe otro pais con ese nombre. */

-- 4. CIUDAD
IF NOT EXISTS (SELECT 1 FROM cat.Ciudad WHERE nombre = 'Miami')
    EXEC cat.usp_Ciudad_Alta 'Miami', @id_usa, 'Eastern Standard Time';

EXEC cat.usp_Ciudad_Alta '', @id_usa, 'Eastern Standard Time'; 
/* Esperado: - El nombre es obligatorio. */

EXEC cat.usp_Ciudad_Alta 'Ciudad Temp', @id_pais_temp, 'UTC';
SELECT @id_ciudad_temp = id_ciudad FROM cat.Ciudad WHERE nombre = 'Ciudad Temp';

EXEC cat.usp_Ciudad_Modificacion @id_ciudad_temp, 'Ciudad Temp 2', @id_pais_temp, 'UTC';
EXEC cat.usp_Ciudad_Modificacion @id_ciudad_temp, 'Ciudad Temp 2', @id_usa, 'Invalid TimeZone'; 
/* Esperado: - Huso horario invalido. */

-- Bajas Cruzadas y Temporales (Protección por FK)
EXEC cat.usp_Moneda_Baja @id_moneda_usd; 
/* Esperado: - Existen paises asociados a esta moneda. (EEUU) */
EXEC cat.usp_Pais_Baja @id_usa; 
/* Esperado: - El pais tiene ciudades. (Miami) */
EXEC cat.usp_Ciudad_Baja @id_miami; 
/* Esperado: - Existen sedes registradas en la ciudad. */

EXEC cat.usp_Ciudad_Baja @id_ciudad_temp; -- BAJA OK
EXEC cat.usp_Pais_Baja @id_pais_temp; -- BAJA OK

-- 5. INDICADOR ECONOMICO
EXEC cat.usp_IndicadorEconomico_Alta @id_usa, 2026, 'PBI', 25000.50;
EXEC cat.usp_IndicadorEconomico_Alta @id_usa, 2026, 'PBI', 1000.00; 
/* Esperado: - Indicador ya existente. */

EXEC cat.usp_IndicadorEconomico_Modificacion @id_usa, 2026, 'PBI', 26000.00;
EXEC cat.usp_IndicadorEconomico_Modificacion @id_usa, 2026, 'PBI', -500.00; 
/* Esperado: - El valor no puede ser negativo. */

EXEC cat.usp_IndicadorEconomico_Baja @id_usa, 2026, 'PBI'; -- BAJA OK

-- 6. TIPO CAMBIO
EXEC cat.usp_TipoCambio_Alta @id_moneda_usd, '2026-06-01', 1.000000;
EXEC cat.usp_TipoCambio_Alta @id_moneda_usd, '2026-06-01', 1.000000; 
/* Esperado: - Ya existe un tipo de cambio para esta moneda en esta fecha. */

EXEC cat.usp_TipoCambio_Modificacion @id_moneda_usd, '2026-06-01', 1.050000;
EXEC cat.usp_TipoCambio_Modificacion @id_moneda_usd, '2026-06-01', -1.0; 
/* Esperado: - La tasa de cambio debe ser mayor a cero. */

EXEC cat.usp_TipoCambio_Baja @id_moneda_usd, '2026-06-01'; -- BAJA OK
EXEC cat.usp_IndicadorEconomico_Baja @id_usa, 2025, 'INFLACION'; 
/* Esperado: - Indicador inexistente. */

EXEC cat.usp_TipoCambio_Baja @id_moneda_usd, '1999-01-01'; 
/* Esperado: - Tipo de cambio inexistente. */

-- 7. FERIADO
EXEC cat.usp_Feriado_Alta @id_usa, '2026-07-04', 'Independence Day';
EXEC cat.usp_Feriado_Alta @id_usa, '2026-07-04', 'Duplicado'; 
/* Esperado: - Ya existe un feriado en esa fecha para este pais. */

EXEC cat.usp_Feriado_Modificacion @id_usa, '2026-07-04', '4th of July';
EXEC cat.usp_Feriado_Modificacion @id_usa, '2026-07-04', ''; 
/* Esperado: - El nombre del feriado es obligatorio. */

EXEC cat.usp_Feriado_Baja @id_usa, '2026-07-04'; -- BAJA OK
EXEC cat.usp_Feriado_Baja @id_usa, '2026-01-01'; 
/* Esperado: - Feriado inexistente. */
GO

/* =================================================================
   BLOQUE 2: PREPARACIÓN COMPETICIÓN (SEDE Y PARTIDO)
   ================================================================= */
DECLARE @id_miami INT, @id_torneo INT, @id_fase INT, @id_sede INT;
SELECT @id_miami = id_ciudad FROM cat.Ciudad WHERE nombre = 'Miami';
SELECT @id_torneo = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @id_fase = id_fase FROM comp.Fase WHERE nombre = 'Grupos';

IF NOT EXISTS (SELECT 1 FROM comp.Sede WHERE nombre_estadio = 'Hard Rock Stadium')
    EXEC comp.usp_Sede_Alta 'Hard Rock Stadium', @id_miami, 65000, NULL, NULL;

SELECT @id_sede = id_sede FROM comp.Sede WHERE nombre_estadio = 'Hard Rock Stadium';

IF NOT EXISTS (SELECT 1 FROM comp.Partido WHERE id_torneo = @id_torneo AND nro_partido = 99)
    EXEC comp.usp_Partido_Alta @id_torneo, 99, @id_fase, NULL, @id_sede, '2026-06-15 20:00:00';
GO

/* =================================================================
   BLOQUE 3: MÓDULO DE PUBLICIDAD
   ================================================================= */
DECLARE @id_pais_usa INT, @id_moneda_usd INT, @id_idioma_en INT;
DECLARE @id_torneo INT, @id_fase INT, @id_partido_99 INT;

SELECT @id_pais_usa = id_pais FROM cat.Pais WHERE nombre = 'Estados Unidos';
SELECT @id_moneda_usd = id_moneda FROM cat.Moneda WHERE codigo_iso = 'USD';
SELECT @id_idioma_en = id_idioma FROM cat.Idioma WHERE codigo_iso = 'EN';
SELECT @id_torneo = id_torneo FROM comp.Torneo WHERE anio = 2026;
SELECT @id_fase = id_fase FROM comp.Fase WHERE nombre = 'Grupos';
SELECT @id_partido_99 = id_partido FROM comp.Partido WHERE nro_partido = 99;

-- 8. ANUNCIANTE
IF NOT EXISTS (SELECT 1 FROM pub.Anunciante WHERE nombre = 'Nike Global')
    EXEC pub.usp_Anunciante_Alta 'Nike Global', @id_pais_usa;

DECLARE @id_anunciante_nike INT;
SELECT @id_anunciante_nike = id_anunciante FROM pub.Anunciante WHERE nombre = 'Nike Global';

EXEC pub.usp_Anunciante_Alta '', 9999; 
/* Esperado: - El nombre es obligatorio. */
EXEC pub.usp_Anunciante_Modificacion @id_anunciante_nike, '', 9999; 
/* Esperado: - El nombre es obligatorio. */

EXEC pub.usp_Anunciante_Alta 'Anunciante Temp', @id_pais_usa;
DECLARE @id_anunciante_temp INT;
SELECT @id_anunciante_temp = id_anunciante FROM pub.Anunciante WHERE nombre = 'Anunciante Temp';

EXEC pub.usp_Anunciante_Modificacion @id_anunciante_temp, 'Anunciante Editado', @id_pais_usa; -- MODIFICACION OK
EXEC pub.usp_Anunciante_Baja @id_anunciante_temp; -- BAJA OK

-- 9. MARCA
EXEC pub.usp_Marca_Alta @id_anunciante_nike, 'Nike Sportswear';
EXEC pub.usp_Marca_Alta @id_anunciante_nike, 'Marca Temp';
EXEC pub.usp_Marca_Alta 9999, '';
/* Esperado: - Anunciante inexistente. - El nombre de la marca es obligatorio. */

DECLARE @id_marca_temp INT, @id_marca_nike INT;
SELECT @id_marca_temp = id_marca FROM pub.Marca WHERE nombre = 'Marca Temp';
SELECT @id_marca_nike = id_marca FROM pub.Marca WHERE nombre = 'Nike Sportswear';

EXEC pub.usp_Marca_Modificacion @id_marca_temp, @id_anunciante_nike, 'Nike Air';

DECLARE @id_marca_existente INT; 
SELECT @id_marca_existente = id_marca FROM pub.Marca WHERE nombre = 'Nike Air';

EXEC pub.usp_Marca_Modificacion @id_marca_existente, @id_anunciante_nike, 'Nike Sportswear';
/* Esperado: - Ya existe otra marca con este nombre. */

EXEC pub.usp_Marca_Baja @id_marca_existente; -- BAJA OK
EXEC pub.usp_Marca_Baja 9999;
/* Esperado: - Marca inexistente. */

-- Baja Error Anunciante
EXEC pub.usp_Anunciante_Baja @id_anunciante_nike; 
/* Esperado: - Existen marcas asociadas a este anunciante. */

-- 10. AGENCIA
EXEC pub.usp_Agencia_Alta 'Wieden+Kennedy';
EXEC pub.usp_Agencia_Alta 'Agencia Temp';
EXEC pub.usp_Agencia_Alta 'Wieden+Kennedy';
/* Esperado: - Ya existe una agencia con ese nombre. */

DECLARE @id_agencia_temp INT, @id_agencia_wk INT;
SELECT @id_agencia_temp = id_agencia FROM pub.Agencia WHERE nombre = 'Agencia Temp';
SELECT @id_agencia_wk = id_agencia FROM pub.Agencia WHERE nombre = 'Wieden+Kennedy';

EXEC pub.usp_Agencia_Modificacion @id_agencia_temp, 'Wieden+Kennedy'; 
/* Esperado: - Ya existe otra agencia con ese nombre. */
EXEC pub.usp_Agencia_Baja @id_agencia_wk; 
/* Esperado: - Existen campanias gestionadas por esta agencia. */

EXEC pub.usp_Agencia_Modificacion @id_agencia_temp, 'Agencia Borrar';
EXEC pub.usp_Agencia_Baja @id_agencia_temp; -- BAJA OK

-- 11. CAMPANIA Y CAMPANIA PAIS
EXEC pub.usp_Campania_Alta @id_marca_nike, @id_agencia_wk, 'Just Do It 2026', '2026-01-01', '2026-12-31', 'Campania Global Mundial';
EXEC pub.usp_Campania_Alta 9999, @id_agencia_wk, 'Error Camp', '2026-12-31', '2026-01-01', '';
/* Esperado: - Marca inexistente. - La fecha de fin no puede ser anterior a la de inicio. */

DECLARE @id_campania_just INT;
SELECT @id_campania_just = id_campania FROM pub.Campania WHERE titulo = 'Just Do It 2026';

EXEC pub.usp_Campania_Modificacion @id_campania_just, @id_marca_nike, @id_agencia_wk, 'Just Do It 2026', '2026-01-01', '2026-12-31', 'Campania Actualizada';
EXEC pub.usp_Campania_Modificacion @id_campania_just, @id_marca_nike, @id_agencia_wk, 'Fallo', '2026-12-31', '2026-01-01', 'Fechas invertidas'; 
/* Esperado: - La fecha de fin no puede ser anterior a la de inicio. */

EXEC pub.usp_CampaniaPais_Alta @id_campania_just, @id_pais_usa;
EXEC pub.usp_CampaniaPais_Alta @id_campania_just, @id_pais_usa;
/* Esperado: - Esta campania ya esta dirigida a este pais. */

EXEC pub.usp_Campania_Baja @id_campania_just;
/* Esperado: - La campania tiene mercados objetivo asociados. */

EXEC pub.usp_CampaniaPais_Baja 9999, @id_pais_usa; 
/* Esperado: - Asignacion de campania a pais inexistente. */

EXEC pub.usp_CampaniaPais_Baja @id_campania_just, @id_pais_usa; -- BAJA OK
EXEC pub.usp_CampaniaPais_Alta @id_campania_just, @id_pais_usa; -- Reasociamos para integridad

EXEC pub.usp_Campania_Alta @id_marca_nike, @id_agencia_wk, 'Campania Borrar', '2026-01-01', '2026-12-31', 'Temp';
DECLARE @id_camp_borrar INT; SELECT @id_camp_borrar = id_campania FROM pub.Campania WHERE titulo = 'Campania Borrar';
EXEC pub.usp_Campania_Baja @id_camp_borrar; -- BAJA OK

-- Bajas Error por Clave Foránea de Marca y Agencia
EXEC pub.usp_Marca_Baja @id_marca_nike; 
/* Esperado: - Existen campanias asociadas a esta marca. */
EXEC pub.usp_Agencia_Baja @id_agencia_wk; 
/* Esperado: - Existen campanias gestionadas por esta agencia. */

-- 12. PIEZA PUBLICITARIA
EXEC pub.usp_PiezaPublicitaria_Alta @id_campania_just, @id_idioma_en, @id_pais_usa, 'Spot Nike TV USA', 'http://nike.com/spot1';
EXEC pub.usp_PiezaPublicitaria_Alta @id_campania_just, 9999, @id_pais_usa, '', 'http://err.com';
/* Esperado: - Idioma inexistente. - El titulo de la pieza es obligatorio. */

DECLARE @id_pieza_spot INT;
SELECT @id_pieza_spot = id_pieza_publicitaria FROM pub.PiezaPublicitaria WHERE titulo = 'Spot Nike TV USA';

EXEC pub.usp_PiezaPublicitaria_Modificacion @id_pieza_spot, @id_campania_just, @id_idioma_en, @id_pais_usa, 'Spot Nike TV USA', 'http://nike.com/spot-new';
EXEC pub.usp_PiezaPublicitaria_Modificacion @id_pieza_spot, @id_campania_just, 1, 1, '', 'http://fail.com'; 
/* Esperado: - El titulo de la pieza es obligatorio. */

EXEC pub.usp_PiezaPublicitaria_Alta @id_campania_just, @id_idioma_en, @id_pais_usa, 'Pieza Borrar', 'http://nike.com/borrar';
DECLARE @id_pieza_borrar INT; SELECT @id_pieza_borrar = id_pieza_publicitaria FROM pub.PiezaPublicitaria WHERE titulo = 'Pieza Borrar';
EXEC pub.usp_PiezaPublicitaria_Baja @id_pieza_borrar; -- BAJA OK

EXEC pub.usp_PiezaPublicitaria_Baja 9999;
/* Esperado: - Pieza inexistente. */

-- Baja Error de Idioma enlazado
EXEC cat.usp_Idioma_Baja @id_idioma_en; 
/* Esperado: - Existen piezas publicitarias en este idioma. (Spot Nike TV USA) */

-- 13. FRANJA HORARIA
EXEC pub.usp_FranjaHoraria_Alta 'Prime Time Noche', '19:00', '23:59', 1;
EXEC pub.usp_FranjaHoraria_Alta 'Madrugada Temp', '00:00', '06:00', 0;
EXEC pub.usp_FranjaHoraria_Alta 'Cruce Noche', '22:00', '02:00', 1;

DECLARE @id_franja_prime INT, @id_franja_temp INT;
SELECT @id_franja_prime = id_franja_horaria FROM pub.FranjaHoraria WHERE nombre = 'Prime Time Noche';
SELECT @id_franja_temp = id_franja_horaria FROM pub.FranjaHoraria WHERE nombre = 'Madrugada Temp';

EXEC pub.usp_FranjaHoraria_Modificacion @id_franja_temp, 'Madrugada Borrar', '01:00', '05:00', 0;
EXEC pub.usp_FranjaHoraria_Modificacion @id_franja_prime, 'Noche', '23:00', '19:00', 1; 

EXEC pub.usp_FranjaHoraria_Baja @id_franja_temp; -- BAJA OK

-- 14. TARIFA
EXEC pub.usp_Tarifa_Alta @id_torneo, @id_fase, @id_franja_prime, 50000.00, @id_moneda_usd;
EXEC pub.usp_Tarifa_Alta @id_torneo, @id_fase, @id_franja_prime, -100, @id_moneda_usd;
/* Esperado: - El monto no puede ser negativo. - Ya existe una tarifa para esta combinacion. */

DECLARE @id_tarifa_55 INT;
SELECT @id_tarifa_55 = id_tarifa FROM pub.Tarifa WHERE monto = 50000.00;

EXEC pub.usp_Tarifa_Modificacion @id_tarifa_55, 55000.00, @id_moneda_usd;
EXEC pub.usp_Tarifa_Modificacion @id_tarifa_55, -1000.00, @id_moneda_usd; 
/* Esperado: - El monto no puede ser negativo. */

DECLARE @id_fase_octavos INT; SELECT @id_fase_octavos = id_fase FROM comp.Fase WHERE nombre = 'Octavos';
EXEC pub.usp_Tarifa_Alta @id_torneo, @id_fase_octavos, @id_franja_prime, 60000.00, @id_moneda_usd;
DECLARE @id_tarifa_borrar INT; SELECT @id_tarifa_borrar = id_tarifa FROM pub.Tarifa WHERE monto = 60000.00;

EXEC pub.usp_Tarifa_Baja @id_tarifa_borrar; -- BAJA OK
EXEC pub.usp_Tarifa_Baja 9999;
/* Esperado: - Tarifa inexistente. */

-- Baja Franja Error por FK a Tarifa
EXEC pub.usp_FranjaHoraria_Baja @id_franja_prime; 
/* Esperado: - Existen tarifas asociadas a esta franja. */

-- 15. EXHIBICION PUBLICITARIA
EXEC pub.usp_ExhibicionPublicitaria_Alta @id_partido_99, 1, @id_pieza_spot, @id_tarifa_55, 55000.00, @id_moneda_usd, 90.5, 'PROPUESTA';
EXEC pub.usp_ExhibicionPublicitaria_Alta @id_partido_99, 5, @id_pieza_spot, @id_tarifa_55, -100, @id_moneda_usd, 0, 'INVALIDO';
/* Esperado: - Nro de espacio entre 1 y 4. - Monto no negativo. - Estado invalido. */
EXEC pub.usp_ExhibicionPublicitaria_Alta @id_partido_99, 1, @id_pieza_spot, @id_tarifa_55, 55000.00, @id_moneda_usd, 90.5, 'PROPUESTA';
/* Esperado: - El espacio publicitario ya esta ocupado. */

DECLARE @id_exhibicion INT;
SELECT @id_exhibicion = id_exhibicion_publicitaria FROM pub.ExhibicionPublicitaria WHERE id_partido = @id_partido_99 AND nro_espacio = 1;

EXEC pub.usp_ExhibicionPublicitaria_Modificacion @id_exhibicion, 'EXHIBIDA';
EXEC pub.usp_ExhibicionPublicitaria_Modificacion @id_exhibicion, 'ESTADO_FALSO'; 
/* Esperado: - Estado de exhibicion invalido. */

EXEC pub.usp_ExhibicionPublicitaria_Baja @id_exhibicion; -- BAJA OK
EXEC pub.usp_ExhibicionPublicitaria_Baja 99999; 
/* Esperado: - Exhibicion inexistente. */

-- Creamos de nuevo para probar la eliminación correcta
EXEC pub.usp_ExhibicionPublicitaria_Alta @id_partido_99, 2, @id_pieza_spot, @id_tarifa_55, 55000.00, @id_moneda_usd, 90.5, 'PROPUESTA';
SELECT @id_exhibicion = id_exhibicion_publicitaria FROM pub.ExhibicionPublicitaria WHERE id_partido = @id_partido_99 AND nro_espacio = 2;
EXEC pub.usp_ExhibicionPublicitaria_Baja @id_exhibicion;
GO

EXEC pub.usp_Tarifa_Baja @id_tarifa_55; 
/* Esperado: - La tarifa fue aplicada a exhibiciones historicas. */

/* =================================================================
   BLOQUE 4: MÓDULO DE IMPORTACIÓN
   ================================================================= */
DECLARE @id_log INT, @id_error INT;

-- 16. LOG Y ERROR DE IMPORTACION
EXEC imp.usp_LogImportacion_Alta 'fifa_sedes.csv', 'FIFA Scraper', '2026-06-01 10:00:00', '2026-06-01 10:05:00', 50, 49, 1;
SELECT @id_log = id_log_importacion FROM imp.LogImportacion WHERE nombre_archivo = 'fifa_sedes.csv';

EXEC imp.usp_ErrorImportacion_Alta @id_log, 14, 'Dato Corrupto Sede', 'La capacidad no es un número.';
SELECT @id_error = id_error_importacion FROM imp.ErrorImportacion WHERE id_log_importacion = @id_log;

-- Modificaciones OK y Error
EXEC imp.usp_ErrorImportacion_Modificacion @id_error, 'La capacidad superó el límite int.';
EXEC imp.usp_ErrorImportacion_Modificacion @id_error, ''; 
/* Esperado: - El mensaje de error es obligatorio. */

-- Restricciones de Borrado en Cascada
EXEC imp.usp_LogImportacion_Baja @id_log; 
/* Esperado: - Existen errores asociados. Borrelos previamente. */

EXEC imp.usp_ErrorImportacion_Baja @id_error; -- BAJA OK (Hijo)
EXEC imp.usp_LogImportacion_Baja @id_log; -- BAJA OK (Padre)

-- Validaciones temporales de fecha 
EXEC imp.usp_LogImportacion_Alta 'temp.csv', 'Test', '2026-01-01', '2026-01-02', 1, 1, 0;
DECLARE @id_log_temp INT; SELECT @id_log_temp = id_log_importacion FROM imp.LogImportacion WHERE nombre_archivo = 'temp.csv';

EXEC imp.usp_LogImportacion_Modificacion @id_log_temp, '2025-01-01', 1, 1, 0; 
/* Esperado: - La fecha de fin no puede ser anterior a la de inicio. */

EXEC imp.usp_ErrorImportacion_Baja 99999; 
/* Esperado: - Registro de error inexistente. */
EXEC imp.usp_LogImportacion_Baja @id_log_temp; -- BAJA OK
GO
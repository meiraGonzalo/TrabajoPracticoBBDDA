/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 6 - Verificacion de lo cargado por las importaciones
 Grupo 02 - Comision 02-5600
 Objetivo: ver, solo con SELECT, que quedo en cada tabla despues de correr las importaciones
           (catalogos y publicidad, sedes, partidos, plantillas y arbitros). No modifica nada.
=====================================================================
*/
USE MundialDB;
GO
SET NOCOUNT ON;


-- 0. Ejecutar sp importacion
EXEC imp.usp_ImportarMonedas_CSV         'C:\Mundial2026_Datos\monedas.csv';
GO
EXEC imp.usp_ImportarIdiomas_CSV         'C:\Mundial2026_Datos\idiomas.csv';
GO
EXEC imp.usp_ImportarFranjasHorarias_CSV 'C:\Mundial2026_Datos\franjas_comerciales.csv';
GO
/* 2) Paises (necesitan las monedas), ciudades y equivalencias */
EXEC imp.usp_ImportarPaises_CSV          'C:\Mundial2026_Datos\paises.csv';
GO
EXEC imp.usp_ImportarCiudades_CSV        'C:\Mundial2026_Datos\ciudades.csv';
GO
EXEC imp.usp_Importar_EquivalenciasPais  'C:\MundialDB\equivalencias_paises_2026.csv';
GO
/* 3) Datos fijos que no salen de ningun archivo: torneo 2026 y posiciones */
IF NOT EXISTS (SELECT 1 FROM comp.Torneo WHERE anio = 2026)
    EXEC comp.usp_Torneo_Alta 'Copa Mundial de la FIFA 2026', 2026, '2026-06-11', '2026-07-19';
GO
DECLARE @t int; SELECT @t = id_torneo FROM comp.Torneo WHERE anio = 2026;
IF NOT EXISTS (SELECT 1 FROM comp.ParametroReglamento WHERE id_torneo = @t AND clave = 'MIN_CONVOCADOS')
    EXEC comp.usp_ParametroReglamento_Alta @t, 'MIN_CONVOCADOS', 23, NULL;
IF NOT EXISTS (SELECT 1 FROM comp.ParametroReglamento WHERE id_torneo = @t AND clave = 'MAX_CONVOCADOS')
    EXEC comp.usp_ParametroReglamento_Alta @t, 'MAX_CONVOCADOS', 26, NULL;
GO
IF NOT EXISTS (SELECT 1 FROM comp.Posicion WHERE nombre = 'Arquero')       EXEC comp.usp_Posicion_Alta 'Arquero';
IF NOT EXISTS (SELECT 1 FROM comp.Posicion WHERE nombre = 'Defensor')      EXEC comp.usp_Posicion_Alta 'Defensor';
IF NOT EXISTS (SELECT 1 FROM comp.Posicion WHERE nombre = 'Mediocampista') EXEC comp.usp_Posicion_Alta 'Mediocampista';
IF NOT EXISTS (SELECT 1 FROM comp.Posicion WHERE nombre = 'Delantero')     EXEC comp.usp_Posicion_Alta 'Delantero';
GO
/* 4) Economia y precios (necesitan paises, monedas, franjas y el torneo) */
EXEC imp.usp_ImportarTipoCambio_CSV          'C:\Mundial2026_Datos\tipos_cambio_frankfurter.csv';
GO
EXEC imp.usp_ImportarIndicadorEconomico_JSON 'C:\Mundial2026_Datos\indicadores_bm.json';
GO
EXEC imp.usp_ImportarFeriados_JSON           'C:\Mundial2026_Datos\feriados_nagerdate.json';
GO
EXEC imp.usp_ImportarTarifas_CSV             'C:\Mundial2026_Datos\tarifas.csv';
GO
/* 5) Scraping del Mundial */
EXEC imp.usp_Importar_Sedes      'C:\MundialDB\sedes_2026.csv';
GO
EXEC imp.usp_Importar_Partidos   'C:\MundialDB\partidos_2026.csv', 2026;
GO
EXEC imp.usp_Importar_Plantillas 'C:\MundialDB\plantillas_2026.csv', 2026;
GO
EXEC imp.usp_ImportarArbitros    'C:\MundialDB\arbitros.xml';
GO
/* 6) Publicidad (necesita paises e idiomas) */
EXEC imp.usp_ImportarPublicidad_CSV 'C:\Mundial2026_Datos\dossier_publicidad.csv';
GO




/* =================================================================
   1. RESUMEN: filas de TODAS las tablas de la base
   ================================================================= */
SELECT s.name AS esquema, t.name AS tabla, SUM(p.row_count) AS filas
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.dm_db_partition_stats p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
GROUP BY s.name, t.name
ORDER BY s.name, t.name;
GO

/* =================================================================
   2. IMPORTACIONES: registro, errores y equivalencias
   ================================================================= */
SELECT * FROM imp.LogImportacion ORDER BY id_log_importacion DESC;

-- Errores por importacion (cuantos y de que archivo)
SELECT l.id_log_importacion, l.nombre_archivo, COUNT(e.id_error_importacion) AS errores
FROM imp.LogImportacion l
LEFT JOIN imp.ErrorImportacion e ON e.id_log_importacion = l.id_log_importacion
GROUP BY l.id_log_importacion, l.nombre_archivo
ORDER BY l.id_log_importacion DESC;

-- Ultimos errores
SELECT TOP 50 e.id_log_importacion, e.nro_linea, e.dato_original, e.mensaje
FROM imp.ErrorImportacion e
ORDER BY e.id_log_importacion DESC, e.nro_linea;

-- Equivalencias de paises (nombre del archivo -> pais del catalogo)
SELECT eq.nombre_externo, pa.nombre AS pais_catalogo
FROM imp.EquivalenciaPais eq
JOIN cat.Pais pa ON pa.id_pais = eq.id_pais
ORDER BY eq.nombre_externo;
GO

/* =================================================================
   3. CATALOGOS (monedas, idiomas, paises, ciudades)
   ================================================================= */
SELECT TOP 30 * FROM cat.Moneda;
SELECT TOP 30 * FROM cat.Idioma;

SELECT p.id_pais, p.nombre, p.confederacion, p.huso_horario, p.id_moneda
FROM cat.Pais p ORDER BY p.nombre;

SELECT c.id_ciudad, c.nombre AS ciudad, pa.nombre AS pais, c.huso_horario
FROM cat.Ciudad c JOIN cat.Pais pa ON pa.id_pais = c.id_pais
ORDER BY pa.nombre, c.nombre;
GO

/* =================================================================
   4. ECONOMIA (tipo de cambio, indicadores, feriados)
   ================================================================= */
SELECT TOP 30 * FROM cat.TipoCambio ORDER BY fecha DESC;

SELECT TOP 30 pa.nombre AS pais, i.anio, i.codigo_indicador, i.valor
FROM cat.IndicadorEconomico i JOIN cat.Pais pa ON pa.id_pais = i.id_pais
ORDER BY pa.nombre, i.anio DESC;

SELECT TOP 30 pa.nombre AS pais, f.fecha, f.nombre AS feriado
FROM cat.Feriado f JOIN cat.Pais pa ON pa.id_pais = f.id_pais
ORDER BY f.fecha;
GO

/* =================================================================
   5. TORNEO, SEDES, SELECCIONES Y PARTIDOS
      (si quedaron torneos de los tests, como 2042 o 2043, aparecen aca tambien)
   ================================================================= */
SELECT * FROM comp.Torneo ORDER BY anio;

SELECT s.id_sede, s.nombre_estadio, c.nombre AS ciudad, s.capacidad, s.latitud, s.longitud
FROM comp.Sede s JOIN cat.Ciudad c ON c.id_ciudad = s.id_ciudad
ORDER BY c.nombre, s.nombre_estadio;

SELECT t.anio, pa.nombre AS seleccion, g.letra AS grupo,
       (SELECT COUNT(*) FROM comp.Convocado cv WHERE cv.id_seleccion = s.id_seleccion) AS convocados
FROM comp.Seleccion s
JOIN comp.Torneo t ON t.id_torneo = s.id_torneo
JOIN cat.Pais pa   ON pa.id_pais = s.id_pais
LEFT JOIN comp.Grupo g ON g.id_grupo = s.id_grupo
ORDER BY t.anio, g.letra, pa.nombre;

SELECT t.anio, p.nro_partido, f.nombre AS fase, g.letra AS grupo, se.nombre_estadio AS estadio,
       p.fecha_hora_local, p.estado,
       pl.nombre AS local, psl.goles AS goles_local,
       pv.nombre AS visitante, psv.goles AS goles_visitante
FROM comp.Partido p
JOIN comp.Torneo t ON t.id_torneo = p.id_torneo
JOIN comp.Fase f   ON f.id_fase = p.id_fase
JOIN comp.Sede se  ON se.id_sede = p.id_sede
LEFT JOIN comp.Grupo g ON g.id_grupo = p.id_grupo
JOIN comp.PartidoSeleccion psl ON psl.id_partido = p.id_partido AND psl.condicion = 'L'
JOIN comp.Seleccion sl ON sl.id_seleccion = psl.id_seleccion
JOIN cat.Pais pl       ON pl.id_pais = sl.id_pais
JOIN comp.PartidoSeleccion psv ON psv.id_partido = p.id_partido AND psv.condicion = 'V'
JOIN comp.Seleccion sv ON sv.id_seleccion = psv.id_seleccion
JOIN cat.Pais pv       ON pv.id_pais = sv.id_pais
ORDER BY t.anio, p.nro_partido;
GO

/* =================================================================
   6. PLANTILLAS Y CLUBES
   ================================================================= */
SELECT pa.nombre AS seleccion, c.dorsal, pe.nombre, pe.apellido, cl.nombre AS club
FROM comp.Convocado c
JOIN comp.Persona pe  ON pe.id_persona = c.id_jugador
JOIN comp.Seleccion s ON s.id_seleccion = c.id_seleccion
JOIN cat.Pais pa      ON pa.id_pais = s.id_pais
LEFT JOIN comp.Club cl ON cl.id_club = c.id_club
ORDER BY pa.nombre, c.dorsal;

SELECT cl.id_club, cl.nombre AS club, pa.nombre AS pais
FROM comp.Club cl JOIN cat.Pais pa ON pa.id_pais = cl.id_pais
ORDER BY pa.nombre, cl.nombre;
GO

/* =================================================================
   7. ARBITROS
   ================================================================= */
SELECT pe.id_persona, pe.nombre, pe.apellido, pa.nombre AS pais, a.categoria
FROM disc.Arbitro a
JOIN comp.Persona pe ON pe.id_persona = a.id_arbitro
JOIN cat.Pais pa     ON pa.id_pais = pe.id_pais_nacionalidad
ORDER BY pa.nombre, pe.apellido;
GO

/* =================================================================
   8. PUBLICIDAD
   ================================================================= */
SELECT TOP 30 * FROM pub.Anunciante;
SELECT TOP 30 * FROM pub.Marca;
SELECT TOP 30 * FROM pub.Agencia;
SELECT TOP 30 * FROM pub.Campania;
SELECT TOP 30 * FROM pub.CampaniaPais;
SELECT TOP 30 * FROM pub.PiezaPublicitaria;
SELECT TOP 30 * FROM pub.FranjaHoraria;
SELECT TOP 30 * FROM pub.Tarifa;
GO



SELECT pa.nombre                        AS seleccion,
       c.dorsal,
       pe.apellido,
       pe.nombre,
       po.nombre                        AS posicion,
       ISNULL(cl.nombre, 'Sin club')    AS club,
       pc.nombre                        AS pais_club
FROM comp.Convocado c
JOIN comp.Seleccion s   ON s.id_seleccion = c.id_seleccion
JOIN comp.Torneo t      ON t.id_torneo = s.id_torneo
JOIN cat.Pais pa        ON pa.id_pais = s.id_pais
JOIN comp.Persona pe    ON pe.id_persona = c.id_jugador
JOIN comp.Jugador j     ON j.id_jugador = c.id_jugador
JOIN comp.Posicion po   ON po.id_posicion = j.id_posicion_habitual
LEFT JOIN comp.Club cl  ON cl.id_club = c.id_club
LEFT JOIN cat.Pais pc   ON pc.id_pais = cl.id_pais
WHERE t.anio = 2026
  AND c.fecha_baja IS NULL              -- solo los convocados activos
ORDER BY pa.nombre, c.dorsal;
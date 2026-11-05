/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 7 - Reportes
 Grupo 02 - Comision 02-5600
 Objetivo: Generar los procedimientos almacenados requeridos para la 
           Entrega 7 (Reportes).
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
   1. REPORTE: MATRIZ DE PRIME TIME
   Genera una tabla cruzada que muestra para cada partido si su horario 
   local cae en "Prime Time" en los distintos países registrados.
   ===================================================================== */
CREATE OR ALTER PROCEDURE pub.usp_Reporte_MatrizPrimeTime
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @cols NVARCHAR(MAX);
    DECLARE @query NVARCHAR(MAX);

    -- Concatenar nombres de países dinámicamente para las columnas del PIVOT
    SELECT @cols = STUFF((SELECT DISTINCT ',' + QUOTENAME(nombre)
                          FROM cat.Pais
                          FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, '');

    IF @cols IS NULL 
    BEGIN
        PRINT 'No hay países registrados para generar la matriz.';
        RETURN;
    END

    -- Armar consulta dinámica PIVOT empleando la función ufn_ObtenerHoraLocalYFranja
    SET @query = N'
    WITH PrimeTimeData AS (
        SELECT 
            p.nro_partido,
            pa.nombre AS Pais,
            CASE WHEN fh.id_franja_horaria IS NOT NULL THEN ''SI'' ELSE ''NO'' END AS EsPrimeTime
        FROM comp.Partido p
        CROSS JOIN cat.Pais pa
        CROSS APPLY pub.ufn_ObtenerHoraLocalYFranja(p.fecha_hora_utc, pa.huso_horario) hl
        LEFT JOIN pub.FranjaHoraria fh ON fh.es_prime_time = 1 AND
            (
                (fh.hora_desde <= fh.hora_hasta AND hl.hora_local >= fh.hora_desde AND hl.hora_local <= fh.hora_hasta)
                OR
                (fh.hora_desde > fh.hora_hasta AND (hl.hora_local >= fh.hora_desde OR hl.hora_local <= fh.hora_hasta))
            )
    )
    SELECT nro_partido AS NroPartido, ' + @cols + N'
    FROM PrimeTimeData
    PIVOT (
        MAX(EsPrimeTime)
        FOR Pais IN (' + @cols + N')
    ) pvt
    ORDER BY NroPartido;';

    EXEC sp_executesql @query;
END
GO


/* =====================================================================
   2. REPORTE: OCUPACIÓN PUBLICITARIA POR SEDE Y PARTIDO (XML)
   Muestra los 4 espacios publicitarios exhibidos por partido, con los 
   ingresos generados y el anunciante. (Retorna XML)
   ===================================================================== */
CREATE OR ALTER PROCEDURE pub.usp_Reporte_OcupacionPublicitaria
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        s.nombre_estadio AS '@Estadio',
        c.nombre AS '@Ciudad',
        p.nro_partido AS '@NroPartido',
        p.fecha_hora_utc AS '@FechaUTC',
        (
            SELECT 
                ep.nro_espacio AS 'Espacio',
                anu.nombre AS 'Anunciante',
                m.nombre AS 'Marca',
                camp.titulo AS 'Campania',
                pz.titulo AS 'PiezaPublicitaria',
                ep.monto_aplicado AS 'IngresoGenerado',
                mon.codigo_iso AS 'Moneda'
            FROM pub.ExhibicionPublicitaria ep
            INNER JOIN pub.PiezaPublicitaria pz ON ep.id_pieza_publicitaria = pz.id_pieza_publicitaria
            INNER JOIN pub.Campania camp ON pz.id_campania = camp.id_campania
            INNER JOIN pub.Marca m ON camp.id_marca = m.id_marca
            INNER JOIN pub.Anunciante anu ON m.id_anunciante = anu.id_anunciante
            INNER JOIN cat.Moneda mon ON ep.id_moneda = mon.id_moneda
            WHERE ep.id_partido = p.id_partido
              -- AND ep.estado = 'EXHIBIDA' -- Se puede descomentar para filtrar solo las confirmadas
            ORDER BY ep.nro_espacio
            FOR XML PATH('Exhibicion'), TYPE
        ) AS 'Exhibiciones'
    FROM comp.Partido p
    INNER JOIN comp.Sede s ON p.id_sede = s.id_sede
    INNER JOIN cat.Ciudad c ON s.id_ciudad = c.id_ciudad
    WHERE EXISTS (SELECT 1 FROM pub.ExhibicionPublicitaria ep2 WHERE ep2.id_partido = p.id_partido)
    ORDER BY p.fecha_hora_utc
    FOR XML PATH('Partido'), ROOT('OcupacionPublicitariaPorSede');
END
GO


/* =====================================================================
   3. REPORTE: INGRESOS GLOBALES POR PUBLICIDAD (TABULAR)
   Resume el total de ingresos generados convertidos a USD por 
   cada anunciante y campaña publicitaria.
   ===================================================================== */
CREATE OR ALTER PROCEDURE pub.usp_Reporte_IngresosPublicidadGlobal
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_usd INT;
    SELECT @id_usd = id_moneda FROM cat.Moneda WHERE codigo_iso = 'USD';

    SELECT 
        anu.nombre AS Anunciante,
        m.nombre AS Marca,
        camp.titulo AS Campania,
        ISNULL(ag.nombre, 'Sin Agencia') AS Agencia,
        COUNT(ep.id_exhibicion_publicitaria) AS TotalExhibiciones,
        SUM(cat.ufn_ConvertirMoneda(ep.monto_aplicado, ep.id_moneda, @id_usd, CAST(p.fecha_hora_utc AS DATE))) AS TotalIngresoUSD
    FROM pub.ExhibicionPublicitaria ep
    INNER JOIN pub.PiezaPublicitaria pz ON ep.id_pieza_publicitaria = pz.id_pieza_publicitaria
    INNER JOIN pub.Campania camp ON pz.id_campania = camp.id_campania
    LEFT JOIN pub.Agencia ag ON camp.id_agencia = ag.id_agencia
    INNER JOIN pub.Marca m ON camp.id_marca = m.id_marca
    INNER JOIN pub.Anunciante anu ON m.id_anunciante = anu.id_anunciante
    INNER JOIN comp.Partido p ON ep.id_partido = p.id_partido
    -- WHERE ep.estado = 'EXHIBIDA' -- Se puede descomentar en producción
    GROUP BY anu.nombre, m.nombre, camp.titulo, ag.nombre
    ORDER BY TotalIngresoUSD DESC;
END
GO


/* =====================================================================
   4. REPORTE: LOG DE IMPORTACIONES Y ERRORES (XML)
   Retorna en XML el resumen de cada proceso de importación y el 
   detalle anidado de los errores ocurridos.
   ===================================================================== */
CREATE OR ALTER PROCEDURE imp.usp_Reporte_LogImportacion
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        l.id_log_importacion AS '@IDLog',
        l.nombre_archivo AS '@Archivo',
        l.fuente AS '@Fuente',
        l.fecha_inicio AS '@FechaInicio',
        l.fecha_fin AS '@FechaFin',
        l.filas_leidas AS '@FilasLeidas',
        l.filas_ok AS '@FilasOK',
        l.filas_error AS '@FilasError',
        (
            SELECT 
                e.nro_linea AS '@NroLinea',
                e.mensaje AS 'MensajeError',
                e.dato_original AS 'DatoOriginal'
            FROM imp.ErrorImportacion e
            WHERE e.id_log_importacion = l.id_log_importacion
            ORDER BY e.nro_linea
            FOR XML PATH('Error'), TYPE
        ) AS 'Errores'
    FROM imp.LogImportacion l
    ORDER BY l.fecha_inicio DESC
    FOR XML PATH('LogImportacion'), ROOT('ReporteImportaciones');
END
GO


/* =====================================================================
   5. REPORTE: CONTEXTO ECONÓMICO Y FERIADOS (XML)
   Combina los datos económicos y feriados por país (Mercados Destino).
   ===================================================================== */
CREATE OR ALTER PROCEDURE cat.usp_Reporte_ContextoEconomicoFeriados
    @anio SMALLINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        p.nombre AS '@Pais',
        p.confederacion AS '@Confederacion',
        ISNULL(m.codigo_iso, 'N/A') AS '@Moneda',
        (
            SELECT TOP 1 ie.valor 
            FROM cat.IndicadorEconomico ie 
            WHERE ie.id_pais = p.id_pais AND ie.anio = @anio
            ORDER BY ie.codigo_indicador
        ) AS 'IndicadorEconomico',
        (
            SELECT 
                f.fecha AS '@Fecha',
                f.nombre AS 'NombreFeriado'
            FROM cat.Feriado f
            WHERE f.id_pais = p.id_pais AND YEAR(f.fecha) = @anio
            ORDER BY f.fecha
            FOR XML PATH('Feriado'), TYPE
        ) AS 'Feriados'
    FROM cat.Pais p
    LEFT JOIN cat.Moneda m ON p.id_moneda = m.id_moneda
    ORDER BY p.nombre
    FOR XML PATH('ContextoPais'), ROOT('ReporteContextoEconomicoFeriados');
END
GO


/* =====================================================================
   TESTING Y LLAMADAS DE PRUEBA
   ===================================================================== */
/*
-- 1. Matriz Prime Time
EXEC pub.usp_Reporte_MatrizPrimeTime;

-- 2. Ocupacion Publicitaria por Sede (XML)
EXEC pub.usp_Reporte_OcupacionPublicitaria;

-- 3. Ingresos Globales por Publicidad
EXEC pub.usp_Reporte_IngresosPublicidadGlobal;

-- 4. Logs de Importacion y Errores (XML)
EXEC imp.usp_Reporte_LogImportacion;

-- 5. Contexto Económico y Feriados del 2026 (XML)
EXEC cat.usp_Reporte_ContextoEconomicoFeriados @anio = 2026;
*/

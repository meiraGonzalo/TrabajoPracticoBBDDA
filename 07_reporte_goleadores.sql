/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 6 - Script 06_importacion_comun: objetos auxiliares para las importaciones
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 05/11/2026
 Objetivo: reporte de goleadores
 Orden: 00 -> 01 -> 02 -> 03 -> 06 (importaciones) -> este script
=====================================================================
*/

USE MundialDB;
GO

-- Tres tablas: goleadores del torneo, por seleccion y por fase.
  
CREATE OR ALTER PROCEDURE disc.usp_Reporte_Goleadores
    @anio      smallint,
    @seleccion varchar(100) = NULL,
    @fase      varchar(30)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @err nvarchar(2000), @id_torneo int, @id_seleccion int, @id_fase int;
    SET @err = '';

    -- Validaciones
    SELECT @id_torneo = id_torneo FROM comp.Torneo WHERE anio = @anio;
    IF @id_torneo IS NULL
        SET @err = @err + ' - No existe el torneo del año ' + ISNULL(CAST(@anio AS varchar(4)), 'vacio') + '.';

    IF @seleccion IS NOT NULL
    BEGIN
        SELECT @id_seleccion = s.id_seleccion
        FROM comp.Seleccion s
        JOIN cat.Pais pa ON pa.id_pais = s.id_pais
        WHERE s.id_torneo = @id_torneo AND pa.nombre = @seleccion;
        IF @id_seleccion IS NULL
            SET @err = @err + ' - La seleccion ' + @seleccion + ' no participa del torneo.';
    END

    IF @fase IS NOT NULL
    BEGIN
        SELECT @id_fase = id_fase FROM comp.Fase WHERE nombre = @fase;
        IF @id_fase IS NULL
            SET @err = @err + ' - No existe la fase ' + @fase + '.';
    END

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Reporte_Goleadores:' + @err;
        THROW 51001, @err, 1;
    END

    -- Paso 1: un registro por gol valido
    SELECT pe.id_persona, pe.apellido, pe.nombre, pa.nombre AS seleccion,
           f.nombre AS fase, f.orden AS orden_fase
    INTO #goles
    FROM disc.Gol g
    JOIN disc.TipoGol tg         ON tg.id_tipo_gol = g.id_tipo_gol
    JOIN comp.Periodo pr         ON pr.id_periodo = g.id_periodo
    JOIN comp.Alineacion a       ON a.id_alineacion = g.id_alineacion_autor
    JOIN comp.Convocado c        ON c.id_convocado = a.id_convocado
    JOIN comp.Persona pe         ON pe.id_persona = c.id_jugador
    JOIN comp.Seleccion s        ON s.id_seleccion = c.id_seleccion
    JOIN cat.Pais pa             ON pa.id_pais = s.id_pais
    JOIN comp.PartidoSeleccion ps ON ps.id_partido_seleccion = a.id_partido_seleccion
    JOIN comp.Partido p          ON p.id_partido = ps.id_partido
    JOIN comp.Fase f             ON f.id_fase = p.id_fase
    WHERE p.id_torneo = @id_torneo
      AND tg.nombre <> 'En contra'
      AND pr.nombre <> 'Definicion por penales'
      AND (@id_seleccion IS NULL OR s.id_seleccion = @id_seleccion)
      AND (@id_fase IS NULL OR p.id_fase = @id_fase);

    -- Tabla 1: goleadores del torneo
    SELECT DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS puesto,
           apellido, nombre, seleccion, COUNT(*) AS goles
    FROM #goles
    GROUP BY id_persona, apellido, nombre, seleccion
    ORDER BY puesto, apellido, nombre;

    -- Tabla 2: goleadores de cada seleccion
    SELECT seleccion,
           DENSE_RANK() OVER (PARTITION BY seleccion ORDER BY COUNT(*) DESC) AS puesto,
           apellido, nombre, COUNT(*) AS goles
    FROM #goles
    GROUP BY seleccion, id_persona, apellido, nombre
    ORDER BY seleccion, puesto, apellido;

    -- Tabla 3: goleadores de cada fase
    SELECT fase,
           DENSE_RANK() OVER (PARTITION BY fase ORDER BY COUNT(*) DESC) AS puesto,
           apellido, nombre, seleccion, COUNT(*) AS goles
    FROM #goles
    GROUP BY orden_fase, fase, id_persona, apellido, nombre, seleccion
    ORDER BY orden_fase, puesto, apellido;
END
GO

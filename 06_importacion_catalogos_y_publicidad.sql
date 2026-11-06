/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 6 - Procesos de Importacion (Version Corregida y Robusta)
 Grupo 02 - Comision 02-5600
 Objetivo: Importacion masiva de catalogos, economia y publicidad.
  Integrantes: 
  Miro, Saba.
  Mendez Camacho, Tatiana Antonella
  Rocha Escalera, Sheila
  Meira Da Cruz Saleiro, Gonzalo
=====================================================================
*/

USE MundialDB;
GO

/* =================================================================
   PARTE 1: TABLAS DE STAGING 
   ================================================================= */
IF OBJECT_ID('imp.stg_Moneda') IS NULL
BEGIN
    CREATE TABLE imp.stg_Moneda (
        id_stg INT IDENTITY(1,1) PRIMARY KEY,
        codigo_iso CHAR(3),
        nombre VARCHAR(50)
    );
END
GO

IF OBJECT_ID('imp.stg_Idioma') IS NULL
BEGIN
    CREATE TABLE imp.stg_Idioma (
        id_stg INT IDENTITY(1,1) PRIMARY KEY,
        codigo_iso CHAR(2),
        nombre VARCHAR(50)
    );
END
GO

IF OBJECT_ID('imp.stg_Pais') IS NULL
BEGIN
    CREATE TABLE imp.stg_Pais (
        id_stg INT IDENTITY(1,1) PRIMARY KEY,
        nombre VARCHAR(100),
        confederacion VARCHAR(20),
        codigo_moneda CHAR(3),
        huso_horario VARCHAR(50)
    );
END
GO

IF OBJECT_ID('imp.stg_Ciudad') IS NULL
BEGIN
    CREATE TABLE imp.stg_Ciudad (
        id_stg INT IDENTITY(1,1) PRIMARY KEY,
        nombre NVARCHAR(100),
        pais VARCHAR(100),
        huso_horario VARCHAR(50)
    );
END
GO

IF OBJECT_ID('imp.stg_IndicadorEconomico') IS NULL
BEGIN
    CREATE TABLE imp.stg_IndicadorEconomico (
        id_stg INT IDENTITY(1,1) PRIMARY KEY,
        pais NVARCHAR(100),
        anio SMALLINT,
        codigo_indicador VARCHAR(30),
        valor DECIMAL(18,2)
    );
END
GO

IF OBJECT_ID('imp.stg_TipoCambio') IS NULL
BEGIN
    CREATE TABLE imp.stg_TipoCambio (
        id_stg INT IDENTITY(1,1) PRIMARY KEY,
        codigo_moneda CHAR(3),
        fecha DATE,
        tasa_usd DECIMAL(18,6)
    );
END
GO

IF OBJECT_ID('imp.stg_Feriado') IS NULL
BEGIN
    CREATE TABLE imp.stg_Feriado (
        id_stg INT IDENTITY(1,1) PRIMARY KEY,
        fecha DATE,
        nombre VARCHAR(150),
        pais NVARCHAR(100)
    );
END
GO

IF OBJECT_ID('imp.stg_FranjaHoraria') IS NULL
BEGIN
    CREATE TABLE imp.stg_FranjaHoraria (
        id_stg INT IDENTITY(1,1) PRIMARY KEY,
        nombre VARCHAR(30),
        hora_desde TIME(0),
        hora_hasta TIME(0),
        es_prime_time BIT
    );
END
GO

IF OBJECT_ID('imp.stg_Tarifa') IS NULL
BEGIN
    CREATE TABLE imp.stg_Tarifa (
        id_stg INT IDENTITY(1,1) PRIMARY KEY,
        anio_torneo SMALLINT,
        fase VARCHAR(30),
        franja VARCHAR(30),
        monto DECIMAL(12,2),
        codigo_moneda CHAR(3)
    );
END
GO

IF OBJECT_ID('imp.stg_Publicidad') IS NULL
BEGIN
    CREATE TABLE imp.stg_Publicidad (
        id_stg INT IDENTITY(1,1) PRIMARY KEY,
        anunciante VARCHAR(100),
        pais_anunciante NVARCHAR(100),
        marca VARCHAR(100),
        agencia VARCHAR(100),
        campania VARCHAR(150),
        fecha_desde DATE,
        fecha_hasta DATE,
        descripcion_campania VARCHAR(500),
        mercado_objetivo NVARCHAR(100),
        pieza_titulo VARCHAR(150),
        pieza_idioma CHAR(2),
        pieza_url VARCHAR(300)
    );
END
GO

/* =================================================================
   PARTE 2: VISTAS INTERMEDIAS PARA CARGA (SIN id_stg)
   ================================================================= */
CREATE OR ALTER VIEW imp.vw_stg_Moneda_carga AS
    SELECT codigo_iso, nombre FROM imp.stg_Moneda;
GO

CREATE OR ALTER VIEW imp.vw_stg_Idioma_carga AS
    SELECT codigo_iso, nombre FROM imp.stg_Idioma;
GO

CREATE OR ALTER VIEW imp.vw_stg_Pais_carga AS
    SELECT nombre, confederacion, codigo_moneda, huso_horario FROM imp.stg_Pais;
GO

CREATE OR ALTER VIEW imp.vw_stg_Ciudad_carga AS
    SELECT nombre, pais, huso_horario FROM imp.stg_Ciudad;
GO

CREATE OR ALTER VIEW imp.vw_stg_IndicadorEconomico_carga AS
    SELECT pais, anio, codigo_indicador, valor FROM imp.stg_IndicadorEconomico;
GO

CREATE OR ALTER VIEW imp.vw_stg_TipoCambio_carga AS
    SELECT codigo_moneda, fecha, tasa_usd FROM imp.stg_TipoCambio;
GO

CREATE OR ALTER VIEW imp.vw_stg_Feriado_carga AS
    SELECT fecha, nombre, pais FROM imp.stg_Feriado;
GO

CREATE OR ALTER VIEW imp.vw_stg_FranjaHoraria_carga AS
    SELECT nombre, hora_desde, hora_hasta, es_prime_time FROM imp.stg_FranjaHoraria;
GO

CREATE OR ALTER VIEW imp.vw_stg_Tarifa_carga AS
    SELECT anio_torneo, fase, franja, monto, codigo_moneda FROM imp.stg_Tarifa;
GO

CREATE OR ALTER VIEW imp.vw_stg_Publicidad_carga AS
    SELECT anunciante, pais_anunciante, marca, agencia, campania,
           fecha_desde, fecha_hasta, descripcion_campania, mercado_objetivo,
           pieza_titulo, pieza_idioma, pieza_url
    FROM imp.stg_Publicidad;
GO

/* =================================================================
   PARTE 3: STORED PROCEDURES DE IMPORTACION MASIVA 
   ================================================================= */

-- 3.1 Monedas
CREATE OR ALTER PROCEDURE imp.usp_ImportarMonedas_CSV
    @archivo VARCHAR(260),
    @fuente  VARCHAR(100) = 'CSV Catalogos ISO'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_log INT;
    DECLARE @filas_leidas INT = 0, @filas_ok INT = 0, @filas_error INT = 0;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio)
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_Moneda;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.vw_stg_Moneda_carga FROM ''' + @archivo + N'''
                     WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','',
                           ROWTERMINATOR = ''
'', CODEPAGE = ''65001'');';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        THROW 50610, 'Error al leer el archivo CSV de Monedas.', 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_Moneda);

    DECLARE @i INT = 1;
    DECLARE @max INT = ISNULL((SELECT MAX(id_stg) FROM imp.stg_Moneda), 0);
    DECLARE @codigo_iso CHAR(3), @nombre VARCHAR(50);
    DECLARE @id_moneda INT;
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);

    WHILE @i <= @max
    BEGIN
        -- Blanqueo explicito
        SET @codigo_iso = NULL;
        SET @nombre = NULL;
        SET @id_moneda = NULL;
        SET @dato = NULL;
        SET @msg = NULL;

        SELECT @codigo_iso = LTRIM(RTRIM(codigo_iso)),
               @nombre = LTRIM(RTRIM(nombre))
        FROM imp.stg_Moneda WHERE id_stg = @i;

        SET @dato = CONCAT(@codigo_iso, ' | ', @nombre);

        BEGIN TRY
            SELECT @id_moneda = id_moneda FROM cat.Moneda WHERE codigo_iso = @codigo_iso;

            IF @id_moneda IS NOT NULL
                EXEC cat.usp_Moneda_Modificacion @id_moneda, @codigo_iso, @nombre;
            ELSE
                EXEC cat.usp_Moneda_Alta @codigo_iso, @nombre;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1;
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @i, @dato, @msg;
        END CATCH;

        SET @i += 1;
    END

    EXEC imp.usp_LogImportacion_Modificacion @id_log, SYSDATETIME(), @filas_leidas, @filas_ok, @filas_error;
END
GO


-- 3.2 Idiomas
CREATE OR ALTER PROCEDURE imp.usp_ImportarIdiomas_CSV
    @archivo VARCHAR(260),
    @fuente  VARCHAR(100) = 'CSV Catalogos ISO'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_log INT;
    DECLARE @filas_leidas INT = 0, @filas_ok INT = 0, @filas_error INT = 0;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio)
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_Idioma;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.vw_stg_Idioma_carga FROM ''' + @archivo + N'''
                     WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','',
                           ROWTERMINATOR = ''
'', CODEPAGE = ''65001'');';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        THROW 50611, 'Error al leer el archivo CSV de Idiomas.', 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_Idioma);

    DECLARE @i INT = 1;
    DECLARE @max INT = ISNULL((SELECT MAX(id_stg) FROM imp.stg_Idioma), 0);
    DECLARE @codigo_iso CHAR(2), @nombre VARCHAR(50);
    DECLARE @id_idioma INT;
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);

    WHILE @i <= @max
    BEGIN
        SET @codigo_iso = NULL;
        SET @nombre = NULL;
        SET @id_idioma = NULL;
        SET @dato = NULL;
        SET @msg = NULL;

        SELECT @codigo_iso = LTRIM(RTRIM(codigo_iso)),
               @nombre = LTRIM(RTRIM(nombre))
        FROM imp.stg_Idioma WHERE id_stg = @i;

        SET @dato = CONCAT(@codigo_iso, ' | ', @nombre);

        BEGIN TRY
            SELECT @id_idioma = id_idioma FROM cat.Idioma WHERE codigo_iso = @codigo_iso;

            IF @id_idioma IS NOT NULL
                EXEC cat.usp_Idioma_Modificacion @id_idioma, @codigo_iso, @nombre;
            ELSE
                EXEC cat.usp_Idioma_Alta @codigo_iso, @nombre;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1;
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @i, @dato, @msg;
        END CATCH;

        SET @i += 1;
    END

    EXEC imp.usp_LogImportacion_Modificacion @id_log, SYSDATETIME(), @filas_leidas, @filas_ok, @filas_error;
END
GO


-- 3.3 Paises
CREATE OR ALTER PROCEDURE imp.usp_ImportarPaises_CSV
    @archivo VARCHAR(260),
    @fuente  VARCHAR(100) = 'CSV Paises Mundial'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_log INT;
    DECLARE @filas_leidas INT = 0, @filas_ok INT = 0, @filas_error INT = 0;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio)
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_Pais;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.vw_stg_Pais_carga FROM ''' + @archivo + N'''
                     WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','',
                           ROWTERMINATOR = ''
'', CODEPAGE = ''65001'');';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        THROW 50612, 'Error al leer el archivo CSV de Paises.', 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_Pais);

    DECLARE @i INT = 1;
    DECLARE @max INT = ISNULL((SELECT MAX(id_stg) FROM imp.stg_Pais), 0);
    DECLARE @nombre VARCHAR(100), @confederacion VARCHAR(20), @codigo_moneda CHAR(3), @huso_horario VARCHAR(50);
    DECLARE @id_pais INT, @id_moneda INT;
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);

    WHILE @i <= @max
    BEGIN
        SET @nombre = NULL;
        SET @confederacion = NULL;
        SET @codigo_moneda = NULL;
        SET @huso_horario = NULL;
        SET @id_pais = NULL;
        SET @id_moneda = NULL;
        SET @dato = NULL;
        SET @msg = NULL;

        SELECT @nombre = LTRIM(RTRIM(nombre)),
               @confederacion = LTRIM(RTRIM(confederacion)),
               @codigo_moneda = LTRIM(RTRIM(codigo_moneda)),
               @huso_horario = REPLACE(REPLACE(LTRIM(RTRIM(huso_horario)), CHAR(13), ''), CHAR(10), '')
        FROM imp.stg_Pais WHERE id_stg = @i;

        IF @confederacion = '' SET @confederacion = NULL;
        IF @codigo_moneda = '' SET @codigo_moneda = NULL;

        SET @dato = CONCAT(@nombre, ' | ', @confederacion, ' | ', @codigo_moneda, ' | ', @huso_horario);

        BEGIN TRY
            IF @codigo_moneda IS NOT NULL
            BEGIN
                SELECT @id_moneda = id_moneda FROM cat.Moneda WHERE codigo_iso = @codigo_moneda;
                IF @id_moneda IS NULL THROW 50612, 'Moneda asignada al pais no encontrada en Catalogo.', 1;
            END

            SELECT @id_pais = id_pais FROM cat.Pais WHERE nombre = @nombre;

            IF @id_pais IS NOT NULL
                EXEC cat.usp_Pais_Modificacion @id_pais, @nombre, @confederacion, @id_moneda, @huso_horario;
            ELSE
                EXEC cat.usp_Pais_Alta @nombre, @confederacion, @id_moneda, @huso_horario;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1;
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @i, @dato, @msg;
        END CATCH;

        SET @i += 1;
    END

    EXEC imp.usp_LogImportacion_Modificacion @id_log, SYSDATETIME(), @filas_leidas, @filas_ok, @filas_error;
END
GO


-- 3.4 Ciudades
CREATE OR ALTER PROCEDURE imp.usp_ImportarCiudades_CSV
    @archivo VARCHAR(260),
    @fuente  VARCHAR(100) = 'CSV Ciudades Mundial'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_log INT;
    DECLARE @filas_leidas INT = 0, @filas_ok INT = 0, @filas_error INT = 0;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio)
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_Ciudad;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.vw_stg_Ciudad_carga FROM ''' + @archivo + N'''
                     WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','',
                           ROWTERMINATOR = ''
'', CODEPAGE = ''65001'');';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        THROW 50613, 'Error al leer el archivo CSV de Ciudades.', 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_Ciudad);

    DECLARE @i INT = 1;
    DECLARE @max INT = ISNULL((SELECT MAX(id_stg) FROM imp.stg_Ciudad), 0);
    DECLARE @nombre NVARCHAR(100), @pais VARCHAR(100), @huso_horario VARCHAR(50);
    DECLARE @id_ciudad INT, @id_pais INT;
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);

    WHILE @i <= @max
    BEGIN
        SET @nombre = NULL;
        SET @pais = NULL;
        SET @huso_horario = NULL;
        SET @id_ciudad = NULL;
        SET @id_pais = NULL;
        SET @dato = NULL;
        SET @msg = NULL;

        SELECT @nombre = LTRIM(RTRIM(nombre)),
               @pais = LTRIM(RTRIM(pais)),
               @huso_horario = REPLACE(REPLACE(LTRIM(RTRIM(huso_horario)), CHAR(13), ''), CHAR(10), '')
        FROM imp.stg_Ciudad WHERE id_stg = @i;

        SET @dato = CONCAT(@nombre, ' | ', @pais, ' | ', @huso_horario);

        BEGIN TRY
            SELECT @id_pais = id_pais FROM cat.Pais WHERE nombre = @pais;
            IF @id_pais IS NULL THROW 50613, 'Pais asociado no encontrado.', 1;

            SELECT @id_ciudad = id_ciudad FROM cat.Ciudad WHERE nombre = @nombre AND id_pais = @id_pais;

            IF @id_ciudad IS NOT NULL
                EXEC cat.usp_Ciudad_Modificacion @id_ciudad, @nombre, @id_pais, @huso_horario;
            ELSE
                EXEC cat.usp_Ciudad_Alta @nombre, @id_pais, @huso_horario;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1;
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @i, @dato, @msg;
        END CATCH;

        SET @i += 1;
    END

    EXEC imp.usp_LogImportacion_Modificacion @id_log, SYSDATETIME(), @filas_leidas, @filas_ok, @filas_error;
END
GO


-- 3.5 Franjas Horarias
CREATE OR ALTER PROCEDURE imp.usp_ImportarFranjasHorarias_CSV
    @archivo VARCHAR(260),
    @fuente  VARCHAR(100) = 'Definicion Comercial CSV'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_log INT;
    DECLARE @filas_leidas INT = 0, @filas_ok INT = 0, @filas_error INT = 0;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio)
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_FranjaHoraria;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.vw_stg_FranjaHoraria_carga FROM ''' + @archivo + N'''
                     WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','',
                           ROWTERMINATOR = ''
'', CODEPAGE = ''65001'');';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        THROW 50614, 'Error al leer el archivo CSV de Franjas Horarias.', 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_FranjaHoraria);

    DECLARE @i INT = 1;
    DECLARE @max INT = ISNULL((SELECT MAX(id_stg) FROM imp.stg_FranjaHoraria), 0);
    DECLARE @nombre VARCHAR(30), @hora_desde TIME(0), @hora_hasta TIME(0), @es_prime_time BIT;
    DECLARE @id_franja INT;
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);

    WHILE @i <= @max
    BEGIN
        SET @nombre = NULL;
        SET @hora_desde = NULL;
        SET @hora_hasta = NULL;
        SET @es_prime_time = NULL;
        SET @id_franja = NULL;
        SET @dato = NULL;
        SET @msg = NULL;

        SELECT @nombre = LTRIM(RTRIM(nombre)),
               @hora_desde = hora_desde,
               @hora_hasta = hora_hasta,
               @es_prime_time = es_prime_time
        FROM imp.stg_FranjaHoraria WHERE id_stg = @i;

        SET @dato = CONCAT(@nombre, ' | ', @hora_desde, ' - ', @hora_hasta, ' | Prime: ', @es_prime_time);

        BEGIN TRY
            SELECT @id_franja = id_franja_horaria FROM pub.FranjaHoraria WHERE nombre = @nombre;

            IF @id_franja IS NOT NULL
                EXEC pub.usp_FranjaHoraria_Modificacion @id_franja, @nombre, @hora_desde, @hora_hasta, @es_prime_time;
            ELSE
                EXEC pub.usp_FranjaHoraria_Alta @nombre, @hora_desde, @hora_hasta, @es_prime_time;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1;
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @i, @dato, @msg;
        END CATCH;

        SET @i += 1;
    END

    EXEC imp.usp_LogImportacion_Modificacion @id_log, SYSDATETIME(), @filas_leidas, @filas_ok, @filas_error;
END
GO


-- 3.6 Tarifas
CREATE OR ALTER PROCEDURE imp.usp_ImportarTarifas_CSV
    @archivo VARCHAR(260),
    @fuente  VARCHAR(100) = 'Precios Comercial CSV'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_log INT;
    DECLARE @filas_leidas INT = 0, @filas_ok INT = 0, @filas_error INT = 0;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio)
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_Tarifa;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.vw_stg_Tarifa_carga FROM ''' + @archivo + N'''
                     WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','',
                           ROWTERMINATOR = ''
'', CODEPAGE = ''65001'');';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        THROW 50615, 'Error al leer el archivo CSV de Tarifas.', 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_Tarifa);

    DECLARE @i INT = 1;
    DECLARE @max INT = ISNULL((SELECT MAX(id_stg) FROM imp.stg_Tarifa), 0);
    DECLARE @anio_torneo SMALLINT, @fase VARCHAR(30), @franja VARCHAR(30), @monto DECIMAL(12,2), @codigo_moneda CHAR(3);
    DECLARE @id_tarifa INT, @id_torneo INT, @id_fase INT, @id_franja INT, @id_moneda INT;
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);

    WHILE @i <= @max
    BEGIN
        SET @anio_torneo = NULL;
        SET @fase = NULL;
        SET @franja = NULL;
        SET @monto = NULL;
        SET @codigo_moneda = NULL;
        SET @id_tarifa = NULL;
        SET @id_torneo = NULL;
        SET @id_fase = NULL;
        SET @id_franja = NULL;
        SET @id_moneda = NULL;
        SET @dato = NULL;
        SET @msg = NULL;

        SELECT @anio_torneo = anio_torneo,
               @fase = LTRIM(RTRIM(fase)),
               @franja = LTRIM(RTRIM(franja)),
               @monto = monto,
               @codigo_moneda = LTRIM(RTRIM(codigo_moneda))
        FROM imp.stg_Tarifa WHERE id_stg = @i;

        SET @dato = CONCAT(@fase, ' | ', @franja, ' | ', @monto, ' ', @codigo_moneda);

        BEGIN TRY
            SELECT @id_torneo = id_torneo FROM comp.Torneo WHERE anio = @anio_torneo;
            IF @id_torneo IS NULL THROW 50615, 'Torneo no encontrado.', 1;

            SELECT @id_fase = id_fase FROM comp.Fase WHERE nombre = @fase;
            IF @id_fase IS NULL THROW 50615, 'Fase no encontrada.', 1;

            SELECT @id_franja = id_franja_horaria FROM pub.FranjaHoraria WHERE nombre = @franja;
            IF @id_franja IS NULL THROW 50615, 'Franja Horaria no encontrada.', 1;

            SELECT @id_moneda = id_moneda FROM cat.Moneda WHERE codigo_iso = @codigo_moneda;
            IF @id_moneda IS NULL THROW 50615, 'Moneda no encontrada.', 1;

            SELECT @id_tarifa = id_tarifa FROM pub.Tarifa
            WHERE id_torneo = @id_torneo AND id_fase = @id_fase AND id_franja_horaria = @id_franja;

            IF @id_tarifa IS NOT NULL
                EXEC pub.usp_Tarifa_Modificacion @id_tarifa, @monto, @id_moneda;
            ELSE
                EXEC pub.usp_Tarifa_Alta @id_torneo, @id_fase, @id_franja, @monto, @id_moneda;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1;
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @i, @dato, @msg;
        END CATCH;

        SET @i += 1;
    END

    EXEC imp.usp_LogImportacion_Modificacion @id_log, SYSDATETIME(), @filas_leidas, @filas_ok, @filas_error;
END
GO


-- 3.7 Indicadores Economicos
CREATE OR ALTER PROCEDURE imp.usp_ImportarIndicadorEconomico_CSV
    @archivo VARCHAR(260),
    @fuente  VARCHAR(100) = 'Banco Mundial (API CSV Export)'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_log INT;
    DECLARE @filas_leidas INT = 0, @filas_ok INT = 0, @filas_error INT = 0;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio)
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_IndicadorEconomico;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.vw_stg_IndicadorEconomico_carga FROM ''' + @archivo + N'''
                     WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','',
                           ROWTERMINATOR = ''
'', CODEPAGE = ''65001'');';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        THROW 50620, 'Error al leer el archivo CSV de Indicadores Economicos.', 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_IndicadorEconomico);

    DECLARE @i INT = 1;
    DECLARE @max INT = ISNULL((SELECT MAX(id_stg) FROM imp.stg_IndicadorEconomico), 0);
    DECLARE @pais NVARCHAR(100), @anio SMALLINT, @codigo_indicador VARCHAR(30), @valor DECIMAL(18,2);
    DECLARE @id_pais INT;
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);

    WHILE @i <= @max
    BEGIN
        SET @pais = NULL;
        SET @anio = NULL;
        SET @codigo_indicador = NULL;
        SET @valor = NULL;
        SET @id_pais = NULL;
        SET @dato = NULL;
        SET @msg = NULL;

        SELECT @pais = LTRIM(RTRIM(pais)),
               @anio = anio,
               @codigo_indicador = LTRIM(RTRIM(codigo_indicador)),
               @valor = valor
        FROM imp.stg_IndicadorEconomico WHERE id_stg = @i;

        SET @dato = CONCAT(@pais, ' | ', @anio, ' | ', @codigo_indicador, ' | ', @valor);

        BEGIN TRY
            SELECT @id_pais = id_pais FROM cat.Pais WHERE nombre = @pais;
            IF @id_pais IS NULL THROW 50621, 'Pais no encontrado.', 1;

            IF EXISTS (SELECT 1 FROM cat.IndicadorEconomico WHERE id_pais = @id_pais AND anio = @anio AND codigo_indicador = @codigo_indicador)
                EXEC cat.usp_IndicadorEconomico_Modificacion @id_pais, @anio, @codigo_indicador, @valor;
            ELSE
                EXEC cat.usp_IndicadorEconomico_Alta @id_pais, @anio, @codigo_indicador, @valor;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1;
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @i, @dato, @msg;
        END CATCH;

        SET @i += 1;
    END

    EXEC imp.usp_LogImportacion_Modificacion @id_log, SYSDATETIME(), @filas_leidas, @filas_ok, @filas_error;
END
GO


-- 3.8 Tipos de Cambio
CREATE OR ALTER PROCEDURE imp.usp_ImportarTipoCambio_CSV
    @archivo VARCHAR(260),
    @fuente  VARCHAR(100) = 'Frankfurter API (CSV Export)'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_log INT;
    DECLARE @filas_leidas INT = 0, @filas_ok INT = 0, @filas_error INT = 0;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio)
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_TipoCambio;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.vw_stg_TipoCambio_carga FROM ''' + @archivo + N'''
                     WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','',
                           ROWTERMINATOR = ''
'', CODEPAGE = ''65001'');';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        THROW 50630, 'Error al leer el archivo CSV de Tipos de Cambio.', 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_TipoCambio);

    DECLARE @i INT = 1;
    DECLARE @max INT = ISNULL((SELECT MAX(id_stg) FROM imp.stg_TipoCambio), 0);
    DECLARE @codigo_moneda CHAR(3), @fecha DATE, @tasa_usd DECIMAL(18,6);
    DECLARE @id_moneda INT;
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);

    WHILE @i <= @max
    BEGIN
        SET @codigo_moneda = NULL;
        SET @fecha = NULL;
        SET @tasa_usd = NULL;
        SET @id_moneda = NULL;
        SET @dato = NULL;
        SET @msg = NULL;

        SELECT @codigo_moneda = LTRIM(RTRIM(codigo_moneda)),
               @fecha = fecha,
               @tasa_usd = tasa_usd
        FROM imp.stg_TipoCambio WHERE id_stg = @i;

        SET @dato = CONCAT(@codigo_moneda, ' | ', @fecha, ' | ', @tasa_usd);

        BEGIN TRY
            SELECT @id_moneda = id_moneda FROM cat.Moneda WHERE codigo_iso = @codigo_moneda;
            IF @id_moneda IS NULL THROW 50631, 'Moneda no encontrada.', 1;

            IF EXISTS (SELECT 1 FROM cat.TipoCambio WHERE id_moneda = @id_moneda AND fecha = @fecha)
                EXEC cat.usp_TipoCambio_Modificacion @id_moneda, @fecha, @tasa_usd;
            ELSE
                EXEC cat.usp_TipoCambio_Alta @id_moneda, @fecha, @tasa_usd;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1;
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @i, @dato, @msg;
        END CATCH;

        SET @i += 1;
    END

    EXEC imp.usp_LogImportacion_Modificacion @id_log, SYSDATETIME(), @filas_leidas, @filas_ok, @filas_error;
END
GO


-- 3.9 Feriados
CREATE OR ALTER PROCEDURE imp.usp_ImportarFeriados_CSV
    @archivo VARCHAR(260),
    @fuente  VARCHAR(100) = 'Nager.Date API (CSV Export)'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_log INT;
    DECLARE @filas_leidas INT = 0, @filas_ok INT = 0, @filas_error INT = 0;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio)
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_Feriado;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.vw_stg_Feriado_carga FROM ''' + @archivo + N'''
                     WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','',
                           ROWTERMINATOR = ''
'', CODEPAGE = ''65001'');';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        THROW 50640, 'Error al leer el archivo CSV de Feriados.', 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_Feriado);

    DECLARE @i INT = 1;
    DECLARE @max INT = ISNULL((SELECT MAX(id_stg) FROM imp.stg_Feriado), 0);
    DECLARE @fecha DATE, @nombre VARCHAR(150), @pais NVARCHAR(100);
    DECLARE @id_pais INT;
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);

    WHILE @i <= @max
    BEGIN
        SET @fecha = NULL;
        SET @nombre = NULL;
        SET @pais = NULL;
        SET @id_pais = NULL;
        SET @dato = NULL;
        SET @msg = NULL;

        SELECT @fecha = fecha,
               @nombre = LTRIM(RTRIM(nombre)),
               @pais = LTRIM(RTRIM(pais))
        FROM imp.stg_Feriado WHERE id_stg = @i;

        SET @dato = CONCAT(@fecha, ' | ', @nombre, ' | ', @pais);

        BEGIN TRY
            SELECT @id_pais = id_pais FROM cat.Pais WHERE nombre = @pais;
            IF @id_pais IS NULL THROW 50641, 'Pais no encontrado.', 1;

            IF EXISTS (SELECT 1 FROM cat.Feriado WHERE id_pais = @id_pais AND fecha = @fecha)
                EXEC cat.usp_Feriado_Modificacion @id_pais, @fecha, @nombre;
            ELSE
                EXEC cat.usp_Feriado_Alta @id_pais, @fecha, @nombre;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1;
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @i, @dato, @msg;
        END CATCH;

        SET @i += 1;
    END

    EXEC imp.usp_LogImportacion_Modificacion @id_log, SYSDATETIME(), @filas_leidas, @filas_ok, @filas_error;
END
GO


-- 3.10 Publicidad (Ecosistema Comercial)
CREATE OR ALTER PROCEDURE imp.usp_ImportarPublicidad_CSV
    @archivo VARCHAR(260),
    @fuente  VARCHAR(100) = 'Scraping dossiermundial.netlify.app'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_log INT;
    DECLARE @filas_leidas INT = 0, @filas_ok INT = 0, @filas_error INT = 0;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio)
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_Publicidad;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.vw_stg_Publicidad_carga FROM ''' + @archivo + N'''
                     WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDTERMINATOR = '','',
                           ROWTERMINATOR = ''
'', CODEPAGE = ''65001'');';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        THROW 50650, 'Error al leer el archivo CSV de Publicidad.', 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_Publicidad);

    DECLARE @i INT = 1;
    DECLARE @max INT = ISNULL((SELECT MAX(id_stg) FROM imp.stg_Publicidad), 0);

    DECLARE @anunciante VARCHAR(100), @pais_anunciante NVARCHAR(100), @marca VARCHAR(100),
            @agencia VARCHAR(100), @campania VARCHAR(150), @fecha_desde DATE, @fecha_hasta DATE,
            @descripcion_campania VARCHAR(500), @mercado_objetivo NVARCHAR(100),
            @pieza_titulo VARCHAR(150), @pieza_idioma CHAR(2), @pieza_url VARCHAR(300);

    DECLARE @id_pais_anu INT, @id_anunciante INT, @id_marca INT, @id_agencia INT,
            @id_campania INT, @id_pais_mer INT, @id_idioma INT, @id_pieza INT;
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);

    WHILE @i <= @max
    BEGIN
        -- Blanqueo total de variables
        SET @anunciante = NULL;
        SET @pais_anunciante = NULL;
        SET @marca = NULL;
        SET @agencia = NULL;
        SET @campania = NULL;
        SET @fecha_desde = NULL;
        SET @fecha_hasta = NULL;
        SET @descripcion_campania = NULL;
        SET @mercado_objetivo = NULL;
        SET @pieza_titulo = NULL;
        SET @pieza_idioma = NULL;
        SET @pieza_url = NULL;

        SET @id_pais_anu = NULL;
        SET @id_anunciante = NULL;
        SET @id_marca = NULL;
        SET @id_agencia = NULL;
        SET @id_campania = NULL;
        SET @id_pais_mer = NULL;
        SET @id_idioma = NULL;
        SET @id_pieza = NULL;
        SET @dato = NULL;
        SET @msg = NULL;

        SELECT @anunciante = LTRIM(RTRIM(anunciante)),
               @pais_anunciante = LTRIM(RTRIM(pais_anunciante)),
               @marca = LTRIM(RTRIM(marca)),
               @agencia = LTRIM(RTRIM(agencia)),
               @campania = LTRIM(RTRIM(campania)),
               @fecha_desde = fecha_desde,
               @fecha_hasta = fecha_hasta,
               @descripcion_campania = LTRIM(RTRIM(descripcion_campania)),
               @mercado_objetivo = LTRIM(RTRIM(mercado_objetivo)),
               @pieza_titulo = LTRIM(RTRIM(pieza_titulo)),
               @pieza_idioma = LTRIM(RTRIM(pieza_idioma)),
               @pieza_url = LTRIM(RTRIM(pieza_url))
        FROM imp.stg_Publicidad WHERE id_stg = @i;

        SET @dato = CONCAT(@anunciante, ' | ', @marca, ' | ', @campania, ' | ', @pieza_titulo);

        BEGIN TRY
            -- 1. Pais del Anunciante
            SELECT @id_pais_anu = id_pais FROM cat.Pais WHERE nombre = @pais_anunciante;
            IF @id_pais_anu IS NULL THROW 50651, 'Pais del anunciante no encontrado.', 1;

            -- 2. Anunciante
            SELECT @id_anunciante = id_anunciante FROM pub.Anunciante WHERE nombre = @anunciante;
            IF @id_anunciante IS NULL
            BEGIN
                EXEC pub.usp_Anunciante_Alta @anunciante, @id_pais_anu;
                SELECT @id_anunciante = id_anunciante FROM pub.Anunciante WHERE nombre = @anunciante;
            END

            -- 3. Marca
            SELECT @id_marca = id_marca FROM pub.Marca WHERE id_anunciante = @id_anunciante AND nombre = @marca;
            IF @id_marca IS NULL
            BEGIN
                EXEC pub.usp_Marca_Alta @id_anunciante, @marca;
                SELECT @id_marca = id_marca FROM pub.Marca WHERE id_anunciante = @id_anunciante AND nombre = @marca;
            END

            -- 4. Agencia (opcional)
            IF @agencia IS NOT NULL AND @agencia <> ''
            BEGIN
                SELECT @id_agencia = id_agencia FROM pub.Agencia WHERE nombre = @agencia;
                IF @id_agencia IS NULL
                BEGIN
                    EXEC pub.usp_Agencia_Alta @agencia;
                    SELECT @id_agencia = id_agencia FROM pub.Agencia WHERE nombre = @agencia;
                END
            END

            -- 5. Campania
            SELECT @id_campania = id_campania FROM pub.Campania WHERE titulo = @campania AND id_marca = @id_marca;
            IF @id_campania IS NULL
            BEGIN
                EXEC pub.usp_Campania_Alta @id_marca, @id_agencia, @campania, @fecha_desde, @fecha_hasta, @descripcion_campania;
                SELECT @id_campania = id_campania FROM pub.Campania WHERE titulo = @campania AND id_marca = @id_marca;
            END

            -- 6. Mercado y CampaniaPais
            SELECT @id_pais_mer = id_pais FROM cat.Pais WHERE nombre = @mercado_objetivo;
            IF @id_pais_mer IS NULL THROW 50652, 'Pais mercado objetivo no encontrado.', 1;

            IF NOT EXISTS (SELECT 1 FROM pub.CampaniaPais WHERE id_campania = @id_campania AND id_pais = @id_pais_mer)
                EXEC pub.usp_CampaniaPais_Alta @id_campania, @id_pais_mer;

            -- 7. Idioma
            SELECT @id_idioma = id_idioma FROM cat.Idioma WHERE codigo_iso = @pieza_idioma;
            IF @id_idioma IS NULL THROW 50653, 'Idioma no encontrado.', 1;

            -- 8. Pieza Publicitaria
            SELECT @id_pieza = id_pieza_publicitaria FROM pub.PiezaPublicitaria
            WHERE titulo = @pieza_titulo AND id_campania = @id_campania;

            IF @id_pieza IS NULL
                EXEC pub.usp_PiezaPublicitaria_Alta @id_campania, @id_idioma, @id_pais_mer, @pieza_titulo, @pieza_url;
            ELSE
                EXEC pub.usp_PiezaPublicitaria_Modificacion @id_pieza, @id_campania, @id_idioma, @id_pais_mer, @pieza_titulo, @pieza_url;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1;
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @i, @dato, @msg;
        END CATCH;

        SET @i += 1;
    END

    EXEC imp.usp_LogImportacion_Modificacion @id_log, SYSDATETIME(), @filas_leidas, @filas_ok, @filas_error;
END
GO

/* =================================================================
   PARTE 4: ORDEN DE EJECUCION
   ================================================================= */

-- 1. Catalogos Raiz (Independientes)
EXEC imp.usp_ImportarMonedas_CSV         'C:\Mundial2026_Datos\monedas.csv';
EXEC imp.usp_ImportarIdiomas_CSV         'C:\Mundial2026_Datos\idiomas.csv';
EXEC imp.usp_ImportarFranjasHorarias_CSV 'C:\Mundial2026_Datos\franjas_comerciales.csv';

-- 2. Catalogos Geograficos (Dependen de Monedas)
EXEC imp.usp_ImportarPaises_CSV          'C:\Mundial2026_Datos\paises.csv';
EXEC imp.usp_ImportarCiudades_CSV        'C:\Mundial2026_Datos\ciudades.csv';

-- 3. Entorno Economico, Cultural y Precios (Dependen de Paises y Franjas)
EXEC imp.usp_ImportarTipoCambio_CSV         'C:\Mundial2026_Datos\tipos_cambio_frankfurter.csv';
EXEC imp.usp_ImportarIndicadorEconomico_CSV 'C:\Mundial2026_Datos\indicadores_bm.csv';
EXEC imp.usp_ImportarFeriados_CSV           'C:\Mundial2026_Datos\feriados_nagerdate.csv';
EXEC imp.usp_ImportarTarifas_CSV            'C:\Mundial2026_Datos\tarifas.csv'; -- Requiere Torneo y Fases previos

-- 4. Modulo Comercial Global (Depende de Marcas, Paises e Idiomas)
EXEC imp.usp_ImportarPublicidad_CSV         'C:\Mundial2026_Datos\dossier_publicidad.csv';


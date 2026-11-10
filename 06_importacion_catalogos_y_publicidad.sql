/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 6 - Procesos de Importacion (Version Corregida y Robusta v5)
 Grupo 02 - Comision 02-5600
 Objetivo: Importacion de tablas de Catalogo y Publicidad.
 Integrantes: 
 Miro, Saba.
 Mendez Camacho, Tatiana Antonella
 Rocha Escalera, Sheila
 Meira Da Cruz Saleiro, Gonzalo
=====================================================================
*/

USE MundialDB;
GO

/* ==============================================================================
   PARTE 0: LIMPIEZA INICIAL DE TABLAS Y REINICIO DE IDENTIDADES
   ============================================================================== */

/*
SET NOCOUNT ON;

BEGIN TRANSACTION;
BEGIN TRY
    PRINT '>> Iniciando vaciado total de la base de datos (Eliminando dependencias cruzadas)...';

    ----------------------------------------------------------------------------
    -- PASO 0.1: Limpieza profunda de módulos externos que bloquean tus catálogos
    ----------------------------------------------------------------------------
    IF OBJECT_ID('disc.InformeArbitral', 'U') IS NOT NULL    DELETE FROM disc.InformeArbitral;
    IF OBJECT_ID('disc.Designacion', 'U') IS NOT NULL        DELETE FROM disc.Designacion;
    IF OBJECT_ID('disc.Suspension', 'U') IS NOT NULL          DELETE FROM disc.Suspension;
    IF OBJECT_ID('disc.Tarjeta', 'U') IS NOT NULL            DELETE FROM disc.Tarjeta;
    IF OBJECT_ID('disc.Gol', 'U') IS NOT NULL                DELETE FROM disc.Gol;
    IF OBJECT_ID('disc.Sustitucion', 'U') IS NOT NULL        DELETE FROM disc.Sustitucion;
    IF OBJECT_ID('comp.Alineacion', 'U') IS NOT NULL         DELETE FROM comp.Alineacion;
    IF OBJECT_ID('comp.CambioConvocatoria', 'U') IS NOT NULL DELETE FROM comp.CambioConvocatoria;
    IF OBJECT_ID('comp.Convocado', 'U') IS NOT NULL          DELETE FROM comp.Convocado;
    IF OBJECT_ID('comp.CuerpoTecnico', 'U') IS NOT NULL      DELETE FROM comp.CuerpoTecnico;
    IF OBJECT_ID('comp.PartidoSeleccion', 'U') IS NOT NULL   DELETE FROM comp.PartidoSeleccion;
    IF OBJECT_ID('comp.Partido', 'U') IS NOT NULL            DELETE FROM comp.Partido;
    IF OBJECT_ID('comp.Seleccion', 'U') IS NOT NULL          DELETE FROM comp.Seleccion;
    IF OBJECT_ID('comp.Club', 'U') IS NOT NULL               DELETE FROM comp.Club;
    IF OBJECT_ID('comp.Jugador', 'U') IS NOT NULL            DELETE FROM comp.Jugador;
    IF OBJECT_ID('comp.Persona', 'U') IS NOT NULL            DELETE FROM comp.Persona;
    IF OBJECT_ID('comp.Sede', 'U') IS NOT NULL               DELETE FROM comp.Sede;
    IF OBJECT_ID('disc.ArbitroIdioma', 'U') IS NOT NULL      DELETE FROM disc.ArbitroIdioma;
    IF OBJECT_ID('disc.Arbitro', 'U') IS NOT NULL            DELETE FROM disc.Arbitro;
    IF OBJECT_ID('comp.Grupo', 'U') IS NOT NULL              DELETE FROM comp.Grupo;
    IF OBJECT_ID('comp.ParametroReglamento', 'U') IS NOT NULL DELETE FROM comp.ParametroReglamento;


    ----------------------------------------------------------------------------
    -- PASO 0.2: Vaciado de las tablas
    ----------------------------------------------------------------------------

    -- Módulo Publicidad y Tarifas (Hijas primero)
    DELETE FROM pub.ExhibicionPublicitaria;
    DELETE FROM pub.Tarifa;
    DELETE FROM pub.PiezaPublicitaria;
    DELETE FROM pub.CampaniaPais;
    DELETE FROM pub.Campania;
    DELETE FROM pub.Marca;
    DELETE FROM pub.Anunciante;
    DELETE FROM pub.Agencia;
    DELETE FROM pub.FranjaHoraria;

    -- Auditoría e Importación
    DELETE FROM imp.ErrorImportacion;
    DELETE FROM imp.LogImportacion;

    -- Catálogos Financieros, Feriados y Geográficos (Nodos Raíz)
    DELETE FROM cat.Feriado;
    DELETE FROM cat.TipoCambio;
    DELETE FROM cat.IndicadorEconomico;
    DELETE FROM cat.Ciudad;
    DELETE FROM cat.Pais;
    DELETE FROM cat.Idioma;
    DELETE FROM cat.Moneda;

    IF OBJECT_ID('comp.Torneo', 'U') IS NOT NULL             DELETE FROM comp.Torneo;
    IF OBJECT_ID('comp.Fase', 'U') IS NOT NULL               DELETE FROM comp.Fase;
    ----------------------------------------------------------------------------
    -- PASO 0.3: Limpieza de Tablas de Staging
    ----------------------------------------------------------------------------
    IF OBJECT_ID('imp.stg_Publicidad', 'U') IS NOT NULL         TRUNCATE TABLE imp.stg_Publicidad;
    IF OBJECT_ID('imp.stg_Tarifa', 'U') IS NOT NULL             TRUNCATE TABLE imp.stg_Tarifa;
    IF OBJECT_ID('imp.stg_FranjaHoraria', 'U') IS NOT NULL      TRUNCATE TABLE imp.stg_FranjaHoraria;
    IF OBJECT_ID('imp.stg_Feriado', 'U') IS NOT NULL            TRUNCATE TABLE imp.stg_Feriado;
    IF OBJECT_ID('imp.stg_TipoCambio', 'U') IS NOT NULL         TRUNCATE TABLE imp.stg_TipoCambio;
    IF OBJECT_ID('imp.stg_IndicadorEconomico', 'U') IS NOT NULL TRUNCATE TABLE imp.stg_IndicadorEconomico;
    IF OBJECT_ID('imp.stg_Ciudad', 'U') IS NOT NULL             TRUNCATE TABLE imp.stg_Ciudad;
    IF OBJECT_ID('imp.stg_Pais', 'U') IS NOT NULL               TRUNCATE TABLE imp.stg_Pais;
    IF OBJECT_ID('imp.stg_Idioma', 'U') IS NOT NULL             TRUNCATE TABLE imp.stg_Idioma;
    IF OBJECT_ID('imp.stg_Moneda', 'U') IS NOT NULL             TRUNCATE TABLE imp.stg_Moneda;

    ----------------------------------------------------------------------------
    -- PASO 0.4: Reseteo de Contadores IDENTITY a 0
    ----------------------------------------------------------------------------
    DBCC CHECKIDENT ('imp.ErrorImportacion', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('imp.LogImportacion', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('pub.ExhibicionPublicitaria', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('pub.Tarifa', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('pub.FranjaHoraria', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('pub.PiezaPublicitaria', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('pub.Campania', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('pub.Marca', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('pub.Anunciante', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('pub.Agencia', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('cat.Ciudad', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('cat.Pais', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('cat.Idioma', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('cat.Moneda', RESEED, 0) WITH NO_INFOMSGS;

    COMMIT TRANSACTION;
    PRINT '[OK] Limpieza total completada con éxito.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 
        ROLLBACK TRANSACTION;

    DECLARE @error_msg NVARCHAR(4000) = ERROR_MESSAGE();
    PRINT '[ERROR] Fallo crítico en la limpieza: ' + @error_msg;
    THROW 50000, @error_msg, 1;
END CATCH;
GO

*/

/* =================================================================
   PARTE 1: TABLAS DE STAGING 
   ================================================================= */
IF OBJECT_ID('imp.stg_Moneda', 'U') IS NULL
    CREATE TABLE imp.stg_Moneda (
        codigo_iso CHAR(3),
        nombre VARCHAR(50)
    );
GO

IF OBJECT_ID('imp.stg_Idioma', 'U') IS NULL
    CREATE TABLE imp.stg_Idioma (
        codigo_iso CHAR(2),
        nombre VARCHAR(50)
    );
GO

IF OBJECT_ID('imp.stg_Pais', 'U') IS NULL
    CREATE TABLE imp.stg_Pais (
        nombre VARCHAR(100),
        confederacion VARCHAR(20),
        codigo_moneda CHAR(3),
        huso_horario VARCHAR(50)
    );
GO

DROP TABLE IF EXISTS imp.stg_PaisEquivalencia;
GO

CREATE TABLE imp.stg_PaisEquivalencia (
    codigo_iso VARCHAR(3) PRIMARY KEY, 
    nombre_pais VARCHAR(100) NOT NULL
);

INSERT INTO imp.stg_PaisEquivalencia (codigo_iso, nombre_pais) VALUES
-- Anfitriones y Norteamérica (con tildes alineadas a cat.Pais)
('USA', 'Estados Unidos'), ('US', 'Estados Unidos'),
('MEX', 'México'), ('MX', 'México'),
('CAN', 'Canadá'), ('CA', 'Canadá'),

-- CONMEBOL
('ARG', 'Argentina'), ('AR', 'Argentina'),
('BRA', 'Brasil'), ('BR', 'Brasil'),
('URY', 'Uruguay'), ('UY', 'Uruguay'),
('COL', 'Colombia'), ('CO', 'Colombia'),
('CHL', 'Chile'), ('CL', 'Chile'),
('ECU', 'Ecuador'), ('EC', 'Ecuador'),
('PRY', 'Paraguay'), ('PY', 'Paraguay'),
('PER', 'Perú'), ('PE', 'Perú'),
('VEN', 'Venezuela'), ('VE', 'Venezuela'),
('BOL', 'Bolivia'), ('BO', 'Bolivia'),

-- UEFA
('ESP', 'España'), ('ES', 'España'),
('FRA', 'Francia'), ('FR', 'Francia'),
('DEU', 'Alemania'), ('GER', 'Alemania'), ('DE', 'Alemania'),
('ITA', 'Italia'), ('IT', 'Italia'),
('GBR', 'Inglaterra'), ('ENG', 'Inglaterra'), ('GB', 'Inglaterra'),
('NLD', 'Países Bajos'), ('NED', 'Países Bajos'), ('NL', 'Países Bajos'),
('PRT', 'Portugal'), ('PT', 'Portugal'),
('BEL', 'Bélgica'), ('BE', 'Bélgica'),
('HRV', 'Croacia'), ('CRO', 'Croacia'), ('HR', 'Croacia'),
('DNK', 'Dinamarca'), ('DEN', 'Dinamarca'), ('DK', 'Dinamarca'),
('CHE', 'Suiza'), ('SUI', 'Suiza'), ('CH', 'Suiza'),
('SRB', 'Serbia'), ('RS', 'Serbia'),
('POL', 'Polonia'), ('PL', 'Polonia'),
('AUT', 'Austria'), ('AT', 'Austria'),
('SWE', 'Suecia'), ('SE', 'Suecia'),
('UKR', 'Ucrania'), ('UA', 'Ucrania'),
('TUR', 'Turquía'), ('TR', 'Turquía'),
('CZE', 'Chequia'), ('CZ', 'Chequia'),

-- CONCACAF
('CRI', 'Costa Rica'), ('CR', 'Costa Rica'),
('PAN', 'Panamá'), ('PA', 'Panamá'),
('JAM', 'Jamaica'), ('JM', 'Jamaica'),
('HND', 'Honduras'), ('HN', 'Honduras'),

-- CAF
('MAR', 'Marruecos'), ('MA', 'Marruecos'),
('SEN', 'Senegal'), ('SN', 'Senegal'),
('EGY', 'Egipto'), ('EG', 'Egipto'),
('NGA', 'Nigeria'), ('NG', 'Nigeria'),
('DZA', 'Argelia'), ('DZ', 'Argelia'),
('CMR', 'Camerún'), ('CM', 'Camerún'),
('TUN', 'Túnez'), ('TN', 'Túnez'),
('GHA', 'Ghana'), ('GH', 'Ghana'),
('ZAF', 'Sudáfrica'), ('ZA', 'Sudáfrica'),

-- AFC y OFC
('JPN', 'Japón'), ('JP', 'Japón'),
('KOR', 'Corea del Sur'), ('KR', 'Corea del Sur'),
('AUS', 'Australia'), ('AU', 'Australia'),
('SAU', 'Arabia Saudita'), ('SA', 'Arabia Saudita'),
('QAT', 'Catar'), ('QA', 'Catar'),
('NZL', 'Nueva Zelanda'), ('NZ', 'Nueva Zelanda');
GO

-- 1. Asegurar Torneo 2026
IF NOT EXISTS (SELECT 1 FROM comp.Torneo WHERE anio = 2026)
    EXEC comp.usp_Torneo_Alta 'Copa Mundial FIFA 2026', 2026, '2026-06-11', '2026-07-19';

-- 2. Asegurar Fases del Torneo
IF NOT EXISTS (SELECT 1 FROM comp.Fase WHERE nombre = 'Grupos')       EXEC comp.usp_Fase_Alta 'Grupos', 1, 0;
IF NOT EXISTS (SELECT 1 FROM comp.Fase WHERE nombre = 'Dieciseisavos') EXEC comp.usp_Fase_Alta 'Dieciseisavos', 2, 1;
IF NOT EXISTS (SELECT 1 FROM comp.Fase WHERE nombre = 'Octavos')      EXEC comp.usp_Fase_Alta 'Octavos', 3, 1;
IF NOT EXISTS (SELECT 1 FROM comp.Fase WHERE nombre = 'Cuartos')      EXEC comp.usp_Fase_Alta 'Cuartos', 4, 1;
IF NOT EXISTS (SELECT 1 FROM comp.Fase WHERE nombre = 'Semifinal')    EXEC comp.usp_Fase_Alta 'Semifinal', 5, 1;
IF NOT EXISTS (SELECT 1 FROM comp.Fase WHERE nombre = 'Tercer puesto') EXEC comp.usp_Fase_Alta 'Tercer puesto', 6, 1;
IF NOT EXISTS (SELECT 1 FROM comp.Fase WHERE nombre = 'Final')        EXEC comp.usp_Fase_Alta 'Final', 7, 1;
GO

/* =================================================================
   PARTE 2: STORED PROCEDURES DE IMPORTACION
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
    DECLARE @fecha_fin DATETIME2;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio) 
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_Moneda;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.stg_Moneda FROM ''' + @archivo + N''' 
                     WITH (
                         FIRSTROW = 2, 
                         FIELDTERMINATOR = '','', 
                         ROWTERMINATOR = ''
'', 
                         CODEPAGE = ''65001''
                     );';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        DECLARE @err_bulk NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @fecha_fin_err DATETIME2 = SYSDATETIME();
        EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin_err, 0, 0, 1;
        EXEC imp.usp_ErrorImportacion_Alta @id_log, 0, @archivo, @err_bulk;
        THROW 50600, @err_bulk, 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_Moneda);

    DECLARE @codigo_iso CHAR(3), @nombre VARCHAR(50);
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);
    DECLARE @nro_fila INT = 1;
    DECLARE @id_moneda INT;

    DECLARE cur_stg CURSOR LOCAL FAST_FORWARD FOR 
        SELECT LTRIM(RTRIM(codigo_iso)), LTRIM(RTRIM(nombre)) FROM imp.stg_Moneda;
    
    OPEN cur_stg;
    FETCH NEXT FROM cur_stg INTO @codigo_iso, @nombre;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @nro_fila += 1;
        SET @dato = CONCAT(@codigo_iso, ' | ', @nombre);
        SET @id_moneda = NULL;

        BEGIN TRY
            SELECT @id_moneda = id_moneda FROM cat.Moneda WHERE codigo_iso = @codigo_iso;
            IF @id_moneda IS NOT NULL EXEC cat.usp_Moneda_Modificacion @id_moneda, @codigo_iso, @nombre;
            ELSE EXEC cat.usp_Moneda_Alta @codigo_iso, @nombre;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1; 
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @nro_fila, @dato, @msg;
        END CATCH;

        FETCH NEXT FROM cur_stg INTO @codigo_iso, @nombre;
    END

    CLOSE cur_stg; 
    DEALLOCATE cur_stg;

    SET @fecha_fin = SYSDATETIME();
    EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin, @filas_leidas, @filas_ok, @filas_error;
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
    DECLARE @fecha_fin DATETIME2;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio) 
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_Idioma;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.stg_Idioma FROM ''' + @archivo + N''' 
                     WITH (
                         FIRSTROW = 2, 
                         FIELDTERMINATOR = '','', 
                         ROWTERMINATOR = ''
'', 
                         CODEPAGE = ''65001''
                     );';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        DECLARE @err_bulk NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @fecha_fin_err DATETIME2 = SYSDATETIME();
        EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin_err, 0, 0, 1;
        EXEC imp.usp_ErrorImportacion_Alta @id_log, 0, @archivo, @err_bulk;
        THROW 50600, @err_bulk, 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_Idioma);

    DECLARE @codigo_iso CHAR(2), @nombre VARCHAR(50);
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);
    DECLARE @nro_fila INT = 1;
    DECLARE @id_idioma INT;

    DECLARE cur_stg CURSOR LOCAL FAST_FORWARD FOR 
        SELECT LTRIM(RTRIM(codigo_iso)), LTRIM(RTRIM(nombre)) FROM imp.stg_Idioma;
    
    OPEN cur_stg;
    FETCH NEXT FROM cur_stg INTO @codigo_iso, @nombre;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @nro_fila += 1;
        SET @dato = CONCAT(@codigo_iso, ' | ', @nombre);
        SET @id_idioma = NULL;

        BEGIN TRY
            SELECT @id_idioma = id_idioma FROM cat.Idioma WHERE codigo_iso = @codigo_iso;
            IF @id_idioma IS NOT NULL EXEC cat.usp_Idioma_Modificacion @id_idioma, @codigo_iso, @nombre;
            ELSE EXEC cat.usp_Idioma_Alta @codigo_iso, @nombre;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1; 
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @nro_fila, @dato, @msg;
        END CATCH;

        FETCH NEXT FROM cur_stg INTO @codigo_iso, @nombre;
    END

    CLOSE cur_stg; 
    DEALLOCATE cur_stg;

    SET @fecha_fin = SYSDATETIME();
    EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin, @filas_leidas, @filas_ok, @filas_error;
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
    DECLARE @fecha_fin DATETIME2;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio) 
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_Pais;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.stg_Pais FROM ''' + @archivo + N''' 
                     WITH (
                         FIRSTROW = 2, 
                         FIELDTERMINATOR = '','', 
                         ROWTERMINATOR = ''
'', 
                         CODEPAGE = ''65001''
                     );';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        DECLARE @err_bulk NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @fecha_fin_err DATETIME2 = SYSDATETIME();
        EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin_err, 0, 0, 1;
        EXEC imp.usp_ErrorImportacion_Alta @id_log, 0, @archivo, @err_bulk;
        THROW 50600, @err_bulk, 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_Pais);

    DECLARE @nombre VARCHAR(100), @confederacion VARCHAR(20), @codigo_moneda CHAR(3), @huso_horario VARCHAR(50);
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);
    DECLARE @nro_fila INT = 1;
    DECLARE @id_pais INT, @id_moneda INT;

    DECLARE cur_stg CURSOR LOCAL FAST_FORWARD FOR 
        SELECT LTRIM(RTRIM(nombre)), LTRIM(RTRIM(confederacion)), LTRIM(RTRIM(codigo_moneda)), LTRIM(RTRIM(huso_horario)) FROM imp.stg_Pais;
    
    OPEN cur_stg;
    FETCH NEXT FROM cur_stg INTO @nombre, @confederacion, @codigo_moneda, @huso_horario;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @nro_fila += 1;
        SET @dato = CONCAT(@nombre, ' | ', @confederacion, ' | ', @codigo_moneda, ' | ', @huso_horario);
        IF @confederacion = '' SET @confederacion = NULL;
        IF @codigo_moneda = '' SET @codigo_moneda = NULL;
        SET @id_pais = NULL; SET @id_moneda = NULL;

        BEGIN TRY
            IF @codigo_moneda IS NOT NULL
            BEGIN
                SELECT @id_moneda = id_moneda FROM cat.Moneda WHERE codigo_iso = @codigo_moneda;
                IF @id_moneda IS NULL THROW 50612, 'Moneda asignada al pais no encontrada en Catalogo.', 1;
            END
            SELECT @id_pais = id_pais FROM cat.Pais WHERE nombre = @nombre;
            IF @id_pais IS NOT NULL EXEC cat.usp_Pais_Modificacion @id_pais, @nombre, @confederacion, @id_moneda, @huso_horario;
            ELSE EXEC cat.usp_Pais_Alta @nombre, @confederacion, @id_moneda, @huso_horario;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1; 
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @nro_fila, @dato, @msg;
        END CATCH;

        FETCH NEXT FROM cur_stg INTO @nombre, @confederacion, @codigo_moneda, @huso_horario;
    END

    CLOSE cur_stg; 
    DEALLOCATE cur_stg;

    SET @fecha_fin = SYSDATETIME();
    EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin, @filas_leidas, @filas_ok, @filas_error;
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
    DECLARE @fecha_fin DATETIME2;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio) 
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_Ciudad;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.stg_Ciudad FROM ''' + @archivo + N''' 
                     WITH (
                         FIRSTROW = 2, 
                         FIELDTERMINATOR = '','', 
                         ROWTERMINATOR = ''
'', 
                         CODEPAGE = ''65001''
                     );';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        DECLARE @err_bulk NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @fecha_fin_err DATETIME2 = SYSDATETIME();
        EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin_err, 0, 0, 1;
        EXEC imp.usp_ErrorImportacion_Alta @id_log, 0, @archivo, @err_bulk;
        THROW 50600, @err_bulk, 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_Ciudad);

    DECLARE @nombre NVARCHAR(100), @pais VARCHAR(100), @huso_horario VARCHAR(50);
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);
    DECLARE @nro_fila INT = 1;
    DECLARE @id_ciudad INT, @id_pais INT;

    DECLARE cur_stg CURSOR LOCAL FAST_FORWARD FOR 
        SELECT LTRIM(RTRIM(nombre)), LTRIM(RTRIM(pais)), LTRIM(RTRIM(huso_horario)) FROM imp.stg_Ciudad;
    
    OPEN cur_stg;
    FETCH NEXT FROM cur_stg INTO @nombre, @pais, @huso_horario;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @nro_fila += 1;
        SET @dato = CONCAT(@nombre, ' | ', @pais, ' | ', @huso_horario);
        SET @id_ciudad = NULL; SET @id_pais = NULL;

        BEGIN TRY
            SELECT @id_pais = id_pais FROM cat.Pais WHERE nombre = @pais;
            IF @id_pais IS NULL THROW 50613, 'Pais asociado no encontrado.', 1;
            SELECT @id_ciudad = id_ciudad FROM cat.Ciudad WHERE nombre = @nombre AND id_pais = @id_pais;
            IF @id_ciudad IS NOT NULL EXEC cat.usp_Ciudad_Modificacion @id_ciudad, @nombre, @id_pais, @huso_horario;
            ELSE EXEC cat.usp_Ciudad_Alta @nombre, @id_pais, @huso_horario;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1; 
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @nro_fila, @dato, @msg;
        END CATCH;

        FETCH NEXT FROM cur_stg INTO @nombre, @pais, @huso_horario;
    END

    CLOSE cur_stg; 
    DEALLOCATE cur_stg;

    SET @fecha_fin = SYSDATETIME();
    EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin, @filas_leidas, @filas_ok, @filas_error;
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
    DECLARE @fecha_fin DATETIME2;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio) 
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_FranjaHoraria;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.stg_FranjaHoraria FROM ''' + @archivo + N''' 
                     WITH (
                         FIRSTROW = 2, 
                         FIELDTERMINATOR = '','', 
                         ROWTERMINATOR = ''
'', 
                         CODEPAGE = ''65001''
                     );';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        DECLARE @err_bulk NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @fecha_fin_err DATETIME2 = SYSDATETIME();
        EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin_err, 0, 0, 1;
        EXEC imp.usp_ErrorImportacion_Alta @id_log, 0, @archivo, @err_bulk;
        THROW 50600, @err_bulk, 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_FranjaHoraria);

    DECLARE @nombre VARCHAR(30), @hora_desde TIME(0), @hora_hasta TIME(0), @es_prime_time BIT;
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);
    DECLARE @nro_fila INT = 1;
    DECLARE @id_franja INT;

    DECLARE cur_stg CURSOR LOCAL FAST_FORWARD FOR 
        SELECT LTRIM(RTRIM(nombre)), hora_desde, hora_hasta, es_prime_time FROM imp.stg_FranjaHoraria;
    
    OPEN cur_stg;
    FETCH NEXT FROM cur_stg INTO @nombre, @hora_desde, @hora_hasta, @es_prime_time;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @nro_fila += 1;
        SET @dato = CONCAT(@nombre, ' | ', @hora_desde, ' - ', @hora_hasta, ' | Prime: ', @es_prime_time);
        SET @id_franja = NULL;

        BEGIN TRY
            SELECT @id_franja = id_franja_horaria FROM pub.FranjaHoraria WHERE nombre = @nombre;
            IF @id_franja IS NOT NULL EXEC pub.usp_FranjaHoraria_Modificacion @id_franja, @nombre, @hora_desde, @hora_hasta, @es_prime_time;
            ELSE EXEC pub.usp_FranjaHoraria_Alta @nombre, @hora_desde, @hora_hasta, @es_prime_time;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1; 
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @nro_fila, @dato, @msg;
        END CATCH;

        FETCH NEXT FROM cur_stg INTO @nombre, @hora_desde, @hora_hasta, @es_prime_time;
    END

    CLOSE cur_stg; 
    DEALLOCATE cur_stg;

    SET @fecha_fin = SYSDATETIME();
    EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin, @filas_leidas, @filas_ok, @filas_error;
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
    DECLARE @fecha_fin DATETIME2;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio) 
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_Tarifa;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.stg_Tarifa FROM ''' + @archivo + N''' 
                     WITH (
                         FIRSTROW = 2, 
                         FIELDTERMINATOR = '','', 
                         ROWTERMINATOR = ''
'', 
                         CODEPAGE = ''65001''
                     );';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        DECLARE @err_bulk NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @fecha_fin_err DATETIME2 = SYSDATETIME();
        EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin_err, 0, 0, 1;
        EXEC imp.usp_ErrorImportacion_Alta @id_log, 0, @archivo, @err_bulk;
        THROW 50600, @err_bulk, 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_Tarifa);

    DECLARE @anio_torneo SMALLINT, @fase VARCHAR(30), @franja VARCHAR(30), @monto DECIMAL(12,2), @codigo_moneda CHAR(3);
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);
    DECLARE @nro_fila INT = 1;
    DECLARE @id_tarifa INT, @id_torneo INT, @id_fase INT, @id_franja INT, @id_moneda INT;

    DECLARE cur_stg CURSOR LOCAL FAST_FORWARD FOR 
        SELECT anio_torneo, LTRIM(RTRIM(fase)), LTRIM(RTRIM(franja)), monto, LTRIM(RTRIM(codigo_moneda)) FROM imp.stg_Tarifa;
    
    OPEN cur_stg;
    FETCH NEXT FROM cur_stg INTO @anio_torneo, @fase, @franja, @monto, @codigo_moneda;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @nro_fila += 1;
        SET @dato = CONCAT(@fase, ' | ', @franja, ' | ', @monto, ' ', @codigo_moneda);
        SET @id_tarifa = NULL; SET @id_torneo = NULL; SET @id_fase = NULL; SET @id_franja = NULL; SET @id_moneda = NULL;

        BEGIN TRY
            SELECT @id_torneo = id_torneo FROM comp.Torneo WHERE anio = @anio_torneo;
            IF @id_torneo IS NULL THROW 50615, 'Torneo no encontrado.', 1;
            SELECT @id_fase = id_fase FROM comp.Fase WHERE nombre = @fase;
            IF @id_fase IS NULL THROW 50615, 'Fase no encontrada.', 1;
            SELECT @id_franja = id_franja_horaria FROM pub.FranjaHoraria WHERE nombre = @franja;
            IF @id_franja IS NULL THROW 50615, 'Franja Horaria no encontrada.', 1;
            SELECT @id_moneda = id_moneda FROM cat.Moneda WHERE codigo_iso = @codigo_moneda;
            IF @id_moneda IS NULL THROW 50615, 'Moneda no encontrada.', 1;
            SELECT @id_tarifa = id_tarifa FROM pub.Tarifa WHERE id_torneo = @id_torneo AND id_fase = @id_fase AND id_franja_horaria = @id_franja;
            IF @id_tarifa IS NOT NULL EXEC pub.usp_Tarifa_Modificacion @id_tarifa, @monto, @id_moneda;
            ELSE EXEC pub.usp_Tarifa_Alta @id_torneo, @id_fase, @id_franja, @monto, @id_moneda;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1; 
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @nro_fila, @dato, @msg;
        END CATCH;

        FETCH NEXT FROM cur_stg INTO @anio_torneo, @fase, @franja, @monto, @codigo_moneda;
    END

    CLOSE cur_stg; 
    DEALLOCATE cur_stg;

    SET @fecha_fin = SYSDATETIME();
    EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin, @filas_leidas, @filas_ok, @filas_error;
END
GO

-- 3.7 TipoCambio
CREATE OR ALTER PROCEDURE imp.usp_ImportarTipoCambio_CSV
    @archivo VARCHAR(260),
    @fuente  VARCHAR(100) = 'Frankfurter API'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_log INT;
    DECLARE @filas_leidas INT = 0, @filas_ok INT = 0, @filas_error INT = 0;
    DECLARE @fecha_fin DATETIME2;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio) 
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_TipoCambio;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.stg_TipoCambio FROM ''' + @archivo + N''' 
                     WITH (
                         FIRSTROW = 2, 
                         FIELDTERMINATOR = '','', 
                         ROWTERMINATOR = ''
'', 
                         CODEPAGE = ''65001''
                     );';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        DECLARE @err_bulk NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @fecha_fin_err DATETIME2 = SYSDATETIME();
        EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin_err, 0, 0, 1;
        EXEC imp.usp_ErrorImportacion_Alta @id_log, 0, @archivo, @err_bulk;
        THROW 50600, @err_bulk, 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_TipoCambio);

    DECLARE @fecha DATE, @moneda_base CHAR(3), @moneda_cotizada CHAR(3), @tasa DECIMAL(18,6);
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);
    DECLARE @nro_fila INT = 1;
    DECLARE @id_moneda INT;

    DECLARE cur_stg CURSOR LOCAL FAST_FORWARD FOR 
        SELECT fecha, LTRIM(RTRIM(moneda_base)), LTRIM(RTRIM(moneda_cotizada)), tasa FROM imp.stg_TipoCambio;
    
    OPEN cur_stg;
    FETCH NEXT FROM cur_stg INTO @fecha, @moneda_base, @moneda_cotizada, @tasa;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @nro_fila += 1;
        SET @dato = CONCAT(@fecha, ' | ', @moneda_base, '/', @moneda_cotizada, ' | ', @tasa);
        SET @id_moneda = NULL;

        BEGIN TRY
            SELECT @id_moneda = id_moneda FROM cat.Moneda WHERE codigo_iso = @moneda_cotizada;
            IF @id_moneda IS NULL THROW 50631, 'Moneda cotizada no registrada en cat.Moneda.', 1;
            IF EXISTS (SELECT 1 FROM cat.TipoCambio WHERE id_moneda = @id_moneda AND fecha = @fecha)
                EXEC cat.usp_TipoCambio_Modificacion @id_moneda, @fecha, @tasa;
            ELSE
                EXEC cat.usp_TipoCambio_Alta @id_moneda, @fecha, @tasa;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1; 
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @nro_fila, @dato, @msg;
        END CATCH;

        FETCH NEXT FROM cur_stg INTO @fecha, @moneda_base, @moneda_cotizada, @tasa;
    END

    CLOSE cur_stg; 
    DEALLOCATE cur_stg;

    SET @fecha_fin = SYSDATETIME();
    EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin, @filas_leidas, @filas_ok, @filas_error;
END
GO


-- 3.8 IndicadorEconomico
CREATE OR ALTER PROCEDURE imp.usp_ImportarIndicadorEconomico_JSON
    @archivo VARCHAR(260),
    @fuente  VARCHAR(100) = 'Banco Mundial (API JSON)'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_log INT;
    DECLARE @filas_leidas INT = 0, @filas_ok INT = 0, @filas_error INT = 0;
    DECLARE @fecha_fin DATETIME2;

    -- 1. Registro de auditoría inicial
    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio) 
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    -- 2. Limpieza de staging
    TRUNCATE TABLE imp.stg_IndicadorEconomico;

    -- 3. Lectura del archivo JSON físico mediante OPENROWSET
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @json NVARCHAR(MAX);
    
    BEGIN TRY
        SET @sql = N'SELECT @json_out = BulkColumn FROM OPENROWSET(BULK ''' + @archivo + N''', SINGLE_CLOB) AS x;';
        EXEC sp_executesql @sql, N'@json_out NVARCHAR(MAX) OUTPUT', @json_out = @json OUTPUT;

        -- Inserción en staging mapeando las claves del JSON plano generado por Python
        INSERT INTO imp.stg_IndicadorEconomico (pais, anio, codigo_indicador, valor)
        SELECT pais, anio, codigo_indicador, valor
        FROM OPENJSON(@json) WITH (
            pais NVARCHAR(100) '$.REF_AREA',
            anio SMALLINT '$.TIME_PERIOD',
            codigo_indicador VARCHAR(30) '$.INDICATOR',
            valor DECIMAL(18,2) '$.OBS_VALUE'
        );
    END TRY
    BEGIN CATCH
        DECLARE @err_bulk NVARCHAR(4000) = ERROR_MESSAGE();
        SET @fecha_fin = SYSDATETIME();
        EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin, 0, 0, 1;
        EXEC imp.usp_ErrorImportacion_Alta @id_log, 0, @archivo, @err_bulk;
        THROW 50620, 'Error al leer y parsear el archivo JSON de Indicadores Economicos.', 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_IndicadorEconomico);

    -- 4. Procesamiento fila por fila mediante Cursor desacoplado
    DECLARE @pais NVARCHAR(100), @anio SMALLINT, @codigo_indicador VARCHAR(30), @valor DECIMAL(18,2);
    DECLARE @id_pais INT;
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);
    DECLARE @nro_fila INT = 0;

    DECLARE cur_ind CURSOR LOCAL FAST_FORWARD FOR 
        SELECT LTRIM(RTRIM(pais)), anio, LTRIM(RTRIM(codigo_indicador)), valor 
        FROM imp.stg_IndicadorEconomico;
    
    OPEN cur_ind;
    FETCH NEXT FROM cur_ind INTO @pais, @anio, @codigo_indicador, @valor;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @nro_fila += 1;
        SET @id_pais = NULL; 
        SET @dato = CONCAT(@pais, ' | ', @anio, ' | ', @codigo_indicador, ' | ', @valor);

        BEGIN TRY
            -- Búsqueda del país contemplando tanto el nombre como los códigos de equivalencia (ISO Alpha-3)
            SELECT @id_pais = p.id_pais 
            FROM cat.Pais p 
            LEFT JOIN imp.stg_PaisEquivalencia eq ON eq.nombre_pais = p.nombre 
            WHERE p.nombre = @pais OR eq.codigo_iso = @pais;

            IF @id_pais IS NULL 
                THROW 50621, 'Pais no encontrado en cat.Pais ni en equivalencias.', 1;

            -- Lógica Upsert delegada en los ABM corporativos
            IF EXISTS (SELECT 1 FROM cat.IndicadorEconomico WHERE id_pais = @id_pais AND anio = @anio AND codigo_indicador = @codigo_indicador)
                EXEC cat.usp_IndicadorEconomico_Modificacion @id_pais, @anio, @codigo_indicador, @valor;
            ELSE
                EXEC cat.usp_IndicadorEconomico_Alta @id_pais, @anio, @codigo_indicador, @valor;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1; 
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @nro_fila, @dato, @msg;
        END CATCH;

        FETCH NEXT FROM cur_ind INTO @pais, @anio, @codigo_indicador, @valor;
    END

    CLOSE cur_ind; 
    DEALLOCATE cur_ind;

    -- 5. Cierre de auditoría con totales reales
    SET @fecha_fin = SYSDATETIME();
    EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin, @filas_leidas, @filas_ok, @filas_error;
END
GO


-- 3.9 Feriado
CREATE OR ALTER PROCEDURE imp.usp_ImportarFeriados_JSON
    @archivo VARCHAR(260),
    @fuente  VARCHAR(100) = 'Nager.Date API'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_log INT;
    DECLARE @filas_leidas INT = 0, @filas_ok INT = 0, @filas_error INT = 0;
    DECLARE @fecha_fin DATETIME2;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio) 
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_Feriado;

    DECLARE @sql NVARCHAR(MAX);
    DECLARE @json NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'SELECT @json_out = BulkColumn FROM OPENROWSET(BULK ''' + @archivo + N''', SINGLE_CLOB) AS x;';
        EXEC sp_executesql @sql, N'@json_out NVARCHAR(MAX) OUTPUT', @json_out = @json OUTPUT;

        INSERT INTO imp.stg_Feriado (fecha, nombre, pais)
        SELECT fecha, nombre, pais
        FROM OPENJSON(@json) WITH (
            fecha DATE '$.date', 
            nombre VARCHAR(150) '$.name', 
            pais NVARCHAR(100) '$.countryCode'
        );
    END TRY
    BEGIN CATCH
        DECLARE @err_bulk NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @fecha_fin_err DATETIME2 = SYSDATETIME();
        EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin_err, 0, 0, 1;
        EXEC imp.usp_ErrorImportacion_Alta @id_log, 0, @archivo, @err_bulk;
        THROW 50600, @err_bulk, 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_Feriado);

    DECLARE @fecha DATE, @nombre VARCHAR(150), @pais NVARCHAR(100);
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);
    DECLARE @nro_fila INT = 1;
    DECLARE @id_pais INT;

    DECLARE cur_stg CURSOR LOCAL FAST_FORWARD FOR 
        SELECT fecha, LTRIM(RTRIM(nombre)), LTRIM(RTRIM(pais)) FROM imp.stg_Feriado;
    
    OPEN cur_stg;
    FETCH NEXT FROM cur_stg INTO @fecha, @nombre, @pais;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @nro_fila += 1;
        SET @dato = CONCAT(@fecha, ' | ', @nombre, ' | ', @pais);
        SET @id_pais = NULL;

        BEGIN TRY
            SELECT @id_pais = p.id_pais FROM cat.Pais p LEFT JOIN imp.stg_PaisEquivalencia eq ON eq.nombre_pais = p.nombre WHERE p.nombre = @pais OR eq.codigo_iso = @pais;
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
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @nro_fila, @dato, @msg;
        END CATCH;

        FETCH NEXT FROM cur_stg INTO @fecha, @nombre, @pais;
    END

    CLOSE cur_stg; 
    DEALLOCATE cur_stg;

    SET @fecha_fin = SYSDATETIME();
    EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin, @filas_leidas, @filas_ok, @filas_error;
END
GO


-- 3.10 Publicidad
CREATE OR ALTER PROCEDURE imp.usp_ImportarPublicidad_CSV
    @archivo VARCHAR(260),
    @fuente  VARCHAR(100) = 'Sistema de Importacion'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_log INT;
    DECLARE @filas_leidas INT = 0, @filas_ok INT = 0, @filas_error INT = 0;
    DECLARE @fecha_fin DATETIME2;

    INSERT INTO imp.LogImportacion (nombre_archivo, fuente, fecha_inicio) 
    VALUES (@archivo, @fuente, SYSDATETIME());
    SET @id_log = SCOPE_IDENTITY();

    TRUNCATE TABLE imp.stg_Publicidad;

    DECLARE @sql NVARCHAR(MAX);
    BEGIN TRY
        SET @sql = N'BULK INSERT imp.stg_Publicidad FROM ''' + @archivo + N''' 
                     WITH (
                         FIRSTROW = 2, 
                         FIELDTERMINATOR = '','', 
                         ROWTERMINATOR = ''
'', 
                         CODEPAGE = ''65001''
                     );';
        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        DECLARE @err_bulk NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @fecha_fin_err DATETIME2 = SYSDATETIME();
        EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin_err, 0, 0, 1;
        EXEC imp.usp_ErrorImportacion_Alta @id_log, 0, @archivo, @err_bulk;
        THROW 50600, @err_bulk, 1;
    END CATCH;

    SET @filas_leidas = (SELECT COUNT(*) FROM imp.stg_Publicidad);

    DECLARE @anunciante VARCHAR(100), @pais_anunciante NVARCHAR(100), @marca VARCHAR(100), @agencia VARCHAR(100), @campania VARCHAR(150), @fecha_desde DATE, @fecha_hasta DATE, @descripcion_campania VARCHAR(500), @mercado_objetivo NVARCHAR(100), @pieza_titulo VARCHAR(150), @pieza_idioma CHAR(2), @pieza_url VARCHAR(300);
    DECLARE @dato NVARCHAR(1000), @msg NVARCHAR(500);
    DECLARE @nro_fila INT = 1;
    DECLARE @id_pais_anu INT, @id_anunciante INT, @id_marca INT, @id_agencia INT, @id_campania INT, @id_pais_mer INT, @id_idioma INT, @id_pieza INT;

    DECLARE cur_stg CURSOR LOCAL FAST_FORWARD FOR 
        SELECT LTRIM(RTRIM(anunciante)), LTRIM(RTRIM(pais_anunciante)), LTRIM(RTRIM(marca)), LTRIM(RTRIM(agencia)), LTRIM(RTRIM(campania)), fecha_desde, fecha_hasta, LTRIM(RTRIM(descripcion_campania)), LTRIM(RTRIM(mercado_objetivo)), LTRIM(RTRIM(pieza_titulo)), LTRIM(RTRIM(pieza_idioma)), LTRIM(RTRIM(pieza_url)) FROM imp.stg_Publicidad;
    
    OPEN cur_stg;
    FETCH NEXT FROM cur_stg INTO @anunciante, @pais_anunciante, @marca, @agencia, @campania, @fecha_desde, @fecha_hasta, @descripcion_campania, @mercado_objetivo, @pieza_titulo, @pieza_idioma, @pieza_url;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @nro_fila += 1;
        SET @dato = CONCAT(@anunciante, ' | ', @marca, ' | ', @campania, ' | ', @pieza_titulo);
        SET @id_pais_anu = NULL; SET @id_anunciante = NULL; SET @id_marca = NULL; SET @id_agencia = NULL; SET @id_campania = NULL; SET @id_pais_mer = NULL; SET @id_idioma = NULL; SET @id_pieza = NULL;

        BEGIN TRY
            -- 1. Pais Anunciante
            SELECT @id_pais_anu = id_pais FROM cat.Pais WHERE nombre = @pais_anunciante;
            IF @id_pais_anu IS NULL THROW 50651, 'Pais del anunciante no encontrado.', 1;
            -- 2. Anunciante
            SELECT @id_anunciante = id_anunciante FROM pub.Anunciante WHERE nombre = @anunciante;
            IF @id_anunciante IS NULL BEGIN EXEC pub.usp_Anunciante_Alta @anunciante, @id_pais_anu; SELECT @id_anunciante = id_anunciante FROM pub.Anunciante WHERE nombre = @anunciante; END
            -- 3. Marca
            SELECT @id_marca = id_marca FROM pub.Marca WHERE id_anunciante = @id_anunciante AND nombre = @marca;
            IF @id_marca IS NULL BEGIN EXEC pub.usp_Marca_Alta @id_anunciante, @marca; SELECT @id_marca = id_marca FROM pub.Marca WHERE id_anunciante = @id_anunciante AND nombre = @marca; END
            -- 4. Agencia
            IF @agencia IS NOT NULL AND @agencia <> ''
            BEGIN
                SELECT @id_agencia = id_agencia FROM pub.Agencia WHERE nombre = @agencia;
                IF @id_agencia IS NULL BEGIN EXEC pub.usp_Agencia_Alta @agencia; SELECT @id_agencia = id_agencia FROM pub.Agencia WHERE nombre = @agencia; END
            END
            -- 5. Campania
            SELECT @id_campania = id_campania FROM pub.Campania WHERE titulo = @campania AND id_marca = @id_marca;
            IF @id_campania IS NULL BEGIN EXEC pub.usp_Campania_Alta @id_marca, @id_agencia, @campania, @fecha_desde, @fecha_hasta, @descripcion_campania; SELECT @id_campania = id_campania FROM pub.Campania WHERE titulo = @campania AND id_marca = @id_marca; END
            -- 6. Mercado Objetivo y CampaniaPais
            SELECT @id_pais_mer = id_pais FROM cat.Pais WHERE nombre = @mercado_objetivo;
            IF @id_pais_mer IS NULL THROW 50652, 'Pais mercado objetivo no encontrado.', 1;
            IF NOT EXISTS (SELECT 1 FROM pub.CampaniaPais WHERE id_campania = @id_campania AND id_pais = @id_pais_mer) EXEC pub.usp_CampaniaPais_Alta @id_campania, @id_pais_mer;
            -- 7. Idioma
            SELECT @id_idioma = id_idioma FROM cat.Idioma WHERE codigo_iso = @pieza_idioma;
            IF @id_idioma IS NULL THROW 50653, 'Idioma no encontrado.', 1;
            -- 8. Pieza Publicitaria
            SELECT @id_pieza = id_pieza_publicitaria FROM pub.PiezaPublicitaria WHERE titulo = @pieza_titulo AND id_campania = @id_campania;
            IF @id_pieza IS NULL EXEC pub.usp_PiezaPublicitaria_Alta @id_campania, @id_idioma, @id_pais_mer, @pieza_titulo, @pieza_url;
            ELSE EXEC pub.usp_PiezaPublicitaria_Modificacion @id_pieza, @id_campania, @id_idioma, @id_pais_mer, @pieza_titulo, @pieza_url;

            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            SET @filas_error += 1; 
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @nro_fila, @dato, @msg;
        END CATCH;

        FETCH NEXT FROM cur_stg INTO @anunciante, @pais_anunciante, @marca, @agencia, @campania, @fecha_desde, @fecha_hasta, @descripcion_campania, @mercado_objetivo, @pieza_titulo, @pieza_idioma, @pieza_url;
    END

    CLOSE cur_stg; 
    DEALLOCATE cur_stg;

    SET @fecha_fin = SYSDATETIME();
    EXEC imp.usp_LogImportacion_Modificacion @id_log, @fecha_fin, @filas_leidas, @filas_ok, @filas_error;
END
GO

/* =================================================================
   PARTE 3: ORDEN DE EJECUCION
   ================================================================= */
/*
-- 1. Catalogos Raiz (Independientes)
 EXEC imp.usp_ImportarMonedas_CSV         'C:\Mundial2026_Datos\monedas.csv';
 EXEC imp.usp_ImportarIdiomas_CSV         'C:\Mundial2026_Datos\idiomas.csv';
 EXEC imp.usp_ImportarFranjasHorarias_CSV 'C:\Mundial2026_Datos\franjas_comerciales.csv';

-- 2. Catalogos Geograficos (Dependen de Monedas)
 EXEC imp.usp_ImportarPaises_CSV          'C:\Mundial2026_Datos\paises.csv';
 EXEC imp.usp_ImportarCiudades_CSV        'C:\Mundial2026_Datos\ciudades.csv';

-- 3. Entorno Economico, Cultural y Precios (Dependen de Paises y Franjas)
 EXEC imp.usp_ImportarTipoCambio_CSV          'C:\Mundial2026_Datos\tipos_cambio_frankfurter.csv';
 EXEC imp.usp_ImportarIndicadorEconomico_JSON 'C:\Mundial2026_Datos\indicadores_bm.json';
 EXEC imp.usp_ImportarFeriados_JSON           'C:\Mundial2026_Datos\feriados_nagerdate.json';
 EXEC imp.usp_ImportarTarifas_CSV             'C:\Mundial2026_Datos\tarifas.csv';

-- 4. Modulo Comercial Global (Depende de Marcas, Paises e Idiomas)
 EXEC imp.usp_ImportarPublicidad_CSV          'C:\Mundial2026_Datos\dossier_publicidad.csv';

 */

 /* =================================================================
   PARTE 4: Verificacion
   ================================================================= */

/*
   -- 1. cat.Moneda
SELECT 'cat.Moneda' AS Tabla, * FROM cat.Moneda;

-- 2. cat.Idioma
SELECT 'cat.Idioma' AS Tabla, * FROM cat.Idioma;

-- 3. cat.Pais
SELECT 'cat.Pais' AS Tabla, * FROM cat.Pais;

-- 4. cat.Ciudad
SELECT 'cat.Ciudad' AS Tabla, * FROM cat.Ciudad;

-- 5. cat.IndicadorEconomico
SELECT 'cat.IndicadorEconomico' AS Tabla, * FROM cat.IndicadorEconomico;

-- 6. cat.TipoCambio
SELECT 'cat.TipoCambio' AS Tabla, * FROM cat.TipoCambio;

-- 7. cat.Feriado
SELECT 'cat.Feriado' AS Tabla, * FROM cat.Feriado;

-- 8. pub.Anunciante
SELECT 'pub.Anunciante' AS Tabla, * FROM pub.Anunciante;

-- 9. pub.Marca
SELECT 'pub.Marca' AS Tabla, * FROM pub.Marca;

-- 10. pub.Agencia
SELECT 'pub.Agencia' AS Tabla, * FROM pub.Agencia;

-- 11. pub.Campania
SELECT 'pub.Campania' AS Tabla, * FROM pub.Campania;

-- 12. pub.CampaniaPais
SELECT 'pub.CampaniaPais' AS Tabla, * FROM pub.CampaniaPais;

-- 13. pub.PiezaPublicitaria
SELECT 'pub.PiezaPublicitaria' AS Tabla, * FROM pub.PiezaPublicitaria;

-- 14. pub.FranjaHoraria
SELECT 'pub.FranjaHoraria' AS Tabla, * FROM pub.FranjaHoraria;

-- 15. pub.Tarifa
SELECT 'pub.Tarifa' AS Tabla, * FROM pub.Tarifa;

-- 16. pub.ExhibicionPublicitaria
SELECT 'pub.ExhibicionPublicitaria' AS Tabla, * FROM pub.ExhibicionPublicitaria;

-- 17. imp.LogImportacion
SELECT 'imp.LogImportacion' AS Tabla, * FROM imp.LogImportacion;

-- 18. imp.ErrorImportacion
SELECT 'imp.ErrorImportacion' AS Tabla, * FROM imp.ErrorImportacion;

GO
*/
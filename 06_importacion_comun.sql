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
 Objetivo: crear lo que comparten los SP de importacion:
   imp.EquivalenciaPais: tabla que dice "este nombre de pais que
      viene en el archivo (en ingles) es este pais de cat.Pais"
    imp.usp_BuscarPais: devuelve el id de un pais buscandolo por su
      nombre en cat.Pais y, si no esta, en las equivalencias.
	  devuelve parametro output
    imp.usp_ConvertirFecha: convierte una fecha escrita como en
      Wikipedia ("17 May 2000 (aged 26)" o "June 11, 2026") a date.
	  devuelve parametro output
 Orden: 00 -> 01 -> 02 -> 03 -> este script 
=====================================================================
*/

USE MundialDB;
GO


/* =====================================================================
   1. TABLA imp.EquivalenciaPais
   Se crea solo si no existe, asi el script se puede volver a ejecutar.
   ===================================================================== */

IF OBJECT_ID('imp.EquivalenciaPais') IS NULL
BEGIN
    CREATE TABLE imp.EquivalenciaPais (
        nombre_externo varchar(100) NOT NULL PRIMARY KEY,   -- como viene en el archivo
        id_pais        int          NOT NULL                -- a que pais corresponde
            CONSTRAINT FK_EquivalenciaPais_id_pais REFERENCES cat.Pais (id_pais)
    );
END
GO


/* ---------- ALTA ---------- */
CREATE OR ALTER PROCEDURE imp.usp_EquivalenciaPais_Alta
    @nombre_externo varchar(100),
    @id_pais        int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF @nombre_externo IS NULL OR @nombre_externo = ''
        SET @err = @err + ' - El nombre externo es obligatorio.';

    IF NOT EXISTS (SELECT 1 FROM cat.Pais WHERE id_pais = @id_pais)
        SET @err = @err + ' - El pais no existe.';

    IF EXISTS (SELECT 1 FROM imp.EquivalenciaPais WHERE nombre_externo = @nombre_externo)
        SET @err = @err + ' - Ya existe una equivalencia para ese nombre.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_EquivalenciaPais_Alta:' + @err;
        THROW 50451, @err, 1;
    END

    INSERT INTO imp.EquivalenciaPais (nombre_externo, id_pais)
    VALUES (@nombre_externo, @id_pais);
END
GO

/* ---------- MODIFICACION ---------- */
CREATE OR ALTER PROCEDURE imp.usp_EquivalenciaPais_Modificacion
    @nombre_externo varchar(100),
    @id_pais        int
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM imp.EquivalenciaPais WHERE nombre_externo = @nombre_externo)
        SET @err = @err + ' - La equivalencia no existe.';

    IF NOT EXISTS (SELECT 1 FROM cat.Pais WHERE id_pais = @id_pais)
        SET @err = @err + ' - El pais no existe.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_EquivalenciaPais_Modificacion:' + @err;
        THROW 50452, @err, 1;
    END

    UPDATE imp.EquivalenciaPais
    SET id_pais = @id_pais
    WHERE nombre_externo = @nombre_externo;
END
GO

/* ---------- BAJA ---------- */
CREATE OR ALTER PROCEDURE imp.usp_EquivalenciaPais_Baja
    @nombre_externo varchar(100)
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM imp.EquivalenciaPais WHERE nombre_externo = @nombre_externo)
        SET @err = @err + ' - La equivalencia no existe.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_EquivalenciaPais_Baja:' + @err;
        THROW 50453, @err, 1;
    END

    DELETE FROM imp.EquivalenciaPais WHERE nombre_externo = @nombre_externo;
END
GO


/* =====================================================================
   2. imp.usp_BuscarPais
   ===================================================================== */

CREATE OR ALTER PROCEDURE imp.usp_BuscarPais
    @nombre  nvarchar(100),
    @id_pais int OUTPUT
AS
BEGIN
    SET @id_pais = NULL;

    SELECT @id_pais = id_pais FROM cat.Pais WHERE nombre = LTRIM(RTRIM(@nombre));

    IF @id_pais IS NULL
        SELECT @id_pais = id_pais FROM imp.EquivalenciaPais WHERE nombre_externo = LTRIM(RTRIM(@nombre));
END
GO


/* =====================================================================
   3. imp.usp_ConvertirFecha
   ===================================================================== */

CREATE OR ALTER PROCEDURE imp.usp_ConvertirFecha
    @texto nvarchar(60),
    @fecha date OUTPUT
AS
BEGIN
    DECLARE @t nvarchar(60), @resto nvarchar(60);
    DECLARE @p1 nvarchar(20), @p2 nvarchar(20), @anio nvarchar(4);
    DECLARE @dia nvarchar(2), @mes_txt nvarchar(20), @mes int;

    SET @fecha = NULL;

    -- a) limpiar
    SET @t = REPLACE(REPLACE(ISNULL(@texto, ''), NCHAR(160), ' '), ',', '');
    IF CHARINDEX('(', @t) > 0
        SET @t = LEFT(@t, CHARINDEX('(', @t) - 1);
    SET @t = LTRIM(RTRIM(@t));

    -- tiene que tener al menos dos espacios (tres palabras)
    IF CHARINDEX(' ', @t) = 0
        RETURN;

    -- b) primera palabra, segunda palabra y anio (las ultimas 4 letras)
    SET @p1 = LEFT(@t, CHARINDEX(' ', @t) - 1);
    SET @resto = LTRIM(SUBSTRING(@t, CHARINDEX(' ', @t) + 1, 60));
    IF CHARINDEX(' ', @resto) = 0
        RETURN;
    SET @p2 = LEFT(@resto, CHARINDEX(' ', @resto) - 1);
    SET @anio = RIGHT(@t, 4);

    -- c) cual es el dia y cual el mes
    IF TRY_CONVERT(int, @p1) IS NOT NULL
    BEGIN
        SET @dia = @p1;
        SET @mes_txt = @p2;
    END
    ELSE
    BEGIN
        SET @dia = @p2;
        SET @mes_txt = @p1;
    END

    -- d) numero de mes
    SET @mes = (CHARINDEX(LEFT(@mes_txt, 3), 'JanFebMarAprMayJunJulAugSepOctNovDec') + 2) / 3;
    IF @mes = 0 OR TRY_CONVERT(int, @dia) IS NULL
        RETURN;

    -- e) armar aaaa-mm-dd y convertir
    SET @fecha = TRY_CONVERT(date, @anio + '-' + RIGHT('0' + CAST(@mes AS varchar(2)), 2) + '-' + RIGHT('0' + @dia, 2));
END

GO





---sp para equivaler paises

IF OBJECT_ID('imp.stg_equivalencias') IS NULL
BEGIN
    CREATE TABLE imp.stg_equivalencias (
        nro_fila       int IDENTITY(1,1) NOT NULL,
        nombre_externo nvarchar(100) NULL,
        nombre_pais    nvarchar(100) NULL
    );
END
GO

-- Vista para el BULK INSERT: mismas columnas que el archivo, sin nro_fila
CREATE OR ALTER VIEW imp.vw_stg_equivalencias_carga
AS
    SELECT nombre_externo, nombre_pais
    FROM imp.stg_equivalencias;
GO

CREATE OR ALTER PROCEDURE imp.usp_Importar_EquivalenciasPais
    @archivo varchar(260)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @err nvarchar(2000), @msg nvarchar(2000), @sql nvarchar(1000);
    DECLARE @id_log int, @ahora datetime2(0);
    DECLARE @i int, @max int, @linea int, @nuevas int, @actualizadas int, @errores int, @ok int;
    DECLARE @externo nvarchar(100), @pais nvarchar(100), @id_pais int;
    DECLARE @dato nvarchar(1000), @err_fila nvarchar(2000);

    -- Validacion general
    SET @err = '';
    IF @archivo IS NULL OR @archivo = ''
        SET @err = @err + ' - La ruta del archivo es obligatoria.';
    IF @err <> ''
    BEGIN
        SET @err = 'usp_Importar_EquivalenciasPais:' + @err;
        THROW 50705, @err, 1;
    END

    SET @nuevas = 0;
    SET @actualizadas = 0;
    SET @errores = 0;

    -- 1) Abrir el registro de la importacion
    SET @ahora = SYSDATETIME();
    EXEC imp.usp_LogImportacion_Alta @archivo, 'Wikipedia - nombres de paises en castellano (scraping)',
                                     @ahora, NULL, NULL, NULL, NULL;
    SELECT @id_log = MAX(id_log_importacion) FROM imp.LogImportacion;

    -- 2) Vaciar la staging y cargar el archivo
    TRUNCATE TABLE imp.stg_equivalencias;

    -- SQL dinamico SOLO porque BULK INSERT no acepta una variable como nombre de archivo
    SET @sql = N'BULK INSERT imp.vw_stg_equivalencias_carga FROM ''' + @archivo + N'''
                 WITH (FIELDTERMINATOR = '';'', ROWTERMINATOR = ''\n'', CODEPAGE = ''65001'', FIRSTROW = 2);';
    BEGIN TRY
        EXEC (@sql);
    END TRY
    BEGIN CATCH
        SET @msg = 'usp_Importar_EquivalenciasPais: - No se pudo leer el archivo: ' + ERROR_MESSAGE();
        SET @err = LEFT(@msg, 500);
        EXEC imp.usp_ErrorImportacion_Alta @id_log, NULL, @archivo, @err;
        SET @ahora = SYSDATETIME();
        EXEC imp.usp_LogImportacion_Modificacion @id_log, @ahora, 0, 0, 0;
        THROW 50705, @msg, 1;
    END CATCH

    SELECT @max = COUNT(*) FROM imp.stg_equivalencias;
    SET @i = 1;

    -- 3) Fila por fila (sin cursores)
    WHILE @i <= @max
    BEGIN
        SET @externo = NULL;
        SET @pais = NULL;
        SET @id_pais = NULL;
        SET @linea = @i + 1;      -- linea en el archivo (la 1 son los titulos)

        SELECT @externo = NULLIF(LTRIM(RTRIM(nombre_externo)), ''),
               @pais    = NULLIF(LTRIM(RTRIM(nombre_pais)), '')
        FROM imp.stg_equivalencias WHERE nro_fila = @i;

        SET @dato = ISNULL(@externo, '') + ';' + ISNULL(@pais, '');

        BEGIN TRY
            SET @err_fila = '';

            IF @externo IS NULL
                SET @err_fila = @err_fila + ' - Falta el nombre externo.';

            SELECT @id_pais = id_pais FROM cat.Pais WHERE nombre = @pais;
            IF @id_pais IS NULL
                SET @err_fila = @err_fila + ' - El pais no esta en cat.Pais (' + ISNULL(@pais, 'vacio') + ').';

            IF @err_fila <> ''
            BEGIN
                SET @err_fila = 'usp_Importar_EquivalenciasPais:' + @err_fila;
                THROW 50706, @err_fila, 1;
            END

            -- Upsert con los SP de ABM
            IF EXISTS (SELECT 1 FROM imp.EquivalenciaPais WHERE nombre_externo = @externo)
            BEGIN
                EXEC imp.usp_EquivalenciaPais_Modificacion @externo, @id_pais;
                SET @actualizadas = @actualizadas + 1;
            END
            ELSE
            BEGIN
                EXEC imp.usp_EquivalenciaPais_Alta @externo, @id_pais;
                SET @nuevas = @nuevas + 1;
            END
        END TRY
        BEGIN CATCH
            SET @err = LEFT(ERROR_MESSAGE(), 500);
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @linea, @dato, @err;
            SET @errores = @errores + 1;
        END CATCH

        SET @i = @i + 1;
    END

    -- 4) Cerrar el registro y mostrar el resultado
    SET @ahora = SYSDATETIME();
    SET @ok = @nuevas + @actualizadas;
    EXEC imp.usp_LogImportacion_Modificacion @id_log, @ahora, @max, @ok, @errores;

    SELECT @id_log AS id_log, @max AS filas_leidas, @nuevas AS equivalencias_nuevas,
           @actualizadas AS equivalencias_actualizadas, @errores AS filas_con_error;

    SELECT nro_linea, dato_original, mensaje
    FROM imp.ErrorImportacion
    WHERE id_log_importacion = @id_log
    ORDER BY nro_linea;
END
GO


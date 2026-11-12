/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 6 - Script 06: Importacion de Disciplina (arbitros)
 Grupo 02 - Comision 02-5600
 Integrantes: Miro, Saba.
              Mendez Camacho, Tatiana Antonella
              Rocha Escalera, Sheila
              Meira Da Cruz Saleiro, Gonzalo
 Fecha: 2026-10-23
 Objetivo: proceso de importacion del modulo disc (arbitros).
           Crea la tabla de staging imp.stg_Arbitro y el SP de importacion
           que recibe el nombre del archivo XML (scrapeado de Wikipedia) como
           parametro, lo carga a staging, valida e inserta mediante los SP ABM
           de la Entrega 5 (comp.usp_Persona_Alta / disc.usp_Arbitro_Alta),
           con importacion parcial y registro de errores en imp.ErrorImportacion.
           Requiere ejecutar antes: 00 (base y schemas), 01 (tablas, incluye
           imp.LogImportacion / imp.ErrorImportacion) y 02 (SP ABM de la E5).
=====================================================================
*/
USE MundialDB;
GO
IF OBJECT_ID('imp.stg_Arbitro') IS NULL
BEGIN
    CREATE TABLE imp.stg_Arbitro (
        id_stg INT IDENTITY(1,1) PRIMARY KEY,
        nombre NVARCHAR(200),
        apellido NVARCHAR(200),
        pais NVARCHAR(200),
        categoria NVARCHAR(200)
    );
END
GO

CREATE OR ALTER PROCEDURE imp.usp_ImportarArbitros
    @archivo VARCHAR(260),
    @fuente  VARCHAR(100) = 'Wikipedia - 2026 FIFA World Cup officials'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @id_log INT;
    DECLARE @filas_leidas INT = 0, @filas_ok INT = 0, @filas_error INT = 0;
    DECLARE @fecha_inicio DATETIME2(0) = SYSDATETIME();
    DECLARE @msg NVARCHAR(500);

    EXEC imp.usp_LogImportacion_Alta @archivo, @fuente, @fecha_inicio, NULL, NULL, NULL, NULL;
    SELECT @id_log = MAX(id_log_importacion) FROM imp.LogImportacion;


    -- ============ PARTE 2: cargar el XML a la staging ============

    -- A. Dejamos la staging vacia (y el IDENTITY vuelve a 1) para que cada corrida sea independiente
    TRUNCATE TABLE imp.stg_Arbitro;

    DECLARE @sql NVARCHAR(MAX);   -- aca armamos el SQL dinamico
    DECLARE @xml XML;             -- aca queda el contenido del archivo ya como XML

    -- B. Leer el archivo.
    -- OPENROWSET no acepta una variable como ruta, por eso armamos el texto del SQL
    -- y lo ejecutamos con sp_executesql. Es la unica parte dinamica del SP.
    BEGIN TRY
        SET @sql = N'SELECT @xml_out = CAST(x.BulkColumn AS XML)
                     FROM OPENROWSET(BULK ' + QUOTENAME(@archivo, '''') + N', SINGLE_BLOB) AS x;';

        -- @xml_out es una variable DENTRO del SQL dinamico; con OUTPUT la copiamos a nuestra @xml
        EXEC sp_executesql @sql,
                           N'@xml_out XML OUTPUT',
                           @xml_out = @xml OUTPUT;
    END TRY
    BEGIN CATCH
        -- Corte total: sin archivo no hay nada que importar.
        -- Se registra el error y se cierra el log antes de cortar, para que no quede abierto.
        SET @msg = 'No se pudo leer el archivo XML (ruta inexistente o sin permisos de lectura del servicio SQL).';
        EXEC imp.usp_ErrorImportacion_Alta @id_log, NULL, @archivo, @msg;
        EXEC imp.usp_LogImportacion_Modificacion @id_log, SYSDATETIME(), 0, 0, 0;
        THROW 50600, @msg, 1;
    END CATCH;

    -- C. Desarmar el XML: una fila de staging por cada <Arbitro>
    INSERT INTO imp.stg_Arbitro (nombre, apellido, pais, categoria)
    SELECT
        T.Arbitro.value('(nombre/text())[1]',    'NVARCHAR(200)'),
        T.Arbitro.value('(apellido/text())[1]',  'NVARCHAR(200)'),
        T.Arbitro.value('(pais/text())[1]',      'NVARCHAR(200)'),
        T.Arbitro.value('(categoria/text())[1]', 'NVARCHAR(200)')
    FROM @xml.nodes('/Arbitros/Arbitro') AS T(Arbitro);

    -- D. Contar lo leido
    SET @filas_leidas = @@ROWCOUNT;


    -- ============ PARTE 3: validar y upsertear fila por fila ============

    DECLARE @i INT = 1;
    DECLARE @max INT = ISNULL((SELECT MAX(id_stg) FROM imp.stg_Arbitro), 0);

    DECLARE @nombre NVARCHAR(200), @apellido NVARCHAR(200),
            @pais NVARCHAR(200),   @categoria NVARCHAR(200);
    DECLARE @id_pais INT, @id_persona INT;
    DECLARE @dato NVARCHAR(1000);   -- fila original, para guardarla si falla

    WHILE @i <= @max
    BEGIN
        -- Tomamos la fila @i de la staging (con espacios sobrantes recortados)
        SELECT @nombre    = LTRIM(RTRIM(nombre)),
               @apellido  = LTRIM(RTRIM(apellido)),
               @pais      = LTRIM(RTRIM(pais)),
               @categoria = LTRIM(RTRIM(categoria))
        FROM imp.stg_Arbitro
        WHERE id_stg = @i;

        SET @id_pais = NULL;
        SET @id_persona = NULL;
        SET @dato = CONCAT(@nombre, ' | ', @apellido, ' | ', @pais, ' | ', @categoria);

        BEGIN TRY
            -- 1) Validaciones propias del import (no escriben nada, van antes de la transaccion)
            IF @nombre IS NULL OR @nombre = ''
                THROW 50601, 'Falta el nombre.', 1;
            IF @apellido IS NULL OR @apellido = ''
                THROW 50602, 'Falta el apellido.', 1;
            IF @pais IS NULL OR @pais = ''
                THROW 50603, 'Falta el pais.', 1;

            IF @categoria IS NULL OR @categoria = ''
                SET @categoria = 'FIFA';                 -- default acordado
            IF @categoria NOT IN ('FIFA', 'Confederacion')
            BEGIN
                SET @msg = CONCAT('Categoria invalida: ', @categoria);
                THROW 50604, @msg, 1;
            END

            -- 2) Resolver el pais (texto -> id)
            EXEC imp.usp_BuscarPais @pais, @id_pais OUTPUT;
            IF @id_pais IS NULL
            BEGIN
                SET @msg = CONCAT('Pais no encontrado en cat.Pais: ', @pais);
                THROW 50605, @msg, 1;
            END

            -- Desde aca se escribe: Persona y Arbitro van juntos o no va ninguno
            BEGIN TRANSACTION;

            -- 3) Persona: si ya existe (nombre + apellido + pais) la reutilizamos; si no, la damos de alta
            SELECT @id_persona = id_persona
            FROM comp.Persona
            WHERE nombre = @nombre AND apellido = @apellido AND id_pais_nacionalidad = @id_pais;

            IF @id_persona IS NULL
            BEGIN
                EXEC comp.usp_Persona_Alta @nombre, @apellido, NULL, @id_pais, NULL, NULL;

                -- el Alta no devuelve el id: lo buscamos por la clave de negocio
                SELECT @id_persona = id_persona
                FROM comp.Persona
                WHERE nombre = @nombre AND apellido = @apellido AND id_pais_nacionalidad = @id_pais;
            END

            -- 4) Arbitro: si ya es arbitro actualizamos la categoria; si no, lo damos de alta
            IF EXISTS (SELECT 1 FROM disc.Arbitro WHERE id_arbitro = @id_persona)
                EXEC disc.usp_Arbitro_Modificacion @id_persona, @categoria;
            ELSE
                EXEC disc.usp_Arbitro_Alta @id_persona, @categoria;

            COMMIT TRANSACTION;
            SET @filas_ok += 1;
        END TRY
        BEGIN CATCH
            -- Si fallo algo despues de abrir la transaccion, se deshace (no queda una Persona huerfana)
            IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;

            -- El error de una fila NO corta el loop: se registra y se sigue con la siguiente
            SET @filas_error += 1;
            SET @msg = ERROR_MESSAGE();
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @i, @dato, @msg;
        END CATCH;

        SET @i += 1;
    END

    -- ============ PARTE 4: cerrar el log y mostrar resumen ============

    EXEC imp.usp_LogImportacion_Modificacion @id_log, SYSDATETIME(), @filas_leidas, @filas_ok, @filas_error;

    SELECT @id_log AS id_log_importacion,
           @filas_leidas AS filas_leidas,
           @filas_ok AS filas_ok,
           @filas_error AS filas_error;
END
GO
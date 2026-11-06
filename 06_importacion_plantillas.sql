/*
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 6 
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 04/11/2026
 Objetivo: importa las plantillas de listas de convocados de cada seleccion desde un archivo CSV.

 ORIGEN DE LOS DATOS (scraping)
   Pagina: https://en.wikipedia.org/wiki/2026_FIFA_World_Cup_squads

*/

USE MundialDB;
GO

IF OBJECT_ID('imp.stg_plantillas') IS NULL
BEGIN
    CREATE TABLE imp.stg_plantillas (
        nro_fila          int IDENTITY(1,1) NOT NULL,
        seleccion         nvarchar(100) NULL,
        dorsal            nvarchar(10) NULL,
        posicion          nvarchar(10) NULL,
        jugador           nvarchar(150) NULL,
        fecha_nacimiento  nvarchar(60) NULL,
        club              nvarchar(150) NULL,
        pais_club         nvarchar(100) NULL
    );
END
GO

CREATE OR ALTER VIEW imp.vw_stg_plantillas_carga
AS
    SELECT seleccion, dorsal, posicion, jugador, fecha_nacimiento, club, pais_club
    FROM imp.stg_plantillas;
GO

CREATE OR ALTER PROCEDURE imp.usp_Importar_Plantillas
    @archivo      varchar(260),   -- ruta completa del CSV, ej. 'C:\MundialDB\plantillas.csv'
    @anio_torneo  smallint,       -- torneo al que pertenecen las listas
    @fecha_alta   date = NULL     -- fecha de alta de los convocados
AS
BEGIN
   /*variables*/
    DECLARE @err nvarchar(2000), @msg nvarchar(2048), @sql nvarchar(1000);
    DECLARE @id_torneo int, @fecha_inicio date;
    DECLARE @id_log int, @ahora datetime2(0);
    DECLARE @i int, @max int, @linea int;
    DECLARE @altas int, @actualizados int, @errores int, @ok int;

    -- Datos de la fila que se esta procesando 
    DECLARE @seleccion nvarchar(100), @dorsal_txt nvarchar(10), @posicion nvarchar(10),
            @jugador nvarchar(150), @fecha_txt nvarchar(60), @club nvarchar(150), @pais_club nvarchar(100);
    DECLARE @dato nvarchar(1000);

    -- Datos de la fila ya convertidos / buscados en la base
    DECLARE @id_pais int, @id_pais_club int, @id_seleccion int, @id_club int, @id_posicion int,
            @id_persona int, @id_convocado int, @dorsal tinyint, @fecha_nac date,
            @nombre nvarchar(80), @apellido nvarchar(80), @err_fila nvarchar(2000);

    --Validaciones generales: si fallan, no se importa nada--
    SET @err = '';

    IF @archivo IS NULL OR @archivo = ''
        SET @err = @err + ' - La ruta del archivo es obligatoria.';

    SELECT @id_torneo = id_torneo, @fecha_inicio = fecha_inicio
    FROM comp.Torneo WHERE anio = @anio_torneo;

    IF @id_torneo IS NULL
        SET @err = @err + ' - El torneo no existe.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Importar_Plantillas:' + @err;
        THROW 50701, @err, 1;
    END

    IF @fecha_alta IS NULL
        SET @fecha_alta = @fecha_inicio;

    SET @altas = 0;
    SET @actualizados = 0;
    SET @errores = 0;


      -- 1) Abrir el registro de la importacion (imp.LogImportacion)--
    SET @ahora = SYSDATETIME();
    EXEC imp.usp_LogImportacion_Alta @archivo, 'Wikipedia - 2026 FIFA World Cup squads (scraping)',
                                     @ahora, NULL, NULL, NULL, NULL;
    SELECT @id_log = MAX(id_log_importacion) FROM imp.LogImportacion;

     --  2) Vaciar la staging y cargar el archivo en ella--
    TRUNCATE TABLE imp.stg_plantillas;

    SET @sql = N'BULK INSERT imp.vw_stg_plantillas_carga FROM ''' + @archivo + N'''
                 WITH (FIELDTERMINATOR = '';'', ROWTERMINATOR = ''\n'', CODEPAGE = ''65001'', FIRSTROW = 2);';

    BEGIN TRY
        EXEC (@sql);
    END TRY
    BEGIN CATCH
        -- El archivo no existe o no se pudo leer: se registra y se corta todo
        SET @msg = 'usp_Importar_Plantillas: - No se pudo leer el archivo: ' + ERROR_MESSAGE();
        SET @err = LEFT(@msg, 500);
        EXEC imp.usp_ErrorImportacion_Alta @id_log, NULL, @archivo, @err;
        SET @ahora = SYSDATETIME();
        EXEC imp.usp_LogImportacion_Modificacion @id_log, @ahora, 0, 0, 0;
        THROW 50701, @msg, 1;
    END CATCH

    SELECT @max = COUNT(*) FROM imp.stg_plantillas;
    SET @i = 1;

   
    --Recorrer fila por fila --
    WHILE @i <= @max
    BEGIN
        -- Limpiar las variables de la vuelta anterior
        SET @id_pais = NULL;      SET @id_pais_club = NULL; SET @id_seleccion = NULL;
        SET @id_club = NULL;      SET @id_posicion = NULL;  SET @id_persona = NULL;
        SET @id_convocado = NULL; SET @dorsal = NULL;       SET @fecha_nac = NULL;
        SET @nombre = NULL;       SET @apellido = NULL;
        SET @linea = @i + 1;      -- linea en el archivo (la 1 son los titulos)

        -- Leer la fila @i (sin espacios de mas; vacio = NULL)
        SELECT @seleccion  = NULLIF(LTRIM(RTRIM(seleccion)), ''),
               @dorsal_txt = NULLIF(LTRIM(RTRIM(dorsal)), ''),
               @posicion   = NULLIF(LTRIM(RTRIM(posicion)), ''),
               @jugador    = NULLIF(LTRIM(RTRIM(jugador)), ''),
               @fecha_txt  = NULLIF(LTRIM(RTRIM(fecha_nacimiento)), ''),
               @club       = NULLIF(LTRIM(RTRIM(club)), ''),
               @pais_club  = NULLIF(LTRIM(RTRIM(pais_club)), '')
        FROM imp.stg_plantillas WHERE nro_fila = @i;

        -- texto de la fila completa, para guardarlo si hay error
        SET @dato = ISNULL(@seleccion, '') + ';' + ISNULL(@dorsal_txt, '') + ';' + ISNULL(@posicion, '') + ';'
                  + ISNULL(@jugador, '') + ';' + ISNULL(@fecha_txt, '') + ';' + ISNULL(@club, '') + ';'
                  + ISNULL(@pais_club, '');

        BEGIN TRY
            -- TRANSFORMAR Y VALIDAR la fila.--
            SET @err_fila = '';

            -- Pais de la seleccion 
            EXEC imp.usp_BuscarPais @seleccion, @id_pais OUTPUT;
            IF @id_pais IS NULL
                SET @err_fila = @err_fila + ' - Pais de la seleccion desconocido (' + ISNULL(@seleccion, 'vacio') + ').';

            -- Dorsal: texto -> numero
            SET @dorsal = TRY_CONVERT(tinyint, @dorsal_txt);
            IF @dorsal IS NULL
                SET @err_fila = @err_fila + ' - Dorsal invalido (' + ISNULL(@dorsal_txt, 'vacio') + ').';

            -- Posicion: codigo de Wikipedia -> nombre en comp.Posicion
            SELECT @id_posicion = id_posicion FROM comp.Posicion
            WHERE nombre = CASE UPPER(@posicion)
                               WHEN 'GK' THEN 'Arquero'
                               WHEN 'DF' THEN 'Defensor'
                               WHEN 'MF' THEN 'Mediocampista'
                               WHEN 'FW' THEN 'Delantero'
                           END;
            IF @id_posicion IS NULL
                SET @err_fila = @err_fila + ' - Posicion invalida (' + ISNULL(@posicion, 'vacio') + '; se espera GK/DF/MF/FW).';

            IF CHARINDEX('(', @jugador) > 0
                SET @jugador = RTRIM(LEFT(@jugador, CHARINDEX('(', @jugador) - 1));

            IF @jugador IS NULL OR @jugador = ''
                SET @err_fila = @err_fila + ' - Falta el nombre del jugador.';
            ELSE IF CHARINDEX(' ', @jugador) > 0
            BEGIN
                SET @nombre   = LEFT(@jugador, CHARINDEX(' ', @jugador) - 1);
                SET @apellido = LTRIM(SUBSTRING(@jugador, CHARINDEX(' ', @jugador) + 1, 150));
            END
            ELSE
            BEGIN
                SET @nombre   = @jugador;
                SET @apellido = @jugador;
            END

            -- Fecha de nacimiento: "17 May 2000 (aged 26)" -> 2000-05-17
            EXEC imp.usp_ConvertirFecha @fecha_txt, @fecha_nac OUTPUT;
            IF @fecha_nac IS NULL
                SET @err_fila = @err_fila + ' - Fecha de nacimiento invalida (' + ISNULL(@fecha_txt, 'vacio') + ').';

            -- Si algo no se pudo convertir: error de la fila
            IF @err_fila <> ''
            BEGIN
                SET @err_fila = 'usp_Importar_Plantillas:' + @err_fila;
                THROW 50702, @err_fila, 1;
            END

            BEGIN TRANSACTION;

                -- Seleccion: si no existe en el torneo, se crea (sin grupo)
                SELECT @id_seleccion = id_seleccion FROM comp.Seleccion
                WHERE id_torneo = @id_torneo AND id_pais = @id_pais;

                IF @id_seleccion IS NULL
                BEGIN
                    EXEC comp.usp_Seleccion_Alta @id_torneo, @id_pais, NULL;
                    SELECT @id_seleccion = id_seleccion FROM comp.Seleccion
                    WHERE id_torneo = @id_torneo AND id_pais = @id_pais;
                END

                -- Club: solo si vino el club y se conoce su pais; si no existe, se crea
                IF @club IS NOT NULL
                BEGIN
                    EXEC imp.usp_BuscarPais @pais_club, @id_pais_club OUTPUT;
                    IF @id_pais_club IS NOT NULL
                    BEGIN
                        SELECT @id_club = id_club FROM comp.Club WHERE nombre = @club AND id_pais = @id_pais_club;
                        IF @id_club IS NULL
                        BEGIN
                            EXEC comp.usp_Club_Alta @club, @id_pais_club;
                            SELECT @id_club = id_club FROM comp.Club WHERE nombre = @club AND id_pais = @id_pais_club;
                        END
                    END
                END

                -- Jugador: ya existe esa persona?
                SELECT @id_persona = id_persona FROM comp.Persona
                WHERE nombre = @nombre AND apellido = @apellido
                  AND fecha_nacimiento = @fecha_nac AND id_pais_nacionalidad = @id_pais;

                IF @id_persona IS NULL
                BEGIN
                    -- NUEVO: Persona + Jugador + Convocado en un paso 
                    EXEC comp.usp_Jugador_AltaCompleta @nombre, @apellido, @fecha_nac, @id_pais, NULL, NULL,
                                                       @id_posicion, @id_seleccion, @dorsal, @id_club, @fecha_alta;
                    SET @altas = @altas + 1;
                END
                ELSE
                BEGIN
                    -- EXISTENTE: se actualiza (upsert)
                    IF EXISTS (SELECT 1 FROM comp.Jugador WHERE id_jugador = @id_persona)
                        EXEC comp.usp_Jugador_Modificacion @id_persona, @id_posicion;
                    ELSE
                        EXEC comp.usp_Jugador_Alta @id_persona, @id_posicion;

                    SELECT @id_convocado = id_convocado FROM comp.Convocado
                    WHERE id_seleccion = @id_seleccion AND id_jugador = @id_persona;

                    IF @id_convocado IS NULL
                        EXEC comp.usp_Convocado_Alta @id_seleccion, @id_persona, @dorsal, @id_club, @fecha_alta;
                    ELSE
                        EXEC comp.usp_Convocado_Modificacion @id_convocado, @dorsal, @id_club;

                    SET @actualizados = @actualizados + 1;
                END

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            
            IF XACT_STATE() <> 0
                ROLLBACK TRANSACTION;

            SET @err = LEFT(ERROR_MESSAGE(), 500);
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @linea, @dato, @err;
            SET @errores = @errores + 1;
        END CATCH

        SET @i = @i + 1;
    END

    /* Cerrar el registro de la importacion */
    SET @ahora = SYSDATETIME();
    SET @ok = @altas + @actualizados;
    EXEC imp.usp_LogImportacion_Modificacion @id_log, @ahora, @max, @ok, @errores;

    /* Resultado: resumen y detalle de errores */
    SELECT @id_log AS id_log, @max AS filas_leidas, @altas AS jugadores_nuevos,
           @actualizados AS jugadores_actualizados, @errores AS filas_con_error;

    SELECT nro_linea, dato_original, mensaje
    FROM imp.ErrorImportacion
    WHERE id_log_importacion = @id_log
    ORDER BY nro_linea;
END
GO
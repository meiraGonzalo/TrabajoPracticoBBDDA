/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 6 - Importacion de goles (scraping de Wikipedia)
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 16/11/2026
 Objetivo: importar goles_2026.csv, que genera scraping_mundial2026.py


   50811  error general (ruta vacia, torneo inexistente, archivo ilegible)
   50812  error de una fila
 Orden: despues de 06_importacion_comun, 06_importacion_partidos y
   06_importacion_plantillas (necesita partidos y convocados cargados).
=====================================================================
*/

USE MundialDB;
GO

/* =====================================================================
   1. Catalogos que necesitan los goles (si no estan, se cargan con su ABM)
   ===================================================================== */
IF NOT EXISTS (SELECT 1 FROM comp.Periodo WHERE nombre = 'Primer tiempo')          EXEC comp.usp_Periodo_Alta 'Primer tiempo', 1;
IF NOT EXISTS (SELECT 1 FROM comp.Periodo WHERE nombre = 'Segundo tiempo')         EXEC comp.usp_Periodo_Alta 'Segundo tiempo', 2;
IF NOT EXISTS (SELECT 1 FROM comp.Periodo WHERE nombre = 'Alargue 1')              EXEC comp.usp_Periodo_Alta 'Alargue 1', 3;
IF NOT EXISTS (SELECT 1 FROM comp.Periodo WHERE nombre = 'Alargue 2')              EXEC comp.usp_Periodo_Alta 'Alargue 2', 4;
IF NOT EXISTS (SELECT 1 FROM comp.Periodo WHERE nombre = 'Definicion por penales') EXEC comp.usp_Periodo_Alta 'Definicion por penales', 5;

IF NOT EXISTS (SELECT 1 FROM disc.TipoGol WHERE nombre = 'Jugada')    EXEC disc.usp_TipoGol_Alta 'Jugada';
IF NOT EXISTS (SELECT 1 FROM disc.TipoGol WHERE nombre = 'Penal')     EXEC disc.usp_TipoGol_Alta 'Penal';
IF NOT EXISTS (SELECT 1 FROM disc.TipoGol WHERE nombre = 'En contra') EXEC disc.usp_TipoGol_Alta 'En contra';
GO


/* =====================================================================
   2. Staging (todo texto) y vista para el BULK INSERT (sin nro_fila)
   ===================================================================== */
IF OBJECT_ID('imp.stg_goles') IS NULL
BEGIN
    CREATE TABLE imp.stg_goles (
        nro_fila         int IDENTITY(1,1) NOT NULL,
        nro_partido      nvarchar(10)  NULL,
        seleccion        nvarchar(100) NULL,
        jugador          nvarchar(160) NULL,
        minuto           nvarchar(10)  NULL,
        minuto_adicional nvarchar(10)  NULL,
        tipo             nvarchar(30)  NULL
    );
END
GO

CREATE OR ALTER VIEW imp.vw_stg_goles_carga
AS
    SELECT nro_partido, seleccion, jugador, minuto, minuto_adicional, tipo
    FROM imp.stg_goles;
GO


/* =====================================================================
   3. imp.usp_Importar_Goles @archivo, @anio_torneo
   ===================================================================== */
CREATE OR ALTER PROCEDURE imp.usp_Importar_Goles
    @archivo     varchar(260),
    @anio_torneo smallint
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @err nvarchar(2000), @msg nvarchar(2000), @sql nvarchar(1000);
    DECLARE @id_log int, @ahora datetime2(0), @id_torneo int;
    DECLARE @i int, @max int, @linea int, @nuevos int, @actualizados int, @errores int, @ok int;
    DECLARE @dato nvarchar(1000), @err_fila nvarchar(2000);
    -- datos de la fila
    DECLARE @nro_txt nvarchar(10), @sel_txt nvarchar(100), @jugador nvarchar(160);
    DECLARE @min_txt nvarchar(10), @adic_txt nvarchar(10), @tipo_txt nvarchar(30);
    DECLARE @nro_partido smallint, @minuto tinyint, @adicional tinyint;
    DECLARE @id_partido int, @id_pais int, @id_seleccion int, @id_partido_seleccion int;
    DECLARE @id_convocado int, @cant_convocados int, @id_alineacion int;
    DECLARE @id_tipo_gol int, @id_periodo int, @nombre_periodo varchar(30), @id_gol int;

    -- Validacion general
    SET @err = '';
    IF @archivo IS NULL OR @archivo = ''
        SET @err = @err + ' - La ruta del archivo es obligatoria.';
    SELECT @id_torneo = id_torneo FROM comp.Torneo WHERE anio = @anio_torneo;
    IF @id_torneo IS NULL
        SET @err = @err + ' - No existe el torneo del año ' + ISNULL(CAST(@anio_torneo AS varchar(4)), 'vacio') + '.';
    IF @err <> ''
    BEGIN
        SET @err = 'usp_Importar_Goles:' + @err;
        THROW 50811, @err, 1;
    END

    SET @nuevos = 0;
    SET @actualizados = 0;
    SET @errores = 0;

    -- 1) Abrir el registro de la importacion
    SET @ahora = SYSDATETIME();
    EXEC imp.usp_LogImportacion_Alta @archivo, 'Wikipedia - 2026 FIFA World Cup, goles por partido (scraping)',
                                     @ahora, NULL, NULL, NULL, NULL;
    SELECT @id_log = MAX(id_log_importacion) FROM imp.LogImportacion;

    -- 2) Vaciar la staging y cargar el archivo
    TRUNCATE TABLE imp.stg_goles;

    -- SQL dinamico SOLO porque BULK INSERT no acepta una variable como nombre de archivo
    SET @sql = N'BULK INSERT imp.vw_stg_goles_carga FROM ''' + @archivo + N'''
                 WITH (FIELDTERMINATOR = '';'', ROWTERMINATOR = ''\n'', CODEPAGE = ''65001'', FIRSTROW = 2);';
    BEGIN TRY
        EXEC (@sql);
    END TRY
    BEGIN CATCH
        SET @msg = 'usp_Importar_Goles: - No se pudo leer el archivo: ' + ERROR_MESSAGE();
        SET @err = LEFT(@msg, 500);
        EXEC imp.usp_ErrorImportacion_Alta @id_log, NULL, @archivo, @err;
        SET @ahora = SYSDATETIME();
        EXEC imp.usp_LogImportacion_Modificacion @id_log, @ahora, 0, 0, 0;
        THROW 50811, @msg, 1;
    END CATCH

    SELECT @max = COUNT(*) FROM imp.stg_goles;
    SET @i = 1;

    -- 3) Fila por fila (sin cursores)
    WHILE @i <= @max
    BEGIN
        -- Reiniciar las variables de la vuelta anterior
        SET @nro_txt = NULL;  SET @sel_txt = NULL;  SET @jugador = NULL;
        SET @min_txt = NULL;  SET @adic_txt = NULL; SET @tipo_txt = NULL;
        SET @nro_partido = NULL; SET @minuto = NULL; SET @adicional = NULL;
        SET @id_partido = NULL;  SET @id_pais = NULL; SET @id_seleccion = NULL;
        SET @id_partido_seleccion = NULL; SET @id_convocado = NULL; SET @cant_convocados = 0;
        SET @id_alineacion = NULL; SET @id_tipo_gol = NULL; SET @id_periodo = NULL;
        SET @nombre_periodo = NULL; SET @id_gol = NULL;
        SET @linea = @i + 1;      -- linea en el archivo (la 1 son los titulos)

        SELECT @nro_txt  = NULLIF(LTRIM(RTRIM(nro_partido)), ''),
               @sel_txt  = NULLIF(LTRIM(RTRIM(seleccion)), ''),
               @jugador  = NULLIF(LTRIM(RTRIM(jugador)), ''),
               @min_txt  = NULLIF(LTRIM(RTRIM(minuto)), ''),
               @adic_txt = NULLIF(LTRIM(RTRIM(minuto_adicional)), ''),
               @tipo_txt = NULLIF(LTRIM(RTRIM(tipo)), '')
        FROM imp.stg_goles WHERE nro_fila = @i;

        SET @dato = ISNULL(@nro_txt, '') + ';' + ISNULL(@sel_txt, '') + ';' + ISNULL(@jugador, '') + ';'
                  + ISNULL(@min_txt, '') + ';' + ISNULL(@adic_txt, '') + ';' + ISNULL(@tipo_txt, '');

        BEGIN TRY
            -- TRANSFORMAR Y VALIDAR la fila
            SET @err_fila = '';

            -- Partido
            SET @nro_partido = TRY_CONVERT(smallint, @nro_txt);
            SELECT @id_partido = id_partido FROM comp.Partido
            WHERE id_torneo = @id_torneo AND nro_partido = @nro_partido;
            IF @id_partido IS NULL
                SET @err_fila = @err_fila + ' - Partido desconocido (' + ISNULL(@nro_txt, 'vacio') + ').';

            -- Seleccion del autor y su participacion en el partido
            EXEC imp.usp_BuscarPais @sel_txt, @id_pais OUTPUT;
            SELECT @id_seleccion = id_seleccion FROM comp.Seleccion
            WHERE id_torneo = @id_torneo AND id_pais = @id_pais;
            IF @id_seleccion IS NULL
                SET @err_fila = @err_fila + ' - Seleccion desconocida (' + ISNULL(@sel_txt, 'vacio') + ').';

            SELECT @id_partido_seleccion = id_partido_seleccion FROM comp.PartidoSeleccion
            WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion;
            IF @id_partido IS NOT NULL AND @id_seleccion IS NOT NULL AND @id_partido_seleccion IS NULL
                SET @err_fila = @err_fila + ' - La seleccion ' + @sel_txt + ' no juega el partido ' + @nro_txt + '.';

            -- Jugador: convocado de esa seleccion con ese nombre completo
            -- (la importacion de plantillas guarda el primer nombre en "nombre" y el resto en
            --  "apellido"; si tenia un solo nombre, lo guarda en los dos)
            SELECT @id_convocado = MIN(c.id_convocado), @cant_convocados = COUNT(*)
            FROM comp.Convocado c
            JOIN comp.Persona pe ON pe.id_persona = c.id_jugador
            WHERE c.id_seleccion = @id_seleccion
              AND c.fecha_baja IS NULL
              AND (pe.nombre + ' ' + pe.apellido = @jugador
                   OR (pe.nombre = @jugador AND pe.apellido = @jugador));
            -- Si no aparece con el nombre completo, se busca por el apellido
            -- (ultima palabra del nombre), siempre dentro de esa seleccion
            IF @cant_convocados = 0 AND CHARINDEX(' ', @jugador) > 0
                SELECT @id_convocado = MIN(c.id_convocado), @cant_convocados = COUNT(*)
                FROM comp.Convocado c
                JOIN comp.Persona pe ON pe.id_persona = c.id_jugador
                WHERE c.id_seleccion = @id_seleccion
                  AND c.fecha_baja IS NULL
                  AND pe.nombre + ' ' + pe.apellido LIKE '% ' + RIGHT(@jugador, CHARINDEX(' ', REVERSE(@jugador)) - 1);

            IF @id_seleccion IS NOT NULL AND @cant_convocados = 0
                SET @err_fila = @err_fila + ' - ' + ISNULL(@jugador, 'Jugador vacio')
                              + ' no es convocado de ' + @sel_txt + '.';
            IF @cant_convocados > 1
                SET @err_fila = @err_fila + ' - Hay mas de un convocado llamado ' + @jugador + '.';

            -- Minuto
            SET @minuto = TRY_CONVERT(tinyint, @min_txt);
            SET @adicional = ISNULL(TRY_CONVERT(tinyint, @adic_txt), 0);
            IF @minuto IS NULL OR @minuto > 120
                SET @err_fila = @err_fila + ' - Minuto invalido (' + ISNULL(@min_txt, 'vacio') + ').';

            -- Periodo segun el minuto
            SET @nombre_periodo = CASE WHEN @minuto <= 45  THEN 'Primer tiempo'
                                       WHEN @minuto <= 90  THEN 'Segundo tiempo'
                                       WHEN @minuto <= 105 THEN 'Alargue 1'
                                       WHEN @minuto <= 120 THEN 'Alargue 2' END;
            SELECT @id_periodo = id_periodo FROM comp.Periodo WHERE nombre = @nombre_periodo;
            IF @minuto IS NOT NULL AND @minuto <= 120 AND @id_periodo IS NULL
                SET @err_fila = @err_fila + ' - Falta el periodo ' + @nombre_periodo + ' en comp.Periodo.';

            -- Tipo de gol
            SELECT @id_tipo_gol = id_tipo_gol FROM disc.TipoGol WHERE nombre = @tipo_txt;
            IF @id_tipo_gol IS NULL
                SET @err_fila = @err_fila + ' - Tipo de gol invalido (' + ISNULL(@tipo_txt, 'vacio')
                              + '; se espera Jugada, Penal o En contra).';

            IF @err_fila <> ''
            BEGIN
                SET @err_fila = 'usp_Importar_Goles:' + @err_fila;
                THROW 50812, @err_fila, 1;
            END

            BEGIN TRANSACTION;

                -- Alineacion del autor: si no esta en ese partido, se agrega como suplente
                SELECT @id_alineacion = id_alineacion FROM comp.Alineacion
                WHERE id_partido_seleccion = @id_partido_seleccion AND id_convocado = @id_convocado;

                IF @id_alineacion IS NULL
                BEGIN
                    EXEC comp.usp_Alineacion_Alta @id_partido_seleccion, @id_convocado, 0, NULL;
                    SELECT @id_alineacion = id_alineacion FROM comp.Alineacion
                    WHERE id_partido_seleccion = @id_partido_seleccion AND id_convocado = @id_convocado;
                END

                -- Upsert del gol: mismo autor, mismo minuto
                SELECT @id_gol = id_gol FROM disc.Gol
                WHERE id_alineacion_autor = @id_alineacion
                  AND minuto = @minuto AND minuto_adicional = @adicional;

                IF @id_gol IS NULL
                BEGIN
                    EXEC disc.usp_Gol_Alta @id_alineacion, NULL, @id_tipo_gol, @id_periodo, @minuto, @adicional;
                    SET @nuevos = @nuevos + 1;
                END
                ELSE
                BEGIN
                    EXEC disc.usp_Gol_Modificacion @id_gol, @id_tipo_gol, @id_periodo, @minuto, @adicional;
                    SET @actualizados = @actualizados + 1;
                END

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
            SET @err = LEFT(ERROR_MESSAGE(), 500);
            EXEC imp.usp_ErrorImportacion_Alta @id_log, @linea, @dato, @err;
            SET @errores = @errores + 1;
        END CATCH

        SET @i = @i + 1;
    END

    -- 4) Cerrar el registro y mostrar el resultado
    -- (EXEC no acepta cuentas como parametro: se calcula antes en una variable)
    SET @ahora = SYSDATETIME();
    SET @ok = @nuevos + @actualizados;
    EXEC imp.usp_LogImportacion_Modificacion @id_log, @ahora, @max, @ok, @errores;

    SELECT @id_log AS id_log, @max AS filas_leidas, @nuevos AS goles_nuevos,
           @actualizados AS goles_actualizados, @errores AS filas_con_error;

    SELECT nro_linea, dato_original, mensaje
    FROM imp.ErrorImportacion
    WHERE id_log_importacion = @id_log
    ORDER BY nro_linea;
END
GO
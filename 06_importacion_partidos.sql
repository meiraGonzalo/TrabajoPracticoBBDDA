/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 6 - Script 06_importacion_partidos: importacion de sedes y fixture (Partidos y juego)
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 05/11/2026
 Objetivo: importar desde archivos CSV
   - imp.usp_Importar_Sedes:    estadios (y su ciudad si no existe)
   - imp.usp_Importar_Partidos: fixture y resultados
   y un SP auxiliar:
   - imp.usp_AsegurarSeleccion: deja creada la seleccion en el torneo
     y con su grupo (lo usa la importacion de partidos)
	el origen de los datos son archivos CSV obtenidos mediante scraping de Wikipedia,
	a partir de las paginas del Mundial 2026, sus grupos y la fase eliminatoria

   - estadio como en Wikipedia: "Estadio Azteca† (Mexico City Stadium)": se
     saca la cruz y lo que esta entre parentesis.
   - latitud, longitud, huso_horario, goles, penales y asistencia
     pueden venir vacios.

 NUMERACION DE ERRORES (THROW)
   50803 / 50804  Importar_Partidos: error general / error de una fila
   50805          AsegurarSeleccion

 Orden: 00 -> 01 -> 02 -> 03 -> 06_importacion_comun -> este script.
 
=====================================================================
*/

USE MundialDB;
GO

/* ---------------------------------------------------------------------
   Staging de esta importacion , se crea solo si no existe
   - imp.stg_sedes: todo nvarchar y NULL, con un
     numero de fila (IDENTITY) para recorrerla con el WHILE.
   - imp.vw_stg_sedes_carga: vista con las columnas del archivo (sin
     nro_fila)
   --------------------------------------------------------------------- */
IF OBJECT_ID('imp.stg_sedes') IS NULL
BEGIN
    CREATE TABLE imp.stg_sedes (
        nro_fila          int IDENTITY(1,1) NOT NULL,
        pais              nvarchar(100) NULL,
        ciudad            nvarchar(100) NULL,
        estadio           nvarchar(150) NULL,
        capacidad         nvarchar(20) NULL,
        latitud           nvarchar(20) NULL,
        longitud          nvarchar(20) NULL,
        huso_horario      nvarchar(50) NULL
    );
END
GO

CREATE OR ALTER VIEW imp.vw_stg_sedes_carga
AS
    SELECT pais, ciudad, estadio, capacidad, latitud, longitud, huso_horario
    FROM imp.stg_sedes;
GO

/* ---------------------------------------------------------------------
   Staging de esta importacion, se crea solo si no existe
   - imp.stg_partidos: todo nvarchar y NULL, con un
     numero de fila (IDENTITY) para recorrerla con el WHILE.
   - imp.vw_stg_partidos_carga: vista con las columnas del archivo (sin
     nro_fila)
   --------------------------------------------------------------------- */
IF OBJECT_ID('imp.stg_partidos') IS NULL
BEGIN
    CREATE TABLE imp.stg_partidos (
        nro_fila          int IDENTITY(1,1) NOT NULL,
        nro_partido       nvarchar(10) NULL,
        fase              nvarchar(50) NULL,
        grupo             nvarchar(10) NULL,
        fecha             nvarchar(60) NULL,
        hora_local        nvarchar(30) NULL,
        estadio           nvarchar(150) NULL,
        ciudad            nvarchar(100) NULL,
        sel_local         nvarchar(100) NULL,
        sel_visitante     nvarchar(100) NULL,
        goles_local       nvarchar(10) NULL,
        goles_visitante   nvarchar(10) NULL,
        penales_local     nvarchar(10) NULL,
        penales_visitante nvarchar(10) NULL,
        asistencia        nvarchar(20) NULL
    );
END
GO

CREATE OR ALTER VIEW imp.vw_stg_partidos_carga
AS
    SELECT nro_partido, fase, grupo, fecha, hora_local, estadio, ciudad, sel_local, sel_visitante, goles_local, goles_visitante, penales_local, penales_visitante, asistencia
    FROM imp.stg_partidos;
GO


/* =====================================================================
   imp.usp_AsegurarSeleccion
   Devuelve (OUTPUT) el id de la seleccion de ese pais en el torneo:
     - si no existe, la crea con el grupo indicado
     - si existe sin grupo y ahora se sabe el grupo, se lo asigna
     - si existe en OTRO grupo, es un error
   ===================================================================== */

CREATE OR ALTER PROCEDURE imp.usp_AsegurarSeleccion
    @id_torneo    int,
    @id_pais      int,
    @id_grupo     int,              -- NULL si el partido no es de fase de grupos
    @id_seleccion int OUTPUT
AS
BEGIN
    DECLARE @grupo_actual int, @err nvarchar(2000);
    SET @id_seleccion = NULL;

    SELECT @id_seleccion = id_seleccion, @grupo_actual = id_grupo
    FROM comp.Seleccion WHERE id_torneo = @id_torneo AND id_pais = @id_pais;

    IF @id_seleccion IS NULL
    BEGIN
        -- No existe: se crea
        EXEC comp.usp_Seleccion_Alta @id_torneo, @id_pais, @id_grupo;
        SELECT @id_seleccion = id_seleccion FROM comp.Seleccion
        WHERE id_torneo = @id_torneo AND id_pais = @id_pais;
    END
    ELSE IF @id_grupo IS NOT NULL AND @grupo_actual IS NULL
        -- Existe sin grupo (la cargo la importacion de plantillas): se le asigna
        EXEC comp.usp_Seleccion_Modificacion @id_seleccion, @id_grupo;
    ELSE IF @id_grupo IS NOT NULL AND @grupo_actual <> @id_grupo
    BEGIN
        SET @err = 'usp_AsegurarSeleccion: - La seleccion ya esta cargada en otro grupo.';
        THROW 50805, @err, 1;
    END
END
GO


/* =====================================================================
   imp.usp_Importar_Sedes
   Upsert de sedes. Clave: nombre del estadio + ciudad.
     - La ciudad se busca por nombre y pais. Si no existe y el archivo
       trae el huso horario, se crea con cat.usp_Ciudad_Alta
       Si no existe y no hay huso, la fila da error
     - Sede nueva -> usp_Sede_Alta. Sede existente -> usp_Sede_Modificacion
       (si la latitud/longitud vienen vacias, se conservan las que tenia)
   ===================================================================== */

CREATE OR ALTER PROCEDURE imp.usp_Importar_Sedes
    @archivo varchar(260)
AS
BEGIN
    DECLARE @err nvarchar(2000), @msg nvarchar(2048), @sql nvarchar(1000);
    DECLARE @id_log int, @ahora datetime2(0);
    DECLARE @i int, @max int, @linea int, @ok int;
    DECLARE @altas int, @actualizados int, @errores int;

    -- Fila tal como viene en el archivo
    DECLARE @pais nvarchar(100), @ciudad nvarchar(100), @estadio nvarchar(150), @capacidad_txt nvarchar(20),
            @latitud_txt nvarchar(20), @longitud_txt nvarchar(20), @huso nvarchar(50), @dato nvarchar(1000);

    -- Fila convertida
    DECLARE @id_pais int, @id_ciudad int, @id_sede int, @capacidad int,
            @latitud decimal(9,6), @longitud decimal(9,6), @err_fila nvarchar(2000);

    /* 0) Validaciones generales */
    IF @archivo IS NULL OR @archivo = ''
    BEGIN
        SET @err = 'usp_Importar_Sedes: - La ruta del archivo es obligatoria.';
        THROW 50801, @err, 1;
    END

    SET @altas = 0;
    SET @actualizados = 0;
    SET @errores = 0;

    /* 1) Log de la importacion */
    SET @ahora = SYSDATETIME();
    EXEC imp.usp_LogImportacion_Alta @archivo, 'Wikipedia - 2026 FIFA World Cup, Venues (scraping)',
                                     @ahora, NULL, NULL, NULL, NULL;
    SELECT @id_log = MAX(id_log_importacion) FROM imp.LogImportacion;

    /* -------------------------------------------------------------
       2) Vaciar la staging y cargar el archivo en ella
          imp.stg_sedes: tabla fija del schema imp, todas las columnas
          nvarchar y NULL (asi ninguna fila falla al leerla). Se vacia
          con TRUNCATE al empezar cada importacion
       ------------------------------------------------------------- */
    TRUNCATE TABLE imp.stg_sedes;

    --   FIELDTERMINATOR ';'  separador de columnas
    --   ROWTERMINATOR  '\n'  fin de fila
    --   CODEPAGE '65001'     UTF-8 (acentos y letras especiales)
    --   FIRSTROW 2           la fila 1 son los titulos
    SET @sql = N'BULK INSERT imp.vw_stg_sedes_carga FROM ''' + @archivo + N'''
                 WITH (FIELDTERMINATOR = '';'', ROWTERMINATOR = ''\n'', CODEPAGE = ''65001'', FIRSTROW = 2);';

    BEGIN TRY
        EXEC (@sql);
    END TRY
    BEGIN CATCH
        SET @msg = 'usp_Importar_Sedes: - No se pudo leer el archivo: ' + ERROR_MESSAGE();
        SET @err = LEFT(@msg, 500);
        EXEC imp.usp_ErrorImportacion_Alta @id_log, NULL, @archivo, @err;
        SET @ahora = SYSDATETIME();
        EXEC imp.usp_LogImportacion_Modificacion @id_log, @ahora, 0, 0, 0;
        THROW 50801, @msg, 1;
    END CATCH

    SELECT @max = COUNT(*) FROM imp.stg_sedes;
    SET @i = 1;

    /* 4) Fila por fila */
    WHILE @i <= @max
    BEGIN
        SET @id_pais = NULL;  SET @id_ciudad = NULL; SET @id_sede = NULL;
        SET @capacidad = NULL; SET @latitud = NULL; SET @longitud = NULL;
        SET @linea = @i + 1;

        SELECT @pais          = NULLIF(LTRIM(RTRIM(pais)), ''),
               @ciudad        = NULLIF(LTRIM(RTRIM(ciudad)), ''),
               @estadio       = NULLIF(LTRIM(RTRIM(estadio)), ''),
               @capacidad_txt = NULLIF(LTRIM(RTRIM(capacidad)), ''),
               @latitud_txt   = NULLIF(LTRIM(RTRIM(latitud)), ''),
               @longitud_txt  = NULLIF(LTRIM(RTRIM(longitud)), ''),
               @huso          = NULLIF(LTRIM(RTRIM(huso_horario)), '')
        FROM imp.stg_sedes WHERE nro_fila = @i;

        SET @dato = ISNULL(@pais, '') + ';' + ISNULL(@ciudad, '') + ';' + ISNULL(@estadio, '') + ';'
                  + ISNULL(@capacidad_txt, '') + ';' + ISNULL(@latitud_txt, '') + ';'
                  + ISNULL(@longitud_txt, '') + ';' + ISNULL(@huso, '');

        BEGIN TRY
            /* Transformar y validar */
            SET @err_fila = '';

            EXEC imp.usp_BuscarPais @pais, @id_pais OUTPUT;
            IF @id_pais IS NULL
                SET @err_fila = @err_fila + ' - Pais desconocido (' + ISNULL(@pais, 'vacio') + ').';

            -- Estadio: sacar la cruz de Wikipedia y el nombre FIFA entre parentesis
            SET @estadio = REPLACE(@estadio, NCHAR(8224), '');
            IF CHARINDEX('(', @estadio) > 0
                SET @estadio = LEFT(@estadio, CHARINDEX('(', @estadio) - 1);
            SET @estadio = LTRIM(RTRIM(@estadio));
            IF @estadio IS NULL OR @estadio = ''
                SET @err_fila = @err_fila + ' - Falta el nombre del estadio.';

            -- Capacidad: "80,824" -> 80824
            SET @capacidad = TRY_CONVERT(int, REPLACE(REPLACE(@capacidad_txt, ',', ''), '.', ''));
            IF @capacidad IS NULL
                SET @err_fila = @err_fila + ' - Capacidad invalida (' + ISNULL(@capacidad_txt, 'vacio') + ').';

            -- Latitud y longitud son opcionales, pero si vienen tienen que ser numeros
            SET @latitud  = TRY_CONVERT(decimal(9,6), @latitud_txt);
            SET @longitud = TRY_CONVERT(decimal(9,6), @longitud_txt);
            IF (@latitud_txt IS NOT NULL AND @latitud IS NULL) OR (@longitud_txt IS NOT NULL AND @longitud IS NULL)
                SET @err_fila = @err_fila + ' - Latitud o longitud invalida.';

            -- Ciudad: existe? si no, hace falta el huso horario para crearla
            SELECT @id_ciudad = id_ciudad FROM cat.Ciudad WHERE nombre = @ciudad AND id_pais = @id_pais;
            IF @id_ciudad IS NULL AND @huso IS NULL AND @id_pais IS NOT NULL
                SET @err_fila = @err_fila + ' - La ciudad no existe y el archivo no trae su huso horario.';

            IF @err_fila <> ''
            BEGIN
                SET @err_fila = 'usp_Importar_Sedes:' + @err_fila;
                THROW 50802, @err_fila, 1;
            END

            /* Grabar (todo o nada para la fila) */
            BEGIN TRANSACTION;

                IF @id_ciudad IS NULL
                BEGIN
                    EXEC cat.usp_Ciudad_Alta @ciudad, @id_pais, @huso;
                    SELECT @id_ciudad = id_ciudad FROM cat.Ciudad WHERE nombre = @ciudad AND id_pais = @id_pais;
                END

                SELECT @id_sede = id_sede FROM comp.Sede WHERE nombre_estadio = @estadio AND id_ciudad = @id_ciudad;

                IF @id_sede IS NULL
                BEGIN
                    EXEC comp.usp_Sede_Alta @estadio, @id_ciudad, @capacidad, @latitud, @longitud;
                    SET @altas = @altas + 1;
                END
                ELSE
                BEGIN
                    -- Si el archivo no trae coordenadas, se dejan las que ya tenia
                    SELECT @latitud  = ISNULL(@latitud, latitud),
                           @longitud = ISNULL(@longitud, longitud)
                    FROM comp.Sede WHERE id_sede = @id_sede;

                    EXEC comp.usp_Sede_Modificacion @id_sede, @estadio, @id_ciudad, @capacidad, @latitud, @longitud;
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

    /* 5) Cerrar el log */
    SET @ahora = SYSDATETIME();
    SET @ok = @altas + @actualizados;
    EXEC imp.usp_LogImportacion_Modificacion @id_log, @ahora, @max, @ok, @errores;

    /* 6) Resultado */
    SELECT @id_log AS id_log, @max AS filas_leidas, @altas AS sedes_nuevas,
           @actualizados AS sedes_actualizadas, @errores AS filas_con_error;

    SELECT nro_linea, dato_original, mensaje
    FROM imp.ErrorImportacion WHERE id_log_importacion = @id_log ORDER BY nro_linea;
END
GO


/* =====================================================================
   imp.usp_Importar_Partidos
   Upsert del fixture y carga de resultados. Clave: torneo + nro_partido.
   ===================================================================== */

CREATE OR ALTER PROCEDURE imp.usp_Importar_Partidos
    @archivo varchar(260),
    @anio_torneo  smallint
AS
BEGIN
    DECLARE @err nvarchar(2000), @msg nvarchar(2048), @sql nvarchar(1000);
    DECLARE @id_torneo int, @id_log int, @ahora datetime2(0);
    DECLARE @i int, @max int, @linea int, @ok int;
    DECLARE @altas int, @actualizados int, @sin_cambios int, @resultados int, @errores int;

    -- Fila tal como viene en el archivo
    DECLARE @nro_txt nvarchar(10), @fase_txt nvarchar(50), @grupo_txt nvarchar(10), @fecha_txt nvarchar(60),
            @hora_txt nvarchar(30), @estadio nvarchar(150), @ciudad nvarchar(100),
            @local_txt nvarchar(100), @visit_txt nvarchar(100),
            @gl_txt nvarchar(10), @gv_txt nvarchar(10), @pl_txt nvarchar(10), @pv_txt nvarchar(10),
            @asis_txt nvarchar(20), @dato nvarchar(1000);

    -- Fila convertida
    DECLARE @nro smallint, @id_fase int, @es_eliminatoria bit, @id_grupo int, @fecha date,
            @fecha_local datetime2(0), @utc datetime2(0), @id_sede int, @huso varchar(50),
            @id_pais_l int, @id_pais_v int, @id_sel_l int, @id_sel_v int, @id_partido int,
            @gl tinyint, @gv tinyint, @pl tinyint, @pv tinyint, @asistencia int,
            @sede_actual int, @utc_actual datetime2(0), @estado varchar(15), @siguiente int,
            @err_fila nvarchar(2000);

    /* 0) Validaciones generales */
    SET @err = '';

    IF @archivo IS NULL OR @archivo = ''
        SET @err = @err + ' - La ruta del archivo es obligatoria.';

    SELECT @id_torneo = id_torneo FROM comp.Torneo WHERE anio = @anio_torneo;
    IF @id_torneo IS NULL
        SET @err = @err + ' - El torneo no existe.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Importar_Partidos:' + @err;
        THROW 50803, @err, 1;
    END

    SET @altas = 0; SET @actualizados = 0; SET @sin_cambios = 0; SET @resultados = 0; SET @errores = 0;

    /* 1) Log */
    SET @ahora = SYSDATETIME();
    EXEC imp.usp_LogImportacion_Alta @archivo, 'Wikipedia - 2026 FIFA World Cup, partidos (scraping)',
                                     @ahora, NULL, NULL, NULL, NULL;
    SELECT @id_log = MAX(id_log_importacion) FROM imp.LogImportacion;

    /* -------------------------------------------------------------
       2) Vaciar la staging y cargar el archivo en ella
          imp.stg_partidos: tabla fija del schema imp, todas las columnas
          nvarchar y NULL (asi ninguna fila falla al leerla)
       ------------------------------------------------------------- */
    TRUNCATE TABLE imp.stg_partidos;

    --   FIELDTERMINATOR ';'  separador de columnas
    --   ROWTERMINATOR  '\n'  fin de fila
    --   CODEPAGE '65001'     UTF-8 (acentos y letras especiales)
    --   FIRSTROW 2           la fila 1 son los titulos
    SET @sql = N'BULK INSERT imp.vw_stg_partidos_carga FROM ''' + @archivo + N'''
                 WITH (FIELDTERMINATOR = '';'', ROWTERMINATOR = ''\n'', CODEPAGE = ''65001'', FIRSTROW = 2);';

    BEGIN TRY
        EXEC (@sql);
    END TRY
    BEGIN CATCH
        SET @msg = 'usp_Importar_Partidos: - No se pudo leer el archivo: ' + ERROR_MESSAGE();
        SET @err = LEFT(@msg, 500);
        EXEC imp.usp_ErrorImportacion_Alta @id_log, NULL, @archivo, @err;
        SET @ahora = SYSDATETIME();
        EXEC imp.usp_LogImportacion_Modificacion @id_log, @ahora, 0, 0, 0;
        THROW 50803, @msg, 1;
    END CATCH

    SELECT @max = COUNT(*) FROM imp.stg_partidos;
    SET @i = 1;

    /* 4) Fila por fila*/
    WHILE @i <= @max
    BEGIN
        SET @nro = NULL; SET @id_fase = NULL; SET @es_eliminatoria = NULL; SET @id_grupo = NULL;
        SET @fecha = NULL; SET @fecha_local = NULL; SET @utc = NULL; SET @id_sede = NULL; SET @huso = NULL;
        SET @id_pais_l = NULL; SET @id_pais_v = NULL; SET @id_sel_l = NULL; SET @id_sel_v = NULL;
        SET @id_partido = NULL; SET @gl = NULL; SET @gv = NULL; SET @pl = NULL; SET @pv = NULL;
        SET @asistencia = NULL; SET @sede_actual = NULL; SET @utc_actual = NULL;
        SET @estado = NULL; SET @siguiente = NULL;
        SET @linea = @i + 1;

        SELECT @nro_txt   = NULLIF(LTRIM(RTRIM(nro_partido)), ''),
               @fase_txt  = NULLIF(LTRIM(RTRIM(fase)), ''),
               @grupo_txt = NULLIF(LTRIM(RTRIM(grupo)), ''),
               @fecha_txt = NULLIF(LTRIM(RTRIM(fecha)), ''),
               @hora_txt  = NULLIF(LTRIM(RTRIM(hora_local)), ''),
               @estadio   = NULLIF(LTRIM(RTRIM(estadio)), ''),
               @ciudad    = NULLIF(LTRIM(RTRIM(ciudad)), ''),
               @local_txt = NULLIF(LTRIM(RTRIM(sel_local)), ''),
               @visit_txt = NULLIF(LTRIM(RTRIM(sel_visitante)), ''),
               @gl_txt    = NULLIF(LTRIM(RTRIM(goles_local)), ''),
               @gv_txt    = NULLIF(LTRIM(RTRIM(goles_visitante)), ''),
               @pl_txt    = NULLIF(LTRIM(RTRIM(penales_local)), ''),
               @pv_txt    = NULLIF(LTRIM(RTRIM(penales_visitante)), ''),
               @asis_txt  = NULLIF(LTRIM(RTRIM(asistencia)), '')
        FROM imp.stg_partidos WHERE nro_fila = @i;

        SET @dato = ISNULL(@nro_txt, '') + ';' + ISNULL(@fase_txt, '') + ';' + ISNULL(@grupo_txt, '') + ';'
                  + ISNULL(@fecha_txt, '') + ';' + ISNULL(@hora_txt, '') + ';' + ISNULL(@estadio, '') + ';'
                  + ISNULL(@ciudad, '') + ';' + ISNULL(@local_txt, '') + ';' + ISNULL(@visit_txt, '') + ';'
                  + ISNULL(@gl_txt, '') + ';' + ISNULL(@gv_txt, '') + ';' + ISNULL(@pl_txt, '') + ';'
                  + ISNULL(@pv_txt, '') + ';' + ISNULL(@asis_txt, '');

        BEGIN TRY
            /* Transformar y validar */
            SET @err_fila = '';

            -- Numero de partido
            SET @nro = TRY_CONVERT(smallint, @nro_txt);
            IF @nro IS NULL
                SET @err_fila = @err_fila + ' - Numero de partido invalido (' + ISNULL(@nro_txt, 'vacio') + ').';

            -- Fase: primero por su nombre en comp.Fase; si no, se traduce el de Wikipedia
            SELECT @id_fase = id_fase, @es_eliminatoria = es_eliminatoria FROM comp.Fase WHERE nombre = @fase_txt;
            IF @id_fase IS NULL
                SELECT @id_fase = id_fase, @es_eliminatoria = es_eliminatoria
                FROM comp.Fase
                WHERE nombre = CASE
                                   WHEN @fase_txt LIKE 'Group%'          THEN 'Grupos'
                                   WHEN @fase_txt = 'Round of 32'        THEN 'Dieciseisavos'
                                   WHEN @fase_txt = 'Round of 16'        THEN 'Octavos'
                                   WHEN @fase_txt LIKE 'Quarter%'        THEN 'Cuartos'
                                   WHEN @fase_txt LIKE 'Semi%'           THEN 'Semifinal'
                                   WHEN @fase_txt LIKE '%third place%'   THEN 'Tercer puesto'
                                   WHEN @fase_txt = 'Final'              THEN 'Final'
                               END;
            IF @id_fase IS NULL
                SET @err_fila = @err_fila + ' - Fase desconocida (' + ISNULL(@fase_txt, 'vacio') + ').';

            -- Grupo: obligatorio en fase de grupos (una letra)
            IF @es_eliminatoria = 0 AND (@grupo_txt IS NULL OR @grupo_txt NOT LIKE '[A-Z]')
                SET @err_fila = @err_fila + ' - Partido de grupos sin letra de grupo valida.';

            -- Fecha y hora local -> fecha y hora
            EXEC imp.usp_ConvertirFecha @fecha_txt, @fecha OUTPUT;
            IF @fecha IS NULL
                SET @err_fila = @err_fila + ' - Fecha invalida (' + ISNULL(@fecha_txt, 'vacio') + ').';
            ELSE
                SET @fecha_local = TRY_CONVERT(datetime2(0), CAST(@fecha AS varchar(10)) + ' ' + LEFT(ISNULL(@hora_txt, ''), 5));
            IF @fecha IS NOT NULL AND @fecha_local IS NULL
                SET @err_fila = @err_fila + ' - Hora invalida (' + ISNULL(@hora_txt, 'vacio') + ').';

            -- Estadio: mismo que en la importacion de sedes, se busca con su ciudad
            SET @estadio = REPLACE(@estadio, NCHAR(8224), '');
            IF CHARINDEX('(', @estadio) > 0
                SET @estadio = LEFT(@estadio, CHARINDEX('(', @estadio) - 1);
            SET @estadio = LTRIM(RTRIM(@estadio));

            SELECT @id_sede = s.id_sede, @huso = c.huso_horario
            FROM comp.Sede s
            INNER JOIN cat.Ciudad c ON c.id_ciudad = s.id_ciudad
            WHERE s.nombre_estadio = @estadio AND c.nombre = @ciudad;
            IF @id_sede IS NULL
                SET @err_fila = @err_fila + ' - Sede desconocida (' + ISNULL(@estadio, 'vacio') + ', ' + ISNULL(@ciudad, 'vacio') + ').';

            -- Hora local de la sede -> UTC (AT TIME ZONE con el huso de la ciudad)
            IF @fecha_local IS NOT NULL AND EXISTS (SELECT 1 FROM sys.time_zone_info WHERE name = @huso)
                SET @utc = CAST((@fecha_local AT TIME ZONE @huso) AT TIME ZONE 'UTC' AS datetime2(0));

            -- Selecciones
            EXEC imp.usp_BuscarPais @local_txt, @id_pais_l OUTPUT;
            IF @id_pais_l IS NULL
                SET @err_fila = @err_fila + ' - Seleccion local desconocida (' + ISNULL(@local_txt, 'vacio') + ').';
            EXEC imp.usp_BuscarPais @visit_txt, @id_pais_v OUTPUT;
            IF @id_pais_v IS NULL
                SET @err_fila = @err_fila + ' - Seleccion visitante desconocida (' + ISNULL(@visit_txt, 'vacio') + ').';

            -- Resultado (opcional): si viene, tiene que ser numerico
            SET @gl = TRY_CONVERT(tinyint, @gl_txt);
            SET @gv = TRY_CONVERT(tinyint, @gv_txt);
            SET @pl = TRY_CONVERT(tinyint, @pl_txt);
            SET @pv = TRY_CONVERT(tinyint, @pv_txt);
            SET @asistencia = TRY_CONVERT(int, REPLACE(REPLACE(@asis_txt, ',', ''), '.', ''));
            IF (@gl_txt IS NOT NULL AND @gl IS NULL) OR (@gv_txt IS NOT NULL AND @gv IS NULL)
               OR (@pl_txt IS NOT NULL AND @pl IS NULL) OR (@pv_txt IS NOT NULL AND @pv IS NULL)
               OR (@asis_txt IS NOT NULL AND @asistencia IS NULL)
                SET @err_fila = @err_fila + ' - Goles, penales o asistencia invalidos.';

            IF @err_fila <> ''
            BEGIN
                SET @err_fila = 'usp_Importar_Partidos:' + @err_fila;
                THROW 50804, @err_fila, 1;
            END

            /*Grabar (todo o nada para la fila) */
            BEGIN TRANSACTION;

                -- 1) Grupo (solo fase de grupos)
                IF @es_eliminatoria = 0
                BEGIN
                    SELECT @id_grupo = id_grupo FROM comp.Grupo WHERE id_torneo = @id_torneo AND letra = @grupo_txt;
                    IF @id_grupo IS NULL
                    BEGIN
                        EXEC comp.usp_Grupo_Alta @id_torneo, @grupo_txt;
                        SELECT @id_grupo = id_grupo FROM comp.Grupo WHERE id_torneo = @id_torneo AND letra = @grupo_txt;
                    END
                END

                -- 2) Selecciones (creadas y con su grupo)
                EXEC imp.usp_AsegurarSeleccion @id_torneo, @id_pais_l, @id_grupo, @id_sel_l OUTPUT;
                EXEC imp.usp_AsegurarSeleccion @id_torneo, @id_pais_v, @id_grupo, @id_sel_v OUTPUT;

                -- 3) Partido: nuevo o existente
                SELECT @id_partido = id_partido, @sede_actual = id_sede, @utc_actual = fecha_hora_utc,
                       @estado = estado, @siguiente = id_partido_siguiente
                FROM comp.Partido WHERE id_torneo = @id_torneo AND nro_partido = @nro;

                IF @id_partido IS NULL
                BEGIN
                    EXEC comp.usp_Partido_Registrar @id_torneo, @nro, @id_fase, @id_grupo, @id_sede, @utc,
                                                    @id_sel_l, @id_sel_v;
                    SELECT @id_partido = id_partido, @estado = estado
                    FROM comp.Partido WHERE id_torneo = @id_torneo AND nro_partido = @nro;
                    SET @altas = @altas + 1;
                END
                ELSE IF @sede_actual <> @id_sede OR @utc_actual <> @utc
                BEGIN
                    EXEC comp.usp_Partido_Modificacion @id_partido, @id_sede, @utc, @estado, @siguiente;
                    SET @actualizados = @actualizados + 1;
                END
                ELSE
                    SET @sin_cambios = @sin_cambios + 1;

                -- 4) Resultado, solo si viene y el partido no esta finalizado
                IF @gl IS NOT NULL AND @gv IS NOT NULL AND @estado <> 'FINALIZADO'
                BEGIN
                    EXEC comp.usp_Partido_RegistrarResultado @id_partido, @gl, @gv, @pl, @pv, @asistencia;
                    SET @resultados = @resultados + 1;
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

    /* 5) Cerrar el log */
    SET @ahora = SYSDATETIME();
    SET @ok = @altas + @actualizados + @sin_cambios;
    EXEC imp.usp_LogImportacion_Modificacion @id_log, @ahora, @max, @ok, @errores;

    /* 6) Resultado */
    SELECT @id_log AS id_log, @max AS filas_leidas, @altas AS partidos_nuevos, @actualizados AS partidos_actualizados,
           @sin_cambios AS partidos_sin_cambios, @resultados AS resultados_cargados, @errores AS filas_con_error;

    SELECT nro_linea, dato_original, mensaje
    FROM imp.ErrorImportacion WHERE id_log_importacion = @id_log ORDER BY nro_linea;
END
GO
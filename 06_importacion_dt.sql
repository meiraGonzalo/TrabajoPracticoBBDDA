/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 6 - Importacion del cuerpo tecnico (scraping de Wikipedia)
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10

 Objetivo: importar cuerpo_tecnico_2026.csv, que genera
   scraping_mundial2026.py con la linea "Head coach:" de cada seleccion
   en la pagina de plantillas de Wikipedia.
   50821  error general (ruta vacia, torneo inexistente, archivo ilegible)
   50822  error de una fila
 Orden: despues de 06_importacion_comun (equivalencias) y de importar
   partidos/plantillas (las selecciones tienen que existir).
=====================================================================
*/

USE MundialDB;
GO

/* ---------------------------------------------------------------------
   Staging (todo texto) y vista para el BULK INSERT (sin nro_fila)
   --------------------------------------------------------------------- */
IF OBJECT_ID('imp.stg_cuerpo_tecnico') IS NULL
BEGIN
    CREATE TABLE imp.stg_cuerpo_tecnico (
        nro_fila          int IDENTITY(1,1) NOT NULL,
        seleccion         nvarchar(100) NULL,
        nombre            nvarchar(160) NULL,
        pais_nacionalidad nvarchar(100) NULL,
        rol               nvarchar(40)  NULL
    );
END
GO

CREATE OR ALTER VIEW imp.vw_stg_cuerpo_tecnico_carga
AS
    SELECT seleccion, nombre, pais_nacionalidad, rol
    FROM imp.stg_cuerpo_tecnico;
GO


/* ---------------------------------------------------------------------
   imp.usp_Importar_CuerpoTecnico @archivo, @anio_torneo
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE imp.usp_Importar_CuerpoTecnico
    @archivo     varchar(260),
    @anio_torneo smallint
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @err nvarchar(2000), @msg nvarchar(2000), @sql nvarchar(1000);
    DECLARE @id_log int, @ahora datetime2(0), @id_torneo int;
    DECLARE @i int, @max int, @linea int, @nuevos int, @existentes int, @errores int, @ok int;
    DECLARE @dato nvarchar(1000), @err_fila nvarchar(2000);
    -- datos de la fila
    DECLARE @sel_txt nvarchar(100), @nombre_completo nvarchar(160), @pais_txt nvarchar(100), @rol varchar(40);
    DECLARE @nombre nvarchar(80), @apellido nvarchar(80);
    DECLARE @id_pais_sel int, @id_seleccion int, @id_pais int, @id_persona int;

    -- Validacion general
    SET @err = '';
    IF @archivo IS NULL OR @archivo = ''
        SET @err = @err + ' - La ruta del archivo es obligatoria.';
    SELECT @id_torneo = id_torneo FROM comp.Torneo WHERE anio = @anio_torneo;
    IF @id_torneo IS NULL
        SET @err = @err + ' - No existe el torneo del anio ' + ISNULL(CAST(@anio_torneo AS varchar(4)), 'vacio') + '.';
    IF @err <> ''
    BEGIN
        SET @err = 'usp_Importar_CuerpoTecnico:' + @err;
        THROW 50821, @err, 1;
    END

    SET @nuevos = 0;
    SET @existentes = 0;
    SET @errores = 0;

    -- 1) Abrir el registro de la importacion
    SET @ahora = SYSDATETIME();
    EXEC imp.usp_LogImportacion_Alta @archivo, 'Wikipedia - 2026 FIFA World Cup squads, Head coach (scraping)',
                                     @ahora, NULL, NULL, NULL, NULL;
    SELECT @id_log = MAX(id_log_importacion) FROM imp.LogImportacion;

    -- 2) Vaciar la staging y cargar el archivo
    TRUNCATE TABLE imp.stg_cuerpo_tecnico;

    -- SQL dinamico SOLO porque BULK INSERT no acepta una variable como nombre de archivo
    SET @sql = N'BULK INSERT imp.vw_stg_cuerpo_tecnico_carga FROM ''' + @archivo + N'''
                 WITH (FIELDTERMINATOR = '';'', ROWTERMINATOR = ''\n'', CODEPAGE = ''65001'', FIRSTROW = 2);';
    BEGIN TRY
        EXEC (@sql);
    END TRY
    BEGIN CATCH
        SET @msg = 'usp_Importar_CuerpoTecnico: - No se pudo leer el archivo: ' + ERROR_MESSAGE();
        SET @err = LEFT(@msg, 500);
        EXEC imp.usp_ErrorImportacion_Alta @id_log, NULL, @archivo, @err;
        SET @ahora = SYSDATETIME();
        EXEC imp.usp_LogImportacion_Modificacion @id_log, @ahora, 0, 0, 0;
        THROW 50821, @msg, 1;
    END CATCH

    SELECT @max = COUNT(*) FROM imp.stg_cuerpo_tecnico;
    SET @i = 1;

    -- 3) Fila por fila (sin cursores)
    WHILE @i <= @max
    BEGIN
        -- Reiniciar las variables de la vuelta anterior
        SET @sel_txt = NULL;  SET @nombre_completo = NULL; SET @pais_txt = NULL; SET @rol = NULL;
        SET @nombre = NULL;   SET @apellido = NULL;
        SET @id_pais_sel = NULL; SET @id_seleccion = NULL; SET @id_pais = NULL; SET @id_persona = NULL;
        SET @linea = @i + 1;      -- linea en el archivo (la 1 son los titulos)

        SELECT @sel_txt         = NULLIF(LTRIM(RTRIM(seleccion)), ''),
               @nombre_completo = NULLIF(LTRIM(RTRIM(nombre)), ''),
               @pais_txt        = NULLIF(LTRIM(RTRIM(pais_nacionalidad)), ''),
               @rol             = NULLIF(LTRIM(RTRIM(rol)), '')
        FROM imp.stg_cuerpo_tecnico WHERE nro_fila = @i;

        SET @dato = ISNULL(@sel_txt, '') + ';' + ISNULL(@nombre_completo, '') + ';'
                  + ISNULL(@pais_txt, '') + ';' + ISNULL(@rol, '');

        BEGIN TRY
            -- TRANSFORMAR Y VALIDAR la fila
            SET @err_fila = '';

            -- Seleccion del torneo
            EXEC imp.usp_BuscarPais @sel_txt, @id_pais_sel OUTPUT;
            SELECT @id_seleccion = id_seleccion FROM comp.Seleccion
            WHERE id_torneo = @id_torneo AND id_pais = @id_pais_sel;
            IF @id_seleccion IS NULL
                SET @err_fila = @err_fila + ' - Seleccion desconocida (' + ISNULL(@sel_txt, 'vacio') + ').';

            -- Nacionalidad del tecnico
            EXEC imp.usp_BuscarPais @pais_txt, @id_pais OUTPUT;
            IF @id_pais IS NULL
                SET @err_fila = @err_fila + ' - Pais de nacionalidad desconocido (' + ISNULL(@pais_txt, 'vacio') + ').';

            -- Nombre: primera palabra = nombre, el resto = apellido (igual que en plantillas)
            IF @nombre_completo IS NULL
                SET @err_fila = @err_fila + ' - Falta el nombre.';
            ELSE IF CHARINDEX(' ', @nombre_completo) > 0
            BEGIN
                SET @nombre   = LEFT(@nombre_completo, CHARINDEX(' ', @nombre_completo) - 1);
                SET @apellido = LTRIM(SUBSTRING(@nombre_completo, CHARINDEX(' ', @nombre_completo) + 1, 150));
            END
            ELSE
            BEGIN
                SET @nombre   = @nombre_completo;
                SET @apellido = @nombre_completo;
            END

            IF @rol IS NULL OR @rol NOT IN ('Director Tecnico', 'Ayudante de Campo', 'Preparador Fisico')
                SET @err_fila = @err_fila + ' - Rol invalido (' + ISNULL(@rol, 'vacio') + ').';

            IF @err_fila <> ''
            BEGIN
                SET @err_fila = 'usp_Importar_CuerpoTecnico:' + @err_fila;
                THROW 50822, @err_fila, 1;
            END

            -- Ya esta en el cuerpo tecnico de esa seleccion? No se hace nada
            IF EXISTS (SELECT 1
                       FROM comp.CuerpoTecnico ct
                       JOIN comp.Persona pe ON pe.id_persona = ct.id_persona
                       WHERE ct.id_seleccion = @id_seleccion
                         AND pe.nombre = @nombre AND pe.apellido = @apellido)
            BEGIN
                SET @existentes = @existentes + 1;
            END
            ELSE
            BEGIN
                BEGIN TRANSACTION;

                    -- La persona: se reutiliza si ya existe; si no, se crea
                    SELECT @id_persona = MIN(id_persona) FROM comp.Persona
                    WHERE nombre = @nombre AND apellido = @apellido AND id_pais_nacionalidad = @id_pais;

                    IF @id_persona IS NULL
                    BEGIN
                        EXEC comp.usp_Persona_Alta @nombre, @apellido, NULL, @id_pais, NULL, NULL;
                        SELECT @id_persona = MAX(id_persona) FROM comp.Persona
                        WHERE nombre = @nombre AND apellido = @apellido AND id_pais_nacionalidad = @id_pais;
                    END

                    -- El cuerpo tecnico 
                    EXEC comp.usp_CuerpoTecnico_Alta @id_seleccion, @id_persona, @rol;
                    SET @nuevos = @nuevos + 1;

                COMMIT TRANSACTION;
            END
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
    SET @ok = @nuevos + @existentes;
    EXEC imp.usp_LogImportacion_Modificacion @id_log, @ahora, @max, @ok, @errores;

    SELECT @id_log AS id_log, @max AS filas_leidas, @nuevos AS tecnicos_nuevos,
           @existentes AS tecnicos_ya_cargados, @errores AS filas_con_error;

    SELECT nro_linea, dato_original, mensaje
    FROM imp.ErrorImportacion
    WHERE id_log_importacion = @id_log
    ORDER BY nro_linea;
END
GO
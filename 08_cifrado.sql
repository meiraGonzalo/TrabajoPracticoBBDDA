/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 8 - Script 08: Cifrado de datos personales
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 2026-11-23
 Objetivo: cifrar el numero de documento de las personas (jugadores, cuerpo tecnico y
           arbitros son subtipos de comp.Persona, por eso alcanza con cifrar ahi).
           Metodo: clave simetrica (AES_256) protegida por un certificado.
              Certificado -> protege a -> Clave simetrica -> cifra -> nro_documento
           Es un script de MODIFICACION sobre lo existente:
             - comp.Persona: nro_documento (varchar) pasa a nro_documento_cif (varbinary).
             - comp.usp_Persona_Alta y comp.usp_Persona_Modificacion: cifran al guardar y
               comparan contra el dato descifrado para validar documentos duplicados.
             - comp.usp_Persona_DescifrarDocumento (nuevo): unico camino para leer el documento.
           Las firmas de los SP no cambian: quien los llama (usp_Jugador_AltaCompleta, la
           importacion de plantillas) sigue funcionando igual.
 Nota:     los SP que abren la clave usan EXECUTE AS OWNER. Asi el usuario comun nunca recibe
           permiso sobre el certificado ni sobre la clave: el permiso de descifrar se controla
           dandole o no EXECUTE sobre usp_Persona_DescifrarDocumento (ver script de roles).
           Los tests de entregas anteriores que lean o carguen nro_documento deben ajustarse.
 Orden:    00 -> 01 -> 02 -> 03 -> importaciones/seed -> 07 -> este script
=====================================================================
*/
USE MundialDB;
GO

/* ----------------- 1. JERARQUIA DE CLAVES ---------------------------------------
   Master key de la base -> certificado -> clave simetrica.
   La contrasena de la master key esta escrita aca porque es un TP; en un sistema
   real se guardaria fuera del codigo.
   ----------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Mundial2026#MasterKey!';
GO

IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'cert_datos_personales')
    CREATE CERTIFICATE cert_datos_personales
        WITH SUBJECT = 'Certificado que protege la clave de datos personales';
GO

IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = 'sk_datos_personales')
    CREATE SYMMETRIC KEY sk_datos_personales
        WITH ALGORITHM = AES_256
        ENCRYPTION BY CERTIFICATE cert_datos_personales;
GO


/* ----------------- 2. TABLA: nro_documento -> nro_documento_cif ------------------ */

IF COL_LENGTH('comp.Persona', 'nro_documento_cif') IS NULL
    ALTER TABLE comp.Persona ADD nro_documento_cif varbinary(256) NULL;
GO

-- Migra los documentos que ya hubiera cargados y elimina la columna en claro.
-- Va en SQL dinamico porque el script tiene que poder correrse dos veces: la segunda vez
-- nro_documento ya no existe y un UPDATE comun no compilaria.
IF COL_LENGTH('comp.Persona', 'nro_documento') IS NOT NULL
BEGIN
    EXEC('
        OPEN SYMMETRIC KEY sk_datos_personales DECRYPTION BY CERTIFICATE cert_datos_personales;

        UPDATE comp.Persona
        SET nro_documento_cif = ENCRYPTBYKEY(KEY_GUID(''sk_datos_personales''), nro_documento)
        WHERE nro_documento IS NOT NULL;

        CLOSE SYMMETRIC KEY sk_datos_personales;

        ALTER TABLE comp.Persona DROP COLUMN nro_documento;
    ');
END
GO


/* ----------------- 3. SP: ALTA ---------------------------------------------------- */

CREATE OR ALTER PROCEDURE comp.usp_Persona_Alta
    @nombre               nvarchar(80),
    @apellido             nvarchar(80),
    @fecha_nacimiento     date,
    @id_pais_nacionalidad int,
    @tipo_documento       varchar(15),
    @nro_documento        varchar(30)
WITH EXECUTE AS OWNER
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF @nombre IS NULL OR @nombre = ''
        SET @err = @err + ' - El nombre es obligatorio.';

    IF @apellido IS NULL OR @apellido = ''
        SET @err = @err + ' - El apellido es obligatorio.';

    IF @fecha_nacimiento > GETDATE()
        SET @err = @err + ' - La fecha de nacimiento no puede ser futura.';

    IF NOT EXISTS(SELECT 1 FROM cat.Pais WHERE id_pais = @id_pais_nacionalidad)
        SET @err = @err + ' - El pais de nacionalidad no existe.';

    IF (@tipo_documento IS NULL AND @nro_documento IS NOT NULL)
       OR (@tipo_documento IS NOT NULL AND @nro_documento IS NULL)
        SET @err = @err + ' - Tipo y numero de documento van juntos (los dos o ninguno).';

    -- Sin documento no hay nada que cifrar ni que comparar: la clave solo se abre si hace falta.
    IF @nro_documento IS NOT NULL
    BEGIN
        OPEN SYMMETRIC KEY sk_datos_personales DECRYPTION BY CERTIFICATE cert_datos_personales;

        -- La columna esta cifrada: se compara contra el dato descifrado.
        IF EXISTS(SELECT 1 FROM comp.Persona
            WHERE tipo_documento = @tipo_documento
              AND CONVERT(varchar(30), DECRYPTBYKEY(nro_documento_cif)) = @nro_documento
              AND id_pais_nacionalidad = @id_pais_nacionalidad)
            SET @err = @err + ' - Ya existe una persona con ese documento.';
    END

    IF @err <> ''
    BEGIN
        IF @nro_documento IS NOT NULL
            CLOSE SYMMETRIC KEY sk_datos_personales;
        SET @err = 'usp_Persona_Alta:' + @err;
        THROW 50051, @err, 1;
    END

    INSERT INTO comp.Persona (nombre, apellido, fecha_nacimiento, id_pais_nacionalidad, tipo_documento, nro_documento_cif)
    VALUES (@nombre, @apellido, @fecha_nacimiento, @id_pais_nacionalidad, @tipo_documento,
            ENCRYPTBYKEY(KEY_GUID('sk_datos_personales'), @nro_documento));   -- NULL si no hay documento

    IF @nro_documento IS NOT NULL
        CLOSE SYMMETRIC KEY sk_datos_personales;
END
GO


/* ----------------- 4. SP: MODIFICACION ------------------------------------------- */

CREATE OR ALTER PROCEDURE comp.usp_Persona_Modificacion
    @id_persona           int,
    @nombre               nvarchar(80),
    @apellido             nvarchar(80),
    @fecha_nacimiento     date,
    @id_pais_nacionalidad int,
    @tipo_documento       varchar(15),
    @nro_documento        varchar(30)
WITH EXECUTE AS OWNER
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF NOT EXISTS (SELECT 1 FROM comp.Persona WHERE id_persona = @id_persona)
        SET @err = @err + ' - La persona no existe.';

    IF @nombre IS NULL OR @nombre = ''
        SET @err = @err + ' - El nombre es obligatorio.';

    IF @apellido IS NULL OR @apellido = ''
        SET @err = @err + ' - El apellido es obligatorio.';

    IF @fecha_nacimiento > GETDATE()
        SET @err = @err + ' - La fecha de nacimiento no puede ser futura.';

    IF NOT EXISTS (SELECT 1 FROM cat.Pais WHERE id_pais = @id_pais_nacionalidad)
        SET @err = @err + ' - El pais de nacionalidad no existe.';

    IF (@tipo_documento IS NULL AND @nro_documento IS NOT NULL)
       OR (@tipo_documento IS NOT NULL AND @nro_documento IS NULL)
        SET @err = @err + ' - Tipo y numero de documento van juntos (los dos o ninguno).';

    IF @nro_documento IS NOT NULL
    BEGIN
        OPEN SYMMETRIC KEY sk_datos_personales DECRYPTION BY CERTIFICATE cert_datos_personales;

        IF EXISTS(SELECT 1 FROM comp.Persona
            WHERE tipo_documento = @tipo_documento
              AND CONVERT(varchar(30), DECRYPTBYKEY(nro_documento_cif)) = @nro_documento
              AND id_pais_nacionalidad = @id_pais_nacionalidad
              AND id_persona <> @id_persona)
            SET @err = @err + ' - Otra persona ya tiene ese documento.';
    END

    IF @err <> ''
    BEGIN
        IF @nro_documento IS NOT NULL
            CLOSE SYMMETRIC KEY sk_datos_personales;
        SET @err = 'usp_Persona_Modificacion:' + @err;
        THROW 50052, @err, 1;
    END

    UPDATE comp.Persona
    SET nombre = @nombre, apellido = @apellido, fecha_nacimiento = @fecha_nacimiento,
        id_pais_nacionalidad = @id_pais_nacionalidad,
        tipo_documento = @tipo_documento,
        nro_documento_cif = ENCRYPTBYKEY(KEY_GUID('sk_datos_personales'), @nro_documento)
    WHERE id_persona = @id_persona;

    IF @nro_documento IS NOT NULL
        CLOSE SYMMETRIC KEY sk_datos_personales;
END
GO


/* ----------------- 5. SP NUEVO: leer el documento descifrado ---------------------- */
-- Es la unica puerta para ver el numero de documento. Solo quien tenga EXECUTE sobre este
-- SP puede descifrar (en el script de roles se lo damos solo al administrador).

CREATE OR ALTER PROCEDURE comp.usp_Persona_DescifrarDocumento
    @id_persona int
WITH EXECUTE AS OWNER
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF @id_persona IS NULL
       OR NOT EXISTS (SELECT 1 FROM comp.Persona WHERE id_persona = @id_persona)
        SET @err = @err + ' - La persona no existe.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_Persona_DescifrarDocumento:' + @err;
        THROW 50054, @err, 1;
    END

    OPEN SYMMETRIC KEY sk_datos_personales DECRYPTION BY CERTIFICATE cert_datos_personales;

    SELECT id_persona, nombre, apellido, tipo_documento,
           CONVERT(varchar(30), DECRYPTBYKEY(nro_documento_cif)) AS nro_documento
    FROM comp.Persona
    WHERE id_persona = @id_persona;

    CLOSE SYMMETRIC KEY sk_datos_personales;
END
GO

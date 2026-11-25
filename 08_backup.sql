/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 8 - Script 08: Backups
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 2026-11-24
 Objetivo: implementar lo definido en doc/08_politica_backup.md.
             - Deja la base en modelo de recuperacion FULL (necesario para respaldar el log).
             - seg.usp_RealizarBackup @tipo: FULL, DIFF o LOG, con compresion y checksum, y la
               verificacion RESTORE VERIFYONLY de lo que acaba de generar.
             - seg.usp_RespaldarClaves: respalda el certificado y la master key (sin ellos, un
               backup restaurado en otro servidor no puede descifrar nro_documento).
           Las frecuencias (RPO 30 min / 5 min en dias de partido) se programan con SQL Server Agent.
 Antes de correr: crear la carpeta C:\MundialDB_Backups\ (o pasar otra en @ruta).
 Orden:    despues de 08_cifrado.sql
=====================================================================
*/
USE MundialDB;
GO

ALTER DATABASE MundialDB SET RECOVERY FULL;
GO

CREATE OR ALTER PROCEDURE seg.usp_RealizarBackup
    @tipo varchar(4),                                -- FULL | DIFF | LOG
    @ruta nvarchar(200) = N'C:\MundialDB_Backups\'
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF @tipo IS NULL OR @tipo NOT IN ('FULL', 'DIFF', 'LOG')
        SET @err = @err + ' - El tipo debe ser FULL, DIFF o LOG.';

    IF @ruta IS NULL OR @ruta = N''
        SET @err = @err + ' - La ruta es obligatoria.';

    -- El backup de log y el diferencial necesitan un FULL previo
    IF @tipo IN ('DIFF', 'LOG')
       AND NOT EXISTS (SELECT 1 FROM msdb.dbo.backupset
                       WHERE database_name = 'MundialDB' AND type = 'D')
        SET @err = @err + ' - Hace falta un backup FULL previo.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_RealizarBackup:' + @err;
        THROW 50082, @err, 1;
    END

    DECLARE @stamp varchar(15) =
        REPLACE(REPLACE(REPLACE(CONVERT(varchar(19), GETDATE(), 120), '-', ''), ':', ''), ' ', '_');
    DECLARE @archivo nvarchar(400) = @ruta + N'MundialDB_' + @tipo + N'_' + @stamp
                                   + CASE WHEN @tipo = 'LOG' THEN N'.trn' ELSE N'.bak' END;

    IF @tipo = 'FULL'
        BACKUP DATABASE MundialDB TO DISK = @archivo
            WITH COMPRESSION, CHECKSUM, INIT, NAME = 'MundialDB FULL';
    ELSE IF @tipo = 'DIFF'
        BACKUP DATABASE MundialDB TO DISK = @archivo
            WITH DIFFERENTIAL, COMPRESSION, CHECKSUM, INIT, NAME = 'MundialDB DIFF';
    ELSE
        BACKUP LOG MundialDB TO DISK = @archivo
            WITH COMPRESSION, CHECKSUM, INIT, NAME = 'MundialDB LOG';

    -- Verificacion: el archivo se puede leer y su checksum es correcto
    RESTORE VERIFYONLY FROM DISK = @archivo WITH CHECKSUM;

    SELECT @tipo AS tipo, @archivo AS archivo, SYSDATETIME() AS generado;
END
GO

CREATE OR ALTER PROCEDURE seg.usp_RespaldarClaves
    @ruta       nvarchar(200) = N'C:\MundialDB_Backups\Claves\',
    @contrasena nvarchar(128)                       -- protege los archivos de claves
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF @contrasena IS NULL OR LEN(@contrasena) < 12
        SET @err = @err + ' - La contrasena debe tener al menos 12 caracteres.';

    IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'cert_datos_personales')
        SET @err = @err + ' - No existe el certificado: ejecutar antes 08_cifrado.sql.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_RespaldarClaves:' + @err;
        THROW 50083, @err, 1;
    END

    -- BACKUP CERTIFICATE y BACKUP MASTER KEY no aceptan variables en la contrasena ni en la ruta,
    -- por eso es SQL dinamico (estrictamente necesario aca).
    DECLARE @sql nvarchar(max);
    SET @sql = N'BACKUP CERTIFICATE cert_datos_personales TO FILE = ''' + @ruta + N'cert_datos_personales.cer''
        WITH PRIVATE KEY (FILE = ''' + @ruta + N'cert_datos_personales.pvk'',
        ENCRYPTION BY PASSWORD = ''' + REPLACE(@contrasena, '''', '''''') + N''');';
    EXEC sp_executesql @sql;

    SET @sql = N'BACKUP MASTER KEY TO FILE = ''' + @ruta + N'MundialDB_masterkey.key''
        ENCRYPTION BY PASSWORD = ''' + REPLACE(@contrasena, '''', '''''') + N''';';
    EXEC sp_executesql @sql;
END
GO

/* ----------------- USO (descomentar para probar) -----------------------------------
EXEC seg.usp_RealizarBackup @tipo = 'FULL';
EXEC seg.usp_RealizarBackup @tipo = 'DIFF';
EXEC seg.usp_RealizarBackup @tipo = 'LOG';
EXEC seg.usp_RespaldarClaves @contrasena = N'Una#Contrasena#Larga#2026';
----------------------------------------------------------------------------------- */

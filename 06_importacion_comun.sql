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
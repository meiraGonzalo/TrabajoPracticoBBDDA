/*
=====================================================================
 Entrega 5 - Testing del ABM de Disciplina (1:1 con el script 02)
 Grupo 02 - Comision 02-5600
 Integrante: Miro, Saba.
 Objetivo: testear los SP de ABM del modulo disciplina.
=====================================================================
*/
USE MundialDB;
GO
SET NOCOUNT ON;
PRINT '=== TEST ABM DISCIPLINA ===';

/* -------- CASO 1 (EXITOSO, via SP, autolimpiante): alta + baja de TipoGol --------
   Esperado: 1a muestra 'TEST_TG' insertado; 1b queda en 0 tras la baja. */
EXEC disc.usp_TipoGol_Alta @nombre = 'TEST_TG';
SELECT 'CASO 1a - alta exitosa' AS caso, * FROM disc.TipoGol WHERE nombre = 'TEST_TG';

DECLARE @id int = (SELECT id_tipo_gol FROM disc.TipoGol WHERE nombre = 'TEST_TG');
EXEC disc.usp_TipoGol_Baja @id_tipo_gol = @id;
SELECT 'CASO 1b - baja exitosa (esperado: 0)' AS caso, COUNT(*) AS quedan
FROM disc.TipoGol WHERE nombre = 'TEST_TG';

/* -------- CASO 2 (VALIDACION): alta de TipoGol con nombre vacio --------
   Esperado: THROW -> 'usp_TipoGol_Alta: - El nombre es obligatorio.' */
BEGIN TRY
    EXEC disc.usp_TipoGol_Alta @nombre = '';
END TRY
BEGIN CATCH
    PRINT 'CASO 2 - error esperado: ' + ERROR_MESSAGE();
END CATCH

/* -------- CASO 3 (VALIDACION - mensaje agrupado): tarjeta invalida en varios campos --------
   Sin jugador ni cuerpo tecnico, tipo invalido, motivo vacio, periodo inexistente, minuto fuera de rango.
   Esperado: UN solo THROW que agrupa TODAS las condiciones no cumplidas. */
BEGIN TRY
    EXEC disc.usp_Tarjeta_Alta
        @id_alineacion = NULL, @id_cuerpo_tecnico = NULL, @id_partido_seleccion = NULL,
        @tipo_tarjeta = 'Violeta', @motivo = '', @id_periodo = 999, @minuto = 200;
END TRY
BEGIN CATCH
    PRINT 'CASO 3 - error esperado (agrupado): ' + ERROR_MESSAGE();
END CATCH
GO
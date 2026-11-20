/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 09 - Vistas para la plataforma de BI (Power BI Desktop)
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 20/11/2026
 Objetivo: vistas para power bi
=====================================================================
*/

USE MundialDB;
GO

IF SCHEMA_ID(N'bi') IS NULL EXEC(N'CREATE SCHEMA bi');   -- vistas para BI
GO


   --Goles: uno por fila--
CREATE OR ALTER VIEW bi.vw_Goles
AS
SELECT t.anio,
       p.nro_partido,
       f.nombre AS fase,
       f.orden  AS orden_fase,
       pa.nombre AS seleccion,
       pe.nombre + ' ' + pe.apellido AS jugador,
       tg.nombre AS tipo_gol,
       pr.nombre AS periodo,
       g.minuto,
       g.minuto_adicional
FROM disc.Gol g
JOIN disc.TipoGol tg          ON tg.id_tipo_gol = g.id_tipo_gol
JOIN comp.Periodo pr          ON pr.id_periodo = g.id_periodo
JOIN comp.Alineacion a        ON a.id_alineacion = g.id_alineacion_autor
JOIN comp.Convocado c         ON c.id_convocado = a.id_convocado
JOIN comp.Persona pe          ON pe.id_persona = c.id_jugador
JOIN comp.Seleccion s         ON s.id_seleccion = c.id_seleccion
JOIN cat.Pais pa              ON pa.id_pais = s.id_pais
JOIN comp.PartidoSeleccion ps ON ps.id_partido_seleccion = a.id_partido_seleccion
JOIN comp.Partido p           ON p.id_partido = ps.id_partido
JOIN comp.Torneo t            ON t.id_torneo = p.id_torneo
JOIN comp.Fase f              ON f.id_fase = p.id_fase
WHERE tg.nombre <> 'En contra'
  AND pr.nombre <> 'Definicion por penales';
GO


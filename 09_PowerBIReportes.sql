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


   --Resultados: un partido por fila--
CREATE OR ALTER VIEW bi.vw_Resultados
AS
SELECT t.anio,
       p.nro_partido,
       f.nombre AS fase,
       f.orden  AS orden_fase,
       g.letra  AS grupo,
       CAST(p.fecha_hora_local AS date) AS fecha,
       p.fecha_hora_local,
       se.nombre_estadio AS sede,
       ci.nombre AS ciudad,
       ISNULL(pal.nombre, 'A definir') AS local,
       ISNULL(pav.nombre, 'A definir') AS visitante,
       psl.goles AS goles_local,
       psv.goles AS goles_visitante,
       psl.goles + psv.goles AS goles_totales,            -- NULL si no se jugo
       CASE WHEN psl.goles IS NULL OR psv.goles IS NULL THEN NULL
            ELSE CAST(psl.goles AS varchar(3)) + '-' + CAST(psv.goles AS varchar(3))
                 + CASE WHEN psl.goles_penales IS NOT NULL
                        THEN ' (pen. ' + CAST(psl.goles_penales AS varchar(3)) + '-'
                             + CAST(psv.goles_penales AS varchar(3)) + ')'
                        ELSE '' END
       END AS resultado,
       CASE WHEN psl.goles IS NULL OR psv.goles IS NULL THEN NULL
            WHEN psl.goles > psv.goles THEN pal.nombre
            WHEN psv.goles > psl.goles THEN pav.nombre
            WHEN psl.goles_penales > psv.goles_penales THEN pal.nombre
            WHEN psv.goles_penales > psl.goles_penales THEN pav.nombre
            ELSE 'Empate'
       END AS ganador,
       CASE WHEN psl.goles IS NULL OR psv.goles IS NULL THEN NULL
            WHEN psl.goles > psv.goles THEN 'Gana local'
            WHEN psv.goles > psl.goles THEN 'Gana visitante'
            WHEN psl.goles_penales IS NOT NULL THEN 'Definido por penales'
            ELSE 'Empate'
       END AS tipo_resultado,
       p.asistencia,
       se.capacidad,
       p.estado
FROM comp.Partido p
JOIN comp.Torneo t      ON t.id_torneo = p.id_torneo
JOIN comp.Fase f        ON f.id_fase = p.id_fase
LEFT JOIN comp.Grupo g  ON g.id_grupo = p.id_grupo
JOIN comp.Sede se       ON se.id_sede = p.id_sede
JOIN cat.Ciudad ci      ON ci.id_ciudad = se.id_ciudad
LEFT JOIN comp.PartidoSeleccion psl ON psl.id_partido = p.id_partido AND psl.condicion = 'L'
LEFT JOIN comp.Seleccion sl         ON sl.id_seleccion = psl.id_seleccion
LEFT JOIN cat.Pais pal              ON pal.id_pais = sl.id_pais
LEFT JOIN comp.PartidoSeleccion psv ON psv.id_partido = p.id_partido AND psv.condicion = 'V'
LEFT JOIN comp.Seleccion sv         ON sv.id_seleccion = psv.id_seleccion
LEFT JOIN cat.Pais pav              ON pav.id_pais = sv.id_pais;
GO


   --Ingresos de publicidad: una exhibicion por fila--

CREATE OR ALTER VIEW bi.vw_IngresosPublicidad
AS
SELECT t.anio,
       p.nro_partido,
       f.nombre AS fase,
       f.orden  AS orden_fase,
       CAST(p.fecha_hora_utc AS date) AS fecha,
       se.nombre_estadio AS sede,
       anu.nombre AS anunciante,
       m.nombre   AS marca,
       camp.titulo AS campania,
       ISNULL(ag.nombre, 'Sin Agencia') AS agencia,
       pm.nombre  AS mercado,                              -- pais al que apunta la pieza
       ep.nro_espacio,
       ep.estado,
       ep.monto_aplicado,
       mo.codigo_iso AS moneda,
       cat.ufn_ConvertirMoneda(ep.monto_aplicado, ep.id_moneda,
                               (SELECT id_moneda FROM cat.Moneda WHERE codigo_iso = 'USD'),
                               CAST(p.fecha_hora_utc AS date)) AS monto_usd
FROM pub.ExhibicionPublicitaria ep
JOIN pub.PiezaPublicitaria pz ON pz.id_pieza_publicitaria = ep.id_pieza_publicitaria
JOIN cat.Pais pm              ON pm.id_pais = pz.id_pais_mercado
JOIN pub.Campania camp        ON camp.id_campania = pz.id_campania
LEFT JOIN pub.Agencia ag      ON ag.id_agencia = camp.id_agencia
JOIN pub.Marca m              ON m.id_marca = camp.id_marca
JOIN pub.Anunciante anu       ON anu.id_anunciante = m.id_anunciante
JOIN cat.Moneda mo            ON mo.id_moneda = ep.id_moneda
JOIN comp.Partido p           ON p.id_partido = ep.id_partido
JOIN comp.Torneo t            ON t.id_torneo = p.id_torneo
JOIN comp.Fase f              ON f.id_fase = p.id_fase
JOIN comp.Sede se             ON se.id_sede = p.id_sede;
GO

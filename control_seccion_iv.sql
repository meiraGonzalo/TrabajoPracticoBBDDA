/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Control de los criterios de aceptacion (seccion IV) - Script 11
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 24/11/2026
 Objetivo: verificar, con consultas sobre la base, cada punto de la
   seccion IV del enunciado. Devuelve una sola tabla: criterio, lo que se
   pide, lo que hay y OK / FALTA. Solo lee datos.
 Orden: al final de todo (importaciones, 10_seed_disciplina.sql,
   10_seed_seccion_IV.sql e importacion de goles).
=====================================================================
*/
USE MundialDB;
GO
SET NOCOUNT ON;

DECLARE @t int = (SELECT id_torneo FROM comp.Torneo WHERE anio = 2026);

DECLARE @sedes int, @husos int, @selecciones int, @partidos_formacion int, @arbitros int,
        @partidos_5_roles int, @paises_anunciantes int, @doble_amarilla int, @roja_directa int,
        @susp_afuera int, @lesion int, @partidos_prime int, @arb_conflicto int, @desig_conflicto int,
        @imp_parcial int;

-- 1. Sedes y husos horarios distintos
SELECT @sedes = COUNT(*), @husos = COUNT(DISTINCT ci.huso_horario)
FROM comp.Sede s JOIN cat.Ciudad ci ON ci.id_ciudad = s.id_ciudad;

-- 2. Selecciones del torneo con al menos 23 convocados activos
SELECT @selecciones = COUNT(*)
FROM comp.Seleccion s
WHERE s.id_torneo = @t
  AND (SELECT COUNT(*) FROM comp.Convocado c WHERE c.id_seleccion = s.id_seleccion AND c.fecha_baja IS NULL) >= 23;

-- 3. Partidos con formacion titular (11) y banco en las dos selecciones
SELECT @partidos_formacion = COUNT(*)
FROM (SELECT ps.id_partido
      FROM comp.PartidoSeleccion ps
      JOIN comp.Partido p ON p.id_partido = ps.id_partido AND p.id_torneo = @t
      WHERE (SELECT COUNT(*) FROM comp.Alineacion a WHERE a.id_partido_seleccion = ps.id_partido_seleccion AND a.es_titular = 1) = 11
        AND (SELECT COUNT(*) FROM comp.Alineacion a WHERE a.id_partido_seleccion = ps.id_partido_seleccion AND a.es_titular = 0) > 0
      GROUP BY ps.id_partido
      HAVING COUNT(*) = 2) x;

-- 4. Arbitros y partidos con los 5 roles designados
SELECT @arbitros = COUNT(*) FROM disc.Arbitro;
SELECT @partidos_5_roles = COUNT(*)
FROM (SELECT d.id_partido
      FROM disc.Designacion d
      JOIN comp.Partido p ON p.id_partido = d.id_partido AND p.id_torneo = @t
      GROUP BY d.id_partido
      HAVING COUNT(DISTINCT d.rol) = 5) x;

-- 5. Paises distintos de los anunciantes con campanias
SELECT @paises_anunciantes = COUNT(DISTINCT an.id_pais)
FROM pub.Anunciante an
JOIN pub.Marca m    ON m.id_anunciante = an.id_anunciante
JOIN pub.Campania c ON c.id_marca = m.id_marca;

-- 6. Expulsion por doble amonestacion y roja directa (en partidos distintos)
SELECT @doble_amarilla = COUNT(*) FROM disc.Tarjeta WHERE tipo_tarjeta = 'Roja por doble amarilla';
SELECT @roja_directa   = COUNT(*) FROM disc.Tarjeta WHERE tipo_tarjeta = 'Roja directa';

-- 7. Suspendido por acumulacion de amarillas que quedo afuera del partido en que cumple
SELECT @susp_afuera = COUNT(*)
FROM disc.Suspension su
JOIN disc.Tarjeta t ON t.id_tarjeta = su.id_tarjeta_origen AND t.tipo_tarjeta = 'Amarilla'
WHERE su.id_convocado IS NOT NULL
  AND su.id_partido_cumple IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM comp.Alineacion a
                  JOIN comp.PartidoSeleccion ps ON ps.id_partido_seleccion = a.id_partido_seleccion
                  WHERE a.id_convocado = su.id_convocado AND ps.id_partido = su.id_partido_cumple);

-- 8. Cambio por lesion en los primeros 20 minutos
SELECT @lesion = COUNT(*)
FROM comp.Sustitucion s
JOIN comp.Periodo pr ON pr.id_periodo = s.id_periodo AND pr.nombre = 'Primer tiempo'
WHERE s.motivo = 'Lesion' AND s.minuto <= 20;

-- 9. Partido en prime time en mas de 4 mercados candidatos, con 4 espacios asignados
SELECT @partidos_prime = COUNT(*)
FROM (SELECT p.id_partido
      FROM comp.Partido p
      CROSS JOIN pub.PiezaPublicitaria pz
      JOIN pub.Campania ca ON ca.id_campania = pz.id_campania
      JOIN cat.Pais pm     ON pm.id_pais = pz.id_pais_mercado
      CROSS APPLY pub.ufn_ObtenerHoraLocalYFranja(p.fecha_hora_utc, pm.huso_horario) hl
      JOIN pub.FranjaHoraria fh ON fh.es_prime_time = 1
           AND ((fh.hora_desde <= fh.hora_hasta AND hl.hora_local >= fh.hora_desde AND hl.hora_local <= fh.hora_hasta)
             OR (fh.hora_desde > fh.hora_hasta AND (hl.hora_local >= fh.hora_desde OR hl.hora_local <= fh.hora_hasta)))
      WHERE p.id_torneo = @t
        AND (ca.fecha_desde IS NULL OR ca.fecha_desde <= CAST(p.fecha_hora_utc AS date))
        AND (ca.fecha_hasta IS NULL OR ca.fecha_hasta >= CAST(p.fecha_hora_utc AS date))
        AND (SELECT COUNT(*) FROM pub.ExhibicionPublicitaria e WHERE e.id_partido = p.id_partido) = 4
      GROUP BY p.id_partido
      HAVING COUNT(DISTINCT pm.id_pais) > 4) x;

-- 10. Designacion descartada por conflicto de nacionalidad: el rechazo no deja fila (se ve en
--     vivo en 10_seed_disciplina.sql, parte 2). Aca se controla que el caso sea posible (hay
--     arbitros del pais de alguna seleccion) y que no haya quedado ninguna designacion en conflicto.
SELECT @arb_conflicto = COUNT(DISTINCT a.id_arbitro)
FROM disc.Arbitro a
JOIN comp.Persona pe  ON pe.id_persona = a.id_arbitro
JOIN comp.Seleccion s ON s.id_pais = pe.id_pais_nacionalidad AND s.id_torneo = @t;

SELECT @desig_conflicto = COUNT(*)
FROM disc.Designacion d
JOIN comp.Partido p           ON p.id_partido = d.id_partido AND p.id_torneo = @t
JOIN comp.PartidoSeleccion ps ON ps.id_partido = p.id_partido
JOIN comp.Seleccion s         ON s.id_seleccion = ps.id_seleccion
JOIN comp.Persona pe          ON pe.id_persona = d.id_arbitro AND pe.id_pais_nacionalidad = s.id_pais;

-- 11. Importacion con errores parciales (filas OK y filas con error en la misma importacion)
SELECT @imp_parcial = COUNT(*) FROM imp.LogImportacion WHERE filas_ok > 0 AND filas_error > 0;


-- Resultado
SELECT criterio, pedido, obtenido, CASE WHEN cumple = 1 THEN 'OK' ELSE 'FALTA' END AS estado
FROM (
    SELECT 1 AS orden, 'Sedes (con al menos 3 husos distintos)' AS criterio, '>= 8 sedes y >= 3 husos' AS pedido,
           CAST(@sedes AS varchar(10)) + ' sedes, ' + CAST(@husos AS varchar(10)) + ' husos' AS obtenido,
           CASE WHEN @sedes >= 8 AND @husos >= 3 THEN 1 ELSE 0 END AS cumple
    UNION ALL SELECT 2, 'Selecciones con al menos 23 convocados', '>= 16',
           CAST(@selecciones AS varchar(10)), CASE WHEN @selecciones >= 16 THEN 1 ELSE 0 END
    UNION ALL SELECT 3, 'Partidos con formacion titular y banco', '>= 24',
           CAST(@partidos_formacion AS varchar(10)), CASE WHEN @partidos_formacion >= 24 THEN 1 ELSE 0 END
    UNION ALL SELECT 4, 'Arbitros', '>= 15',
           CAST(@arbitros AS varchar(10)), CASE WHEN @arbitros >= 15 THEN 1 ELSE 0 END
    UNION ALL SELECT 5, 'Partidos con designacion completa (5 roles)', '>= 24 (todos los partidos)',
           CAST(@partidos_5_roles AS varchar(10)), CASE WHEN @partidos_5_roles >= 24 THEN 1 ELSE 0 END
    UNION ALL SELECT 6, 'Paises de los anunciantes con campanias', '>= 6',
           CAST(@paises_anunciantes AS varchar(10)), CASE WHEN @paises_anunciantes >= 6 THEN 1 ELSE 0 END
    UNION ALL SELECT 7, 'Expulsion por doble amonestacion', '>= 1',
           CAST(@doble_amarilla AS varchar(10)), CASE WHEN @doble_amarilla >= 1 THEN 1 ELSE 0 END
    UNION ALL SELECT 8, 'Expulsion por roja directa', '>= 1',
           CAST(@roja_directa AS varchar(10)), CASE WHEN @roja_directa >= 1 THEN 1 ELSE 0 END
    UNION ALL SELECT 9, 'Suspendido por acumulacion fuera de la formacion siguiente', '>= 1',
           CAST(@susp_afuera AS varchar(10)), CASE WHEN @susp_afuera >= 1 THEN 1 ELSE 0 END
    UNION ALL SELECT 10, 'Cambio por lesion en los primeros 20 minutos', '>= 1',
           CAST(@lesion AS varchar(10)), CASE WHEN @lesion >= 1 THEN 1 ELSE 0 END
    UNION ALL SELECT 11, 'Partido en prime time en mas de 4 mercados (con 4 espacios asignados)', '>= 1',
           CAST(@partidos_prime AS varchar(10)), CASE WHEN @partidos_prime >= 1 THEN 1 ELSE 0 END
    UNION ALL SELECT 12, 'Designacion descartada por conflicto de nacionalidad', 'arbitros en conflicto posibles > 0 y designaciones en conflicto = 0',
           CAST(@arb_conflicto AS varchar(10)) + ' posibles, ' + CAST(@desig_conflicto AS varchar(10)) + ' cargadas',
           CASE WHEN @arb_conflicto > 0 AND @desig_conflicto = 0 THEN 1 ELSE 0 END
    UNION ALL SELECT 13, 'Importacion con errores parciales', '>= 1',
           CAST(@imp_parcial AS varchar(10)), CASE WHEN @imp_parcial >= 1 THEN 1 ELSE 0 END
) r
ORDER BY orden;
GO
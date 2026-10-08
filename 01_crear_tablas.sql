/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 5 - Script 01: Creacion de tablas, indices, FK y CHECK
 Grupo 02 - Comision 02-5600
 Integrantes: [completar]
 Fecha: 2026-10-08
 Objetivo: crear todas las tablas del modelo con sus restricciones.
           Requiere ejecutar antes el script 00 (crea MundialDB).
 Convertido desde el export de dbdiagram (estaba en dialecto MySQL).
=====================================================================
*/

USE MundialDB;
GO

/* ===================== TABLAS ===================== */

CREATE TABLE cat.Moneda (
  id_moneda int IDENTITY(1,1) PRIMARY KEY,
  codigo_iso char(3) UNIQUE NOT NULL,
  nombre varchar(50) NOT NULL
);
GO

CREATE TABLE cat.Idioma (
  id_idioma int IDENTITY(1,1) PRIMARY KEY,
  codigo_iso char(2) UNIQUE NOT NULL,
  nombre varchar(50) NOT NULL
);
GO

CREATE TABLE cat.Pais (
  id_pais int IDENTITY(1,1) PRIMARY KEY,
  nombre varchar(100) NOT NULL,
  confederacion varchar(20),  -- CHECK: CONMEBOL / UEFA / CAF / AFC / CONCACAF / OFC
  id_moneda int,
  huso_horario varchar(50) NOT NULL  -- Huso de referencia del mercado. Nombre Windows para AT TIME ZONE
);
GO

CREATE TABLE cat.Ciudad (
  id_ciudad int IDENTITY(1,1) PRIMARY KEY,
  nombre nvarchar(100) NOT NULL,
  id_pais int NOT NULL,
  huso_horario varchar(50) NOT NULL  -- El huso depende de la ciudad, no del estadio
);
GO

CREATE TABLE cat.IndicadorEconomico (
  id_pais int NOT NULL,
  anio smallint NOT NULL,
  codigo_indicador varchar(30) NOT NULL,  -- Ej: NY.GDP.PCAP.CD (Banco Mundial)
  valor decimal(18,2) NOT NULL,
  PRIMARY KEY (id_pais, anio, codigo_indicador)
);
GO

CREATE TABLE cat.TipoCambio (
  id_moneda int NOT NULL,
  fecha date NOT NULL,
  tasa_usd decimal(18,6) NOT NULL,
  PRIMARY KEY (id_moneda, fecha)
);
GO

CREATE TABLE cat.Feriado (
  id_pais int NOT NULL,
  fecha date NOT NULL,
  nombre varchar(150) NOT NULL,
  PRIMARY KEY (id_pais, fecha)
);
GO

CREATE TABLE comp.Torneo (
  id_torneo int IDENTITY(1,1) PRIMARY KEY,
  nombre varchar(100) NOT NULL,
  anio smallint UNIQUE NOT NULL,
  fecha_inicio date,
  fecha_fin date
);
GO

CREATE TABLE comp.ParametroReglamento (
  id_torneo int NOT NULL,
  clave varchar(50) NOT NULL,  -- MIN_CONVOCADOS, MAX_CONVOCADOS, MAX_CAMBIOS, MAX_VENTANAS, CAMBIOS_EXTRA_ALARGUE, AMARILLAS_SUSPENSION, AMARILLAS_SUSPENSION_CT, FASE_LIMPIA_AMARILLAS, PARTIDOS_POR_ROJA...
  valor int NOT NULL,
  descripcion varchar(200),
  PRIMARY KEY (id_torneo, clave)
);
GO

CREATE TABLE comp.Sede (
  id_sede int IDENTITY(1,1) PRIMARY KEY,
  nombre_estadio nvarchar(100) NOT NULL,
  id_ciudad int NOT NULL,
  capacidad int NOT NULL,
  latitud decimal(9,6),
  longitud decimal(9,6)
);
GO

CREATE TABLE comp.Fase (
  id_fase int IDENTITY(1,1) PRIMARY KEY,
  nombre varchar(30) UNIQUE NOT NULL,  -- Grupos, Dieciseisavos, Octavos, Cuartos, Semifinal, Tercer puesto, Final
  orden tinyint NOT NULL,
  es_eliminatoria bit NOT NULL
);
GO

CREATE TABLE comp.Grupo (
  id_grupo int IDENTITY(1,1) PRIMARY KEY,
  id_torneo int NOT NULL,
  letra char(1) NOT NULL
);
GO

CREATE TABLE comp.Partido (
  id_partido int IDENTITY(1,1) PRIMARY KEY,
  id_torneo int NOT NULL,
  nro_partido smallint NOT NULL,  -- Numero oficial FIFA
  id_fase int NOT NULL,
  id_grupo int,  -- fase de grupos
  id_sede int NOT NULL,
  fecha_hora_utc datetime2(0) NOT NULL,
  fecha_hora_local datetime2(0) NOT NULL,  -- DESNORMALIZADO: derivable de UTC + huso. Lo exige el enunciado
  asistencia int,
  estado varchar(15) NOT NULL DEFAULT 'PROGRAMADO',  -- CHECK: PROGRAMADO / EN_JUEGO / FINALIZADO / SUSPENDIDO
  id_partido_siguiente int  -- Llave: partido al que avanza el ganador. Permite calcular cruces posibles
);
GO

CREATE TABLE comp.PartidoSeleccion (
  id_partido_seleccion int IDENTITY(1,1) PRIMARY KEY,
  id_partido int NOT NULL,
  id_seleccion int NOT NULL,
  condicion char(1) NOT NULL,  -- CHECK: L / V. Exactamente 2 filas por partido (valida SP)
  esquema_tactico varchar(10),  -- Notacion libre: 4-3-3, 4-4-2, 3-5-2, 3-4-1-2
  goles tinyint,  -- DESNORMALIZADO: derivable de Gol. Se importan resultados sin detalle de goles
  goles_penales tinyint  -- Solo si hubo definicion por penales
);
GO

CREATE TABLE comp.Persona (
  id_persona int IDENTITY(1,1) PRIMARY KEY,
  nombre nvarchar(80) NOT NULL,
  apellido nvarchar(80) NOT NULL,
  fecha_nacimiento date,
  id_pais_nacionalidad int NOT NULL,
  tipo_documento varchar(15),
  nro_documento varchar(30)
);
GO

CREATE TABLE comp.Posicion (
  id_posicion int IDENTITY(1,1) PRIMARY KEY,
  nombre varchar(30) UNIQUE NOT NULL  -- Arquero, Defensor, Mediocampista, Delantero
);
GO

CREATE TABLE comp.Jugador (
  id_jugador int PRIMARY KEY,
  id_posicion_habitual int NOT NULL  -- Catalogo y no CHECK: el dominio se referencia desde Jugador y Alineacion; un CHECK duplicado en dos tablas puede divergir
);
GO

CREATE TABLE comp.Club (
  id_club int IDENTITY(1,1) PRIMARY KEY,
  nombre nvarchar(100) NOT NULL,
  id_pais int NOT NULL
);
GO

CREATE TABLE comp.Seleccion (
  id_seleccion int IDENTITY(1,1) PRIMARY KEY,
  id_torneo int NOT NULL,
  id_pais int NOT NULL,
  id_grupo int
);
GO

CREATE TABLE comp.CuerpoTecnico (
  id_cuerpo_tecnico int IDENTITY(1,1) PRIMARY KEY,
  id_seleccion int NOT NULL,
  id_persona int NOT NULL,
  rol varchar(40) NOT NULL  -- CHECK: Director Tecnico / Ayudante de Campo / Preparador Fisico
);
GO

CREATE TABLE comp.Convocado (
  id_convocado int IDENTITY(1,1) PRIMARY KEY,
  id_seleccion int NOT NULL,
  id_jugador int NOT NULL,
  dorsal tinyint NOT NULL,  -- Unico entre convocados activos de la seleccion
  id_club int,  -- Club de origen al momento del torneo
  fecha_alta date NOT NULL,
  fecha_baja date  -- DESNORMALIZADO: derivable de CambioConvocatoria. Copia para consulta rapida del plantel activo
);
GO

CREATE TABLE comp.CambioConvocatoria (
  id_cambio_convocatoria int IDENTITY(1,1) PRIMARY KEY,
  id_convocado_baja int,
  id_convocado_alta int,
  motivo varchar(40) NOT NULL,  -- CHECK sugerido: Lesion / Enfermedad / Decision tecnica / Sancion (dominio no explicito en el enunciado, definido por el grupo).
  fecha date NOT NULL,
  observacion varchar(200)
);
GO

CREATE TABLE comp.Alineacion (
  id_alineacion int IDENTITY(1,1) PRIMARY KEY,
  id_partido_seleccion int NOT NULL,
  id_convocado int NOT NULL,  -- Dorsal sale de Convocado. SP valida misma seleccion y que no este suspendido
  es_titular bit NOT NULL,  -- 1 = titular, 0 = banco de suplentes
  id_posicion_cancha int  -- Solo titulares
);
GO

CREATE TABLE disc.Periodo (
  id_periodo int IDENTITY(1,1) PRIMARY KEY,
  nombre varchar(30) UNIQUE NOT NULL,  -- Primer tiempo, Segundo tiempo, Alargue 1, Alargue 2, Definicion por penales
  orden tinyint NOT NULL  -- el orden es imprescindible para ordenar goles/tarjetas/cambios cronologicamente y reconstruir el equipo en cualquier minuto
);
GO

CREATE TABLE comp.Sustitucion (
  id_sustitucion int IDENTITY(1,1) PRIMARY KEY,
  id_alineacion_sale int NOT NULL,
  id_alineacion_entra int NOT NULL,
  id_periodo int NOT NULL,
  minuto tinyint NOT NULL,
  minuto_adicional tinyint NOT NULL DEFAULT 0,  -- 45+2 => minuto 45, adicional 2
  nro_ventana tinyint,  -- NULL = entretiempo
  motivo varchar(20) NOT NULL  -- CHECK: Tactico / Lesion / Precaucion
);
GO

CREATE TABLE disc.TipoGol (
  id_tipo_gol int IDENTITY(1,1) PRIMARY KEY,
  nombre varchar(30) UNIQUE NOT NULL  -- Jugada, Penal, Tiro libre, En contra, Cabezazo... El enunciado deja el dominio abierto ("etc.") y los datasets importados traen valores propios: con CHECK cada valor nuevo exigiria ALTER TABLE
);
GO

CREATE TABLE disc.Gol (
  id_gol int IDENTITY(1,1) PRIMARY KEY,
  id_alineacion_autor int NOT NULL,
  id_alineacion_asistencia int,
  id_tipo_gol int NOT NULL,
  id_periodo int NOT NULL,
  minuto tinyint NOT NULL,
  minuto_adicional tinyint NOT NULL DEFAULT 0
);
GO

CREATE TABLE disc.Tarjeta (
  id_tarjeta int IDENTITY(1,1) PRIMARY KEY,
  id_alineacion int,  -- Sancionado = JUGADOR (trae partido+seleccion via Alineacion). Exclusivo con la rama cuerpo tecnico
  id_cuerpo_tecnico int,  -- Sancionado = miembro del CUERPO TECNICO (DT, ayudantes). No esta en Alineacion, por eso rama propia. IFAB admite tarjetas a oficiales de equipo
  id_partido_seleccion int,  -- Contexto partido+seleccion SOLO para la rama cuerpo tecnico; el jugador ya lo trae via Alineacion (no se duplica)
  tipo_tarjeta varchar(30) NOT NULL,  -- CHECK: Amarilla / Roja directa / Roja por doble amarilla
  motivo varchar(200) NOT NULL,  -- el motivo de una tarjeta es descriptivo (ej. "manos", "protesta", "juego brusco por detras")
  id_periodo int NOT NULL,
  minuto tinyint NOT NULL,
  minuto_adicional tinyint NOT NULL DEFAULT 0
);
GO

CREATE TABLE disc.Suspension (
  id_suspension int IDENTITY(1,1) PRIMARY KEY,
  id_convocado int,  -- Suspendido = JUGADOR. Exclusivo con id_cuerpo_tecnico
  id_cuerpo_tecnico int,  -- Suspendido = CUERPO TECNICO (no juega: no puede estar en el area tecnica del proximo partido)
  id_tarjeta_origen int NOT NULL,  -- Roja, o la amarilla que completo la acumulacion
  id_partido_cumple int,  -- Partido en el que cumple. NULL = aun sin determinar
  estado varchar(10) NOT NULL DEFAULT 'PENDIENTE'  -- CHECK: PENDIENTE / CUMPLIDA / ANULADA
);
GO

CREATE TABLE disc.Arbitro (
  id_arbitro int PRIMARY KEY,  -- Subtipo de Persona. Pais = Persona.id_pais_nacionalidad
  categoria varchar(20) NOT NULL  -- CHECK: FIFA / Confederacion. Colapsado desde tabla CategoriaArbitro: 2 valores fijos, sin atributos propios
);
GO

CREATE TABLE disc.ArbitroIdioma (
  id_arbitro int NOT NULL,
  id_idioma int NOT NULL,
  PRIMARY KEY (id_arbitro, id_idioma)
);
GO

CREATE TABLE disc.Designacion (
  id_designacion int IDENTITY(1,1) PRIMARY KEY,
  id_partido int NOT NULL,
  id_arbitro int NOT NULL,
  rol varchar(20) NOT NULL,  -- CHECK: Principal / Asistente 1 / Asistente 2 / Cuarto Arbitro / VAR
  fecha_designacion date NOT NULL,
  advertencia varchar(200)  -- Desde dieciseisavos: posible cruce con el pais del arbitro
);
GO

CREATE TABLE disc.InformeArbitral (
  id_informe_arbitral int IDENTITY(1,1) PRIMARY KEY,
  id_designacion int NOT NULL,
  tipo varchar(10) NOT NULL,  -- CHECK: INFORME / SANCION
  fecha date NOT NULL,
  calificacion decimal(3,1),
  descripcion varchar(500)
);
GO

CREATE TABLE pub.Anunciante (
  id_anunciante int IDENTITY(1,1) PRIMARY KEY,
  nombre varchar(100) UNIQUE NOT NULL,  -- varchar a proposito: marcas globales en alfabeto latino. Pasar a nvarchar solo si se cargan anunciantes con caracteres no latinos
  id_pais int NOT NULL
);
GO

CREATE TABLE pub.Marca (
  id_marca int IDENTITY(1,1) PRIMARY KEY,
  id_anunciante int NOT NULL,
  nombre varchar(100) NOT NULL  -- varchar a proposito: marcas globales en alfabeto latino. Pasar a nvarchar solo si se cargan anunciantes con caracteres no latinos
);
GO

CREATE TABLE pub.Agencia (
  id_agencia int IDENTITY(1,1) PRIMARY KEY,
  nombre varchar(100) UNIQUE NOT NULL
);
GO

CREATE TABLE pub.Campania (
  id_campania int IDENTITY(1,1) PRIMARY KEY,
  id_marca int NOT NULL,
  id_agencia int,
  titulo varchar(150) NOT NULL,  -- varchar a proposito: marcas globales en alfabeto latino. Pasar a nvarchar solo si se cargan anunciantes con caracteres no latinos
  fecha_desde date,
  fecha_hasta date,
  descripcion varchar(500)
);
GO

CREATE TABLE pub.CampaniaPais (
  id_campania int NOT NULL,
  id_pais int NOT NULL,
  PRIMARY KEY (id_campania, id_pais)
);
GO

CREATE TABLE pub.PiezaPublicitaria (
  id_pieza_publicitaria int IDENTITY(1,1) PRIMARY KEY,
  id_campania int NOT NULL,
  id_idioma int NOT NULL,
  id_pais_mercado int NOT NULL,
  titulo varchar(150) NOT NULL,
  url_contenido varchar(300)
);
GO

CREATE TABLE pub.FranjaHoraria (
  id_franja_horaria int IDENTITY(1,1) PRIMARY KEY,
  nombre varchar(30) UNIQUE NOT NULL,
  hora_desde time(0) NOT NULL,
  hora_hasta time(0) NOT NULL,
  es_prime_time bit NOT NULL  -- Ej: 19 a 23 hs. Parametrizable
);
GO

CREATE TABLE pub.Tarifa (
  id_tarifa int IDENTITY(1,1) PRIMARY KEY,
  id_torneo int NOT NULL,
  id_fase int NOT NULL,
  id_franja_horaria int NOT NULL,
  monto decimal(12,2) NOT NULL,
  id_moneda int NOT NULL
);
GO

CREATE TABLE pub.ExhibicionPublicitaria (
  id_exhibicion_publicitaria int IDENTITY(1,1) PRIMARY KEY,
  id_partido int NOT NULL,
  nro_espacio tinyint NOT NULL,  -- CHECK entre 1 y 4
  id_pieza_publicitaria int NOT NULL,
  id_tarifa int NOT NULL,
  monto_aplicado decimal(12,2) NOT NULL,  -- DESNORMALIZADO: foto historica para facturar aunque cambie la tarifa
  id_moneda int NOT NULL,
  puntaje_prioridad decimal(8,2),  -- Resultado del criterio de priorizacion
  estado varchar(10) NOT NULL DEFAULT 'PROPUESTA'  -- CHECK: PROPUESTA / EXHIBIDA / CANCELADA
);
GO

CREATE TABLE imp.LogImportacion (
  id_log_importacion int IDENTITY(1,1) PRIMARY KEY,
  nombre_archivo varchar(260) NOT NULL,
  fuente varchar(100),
  fecha_inicio datetime2(0) NOT NULL,
  fecha_fin datetime2(0),
  filas_leidas int,
  filas_ok int,
  filas_error int
);
GO

CREATE TABLE imp.ErrorImportacion (
  id_error_importacion int IDENTITY(1,1) PRIMARY KEY,
  id_log_importacion int NOT NULL,
  nro_linea int,
  dato_original nvarchar(1000),
  mensaje varchar(500) NOT NULL
);
GO

/* ===================== INDICES UNICOS ===================== */
CREATE UNIQUE INDEX UQ_Ciudad_nombre_id_pais ON cat.Ciudad (nombre, id_pais);
CREATE UNIQUE INDEX UQ_Grupo_id_torneo_letra ON comp.Grupo (id_torneo, letra);
CREATE UNIQUE INDEX UQ_Partido_id_torneo_nro_partido ON comp.Partido (id_torneo, nro_partido);
CREATE UNIQUE INDEX UQ_PartidoSeleccion_id_partido_id_seleccion ON comp.PartidoSeleccion (id_partido, id_seleccion);
CREATE UNIQUE INDEX UQ_PartidoSeleccion_id_partido_condicion ON comp.PartidoSeleccion (id_partido, condicion);
CREATE UNIQUE INDEX UQ_Club_nombre_id_pais ON comp.Club (nombre, id_pais);
CREATE UNIQUE INDEX UQ_Seleccion_id_torneo_id_pais ON comp.Seleccion (id_torneo, id_pais);
CREATE UNIQUE INDEX UQ_CuerpoTecnico_id_seleccion_id_persona ON comp.CuerpoTecnico (id_seleccion, id_persona);
CREATE UNIQUE INDEX UQ_Convocado_id_seleccion_id_jugador ON comp.Convocado (id_seleccion, id_jugador);
CREATE UNIQUE INDEX UQ_Alineacion_id_partido_seleccion_id_convocado ON comp.Alineacion (id_partido_seleccion, id_convocado);
CREATE UNIQUE INDEX UQ_Designacion_id_partido_rol ON disc.Designacion (id_partido, rol);
CREATE UNIQUE INDEX UQ_Designacion_id_partido_id_arbitro ON disc.Designacion (id_partido, id_arbitro);
CREATE UNIQUE INDEX UQ_Marca_id_anunciante_nombre ON pub.Marca (id_anunciante, nombre);
CREATE UNIQUE INDEX UQ_Tarifa_id_torneo_id_fase_id_franja_horaria ON pub.Tarifa (id_torneo, id_fase, id_franja_horaria);
CREATE UNIQUE INDEX UQ_ExhibicionPublicitaria_id_partido_nro_espacio ON pub.ExhibicionPublicitaria (id_partido, nro_espacio);
GO

/* ===================== FOREIGN KEYS ===================== */
ALTER TABLE cat.Pais ADD CONSTRAINT FK_Pais_id_moneda FOREIGN KEY (id_moneda) REFERENCES cat.Moneda (id_moneda);
ALTER TABLE cat.Ciudad ADD CONSTRAINT FK_Ciudad_id_pais FOREIGN KEY (id_pais) REFERENCES cat.Pais (id_pais);
ALTER TABLE cat.IndicadorEconomico ADD CONSTRAINT FK_IndicadorEconomico_id_pais FOREIGN KEY (id_pais) REFERENCES cat.Pais (id_pais);
ALTER TABLE cat.TipoCambio ADD CONSTRAINT FK_TipoCambio_id_moneda FOREIGN KEY (id_moneda) REFERENCES cat.Moneda (id_moneda);
ALTER TABLE cat.Feriado ADD CONSTRAINT FK_Feriado_id_pais FOREIGN KEY (id_pais) REFERENCES cat.Pais (id_pais);
ALTER TABLE comp.ParametroReglamento ADD CONSTRAINT FK_ParametroReglamento_id_torneo FOREIGN KEY (id_torneo) REFERENCES comp.Torneo (id_torneo);
ALTER TABLE comp.Sede ADD CONSTRAINT FK_Sede_id_ciudad FOREIGN KEY (id_ciudad) REFERENCES cat.Ciudad (id_ciudad);
ALTER TABLE comp.Grupo ADD CONSTRAINT FK_Grupo_id_torneo FOREIGN KEY (id_torneo) REFERENCES comp.Torneo (id_torneo);
ALTER TABLE comp.Partido ADD CONSTRAINT FK_Partido_id_torneo FOREIGN KEY (id_torneo) REFERENCES comp.Torneo (id_torneo);
ALTER TABLE comp.Partido ADD CONSTRAINT FK_Partido_id_fase FOREIGN KEY (id_fase) REFERENCES comp.Fase (id_fase);
ALTER TABLE comp.Partido ADD CONSTRAINT FK_Partido_id_grupo FOREIGN KEY (id_grupo) REFERENCES comp.Grupo (id_grupo);
ALTER TABLE comp.Partido ADD CONSTRAINT FK_Partido_id_sede FOREIGN KEY (id_sede) REFERENCES comp.Sede (id_sede);
ALTER TABLE comp.Partido ADD CONSTRAINT FK_Partido_id_partido_siguiente FOREIGN KEY (id_partido_siguiente) REFERENCES comp.Partido (id_partido);
ALTER TABLE comp.PartidoSeleccion ADD CONSTRAINT FK_PartidoSeleccion_id_partido FOREIGN KEY (id_partido) REFERENCES comp.Partido (id_partido);
ALTER TABLE comp.PartidoSeleccion ADD CONSTRAINT FK_PartidoSeleccion_id_seleccion FOREIGN KEY (id_seleccion) REFERENCES comp.Seleccion (id_seleccion);
ALTER TABLE comp.Persona ADD CONSTRAINT FK_Persona_id_pais_nacionalidad FOREIGN KEY (id_pais_nacionalidad) REFERENCES cat.Pais (id_pais);
ALTER TABLE comp.Jugador ADD CONSTRAINT FK_Jugador_id_jugador FOREIGN KEY (id_jugador) REFERENCES comp.Persona (id_persona);
ALTER TABLE comp.Jugador ADD CONSTRAINT FK_Jugador_id_posicion_habitual FOREIGN KEY (id_posicion_habitual) REFERENCES comp.Posicion (id_posicion);
ALTER TABLE comp.Club ADD CONSTRAINT FK_Club_id_pais FOREIGN KEY (id_pais) REFERENCES cat.Pais (id_pais);
ALTER TABLE comp.Seleccion ADD CONSTRAINT FK_Seleccion_id_torneo FOREIGN KEY (id_torneo) REFERENCES comp.Torneo (id_torneo);
ALTER TABLE comp.Seleccion ADD CONSTRAINT FK_Seleccion_id_pais FOREIGN KEY (id_pais) REFERENCES cat.Pais (id_pais);
ALTER TABLE comp.Seleccion ADD CONSTRAINT FK_Seleccion_id_grupo FOREIGN KEY (id_grupo) REFERENCES comp.Grupo (id_grupo);
ALTER TABLE comp.CuerpoTecnico ADD CONSTRAINT FK_CuerpoTecnico_id_seleccion FOREIGN KEY (id_seleccion) REFERENCES comp.Seleccion (id_seleccion);
ALTER TABLE comp.CuerpoTecnico ADD CONSTRAINT FK_CuerpoTecnico_id_persona FOREIGN KEY (id_persona) REFERENCES comp.Persona (id_persona);
ALTER TABLE comp.Convocado ADD CONSTRAINT FK_Convocado_id_seleccion FOREIGN KEY (id_seleccion) REFERENCES comp.Seleccion (id_seleccion);
ALTER TABLE comp.Convocado ADD CONSTRAINT FK_Convocado_id_jugador FOREIGN KEY (id_jugador) REFERENCES comp.Jugador (id_jugador);
ALTER TABLE comp.Convocado ADD CONSTRAINT FK_Convocado_id_club FOREIGN KEY (id_club) REFERENCES comp.Club (id_club);
ALTER TABLE comp.CambioConvocatoria ADD CONSTRAINT FK_CambioConvocatoria_id_convocado_baja FOREIGN KEY (id_convocado_baja) REFERENCES comp.Convocado (id_convocado);
ALTER TABLE comp.CambioConvocatoria ADD CONSTRAINT FK_CambioConvocatoria_id_convocado_alta FOREIGN KEY (id_convocado_alta) REFERENCES comp.Convocado (id_convocado);
ALTER TABLE comp.Alineacion ADD CONSTRAINT FK_Alineacion_id_partido_seleccion FOREIGN KEY (id_partido_seleccion) REFERENCES comp.PartidoSeleccion (id_partido_seleccion);
ALTER TABLE comp.Alineacion ADD CONSTRAINT FK_Alineacion_id_convocado FOREIGN KEY (id_convocado) REFERENCES comp.Convocado (id_convocado);
ALTER TABLE comp.Alineacion ADD CONSTRAINT FK_Alineacion_id_posicion_cancha FOREIGN KEY (id_posicion_cancha) REFERENCES comp.Posicion (id_posicion);
ALTER TABLE comp.Sustitucion ADD CONSTRAINT FK_Sustitucion_id_alineacion_sale FOREIGN KEY (id_alineacion_sale) REFERENCES comp.Alineacion (id_alineacion);
ALTER TABLE comp.Sustitucion ADD CONSTRAINT FK_Sustitucion_id_alineacion_entra FOREIGN KEY (id_alineacion_entra) REFERENCES comp.Alineacion (id_alineacion);
ALTER TABLE comp.Sustitucion ADD CONSTRAINT FK_Sustitucion_id_periodo FOREIGN KEY (id_periodo) REFERENCES disc.Periodo (id_periodo);
ALTER TABLE disc.Gol ADD CONSTRAINT FK_Gol_id_alineacion_autor FOREIGN KEY (id_alineacion_autor) REFERENCES comp.Alineacion (id_alineacion);
ALTER TABLE disc.Gol ADD CONSTRAINT FK_Gol_id_alineacion_asistencia FOREIGN KEY (id_alineacion_asistencia) REFERENCES comp.Alineacion (id_alineacion);
ALTER TABLE disc.Gol ADD CONSTRAINT FK_Gol_id_tipo_gol FOREIGN KEY (id_tipo_gol) REFERENCES disc.TipoGol (id_tipo_gol);
ALTER TABLE disc.Gol ADD CONSTRAINT FK_Gol_id_periodo FOREIGN KEY (id_periodo) REFERENCES disc.Periodo (id_periodo);
ALTER TABLE disc.Tarjeta ADD CONSTRAINT FK_Tarjeta_id_alineacion FOREIGN KEY (id_alineacion) REFERENCES comp.Alineacion (id_alineacion);
ALTER TABLE disc.Tarjeta ADD CONSTRAINT FK_Tarjeta_id_cuerpo_tecnico FOREIGN KEY (id_cuerpo_tecnico) REFERENCES comp.CuerpoTecnico (id_cuerpo_tecnico);
ALTER TABLE disc.Tarjeta ADD CONSTRAINT FK_Tarjeta_id_partido_seleccion FOREIGN KEY (id_partido_seleccion) REFERENCES comp.PartidoSeleccion (id_partido_seleccion);
ALTER TABLE disc.Tarjeta ADD CONSTRAINT FK_Tarjeta_id_periodo FOREIGN KEY (id_periodo) REFERENCES disc.Periodo (id_periodo);
ALTER TABLE disc.Suspension ADD CONSTRAINT FK_Suspension_id_convocado FOREIGN KEY (id_convocado) REFERENCES comp.Convocado (id_convocado);
ALTER TABLE disc.Suspension ADD CONSTRAINT FK_Suspension_id_cuerpo_tecnico FOREIGN KEY (id_cuerpo_tecnico) REFERENCES comp.CuerpoTecnico (id_cuerpo_tecnico);
ALTER TABLE disc.Suspension ADD CONSTRAINT FK_Suspension_id_tarjeta_origen FOREIGN KEY (id_tarjeta_origen) REFERENCES disc.Tarjeta (id_tarjeta);
ALTER TABLE disc.Suspension ADD CONSTRAINT FK_Suspension_id_partido_cumple FOREIGN KEY (id_partido_cumple) REFERENCES comp.Partido (id_partido);
ALTER TABLE disc.Arbitro ADD CONSTRAINT FK_Arbitro_id_arbitro FOREIGN KEY (id_arbitro) REFERENCES comp.Persona (id_persona);
ALTER TABLE disc.ArbitroIdioma ADD CONSTRAINT FK_ArbitroIdioma_id_arbitro FOREIGN KEY (id_arbitro) REFERENCES disc.Arbitro (id_arbitro);
ALTER TABLE disc.ArbitroIdioma ADD CONSTRAINT FK_ArbitroIdioma_id_idioma FOREIGN KEY (id_idioma) REFERENCES cat.Idioma (id_idioma);
ALTER TABLE disc.Designacion ADD CONSTRAINT FK_Designacion_id_partido FOREIGN KEY (id_partido) REFERENCES comp.Partido (id_partido);
ALTER TABLE disc.Designacion ADD CONSTRAINT FK_Designacion_id_arbitro FOREIGN KEY (id_arbitro) REFERENCES disc.Arbitro (id_arbitro);
ALTER TABLE disc.InformeArbitral ADD CONSTRAINT FK_InformeArbitral_id_designacion FOREIGN KEY (id_designacion) REFERENCES disc.Designacion (id_designacion);
ALTER TABLE pub.Anunciante ADD CONSTRAINT FK_Anunciante_id_pais FOREIGN KEY (id_pais) REFERENCES cat.Pais (id_pais);
ALTER TABLE pub.Marca ADD CONSTRAINT FK_Marca_id_anunciante FOREIGN KEY (id_anunciante) REFERENCES pub.Anunciante (id_anunciante);
ALTER TABLE pub.Campania ADD CONSTRAINT FK_Campania_id_marca FOREIGN KEY (id_marca) REFERENCES pub.Marca (id_marca);
ALTER TABLE pub.Campania ADD CONSTRAINT FK_Campania_id_agencia FOREIGN KEY (id_agencia) REFERENCES pub.Agencia (id_agencia);
ALTER TABLE pub.CampaniaPais ADD CONSTRAINT FK_CampaniaPais_id_campania FOREIGN KEY (id_campania) REFERENCES pub.Campania (id_campania);
ALTER TABLE pub.CampaniaPais ADD CONSTRAINT FK_CampaniaPais_id_pais FOREIGN KEY (id_pais) REFERENCES cat.Pais (id_pais);
ALTER TABLE pub.PiezaPublicitaria ADD CONSTRAINT FK_PiezaPublicitaria_id_campania FOREIGN KEY (id_campania) REFERENCES pub.Campania (id_campania);
ALTER TABLE pub.PiezaPublicitaria ADD CONSTRAINT FK_PiezaPublicitaria_id_idioma FOREIGN KEY (id_idioma) REFERENCES cat.Idioma (id_idioma);
ALTER TABLE pub.PiezaPublicitaria ADD CONSTRAINT FK_PiezaPublicitaria_id_pais_mercado FOREIGN KEY (id_pais_mercado) REFERENCES cat.Pais (id_pais);
ALTER TABLE pub.Tarifa ADD CONSTRAINT FK_Tarifa_id_torneo FOREIGN KEY (id_torneo) REFERENCES comp.Torneo (id_torneo);
ALTER TABLE pub.Tarifa ADD CONSTRAINT FK_Tarifa_id_fase FOREIGN KEY (id_fase) REFERENCES comp.Fase (id_fase);
ALTER TABLE pub.Tarifa ADD CONSTRAINT FK_Tarifa_id_franja_horaria FOREIGN KEY (id_franja_horaria) REFERENCES pub.FranjaHoraria (id_franja_horaria);
ALTER TABLE pub.Tarifa ADD CONSTRAINT FK_Tarifa_id_moneda FOREIGN KEY (id_moneda) REFERENCES cat.Moneda (id_moneda);
ALTER TABLE pub.ExhibicionPublicitaria ADD CONSTRAINT FK_ExhibicionPublicitaria_id_partido FOREIGN KEY (id_partido) REFERENCES comp.Partido (id_partido);
ALTER TABLE pub.ExhibicionPublicitaria ADD CONSTRAINT FK_ExhibicionPublicitaria_id_pieza_publicitaria FOREIGN KEY (id_pieza_publicitaria) REFERENCES pub.PiezaPublicitaria (id_pieza_publicitaria);
ALTER TABLE pub.ExhibicionPublicitaria ADD CONSTRAINT FK_ExhibicionPublicitaria_id_tarifa FOREIGN KEY (id_tarifa) REFERENCES pub.Tarifa (id_tarifa);
ALTER TABLE pub.ExhibicionPublicitaria ADD CONSTRAINT FK_ExhibicionPublicitaria_id_moneda FOREIGN KEY (id_moneda) REFERENCES cat.Moneda (id_moneda);
ALTER TABLE imp.ErrorImportacion ADD CONSTRAINT FK_ErrorImportacion_id_log_importacion FOREIGN KEY (id_log_importacion) REFERENCES imp.LogImportacion (id_log_importacion);
GO

/* ===================== CHECK CONSTRAINTS ===================== */
/* (dominios + arcos exclusivos sacados del DER) */
/* ---------- Catalogos / Competicion ---------- */ 

ALTER TABLE cat.Pais WITH CHECK ADD CONSTRAINT CK_Pais_Confederacion
  CHECK (confederacion IN ('CONMEBOL','UEFA','CAF','AFC','CONCACAF','OFC'));

ALTER TABLE comp.Partido WITH CHECK ADD CONSTRAINT CK_Partido_Estado
  CHECK (estado IN ('PROGRAMADO','EN_JUEGO','FINALIZADO','SUSPENDIDO'));

ALTER TABLE comp.PartidoSeleccion WITH CHECK ADD CONSTRAINT CK_PartidoSeleccion_Condicion
  CHECK (condicion IN ('L','V'));

/* ---------- Selecciones y convocatoria ---------- */

ALTER TABLE comp.CuerpoTecnico WITH CHECK ADD CONSTRAINT CK_CuerpoTecnico_Rol
  CHECK (rol IN ('Director Tecnico','Ayudante de Campo','Preparador Fisico'));

ALTER TABLE comp.CambioConvocatoria WITH CHECK ADD CONSTRAINT CK_CambioConvocatoria_Motivo
  CHECK (motivo IN ('Lesion','Enfermedad','Decision tecnica','Sancion'));

-- Al menos uno de baja/alta debe informarse
ALTER TABLE comp.CambioConvocatoria WITH CHECK ADD CONSTRAINT CK_CambioConvocatoria_BajaOAlta
  CHECK (id_convocado_baja IS NOT NULL OR id_convocado_alta IS NOT NULL);

/* ---------- Alineaciones y cambios ---------- */

-- La posicion en cancha es solo para titulares (el banco no la tiene)
ALTER TABLE comp.Alineacion WITH CHECK ADD CONSTRAINT CK_Alineacion_PosicionSoloTitular
  CHECK ( (es_titular = 1 AND id_posicion_cancha IS NOT NULL)
       OR (es_titular = 0 AND id_posicion_cancha IS NULL) );

ALTER TABLE comp.Sustitucion WITH CHECK ADD CONSTRAINT CK_Sustitucion_Motivo
  CHECK (motivo IN ('Tactico','Lesion','Precaucion'));

/* ---------- Disciplina (goles, tarjetas, suspensiones) ---------- */
-- OJO: disc.TipoGol NO lleva CHECK a proposito (dominio abierto, se importa).

ALTER TABLE disc.Tarjeta WITH CHECK ADD CONSTRAINT CK_Tarjeta_Tipo
  CHECK (tipo_tarjeta IN ('Amarilla','Roja directa','Roja por doble amarilla'));

-- Arco exclusivo: sancionado jugador O cuerpo tecnico, nunca ambos
ALTER TABLE disc.Tarjeta WITH CHECK ADD CONSTRAINT CK_Tarjeta_Sancionado
  CHECK ( (id_alineacion IS NOT NULL AND id_cuerpo_tecnico IS NULL     AND id_partido_seleccion IS NULL)
       OR (id_alineacion IS NULL     AND id_cuerpo_tecnico IS NOT NULL AND id_partido_seleccion IS NOT NULL) );

ALTER TABLE disc.Suspension WITH CHECK ADD CONSTRAINT CK_Suspension_Estado
  CHECK (estado IN ('PENDIENTE','CUMPLIDA','ANULADA'));

-- Arco exclusivo: suspendido jugador O cuerpo tecnico
ALTER TABLE disc.Suspension WITH CHECK ADD CONSTRAINT CK_Suspension_Sancionado
  CHECK ( (id_convocado IS NOT NULL AND id_cuerpo_tecnico IS NULL)
       OR (id_convocado IS NULL     AND id_cuerpo_tecnico IS NOT NULL) );

/* ---------- Arbitros ---------- */

ALTER TABLE disc.Arbitro WITH CHECK ADD CONSTRAINT CK_Arbitro_Categoria
  CHECK (categoria IN ('FIFA','Confederacion'));

ALTER TABLE disc.Designacion WITH CHECK ADD CONSTRAINT CK_Designacion_Rol
  CHECK (rol IN ('Principal','Asistente 1','Asistente 2','Cuarto Arbitro','VAR'));

ALTER TABLE disc.InformeArbitral WITH CHECK ADD CONSTRAINT CK_InformeArbitral_Tipo
  CHECK (tipo IN ('INFORME','SANCION'));

/* ---------- Publicidad ---------- */

ALTER TABLE pub.ExhibicionPublicitaria WITH CHECK ADD CONSTRAINT CK_Exhibicion_NroEspacio
  CHECK (nro_espacio BETWEEN 1 AND 4);

ALTER TABLE pub.ExhibicionPublicitaria WITH CHECK ADD CONSTRAINT CK_Exhibicion_Estado
  CHECK (estado IN ('PROPUESTA','EXHIBIDA','CANCELADA'));


ALTER TABLE comp.Sede WITH CHECK ADD CONSTRAINT CK_Sede_Capacidad
  CHECK (capacidad > 0);

ALTER TABLE comp.Partido WITH CHECK ADD CONSTRAINT CK_Partido_Asistencia
  CHECK (asistencia IS NULL OR asistencia >= 0);

ALTER TABLE comp.Convocado WITH CHECK ADD CONSTRAINT CK_Convocado_Dorsal
  CHECK (dorsal BETWEEN 1 AND 99);

ALTER TABLE pub.Tarifa WITH CHECK ADD CONSTRAINT CK_Tarifa_Monto
  CHECK (monto >= 0);

ALTER TABLE pub.ExhibicionPublicitaria WITH CHECK ADD CONSTRAINT CK_Exhibicion_Monto
  CHECK (monto_aplicado >= 0);
GO

PRINT 'OK: tablas, indices, FK y CHECK creados en MundialDB.';
GO
# Sistema de Registro y Gestión del Mundial de Fútbol (MundialDB)

**Universidad:** Universidad Nacional de La Matanza (UNLaM)  
**Asignatura:** 3641 – Bases de Datos Aplicada  
**Comisión:** 02-5600  
**Grupo:** 02  

---

## 👥 Integrantes del Grupo

| Apellido y Nombre | Usuario GitHub |
| :--- | :--- |
| Mendez Camacho, Tatiana Antonella | `tatimendez` |
| Rocha Escalera, Sheila Belisa | `sheilarocha02` |
| Meira da Cruz Saleiro, Gonzalo | `meiraGonzalo` |
| Miro, Saba Alejandro | `SabaM10` |

---

## 📌 Descripción del Proyecto

Sistema centralizado en Microsoft SQL Server diseñado para registrar y gestionar integralmente las operaciones de la Copa Mundial de Fútbol. Permite la administración de sedes, partidos, convocatorias, alineaciones, incidencias disciplinarias, designaciones arbitrales y el ecosistema publicitario con asignación automática de espacios basada en audiencia y reglas de negocio.

El sistema incorpora información mediante *Stored Procedures* desde APIs externas (Nager.Date, Banco Mundial, Frankfurter) y Web Scraping (Dossier Publicidad, Wikipedia, FIFA).

---

## 🏗️ Arquitectura y Esquemas de la Base de Datos

El sistema se encuentra organizado en esquemas temáticos de dominio:

* `cat`: Catálogos maestros, geografía y series económicas (`Moneda`, `Idioma`, `Pais`, `Ciudad`, `IndicadorEconomico`, `TipoCambio`, `Feriado`).
* `comp`: Gestión deportiva y logística de torneo (`Torneo`, `Sede`, `Fase`, `Grupo`, `Posicion`, `Jugador`, `Club`, `Periodo`, `Seleccion`, `Convocado`, `Alineacion`, `Sustitucion`, `Partido`, `PartidoSeleccion`).
* `disc`: Incidencias de juego, disciplina y arbitraje (`TipoGol`, `Gol`, `Tarjeta`, `Arbitro`, `Designacion`, `InformeArbitral`).
* `pub`: Comercialización, pautas y subasta de espacios perimetrales (`Anunciante`, `Marca`, `Agencia`, `Campania`, `CampaniaPais`, `FranjaHoraria`, `Tarifa`, `PiezaPublicitaria`, `ExhibicionPublicitaria`).
* `imp`: Arquitectura de ingesta de datos, tablas de staging y auditoría técnica (`LogImportacion`, `ErrorImportacion`, `stg_*`).

---

## 🚀 Requisitos Previos y Entorno

* **RDBMS:** Microsoft SQL Server 2019 o superior.
* **Herramienta:** SQL Server Management Studio (SSMS) 19 o superior.
* **Almacenamiento Local:** Se requiere la existencia del directorio `C:\MundialDB\` para la instanciación de los archivos `.mdf`, `.ndf` y `.ldf` de los filegroups (`PRIMARY` y `FG_DATOS`).

---

## ⚙️ Guía de Ejecución de la Solución (Orden Secuencial)

Para reconstruir la solución íntegramente desde cero, ejecute los scripts en SSMS respetando la numeración de los archivos:

### 1. Creación del Entorno
* **`00`**: Limpia conexiones activas (`SINGLE_USER`), recrea `MundialDB`, define los Filegroups (`FG_DATOS`) e inicializa los esquemas de dominio.
* **`01`**: Genera la totalidad de tablas operativas, índices únicos (`UNIQUE`), constraints de verificación (`CHECK`) y claves foráneas (`FK`).

### 2. Capa Transaccional y Lógica de Negocio
* **`02`**: Procedimientos almacenados para el 100% de operaciones ABM, con validaciones encapsuladas y manejo de excepciones mediante `THROW`.
* **`03`**: Procedimientos con reglas complejas (motor de asignación de publicidad, control de acumulación de tarjetas, validación de árbitros por confederación).
* **`04`** y **`05`**: Conjunto de pruebas automatizadas con casos de éxito y casos que disparan intencionalmente cada validación.

### 3. Ingesta Masiva de Datos (ETL)
* **`06`**: Crea tablas de *staging*, vistas de carga y stored procedures de importación masiva con lógica de *Upsert* y registro en auditoría (`LogImportacion` y `ErrorImportacion`).

### 4. Reportes y Seguridad
* **`07`**: Consultas operativas y analíticas (salidas tabulares y en formato `XML`).
* **`08`**: Implementación de cifrado de columnas sensibles y definición de roles (`db_administrador`, `db_operador_resultados`, `db_gestor_publicidad`, `db_consulta`).

---

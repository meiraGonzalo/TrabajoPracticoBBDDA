# Entrega 8 - Cuadro de roles y permisos

Implementado en `08_roles_permisos.sql` (SPs `seg.usp_CrearRolesYUsuarios` y `seg.usp_AsignarPermisos`).
Nada se hace directo sobre las tablas: todo pasa por stored procedures.

| Rol | Usuario de prueba |
|---|---|
| rol_administrador | usr_admin |
| rol_cargador_resultados | usr_cargador |
| rol_gestor_publicidad | usr_publicidad |
| rol_consulta | usr_consulta |

| Objeto | Administrador | Cargador resultados | Gestor publicidad | Consulta |
|---|:-:|:-:|:-:|:-:|
| Tablas, acceso directo (SELECT/INSERT/UPDATE/DELETE) | Si | No | No | No |
| SPs de catalogos (`cat.*` ABM) | Si | No | No | No |
| SPs de competencia y disciplina (`comp.*`, `disc.*`) | Si | Si | No | No |
| SPs de publicidad (`pub.*`) | Si | No | Si | No |
| SPs de importacion (`imp.usp_Importar_*`) | Si | No | No | No |
| Alta y modificacion de Persona (cifra el documento) | Si | Si | No | No |
| Descifrar documento (`comp.usp_Persona_DescifrarDocumento`) | Si | No | No | No |
| Reportes de competencia y disciplina | Si | Si | No | Si |
| Reportes de publicidad | Si | No | Si | Si |
| Reportes de catalogos e importacion | Si | No | No | Si |
| Vistas del esquema `bi` | Si | No | No | Si |

/*
=====================================================================
 UNLaM - 3641 Bases de Datos Aplicada
 TP: Sistema de Registro y Gestion del Mundial de Futbol
 Entrega 8 - Script 08: Roles, usuarios y permisos
 Grupo 02 - Comision 02-5600
 Integrantes: Mendez Camacho, Tatiana Antonella   nickGithub: tatimendez
              Rocha Escalera, Sheila Belisa       nickGithub: sheilarocha02
              Meira da Cruz Saleiro, Gonzalo      nickGithub: meiraGonzalo
              Miro, Saba Alejandro                nickGithub: SabaM10
 Fecha: 2026-11-24
 Objetivo: crear 4 roles de seguridad con permisos granulares, y un usuario de prueba por rol.
             rol_administrador        -> todo, incluido descifrar el documento de las personas
             rol_cargador_resultados  -> SPs de comp y disc (partidos, goles, tarjetas, designaciones)
             rol_gestor_publicidad    -> SPs de pub (campanias, tarifas, asignacion de publicidad)
             rol_consulta             -> solo reportes (usp_Reporte_*) y vistas del esquema bi
           Se implementa con dos SPs en el esquema seg:
             seg.usp_CrearRolesYUsuarios  crea roles y usuarios y los asocia
             seg.usp_AsignarPermisos      da y niega los permisos (cuadro en doc/08_cuadro_roles_permisos.md)
 Criterio: ninguna operacion se hace directo sobre las tablas, todo pasa por stored procedures.
           Los roles que no son administrador reciben DENY sobre las tablas y EXECUTE sobre los
           SP que les corresponden. Como los SP y las tablas tienen el mismo dueno (dbo), el SP
           puede tocar la tabla aunque el usuario no tenga permiso sobre ella (ownership chaining).
           Los usuarios son WITHOUT LOGIN: sirven para EXECUTE AS en los scripts de prueba. Para
           una herramienta externa (Metabase, E9) se crea un LOGIN y se lo asocia a rol_consulta.
 Orden:    00 -> 01 -> 02 -> 03 -> importaciones/seed -> 07 -> 08_cifrado -> 09 (vistas bi) -> este script
           (si se corre antes del 09, volver a ejecutar seg.usp_AsignarPermisos despues del 09)
=====================================================================
*/
USE MundialDB;
GO

IF SCHEMA_ID('seg') IS NULL
    EXEC('CREATE SCHEMA seg');
GO


/* ----------------- 1. ROLES Y USUARIOS ------------------------------------------- */

CREATE OR ALTER PROCEDURE seg.usp_CrearRolesYUsuarios
AS
BEGIN
    IF DATABASE_PRINCIPAL_ID('rol_administrador') IS NULL       CREATE ROLE rol_administrador;
    IF DATABASE_PRINCIPAL_ID('rol_cargador_resultados') IS NULL CREATE ROLE rol_cargador_resultados;
    IF DATABASE_PRINCIPAL_ID('rol_gestor_publicidad') IS NULL   CREATE ROLE rol_gestor_publicidad;
    IF DATABASE_PRINCIPAL_ID('rol_consulta') IS NULL            CREATE ROLE rol_consulta;

    IF DATABASE_PRINCIPAL_ID('usr_admin') IS NULL      CREATE USER usr_admin      WITHOUT LOGIN;
    IF DATABASE_PRINCIPAL_ID('usr_cargador') IS NULL   CREATE USER usr_cargador   WITHOUT LOGIN;
    IF DATABASE_PRINCIPAL_ID('usr_publicidad') IS NULL CREATE USER usr_publicidad WITHOUT LOGIN;
    IF DATABASE_PRINCIPAL_ID('usr_consulta') IS NULL   CREATE USER usr_consulta   WITHOUT LOGIN;

    IF IS_ROLEMEMBER('rol_administrador', 'usr_admin') = 0
        ALTER ROLE rol_administrador ADD MEMBER usr_admin;
    IF IS_ROLEMEMBER('rol_cargador_resultados', 'usr_cargador') = 0
        ALTER ROLE rol_cargador_resultados ADD MEMBER usr_cargador;
    IF IS_ROLEMEMBER('rol_gestor_publicidad', 'usr_publicidad') = 0
        ALTER ROLE rol_gestor_publicidad ADD MEMBER usr_publicidad;
    IF IS_ROLEMEMBER('rol_consulta', 'usr_consulta') = 0
        ALTER ROLE rol_consulta ADD MEMBER usr_consulta;
END
GO


/* ----------------- 2. PERMISOS ---------------------------------------------------- */

CREATE OR ALTER PROCEDURE seg.usp_AsignarPermisos
AS
BEGIN
    DECLARE @err nvarchar(2000);
    SET @err = '';

    IF DATABASE_PRINCIPAL_ID('rol_administrador') IS NULL
       OR DATABASE_PRINCIPAL_ID('rol_cargador_resultados') IS NULL
       OR DATABASE_PRINCIPAL_ID('rol_gestor_publicidad') IS NULL
       OR DATABASE_PRINCIPAL_ID('rol_consulta') IS NULL
        SET @err = @err + ' - Faltan los roles: ejecutar antes seg.usp_CrearRolesYUsuarios.';

    IF OBJECT_ID('comp.usp_Persona_DescifrarDocumento', 'P') IS NULL
        SET @err = @err + ' - Falta comp.usp_Persona_DescifrarDocumento: ejecutar antes 08_cifrado.sql.';

    IF @err <> ''
    BEGIN
        SET @err = 'usp_AsignarPermisos:' + @err;
        THROW 50081, @err, 1;
    END

    /* ---- rol_administrador: todo sobre los 5 esquemas de negocio y el esquema seg ---- */
    GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::cat  TO rol_administrador;
    GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::comp TO rol_administrador;
    GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::disc TO rol_administrador;
    GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::pub  TO rol_administrador;
    GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE ON SCHEMA::imp  TO rol_administrador;
    GRANT EXECUTE ON SCHEMA::seg TO rol_administrador;
    IF SCHEMA_ID('bi') IS NOT NULL
        GRANT SELECT ON SCHEMA::bi TO rol_administrador;

    /* ---- rol_cargador_resultados: SPs de competencia y disciplina ---- */
    GRANT EXECUTE ON SCHEMA::comp TO rol_cargador_resultados;
    GRANT EXECUTE ON SCHEMA::disc TO rol_cargador_resultados;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::cat  TO rol_cargador_resultados;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::comp TO rol_cargador_resultados;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::disc TO rol_cargador_resultados;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::pub  TO rol_cargador_resultados;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::imp  TO rol_cargador_resultados;
    DENY EXECUTE ON SCHEMA::cat TO rol_cargador_resultados;
    DENY EXECUTE ON SCHEMA::pub TO rol_cargador_resultados;
    DENY EXECUTE ON SCHEMA::imp TO rol_cargador_resultados;
    DENY EXECUTE ON OBJECT::comp.usp_Persona_DescifrarDocumento TO rol_cargador_resultados;

    /* ---- rol_gestor_publicidad: SPs de publicidad ---- */
    GRANT EXECUTE ON SCHEMA::pub TO rol_gestor_publicidad;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::cat  TO rol_gestor_publicidad;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::comp TO rol_gestor_publicidad;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::disc TO rol_gestor_publicidad;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::pub  TO rol_gestor_publicidad;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::imp  TO rol_gestor_publicidad;
    DENY EXECUTE ON SCHEMA::cat  TO rol_gestor_publicidad;
    DENY EXECUTE ON SCHEMA::comp TO rol_gestor_publicidad;
    DENY EXECUTE ON SCHEMA::disc TO rol_gestor_publicidad;
    DENY EXECUTE ON SCHEMA::imp  TO rol_gestor_publicidad;

    /* ---- rol_consulta: solo reportes y vistas bi ---- */
    GRANT EXECUTE ON OBJECT::cat.usp_Reporte_ContextoEconomicoFeriados   TO rol_consulta;
    GRANT EXECUTE ON OBJECT::comp.usp_Reporte_Plantillas_XML             TO rol_consulta;
    GRANT EXECUTE ON OBJECT::comp.usp_Reporte_Resultados                 TO rol_consulta;
    GRANT EXECUTE ON OBJECT::disc.usp_Reporte_Goleadores                 TO rol_consulta;
    GRANT EXECUTE ON OBJECT::disc.usp_Reporte_Tarjetas                   TO rol_consulta;
    GRANT EXECUTE ON OBJECT::disc.usp_Reporte_Designaciones_XML          TO rol_consulta;
    GRANT EXECUTE ON OBJECT::pub.usp_Reporte_IngresosPublicidadGlobal    TO rol_consulta;
    GRANT EXECUTE ON OBJECT::pub.usp_Reporte_MatrizPrimeTime             TO rol_consulta;
    GRANT EXECUTE ON OBJECT::pub.usp_Reporte_OcupacionPublicitaria       TO rol_consulta;
    GRANT EXECUTE ON OBJECT::imp.usp_Reporte_LogImportacion              TO rol_consulta;
    IF SCHEMA_ID('bi') IS NOT NULL
        GRANT SELECT ON SCHEMA::bi TO rol_consulta;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::cat  TO rol_consulta;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::comp TO rol_consulta;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::disc TO rol_consulta;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::pub  TO rol_consulta;
    DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::imp  TO rol_consulta;
    DENY EXECUTE ON OBJECT::comp.usp_Persona_DescifrarDocumento TO rol_consulta;
END
GO


/* ----------------- 3. EJECUCION --------------------------------------------------- */

EXEC seg.usp_CrearRolesYUsuarios;
GO
EXEC seg.usp_AsignarPermisos;
GO

-- Verificacion rapida: a que rol pertenece cada usuario
SELECT r.name AS rol, m.name AS usuario
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE r.name LIKE 'rol[_]%'
ORDER BY r.name;
GO

# Entrega 8 - Politica de respaldo (RPO)

**Sistema:** base `MundialDB` (SQL Server). **Grupo 02 - Comision 02-5600.**

## 1. Que protegemos y por que importa el ritmo de escritura

La base recibe pocas escrituras fuera del torneo (carga de plantillas, catalogos, publicidad) y **muchas en los
dias de partido**: resultados, alineaciones, sustituciones, goles, tarjetas, designaciones y exhibiciones
publicitarias. Perder datos de un partido en curso es mucho mas grave que perder datos de un dia sin juego.
Por eso la politica tiene **dos regimenes**.

**RPO** (objetivo de punto de recuperacion) = maximo de datos que aceptamos perder, medido en tiempo.
Con backups de log cada N minutos, el RPO es N minutos.

## 2. Politica

| | Dias sin partido | Dias de partido |
|---|---|---|
| **RPO** | 30 minutos | **5 minutos** |
| Backup completo (FULL) | domingo 03:00 | domingo 03:00 + uno extra la noche previa al primer partido del dia |
| Backup diferencial | todos los dias 03:00 | cada 6 horas (03:00, 09:00, 15:00, 21:00) |
| Backup de log de transacciones | cada 30 min | **cada 5 min** durante la jornada |

- La base usa el modelo de recuperacion **FULL** (sin esto no hay backups de log ni restauracion a un punto en el tiempo).
- Todos los backups se hacen con `COMPRESSION` y `CHECKSUM`.
- Cada backup se verifica con `RESTORE VERIFYONLY` (como dice la teoria: "verifique los backups, siempre").

## 3. Donde se guardan y cuanto tiempo

1. **Copia local**, en un disco distinto al de los datos (`C:\MundialDB_Backups\` en el TP; en produccion, otro volumen).
2. **Copia externa** (otro servidor o nube), sincronizada al terminar cada backup FULL y diferencial.
3. **Retencion:** 4 semanas de FULL + diferenciales; logs desde el ultimo FULL que se conserve.

## 4. Cifrado: el certificado tambien se respalda

La columna `nro_documento` esta cifrada con la clave `sk_datos_personales`, protegida por el certificado
`cert_datos_personales` y la master key de la base. **Sin el certificado, un backup restaurado en otro servidor
muestra los documentos como bytes ilegibles para siempre.** Por eso, ademas de la base:

- `BACKUP CERTIFICATE cert_datos_personales` (con su clave privada) y `BACKUP MASTER KEY`, protegidos con contrasena.
- Se guardan **separados** de los backups de la base (si estuvieran juntos, el cifrado no serviria de nada).
- Se hace una vez al crearlos y otra vez si cambian.

## 5. Como se restaura

Ante una falla, en este orden:

1. Si la base todavia responde: backup del **tail log** (`BACKUP LOG ... WITH NORECOVERY`) para no perder lo ultimo.
2. `RESTORE DATABASE` del ultimo **FULL** `WITH NORECOVERY`.
3. `RESTORE DATABASE` del ultimo **diferencial** `WITH NORECOVERY`.
4. `RESTORE LOG` de cada backup de log, en orden. El ultimo con `WITH STOPAT = 'fecha y hora'` (si hay que volver a un
   momento exacto) y `WITH RECOVERY`.
5. En un servidor nuevo, antes del paso 2: restaurar la master key y el certificado (`CREATE CERTIFICATE ... FROM FILE`).
6. Verificar: contar partidos, goles y designaciones, y probar `usp_Persona_DescifrarDocumento`.

**Prueba de restauracion:** una vez por mes se restaura un FULL en una base de prueba (`MundialDB_Restore`)
para confirmar que el backup sirve.

## 6. Implementacion

`08_backup.sql` deja la base en modelo FULL y crea `seg.usp_RealizarBackup @tipo` (`FULL`, `DIFF` o `LOG`) y
`seg.usp_RespaldarClaves`. La programacion (jobs de SQL Server Agent) sigue las frecuencias de la tabla del punto 2.

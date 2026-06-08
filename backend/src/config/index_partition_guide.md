# Guía de Indexación y Particionamiento de la Bitácora (PostgreSQL)

Este documento detalla la estructura y el propósito de los índices de rendimiento creados para la bitácora (`audit_logs`), además de proponer una estrategia de particionamiento mensual por rangos para mantener la escalabilidad de la base de datos a largo plazo.

---

## 1. Índices de Rendimiento Creados

Para optimizar las consultas de la bitácora que combinan filtros dinámicos con ordenamiento descendente y paginación, se agregaron los siguientes índices en PostgreSQL a través de [initDb.js](file:///c:/code/MarySold/backend/initDb.js):

### A. Índice de Fecha Descendente
```sql
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at_desc 
ON audit_logs (created_at DESC);
```
*   **Propósito:** Optimiza la consulta general de logs cuando no hay filtros aplicados, sirviendo de manera inmediata los últimos registros solicitados por la paginación (`LIMIT 20 OFFSET X`) y evitando ordenar en memoria.

### B. Índice Compuesto por Usuario
```sql
CREATE INDEX IF NOT EXISTS idx_audit_logs_username_created_at_desc 
ON audit_logs (username, created_at DESC);
```
*   **Propósito:** Optimiza las búsquedas filtradas por un usuario en específico (`username = $1`), permitiendo que PostgreSQL localice los registros de ese usuario de inmediato y los devuelva ya ordenados cronológicamente de forma descendente.

### C. Índice Compuesto por Acción
```sql
CREATE INDEX IF NOT EXISTS idx_audit_logs_action_created_at_desc 
ON audit_logs (action, created_at DESC);
```
*   **Propósito:** Optimiza las búsquedas de auditoría por tipo de acción (`action = $1`) (ej. `CHECKOUT`, `LOGIN`), agilizando el escaneo de registros y la paginación para ese filtro.

---

## 2. Propuesta de Particionamiento Mensual (`PARTITION BY RANGE`)

Cuando la bitácora de auditoría crezca a cientos de miles o millones de filas, PostgreSQL tardará más tiempo en buscar en los índices globales. La solución recomendada es segmentar la tabla físicamente por meses usando particionamiento declarativo.

### Regla de Clave Primaria en Tablas Particionadas
> [!WARNING]
> En PostgreSQL, cualquier restricción de unicidad (incluyendo `PRIMARY KEY`) en una tabla particionada **debe incluir la columna de partición**. Por lo tanto, la clave primaria debe redefinirse como una clave compuesta: `(id, created_at)`.

### Script SQL para Crear Bitácora Particionada y Migrar Datos

A continuación se detalla el script SQL para realizar el particionamiento de forma segura en producción dentro de un bloque de transacción:

```sql
BEGIN;

-- 1. Crear la tabla principal particionada por rangos de fecha (created_at)
CREATE TABLE audit_logs_partitioned (
    id SERIAL,
    user_id INTEGER,
    username VARCHAR(50) NOT NULL,
    action VARCHAR(100) NOT NULL,
    details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- 2. Crear las tablas de partición mensuales para el año 2026
CREATE TABLE audit_logs_y2026m05 PARTITION OF audit_logs_partitioned
    FOR VALUES FROM ('2026-05-01 00:00:00') TO ('2026-06-01 00:00:00');

CREATE TABLE audit_logs_y2026m06 PARTITION OF audit_logs_partitioned
    FOR VALUES FROM ('2026-06-01 00:00:00') TO ('2026-07-01 00:00:00');

CREATE TABLE audit_logs_y2026m07 PARTITION OF audit_logs_partitioned
    FOR VALUES FROM ('2026-07-01 00:00:00') TO ('2026-08-01 00:00:00');

-- 3. Migrar los datos existentes de la tabla antigua a la particionada
INSERT INTO audit_logs_partitioned (id, user_id, username, action, details, created_at)
SELECT id, user_id, username, action, details, created_at FROM audit_logs;

-- 4. Eliminar la tabla vieja y renombrar la nueva
DROP TABLE audit_logs;
ALTER TABLE audit_logs_partitioned RENAME TO audit_logs;

-- 5. Crear los índices óptimos en la nueva tabla (se propagan automáticamente a las particiones)
CREATE INDEX idx_audit_logs_created_at_desc ON audit_logs (created_at DESC);
CREATE INDEX idx_audit_logs_username_created_at_desc ON audit_logs (username, created_at DESC);
CREATE INDEX idx_audit_logs_action_created_at_desc ON audit_logs (action, created_at DESC);

COMMIT;
```

### Ventajas de esta Estrategia:
1.  **Consulta Rápida (Partition Pruning):** Si el usuario filtra por las últimas 24 horas, PostgreSQL ignorará por completo todas las particiones de los meses anteriores y solo escaneará la partición actual.
2.  **Mantenimiento Eficiente:** En lugar de ejecutar costosos comandos `DELETE FROM audit_logs WHERE created_at < ...` que generan fragmentación en el disco, se puede purgar logs antiguos instantáneamente soltando la partición completa:
    `DROP TABLE audit_logs_y2026m05;`

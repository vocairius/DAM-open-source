# ADR 0002 — Esquema de base de datos y migraciones versionadas

- **Estado:** Aceptado
- **Fecha:** 2026-11-12

## Contexto

El índice local debe soportar cientos de miles de archivos sin que las búsquedas o
filtros recorran el sistema de archivos en tiempo real. Toda la verdad vive en una
base de datos SQLite local de metadatos. La spec exige que cualquier cambio al
esquema vaya acompañado de una migración con número de versión y un camino de
reversión probado, además de un backup automático antes de cada migración.

## Decisión

### Motor
SQLite local en el directorio de soporte de la aplicación (Application Support de
macOS), no en el disco externo. Configuración recomendada: modo WAL, `foreign_keys
ON`, `synchronous=NORMAL`.

### Tablas

| Tabla | Propósito | Campos clave |
|---|---|---|
| `schema_version` | Control de versión del esquema | `version INTEGER` |
| `assets` | Activo multimedia indexado | `id`, `path` (absoluta, UNIQUE), `hash` (índice), `type`, `size`, `width`, `height`, `duration_ms`, `imported_at`, `modified_at`, `rating`, `color_label`, `notes`, `deleted_at` |
| `tags` | Etiquetas con jerarquía opcional | `id`, `name`, `parent_id` (FK self), `color` |
| `categories` | Categorías jerárquicas (Envato) | `id`, `name`, `parent_id` (FK self), `slug` |
| `licenses` | Licencia de activos Envato | `id`, `asset_id` (FK), `license_type`, `compatible_software`, `author`, `source` |
| `collections` | Colecciones manuales o inteligentes | `id`, `name`, `kind` (`manual`/`smart`), `rule_json` (solo smart) |
| `watched_folders` | Carpetas vigiladas | `id`, `path` (UNIQUE), `enabled`, `last_scan_at` |
| `asset_tags` | Relación N:M asset↔tag | `asset_id`, `tag_id` (PK compuesta) |
| `collection_assets` | Relación N:M collection↔asset | `collection_id`, `asset_id` (PK compuesta) |
| `operations_log` | Auditoría de operaciones destructivas / edición masiva | `id`, `operation`, `payload_json`, `created_at`, `reversible` |

### Migraciones

- Cada migración tiene un `version` entero incremental y dos funciones: `up()` y
  `down()` (reversión).
- El arranque compara la versión registrada en `schema_version` con la versión
  objetivo del código y aplica las migraciones pendientes en orden.
- Antes de aplicar cada migración se copia la DB completa a
  `backups/<timestamp>-v<from>-to-v<to>.db` (backup de metadatos, no del multimedia).
- Cada migración incluye una prueba de regresión con datos de ejemplo antes de
  aceptarse en un PR.
- La reversión (`down()`) se prueba explícitamente en la suite de integración.

### Integridad y no destructividad

- Borrado desde la app = *soft delete* (`assets.deleted_at`), nunca `DELETE` físico
  inmediato. Los archivos originales del usuario nunca se modifican.
- Toda operación destructiva o edición masiva se registra en `operations_log`.
- El hash se calcula en solo lectura sobre el archivo original; nunca se reescribe
  EXIF ni metadata del original.
- SQLite usa WAL, `foreign_keys=ON` y `synchronous=NORMAL`. Los backups se hacen
  con la conexión cerrada, antes de cada transición de versión.

## Consecuencias

- Las consultas y filtros se resuelven exclusivamente contra el índice SQLite; el
  sistema de archivos solo se recorre durante el escaneo (asíncrono).
- Cambiar el esquema implica nueva migración + prueba de regresión + reversión
  probada; sin ello el PR no se acepta.
- El backup previo a migración protege al usuario ante fallos.

# ADR 0001 — Stack de la aplicación: Flutter desktop (macOS)

- **Estado:** Aceptado
- **Fecha:** 2026-11-12
- **Decisor:** Nicolas Murcia (confirmación explícita)

## Contexto

Vault DAM es una aplicación de escritorio para macOS que indexa, cataloga y busca
contenido multimedia en un disco externo de ~2 TB (proyectos propios, archivos de
producción y activos de Envato). Debe operar en una Mac con chip Apple Silicon
(M1) y ejecutar en segundo plano tareas de escaneo, hashing y generación de
miniaturas sin bloquear la interfaz ni saturar la memoria.

La especificación del proyecto prohíbe mezclar stacks a mitad de proyecto y exige
fijar uno antes de escribir la primera línea de código de producto.

## Decisión

Se adopta **Flutter desktop con target macOS** como stack único del proyecto.

- Lenguaje: Dart.
- UI (fases posteriores): Flutter.
- Persistencia: SQLite (vía `drift` o `sqflite_common_ffi`) con migraciones versionadas.
- Sistema de archivos: `dart:io` (escaneo, hash, lectura de metadatos).
- Miniaturas: generación local para imagen y frames de video (ffmpeg vía proceso externo, solo lectura del original).

## Justificación

1. Orden de preferencia #1 de la especificación.
2. Experiencia previa del equipo con Flutter y React reduce la curva de aprendizaje.
3. Buen rendimiento en Apple Silicon; menor huella de memoria que Electron en tareas
   de indexado en segundo plano.
4. Ecosistema maduro para SQLite y generación de miniaturas.
5. `dart:io` cubre las necesidades de acceso al sistema de archivos del disco externo.

## Alternativas consideradas

- **Swift + SwiftUI (nativo):** mejor integración con macOS (Quick Look, Spotlight,
  etiquetas de Finder), pero mayor tiempo de aprendizaje si Swift no se domina. Se
  reserva como posible integración profunda posterior; no se usa en esta fase.
- **Electron (antecesor en `DAM/`):** descartado. Consumo de memoria elevado e
  inadecuado para indexar de forma continua un disco de 2 TB en segundo plano. La
  spec lo desaconseja explícitamente.

## Consecuencias

- Todo el código de producto de la fase 1 se escribe en Dart.
- No se importa código ni dependencias de Electron; el proyecto `DAM/` queda como
  referencia de UI/modelado únicamente.
- Cualquier cambio de stack futuro requerirá un nuevo ADR y una migración planificada.

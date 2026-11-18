# ADR 0003: Acceso local y navegación al archivo original en macOS

- Estado: Aceptado
- Fecha: 2026-11-13

## Contexto

La primera versión ejecutable debe registrar la ruta de ZIPs y archivos raíz y
permitir localizarlos después desde Finder. La app macOS usa App Sandbox y el
archivo original no debe modificarse ni salir del equipo.

## Decisión

- Mantener App Sandbox habilitado y conceder solo el entitlement de lectura
  para archivos seleccionados por el usuario.
- Usar el selector nativo existente (`file_selector`) para elegir archivos.
- Usar `Indexer` para leer metadatos y calcular SHA-256 en streaming con
  cancelación; persistir ruta, hash y metadatos en la tabla `assets` existente.
- Mostrar el original mediante `NSWorkspace.selectFile` por un MethodChannel
  macOS. No ejecutar `open`, shell ni procesos externos.
- Guardar la base de datos en el directorio Application Support que reporta
  macOS. No se requiere una migración: `assets.path` ya guarda la ruta.
- Tratar cada ZIP como un archivo único. No extraer ni inspeccionar su
  contenido.

## Consecuencias

- Las rutas permanecen en el índice local y permiten volver al original en
  Finder mientras siga en esa ubicación.
- Las lecturas se limitan a archivos elegidos explícitamente por el usuario;
  no se habilita acceso general a su disco.
- El diseño no agrega dependencias ni altera los originales.
- La relectura automática de archivos seleccionados en ejecuciones futuras
  requeriría permisos persistentes mediante bookmarks de seguridad y deberá
  abordarse con una migración versionada si se incorpora.

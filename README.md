# Vault DAM

Aplicación local para catalogar activos multimedia y volver a su archivo
original desde Finder. El índice y los hashes se guardan en SQLite dentro de
Application Support de macOS.

## Ejecutar en macOS

```sh
flutter run -d macos
```

Pulsa **Importar** para seleccionar uno o varios ZIP o archivos raíz. Vault DAM
los indexa en segundo plano, permite cancelar, guarda la ruta absoluta y el
hash para detectar duplicados, y conserva la selección al reiniciar la app.
Abre la ficha de un activo y pulsa **Mostrar en Finder** para localizar el
original.

La app no extrae, mueve, renombra ni modifica los originales. Un ZIP se cataloga
como un único archivo: sus contenidos internos no se extraen ni se indexan. El
acceso a los originales se limita a lectura y la operación de Finder se hace
mediante una llamada nativa de macOS, sin ejecutar un shell.

Para crear la aplicación ejecutable:

```sh
flutter build macos --release
```

El `.app` se genera en
`build/macos/Build/Products/Release/vault_dam.app`.

## Vista previa web

```sh
flutter run -d web-server --web-port 7357
```

La vista web conserva los datos sintéticos y una importación temporal en
memoria. La persistencia y **Mostrar en Finder** requieren la aplicación macOS.

## Estado y siguientes pasos

La primera entrega ejecutable ya permite indexar archivos seleccionados,
persistir sus rutas y volver a ellos. Aún falta conectar el escaneo de carpetas
completas y carpetas vigiladas a la interfaz, además de miniaturas, tags,
colecciones, filtros avanzados e integración Quick Look.

Las decisiones están en [`docs/adr/`](docs/adr/).

## Validación local

```sh
flutter analyze --fatal-infos
flutter test --coverage
```

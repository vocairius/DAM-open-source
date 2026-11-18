/// Una migración versionada con su propia reversión.
///
/// Cada migración tiene un número `version` creciente y dos sentencias SQL:
/// `upSql` (aplicar) y `downSql` (revertir).
class Migration {
  /// Número de versión incremental (1, 2, 3, ...).
  final int version;

  /// SQL para aplicar la migración (forward).
  final String upSql;

  /// SQL para revertir la migración (rollback).
  final String downSql;

  const Migration({
    required this.version,
    required this.upSql,
    required this.downSql,
  });
}

/// Esquema inicial de Vault DAM (versión 1).
///
/// Todas las tablas del modelo mínimo: assets, tags, categories, licenses,
/// collections, watched_folders, asset_tags, collection_assets, operations_log.
class InitialMigration extends Migration {
  static const int schemaVersion = 1;

  InitialMigration()
      : super(
          version: schemaVersion,
          upSql: '''
            CREATE TABLE schema_version (
              version INTEGER NOT NULL
            );

            INSERT INTO schema_version (version) VALUES ($schemaVersion);

            CREATE TABLE assets (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              path TEXT NOT NULL UNIQUE,
              hash TEXT NOT NULL,
              type TEXT NOT NULL,
              size INTEGER NOT NULL,
              width INTEGER,
              height INTEGER,
              duration_ms INTEGER,
              imported_at TEXT NOT NULL,
              modified_at TEXT NOT NULL,
              rating INTEGER,
              color_label TEXT NOT NULL DEFAULT 'none',
              notes TEXT NOT NULL DEFAULT '',
              deleted_at TEXT
            );

            CREATE INDEX idx_assets_hash ON assets(hash);
            CREATE INDEX idx_assets_type ON assets(type);
            CREATE INDEX idx_assets_imported_at ON assets(imported_at);
            CREATE INDEX idx_assets_deleted_at ON assets(deleted_at);
            CREATE INDEX idx_assets_rating ON assets(rating);
            CREATE INDEX idx_assets_color_label ON assets(color_label);

            CREATE TABLE tags (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              parent_id INTEGER REFERENCES tags(id),
              color TEXT NOT NULL DEFAULT '#808080'
            );
            CREATE INDEX idx_tags_parent_id ON tags(parent_id);

            CREATE TABLE categories (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              parent_id INTEGER REFERENCES categories(id),
              slug TEXT NOT NULL UNIQUE
            );
            CREATE INDEX idx_categories_parent_id ON categories(parent_id);

            CREATE TABLE licenses (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              asset_id INTEGER NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
              license_type TEXT NOT NULL,
              compatible_software TEXT NOT NULL DEFAULT '',
              author TEXT,
              source TEXT
            );
            CREATE INDEX idx_licenses_asset_id ON licenses(asset_id);

            CREATE TABLE collections (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              kind TEXT NOT NULL,
              rule_json TEXT,
              created_at TEXT NOT NULL
            );

            CREATE TABLE asset_tags (
              asset_id INTEGER NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
              tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
              PRIMARY KEY (asset_id, tag_id)
            );

            CREATE TABLE collection_assets (
              collection_id INTEGER NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
              asset_id INTEGER NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
              PRIMARY KEY (collection_id, asset_id)
            );

            CREATE TABLE watched_folders (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              path TEXT NOT NULL UNIQUE,
              enabled INTEGER NOT NULL DEFAULT 1,
              last_scan_at TEXT
            );

            CREATE TABLE operations_log (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              operation TEXT NOT NULL,
              payload_json TEXT NOT NULL,
              created_at TEXT NOT NULL,
              reversible INTEGER NOT NULL DEFAULT 1
            );
            CREATE INDEX idx_operations_log_created_at ON operations_log(created_at);
          ''',
          downSql: '''
            DROP TABLE IF EXISTS collection_assets;
            DROP TABLE IF EXISTS asset_tags;
            DROP TABLE IF EXISTS watched_folders;
            DROP TABLE IF EXISTS operations_log;
            DROP TABLE IF EXISTS collections;
            DROP TABLE IF EXISTS licenses;
            DROP TABLE IF EXISTS categories;
            DROP TABLE IF EXISTS tags;
            DROP TABLE IF EXISTS assets;
            DROP TABLE IF EXISTS schema_version;
          ''',
        );
}

/// Todas las migraciones ordenadas por versión.
///
/// Para añadir una nueva versión: crear una clase que extienda [Migration] con
/// upSql/downSql, registrarla aquí, y añadir su prueba de regresión en
/// test/database/migrations_test.dart.
class AssetCategoryMigration extends Migration {
  static const int schemaVersion = 2;

  const AssetCategoryMigration()
      : super(
          version: schemaVersion,
          upSql:
              "ALTER TABLE assets ADD COLUMN category TEXT NOT NULL DEFAULT '';",
          downSql: 'ALTER TABLE assets DROP COLUMN category;',
        );
}

final List<Migration> registeredMigrations = <Migration>[
  InitialMigration(),
  const AssetCategoryMigration(),
];

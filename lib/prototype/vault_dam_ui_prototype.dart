// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;

import '../model/asset.dart';
import '../model/asset_catalog.dart';
import '../model/asset_type.dart';
import '../model/cancel_token.dart';

const _background = Color(0xFF0B0B0C);
const _sidebar = Color(0xFF141416);
const _surface = Color(0xFF19191C);
const _border = Color(0xFF28282B);
const _green = Color(0xFF49D17E);
const _muted = Color(0xFF9B9BA0);

class VaultDamUiPrototype extends StatelessWidget {
  const VaultDamUiPrototype({
    super.key,
    this.catalog,
    this.revealSource,
    this.thumbnailGenerator,
    this.showSampleAssets = true,
  });

  final AssetCatalog? catalog;
  final Future<void> Function(String path)? revealSource;
  final Future<Uint8List?> Function(String path, AssetType type)?
      thumbnailGenerator;
  final bool showSampleAssets;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Vault DAM — Biblioteca',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: _background,
          fontFamily: 'Arial',
          colorScheme: const ColorScheme.dark(
            primary: _green,
            surface: _surface,
          ),
        ),
        home: VaultLibraryPreview(
          catalog: catalog,
          revealSource: revealSource,
          thumbnailGenerator: thumbnailGenerator,
          showSampleAssets: showSampleAssets,
        ),
      );
}

class VaultLibraryPreview extends StatefulWidget {
  const VaultLibraryPreview({
    super.key,
    this.zipPicker,
    this.directoryPicker,
    this.catalog,
    this.revealSource,
    this.thumbnailGenerator,
    this.showSampleAssets = true,
  });

  final Future<List<LibraryAsset>> Function()? zipPicker;
  final Future<String?> Function()? directoryPicker;
  final AssetCatalog? catalog;
  final Future<void> Function(String path)? revealSource;
  final Future<Uint8List?> Function(String path, AssetType type)?
      thumbnailGenerator;
  final bool showSampleAssets;

  @override
  State<VaultLibraryPreview> createState() => _VaultLibraryPreviewState();
}

class _VaultLibraryPreviewState extends State<VaultLibraryPreview> {
  final _searchController = TextEditingController();
  final _favorites = <String>{};
  final _zipAssets = <LibraryAsset>[];
  String _query = '';
  String _activeFilter = '';
  String _activeSection = 'Biblioteca';
  String? _selectedAsset;
  bool _isIndexing = false;
  int _filesToIndex = 0;
  int _filesIndexed = 0;
  CancelToken? _cancelToken;
  String? _catalogError;
  final _thumbnailPaths = <String, Uint8List>{};

  List<LibraryAsset> get _filteredAssets {
    final normalizedQuery = _query.trim().toLowerCase();
    final List<LibraryAsset> sampleAssets =
        widget.showSampleAssets ? _libraryAssets : const [];
    final catalogAssets = _zipAssets.map((asset) {
      final thumbnail = asset.sourcePath == null
          ? null
          : _thumbnailPaths[asset.sourcePath!];
      return thumbnail == null ? asset : asset.copyWith(thumbnailPath: thumbnail);
    }).toList();
    return [...sampleAssets, ...catalogAssets].where((asset) {
      final matchesQuery = normalizedQuery.isEmpty ||
          asset.name.toLowerCase().contains(normalizedQuery) ||
          (asset.archiveName?.toLowerCase().contains(normalizedQuery) ??
              false) ||
          asset.owner.toLowerCase().contains(normalizedQuery) ||
          asset.category.toLowerCase().contains(normalizedQuery) ||
          asset.tags.any((tag) => tag.toLowerCase().contains(normalizedQuery));
      final matchesFilter = _activeFilter.isEmpty ||
          asset.category == _activeFilter ||
          asset.tags
              .any((tag) => tag.toLowerCase() == _activeFilter.toLowerCase());
      final matchesSection =
          _activeSection != 'Favoritos' || _favorites.contains(asset.identity);
      return matchesQuery && matchesFilter && matchesSection;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final catalog = widget.catalog;
    if (catalog == null) return;
    try {
      final assets = await catalog.listAssets();
      if (!mounted) return;
      setState(() {
        _zipAssets
          ..clear()
          ..addAll(assets.map(LibraryAsset.fromAsset));
        _catalogError = null;
      });
      await _generateThumbnails();
    } on AssetCatalogException catch (error) {
      if (!mounted) return;
      setState(() => _catalogError = error.message);
    }
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF29292C),
        ),
      );
  }

  void _selectSection(String section) {
    setState(() {
      _activeSection = section;
      _activeFilter = '';
    });
  }

  void _selectFilter(String filter) {
    final category = switch (filter) {
      'Plantillas AE' => 'Plantillas de video',
      'Stock de video' => 'Video de stock',
      'Audio iglesia' => 'Audio',
      'Diseño redes' => 'Gráficos',
      _ => filter,
    };
    setState(() {
      _activeFilter = _activeFilter == category ? '' : category;
      _activeSection = 'Biblioteca';
    });
  }

  void _toggleFavorite(LibraryAsset asset) {
    setState(() {
      if (!_favorites.add(asset.identity)) {
        _favorites.remove(asset.identity);
      }
    });
    _showInfo(
      _favorites.contains(asset.identity)
          ? 'Añadido a favoritos'
          : 'Eliminado de favoritos',
    );
  }

  Future<void> _pickAssets() async {
    final selected = await (widget.zipPicker?.call() ?? _selectAssets());
    if (!mounted || selected.isEmpty) return;

    final catalog = widget.catalog;
    if (catalog == null) {
      setState(() {
        for (final asset in selected) {
          _zipAssets.removeWhere(
            (existing) => existing.identity == asset.identity,
          );
          _zipAssets.add(asset);
        }
        _activeSection = 'Biblioteca';
        _activeFilter = '';
      });
      _showInfo(
        '${selected.length} archivos listos para la vista previa. '
        'No se extrajeron ni modificaron.',
      );
      return;
    }

    if (selected.any((asset) => asset.sourcePath == null)) {
      _showInfo(
        'El selector no proporcionó rutas locales. '
        'Usa la aplicación de macOS para indexar archivos.',
      );
      return;
    }

    final token = CancelToken();
    var cancelled = false;
    String? failure;
    setState(() {
      _isIndexing = true;
      _filesToIndex = selected.length;
      _filesIndexed = 0;
      _cancelToken = token;
      _activeSection = 'Biblioteca';
      _activeFilter = '';
    });

    try {
      for (final asset in selected) {
        if (token.isCancelled) {
          cancelled = true;
          break;
        }
        await catalog.indexFile(asset.sourcePath!, cancelToken: token);
        if (!mounted) return;
        setState(() => _filesIndexed++);
      }
    } on IndexingCancelledException {
      cancelled = true;
    } on AssetReadException catch (error) {
      failure = error.message;
    } on AssetCatalogException catch (error) {
      failure = error.message;
    } finally {
      await _loadCatalog();
      if (mounted) {
        setState(() {
          _isIndexing = false;
          _cancelToken = null;
        });
      }
    }

    if (!mounted) return;
    if (failure != null) {
      _showInfo(failure);
    } else if (cancelled || token.isCancelled) {
      _showInfo(
        'Indexación cancelada. $_filesIndexed de ${selected.length} archivos '
        'quedaron registrados.',
      );
    } else {
      _showInfo(
        '${selected.length} archivos indexados. '
        'Los originales siguen intactos.',
      );
    }
  }

  Future<void> _generateThumbnails() async {
    final generator = widget.thumbnailGenerator;
    if (generator == null) return;
    for (final asset in _zipAssets) {
      final path = asset.sourcePath;
      if (path == null || _thumbnailPaths.containsKey(path)) continue;
      final type = typeByExtension(p.extension(path).replaceFirst('.', ''));
      if (type == null ||
          (type != AssetType.image && type != AssetType.video)) {
        continue;
      }
      try {
        final thumbnail = await generator(path, type);
        if (!mounted || thumbnail == null) continue;
        setState(() => _thumbnailPaths[path] = thumbnail);
      } on Exception {
        continue;
      }
    }
  }

  Future<void> _pickDirectory() async {
    final catalog = widget.catalog;
    if (catalog == null) {
      _showInfo('La importación de carpetas requiere la aplicación macOS.');
      return;
    }
    final directory = await (widget.directoryPicker?.call() ??
        getDirectoryPath(confirmButtonText: 'Importar carpeta'));
    if (!mounted || directory == null || directory.isEmpty) return;

    final token = CancelToken();
    var cancelled = false;
    String? failure;
    setState(() {
      _isIndexing = true;
      _filesToIndex = 0;
      _filesIndexed = 0;
      _cancelToken = token;
      _activeSection = 'Biblioteca';
      _activeFilter = '';
    });

    try {
      await catalog.indexDirectory(
        root: directory,
        cancelToken: token,
        onProgress: (processed, currentPath) {
          if (!mounted) return;
          setState(() {
            _filesIndexed = processed;
            _filesToIndex = processed;
          });
        },
      );
      cancelled = token.isCancelled;
    } on IndexingCancelledException {
      cancelled = true;
    } on AssetReadException catch (error) {
      failure = error.message;
    } on AssetCatalogException catch (error) {
      failure = error.message;
    } finally {
      await _loadCatalog();
      if (mounted) {
        setState(() {
          _isIndexing = false;
          _cancelToken = null;
        });
      }
    }

    if (!mounted) return;
    if (failure != null) {
      _showInfo(failure);
    } else if (cancelled) {
      _showInfo(
        'Importación cancelada. $_filesIndexed archivos quedaron registrados.',
      );
    } else {
      _showInfo('$_filesIndexed archivos indexados desde la carpeta.');
    }
  }

  void _cancelIndexing() {
    _cancelToken?.cancel();
  }

  Future<void> _revealAsset(LibraryAsset asset) async {
    final path = asset.sourcePath;
    final revealSource = widget.revealSource;
    if (path == null || revealSource == null) {
      _showInfo('Mostrar en Finder está disponible en la aplicación macOS.');
      return;
    }
    try {
      await revealSource(path);
    } on PlatformException catch (error) {
      _showInfo(error.message ?? 'Finder no pudo mostrar el archivo original.');
    }
  }

  void _openAsset(LibraryAsset asset) {
    setState(() => _selectedAsset = asset.identity);
    showDialog<void>(
      context: context,
      builder: (context) {
        var selectedCategory =
            asset.category == 'Otros' ? '' : asset.category;
        const categories = [
          'Plantillas de video',
          'Video de stock',
          'Audio',
          'Gráficos',
          'Fuentes',
          'LUTs',
          'Add-ons',
          'Fotos',
          'Documentos',
          'Proyectos',
        ];
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1D),
            title: Text(asset.name),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.sourcePath ??
                        'Ejemplo local de la vista previa.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory.isEmpty ||
                            categories.contains(selectedCategory)
                        ? (selectedCategory.isEmpty ? null : selectedCategory)
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Sin categoría'),
                      ),
                      ...categories.map(
                        (category) => DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => selectedCategory = value ?? ''),
                  ),
                ],
              ),
            ),
            actions: [
              if (asset.sourcePath != null)
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _revealAsset(asset);
                  },
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Mostrar en Finder'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  final catalog = widget.catalog;
                  final path = asset.sourcePath;
                  if (catalog != null && path != null) {
                    try {
                      await catalog.updateCategory(path, selectedCategory);
                    } on AssetCatalogException catch (error) {
                      if (!context.mounted) return;
                      _showInfo(error.message);
                      return;
                    }
                  }
                  if (!mounted) return;
                  setState(() {
                    final index = _zipAssets.indexWhere(
                      (item) => item.identity == asset.identity,
                    );
                    if (index >= 0) {
                      _zipAssets[index] =
                          _zipAssets[index].copyWith(category: selectedCategory);
                    }
                  });
                  if (context.mounted) Navigator.pop(context);
                  _showInfo(
                    selectedCategory.isEmpty
                        ? 'Categoría eliminada'
                        : 'Categoría: $selectedCategory',
                  );
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final assets = _filteredAssets;
    final recent = assets.where((asset) => !asset.featured).toList();
    final featured = assets.where((asset) => asset.featured).take(2).toList();
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (width > 760)
              _LibrarySidebar(
                activeSection: _activeSection,
                onSectionSelected: _selectSection,
                onCollectionSelected: _selectFilter,
                onConfigure: () => _showInfo(
                  'La conexión a NAS estará disponible en una fase posterior.',
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  _LibraryTopBar(
                    searchController: _searchController,
                    onSearch: (value) => setState(() => _query = value),
                    onImportFiles: _pickAssets,
                    onImportFolder: _pickDirectory,
                    isIndexing: _isIndexing,
                    onCancel: _cancelIndexing,
                  ),
                  if (_isIndexing)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: _filesToIndex == 0
                                  ? null
                                  : _filesIndexed / _filesToIndex,
                              color: _green,
                              backgroundColor: _border,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$_filesIndexed / $_filesToIndex',
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_catalogError != null)
                    MaterialBanner(
                      content: Text(_catalogError!),
                      actions: [
                        TextButton(
                          onPressed: _loadCatalog,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth < 620
                            ? 2
                            : constraints.maxWidth < 960
                                ? 3
                                : 4;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(28, 26, 28, 44),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (featured.isNotEmpty) ...[
                                _FeaturedRow(
                                  assets: featured,
                                  favorites: _favorites,
                                  onFavorite: _toggleFavorite,
                                  onOpen: _openAsset,
                                  onShare: () => _showInfo(
                                    'Los originales no se han compartido ni subido.',
                                  ),
                                ),
                                const SizedBox(height: 32),
                              ],
                              _CategorySection(
                                activeFilter: _activeFilter,
                                onSelected: _selectFilter,
                              ),
                              const SizedBox(height: 32),
                              _RecentSection(
                                assets: recent,
                                columns: columns,
                                selectedAsset: _selectedAsset,
                                favorites: _favorites,
                                archiveCount: _zipAssets
                                    .where((asset) => asset.archiveName != null)
                                    .length,
                                onOpen: _openAsset,
                                onFavorite: _toggleFavorite,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: width <= 760
          ? _MobileNavigation(
              activeSection: _activeSection,
              onSelected: _selectSection,
            )
          : null,
    );
  }
}

class _LibrarySidebar extends StatelessWidget {
  const _LibrarySidebar({
    required this.activeSection,
    required this.onSectionSelected,
    required this.onCollectionSelected,
    required this.onConfigure,
  });

  final String activeSection;
  final ValueChanged<String> onSectionSelected;
  final ValueChanged<String> onCollectionSelected;
  final VoidCallback onConfigure;

  static const _sections = [
    ('Biblioteca', Icons.home_outlined),
    ('Recientes', Icons.schedule_outlined),
    ('Categorías', Icons.grid_view_outlined),
    ('Favoritos', Icons.favorite_border),
    ('Tus assets', Icons.folder_open_outlined),
  ];

  static const _collections = [
    ('AE', 'Plantillas AE', Color(0xFF49D17E)),
    ('SV', 'Stock de video', Color(0xFF5FB0E8)),
    ('AI', 'Audio iglesia', Color(0xFFE8A85F)),
    ('Fu', 'Fuentes', Color(0xFFC98AF0)),
    ('DR', 'Diseño redes', Color(0xFFF06F8A)),
  ];

  @override
  Widget build(BuildContext context) => Container(
        width: 252,
        decoration: const BoxDecoration(
          color: _sidebar,
          border: Border(right: BorderSide(color: Color(0xFF232325))),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Brand(),
              const SizedBox(height: 30),
              for (final section in _sections)
                _NavigationItem(
                  title: section.$1,
                  icon: section.$2,
                  active: activeSection == section.$1,
                  onTap: () => onSectionSelected(section.$1),
                ),
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.only(left: 10, bottom: 8),
                child: Text(
                  'COLECCIONES',
                  style: TextStyle(
                    color: Color(0xFF6C6C71),
                    fontSize: 11,
                    letterSpacing: .7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final collection in _collections)
                _CollectionItem(
                  initials: collection.$1,
                  title: collection.$2,
                  color: collection.$3,
                  onTap: () => onCollectionSelected(collection.$2),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1D),
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text.rich(
                      TextSpan(
                        style: TextStyle(
                          color: Color(0xFFD7D7DA),
                          fontSize: 13,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(
                            text: 'Conecta tu NAS casero\n',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text:
                                'Comparte la biblioteca con el equipo de Orquid Media.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onConfigure,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _green,
                          side: const BorderSide(color: Color(0xFF2FAE63)),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                        ),
                        child: const Text(
                          'Configurar',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          SizedBox(
            width: 34,
            height: 18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF1F8A4C),
                borderRadius: BorderRadius.all(Radius.circular(99)),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: 2),
                  child: CircleAvatar(
                    radius: 7,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 10),
          Text(
            'Vault DAM',
            style: TextStyle(
              color: Color(0xFFF4F4F5),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.title,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: active ? const Color(0xFF1F1F22) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 38,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: active ? Colors.white : _muted,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      title,
                      style: TextStyle(
                        color: active ? Colors.white : _muted,
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _CollectionItem extends StatelessWidget {
  const _CollectionItem({
    required this.initials,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final String initials;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 39,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12.5,
                  backgroundColor: color,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Color(0xFF101012),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFC9C9CD),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _LibraryTopBar extends StatelessWidget {
  const _LibraryTopBar({
    required this.searchController,
    required this.onSearch,
    required this.onImportFiles,
    required this.onImportFolder,
    required this.isIndexing,
    required this.onCancel,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onImportFiles;
  final VoidCallback onImportFolder;
  final bool isIndexing;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1E1E21))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _surface,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search,
                      color: Color(0xFF8D8D92),
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearch,
                        style: const TextStyle(
                          color: Color(0xFFF2F2F2),
                          fontSize: 13,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Buscar archivos, tags o categorías…',
                          hintStyle: TextStyle(
                            color: Color(0xFF77777D),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (searchController.text.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          searchController.clear();
                          onSearch('');
                        },
                        icon: const Icon(Icons.close, size: 16),
                        color: _muted,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            if (isIndexing)
              OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 15),
                label: const Text('Cancelar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  side: const BorderSide(color: Color(0xFF2FAE63)),
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: onImportFiles,
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('Importar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: Color(0xFF2FAE63)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton(
                    onPressed: onImportFolder,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: Color(0xFF2FAE63)),
                      minimumSize: const Size(40, 40),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Tooltip(
                      message: 'Importar carpeta',
                      child: Icon(Icons.folder_open_outlined, size: 16),
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 20),
            const _UserButton(),
          ],
        ),
      );
}

class _UserButton extends StatelessWidget {
  const _UserButton();

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil local de vista previa'),
            behavior: SnackBarBehavior.floating,
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFE7E7E9),
          padding: EdgeInsets.zero,
        ),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFF3C3C40),
              child: Text(
                'N',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(width: 8),
            Text('Nicolás', style: TextStyle(fontSize: 12)),
            SizedBox(width: 5),
            Icon(Icons.keyboard_arrow_down, size: 16),
          ],
        ),
      );
}

class _FeaturedRow extends StatelessWidget {
  const _FeaturedRow({
    required this.assets,
    required this.favorites,
    required this.onFavorite,
    required this.onOpen,
    required this.onShare,
  });

  final List<LibraryAsset> assets;
  final Set<String> favorites;
  final ValueChanged<LibraryAsset> onFavorite;
  final ValueChanged<LibraryAsset> onOpen;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final vertical = constraints.maxWidth < 620;
          return Flex(
            direction: vertical ? Axis.vertical : Axis.horizontal,
            children: [
              for (var index = 0; index < assets.length; index++) ...[
                if (index > 0)
                  SizedBox(
                    width: vertical ? 0 : 20,
                    height: vertical ? 16 : 0,
                  ),
                _ExpandedIfHorizontal(
                  vertical: vertical,
                  child: SizedBox(
                    height: 220,
                    child: _FeaturedCard(
                      asset: assets[index],
                      favorite: favorites.contains(assets[index].identity),
                      onFavorite: () => onFavorite(assets[index]),
                      onOpen: () => onOpen(assets[index]),
                      onShare: onShare,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      );
}

class _ExpandedIfHorizontal extends StatelessWidget {
  const _ExpandedIfHorizontal({
    required this.vertical,
    required this.child,
  });

  final bool vertical;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      vertical ? child : Expanded(child: child);
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.asset,
    required this.favorite,
    required this.onFavorite,
    required this.onOpen,
    required this.onShare,
  });

  final LibraryAsset asset;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onOpen;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 220),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                asset.color.withAlpha(122),
                const Color(0xFF151517),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF29292D)),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: Wrap(
                  spacing: 6,
                  children: asset.tags.take(2).map((tag) {
                    return _Pill(
                      label: tag.toUpperCase(),
                      background: const Color(0x80000000),
                      foreground: const Color(0xFF9FE8B8),
                      small: true,
                    );
                  }).toList(),
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: Row(
                  children: [
                    _RoundIconButton(
                      icon: favorite ? Icons.favorite : Icons.favorite_border,
                      label: favorite
                          ? 'Quitar de favoritos'
                          : 'Marcar como favorito',
                      active: favorite,
                      onTap: onFavorite,
                    ),
                    const SizedBox(width: 8),
                    _RoundIconButton(
                      icon: Icons.ios_share,
                      label: 'Compartir archivo',
                      onTap: onShare,
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: _Pill(
                  label: asset.duration,
                  background: const Color(0x80000000),
                  foreground: const Color(0xFFD9D9DB),
                ),
              ),
              Align(
                alignment: Alignment.bottomLeft,
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2B2B2E),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        asset.icon,
                        size: 16,
                        color: const Color(0xFFC9C9CD),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asset.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            asset.owner,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 15),
          color: active ? _green : Colors.white,
          style: IconButton.styleFrom(
            backgroundColor: const Color(0x73000000),
            fixedSize: const Size(30, 30),
          ),
        ),
      );
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.activeFilter,
    required this.onSelected,
  });

  final String activeFilter;
  final ValueChanged<String> onSelected;

  static const _categories = [
    'Plantillas de video',
    'Video de stock',
    'Audio',
    'Gráficos',
    'Fuentes',
    'LUTs',
    'Add-ons',
    'Fotos',
  ];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Explorar por categorías',
            style: TextStyle(
              color: Color(0xFFF4F4F5),
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _categories.map((category) {
              final active = activeFilter == category;
              return Material(
                color: active ? const Color(0xFF1F3B2A) : _surface,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: () => onSelected(category),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: active ? const Color(0xFF2FAE63) : _border,
                      ),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: active
                            ? const Color(0xFF9FE8B8)
                            : const Color(0xFFD7D7DA),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
}

class _RecentSection extends StatelessWidget {
  const _RecentSection({
    required this.assets,
    required this.columns,
    required this.selectedAsset,
    required this.favorites,
    required this.archiveCount,
    required this.onOpen,
    required this.onFavorite,
  });

  final List<LibraryAsset> assets;
  final int columns;
  final String? selectedAsset;
  final Set<String> favorites;
  final int archiveCount;
  final ValueChanged<LibraryAsset> onOpen;
  final ValueChanged<LibraryAsset> onFavorite;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Activos recientes',
                style: TextStyle(
                  color: Color(0xFFF4F4F5),
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (archiveCount > 0) ...[
                const SizedBox(width: 10),
                _Pill(
                  label: '$archiveCount ZIP de Envato',
                  background: const Color(0xFF1F3B2A),
                  foreground: const Color(0xFF9FE8B8),
                  small: true,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (assets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'No hay activos para esta búsqueda.',
                  style: TextStyle(color: _muted, fontSize: 13),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final actualColumns = constraints.maxWidth < 430
                    ? 1
                    : columns.clamp(1, assets.length);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: assets.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: actualColumns,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: 1.12,
                  ),
                  itemBuilder: (context, index) {
                    final asset = assets[index];
                    return _AssetTile(
                      asset: asset,
                      selected: asset.identity == selectedAsset,
                      favorite: favorites.contains(asset.identity),
                      onOpen: () => onOpen(asset),
                      onFavorite: () => onFavorite(asset),
                    );
                  },
                );
              },
            ),
        ],
      );
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({
    required this.asset,
    required this.selected,
    required this.favorite,
    required this.onOpen,
    required this.onFavorite,
  });

  final LibraryAsset asset;
  final bool selected;
  final bool favorite;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1D20),
                  border: Border.all(
                    color: selected ? _green : const Color(0xFF27272A),
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: asset.thumbnailPath == null
                          ? Icon(
                              asset.icon,
                              size: 28,
                              color: const Color(0xFF77777D),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.memory(
                                asset.thumbnailPath!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              ),
                            ),
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: _Pill(
                        label: asset.archiveName == null ? asset.badge : 'ZIP',
                        background: const Color(0x80000000),
                        foreground: const Color(0xFF9FE8B8),
                        small: true,
                      ),
                    ),
                    Positioned(
                      top: 5,
                      right: 5,
                      child: IconButton(
                        onPressed: onFavorite,
                        tooltip: favorite ? 'Quitar de favoritos' : 'Favorito',
                        icon: Icon(
                          favorite ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                        ),
                        color: favorite ? _green : Colors.white70,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              asset.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFF2F2F2),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              asset.duration == '—' ? asset.category : asset.duration,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF8D8D92), fontSize: 11),
            ),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
    this.small = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final bool small;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 9 : 8,
          vertical: small ? 4 : 3,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: small ? 10 : 11,
            fontWeight: FontWeight.w700,
            letterSpacing: small ? .3 : 0,
          ),
        ),
      );
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({
    required this.activeSection,
    required this.onSelected,
  });

  final String activeSection;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => BottomNavigationBar(
        currentIndex: switch (activeSection) {
          'Recientes' => 1,
          'Categorías' => 2,
          'Favoritos' => 3,
          _ => 0,
        },
        onTap: (index) => onSelected(
          ['Biblioteca', 'Recientes', 'Categorías', 'Favoritos'][index],
        ),
        type: BottomNavigationBarType.fixed,
        backgroundColor: _sidebar,
        selectedItemColor: _green,
        unselectedItemColor: _muted,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Biblioteca',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule_outlined),
            label: 'Recientes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            label: 'Categorías',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: 'Favoritos',
          ),
        ],
      );
}

class LibraryAsset {
  const LibraryAsset({
    required this.name,
    required this.owner,
    required this.category,
    required this.duration,
    required this.tags,
    required this.icon,
    required this.badge,
    required this.color,
    this.featured = false,
    this.archiveName,
    this.sourcePath,
    this.thumbnailPath,
  });

  final String name;
  final String owner;
  final String category;
  final String duration;
  final List<String> tags;
  final IconData icon;
  final String badge;
  final Color color;
  final bool featured;
  final String? archiveName;
  final String? sourcePath;
  final Uint8List? thumbnailPath;

  String get identity => sourcePath ?? archiveName ?? name;

  LibraryAsset copyWith({
    Uint8List? thumbnailPath,
    String? category,
  }) =>
      LibraryAsset(
        name: name,
        owner: owner,
        category: category ?? this.category,
        duration: duration,
        tags: tags,
        icon: icon,
        badge: badge,
        color: color,
        featured: featured,
        archiveName: archiveName,
        sourcePath: sourcePath,
        thumbnailPath: thumbnailPath,
      );

  factory LibraryAsset.fromZip({
    required String fileName,
    required int sizeBytes,
    String? sourcePath,
    String? category,
  }) {
    final stem =
        fileName.replaceFirst(RegExp(r'\.zip$', caseSensitive: false), '');
    final cleanStem = stem.replaceFirst(
      RegExp(
        r'-\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}-utc$',
        caseSensitive: false,
      ),
      '',
    );
    final resolvedCategory = category ?? _zipCategory(cleanStem);
    final title = cleanStem
        .replaceAll(RegExp(r'[-_]+'), ' ')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');

    return LibraryAsset(
      name: title,
      owner: 'Envato Elements',
      category: resolvedCategory,
      duration: _formatZipSize(sizeBytes),
      tags: ['ENVATO', resolvedCategory.toUpperCase(), 'ZIP'],
      icon: _zipIcon(resolvedCategory),
      badge: 'ENVATO',
      color: const Color(0xFF37333D),
      archiveName: fileName,
      sourcePath: sourcePath,
    );
  }

  factory LibraryAsset.fromFile({
    required String fileName,
    required int sizeBytes,
    String? sourcePath,
    String? category,
  }) {
    if (p.extension(fileName).toLowerCase() == '.zip') {
      return LibraryAsset.fromZip(
        fileName: fileName,
        sizeBytes: sizeBytes,
        sourcePath: sourcePath,
        category: category,
      );
    }

    final extension = p.extension(fileName).replaceFirst('.', '');
    final type = typeByExtension(extension) ?? AssetType.other;
    return LibraryAsset(
      name: fileName,
      owner: 'Archivo local',
      category: category ?? _assetCategory(type),
      duration: _formatZipSize(sizeBytes),
      tags: ['LOCAL', type.name.toUpperCase()],
      icon: _assetIcon(type),
      badge: type.name.toUpperCase(),
      color: const Color(0xFF373A35),
      sourcePath: sourcePath,
    );
  }

  factory LibraryAsset.fromAsset(Asset asset) {
    final fileName = p.basename(asset.path);
    if (p.extension(fileName).toLowerCase() == '.zip') {
      return LibraryAsset.fromZip(
        fileName: fileName,
        sizeBytes: asset.size,
        sourcePath: asset.path,
        category: asset.category,
      );
    }
    return LibraryAsset.fromFile(
      fileName: fileName,
      sizeBytes: asset.size,
      sourcePath: asset.path,
      category: asset.category,
    );
  }
}

Future<List<LibraryAsset>> _selectAssets() async {
  final files = await openFiles();
  final assets = <LibraryAsset>[];
  for (final file in files) {
    assets.add(
      LibraryAsset.fromFile(
        fileName: file.name,
        sizeBytes: await file.length(),
        sourcePath: file.path.isEmpty ? null : file.path,
      ),
    );
  }
  return assets;
}

String _assetCategory(AssetType type) => switch (type) {
      AssetType.video => 'Video',
      AssetType.audio => 'Audio',
      AssetType.image => 'Imágenes',
      AssetType.project => 'Proyectos',
      AssetType.font => 'Fuentes',
      AssetType.document => 'Documentos',
      AssetType.other => 'Otros',
    };

IconData _assetIcon(AssetType type) => switch (type) {
      AssetType.video => Icons.movie_outlined,
      AssetType.audio => Icons.graphic_eq_outlined,
      AssetType.image => Icons.image_outlined,
      AssetType.project => Icons.video_library_outlined,
      AssetType.font => Icons.font_download_outlined,
      AssetType.document => Icons.description_outlined,
      AssetType.other => Icons.insert_drive_file_outlined,
    };

String _zipCategory(String filename) {
  final name = filename.toLowerCase();
  if (name.contains('lightroom') || name.contains('preset')) return 'Fotos';
  if (name.contains('brush') || name.contains('shader')) return 'Add-ons';
  if (name.contains('mockup') ||
      name.contains('poster') ||
      name.contains('typography')) {
    return 'Gráficos';
  }
  if (name.contains('overlay') ||
      name.contains('grain') ||
      name.contains('film')) {
    return 'Video de stock';
  }
  return 'Plantillas de video';
}

IconData _zipIcon(String category) => switch (category) {
      'Fotos' => Icons.photo_library_outlined,
      'Add-ons' => Icons.brush_outlined,
      'Gráficos' => Icons.image_outlined,
      'Video de stock' => Icons.movie_outlined,
      _ => Icons.video_library_outlined,
    };

String _formatZipSize(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

const _libraryAssets = <LibraryAsset>[
  LibraryAsset(
    name: 'mapping_bailarines_v3.mp4',
    owner: 'Orquid Media',
    category: 'Plantillas de video',
    duration: '03:42',
    tags: ['VIDEO', 'MAPPING', 'Plantillas de video'],
    icon: Icons.play_arrow_rounded,
    badge: 'IGLESIA',
    color: Color(0xFF38443E),
    featured: true,
  ),
  LibraryAsset(
    name: 'intro_conexion7d_master.mov',
    owner: 'Conexión 7D',
    category: 'Video de stock',
    duration: '12:08',
    tags: ['VIDEO', 'PODCAST', 'Video de stock'],
    icon: Icons.play_arrow_rounded,
    badge: 'ORQUID',
    color: Color(0xFF3A4149),
    featured: true,
  ),
  LibraryAsset(
    name: 'church_sermon_loop.mp4',
    owner: 'Orquid Media',
    category: 'Plantillas de video',
    duration: '02:15',
    tags: ['IGLESIA'],
    icon: Icons.play_arrow_rounded,
    badge: 'IGLESIA',
    color: Color(0xFF353A38),
  ),
  LibraryAsset(
    name: 'SFX_whoosh_pack.wav',
    owner: 'Envato',
    category: 'Audio',
    duration: '24 archivos',
    tags: ['ENVATO'],
    icon: Icons.graphic_eq_rounded,
    badge: 'ENVATO',
    color: Color(0xFF37333D),
  ),
  LibraryAsset(
    name: 'logo_orquid_media.ai',
    owner: 'Orquid Media',
    category: 'Gráficos',
    duration: '—',
    tags: ['ORQUID'],
    icon: Icons.image_outlined,
    badge: 'ORQUID',
    color: Color(0xFF373A35),
  ),
  LibraryAsset(
    name: 'LUT_cinematic_warm.cube',
    owner: 'Envato',
    category: 'LUTs',
    duration: '—',
    tags: ['ENVATO'],
    icon: Icons.palette_outlined,
    badge: 'ENVATO',
    color: Color(0xFF403A32),
  ),
  LibraryAsset(
    name: 'Neue Forma — Display.otf',
    owner: 'Envato',
    category: 'Fuentes',
    duration: '—',
    tags: ['ENVATO'],
    icon: Icons.text_fields_rounded,
    badge: 'ENVATO',
    color: Color(0xFF343A3A),
  ),
  LibraryAsset(
    name: 'Citrus — Social pack.aep',
    owner: 'Orquid Media',
    category: 'Add-ons',
    duration: '—',
    tags: ['ORQUID'],
    icon: Icons.movie_creation_outlined,
    badge: 'ORQUID',
    color: Color(0xFF413A30),
  ),
];

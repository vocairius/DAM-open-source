// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault_dam/prototype/vault_dam_ui_prototype.dart';

void main() {
  testWidgets('renders the reference library and search filters assets',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VaultDamUiPrototype());

    expect(find.text('Vault DAM'), findsOneWidget);
    expect(find.text('Explorar por categorías'), findsOneWidget);
    expect(find.text('mapping_bailarines_v3.mp4'), findsOneWidget);
    expect(find.text('SFX_whoosh_pack.wav'), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'SFX_whoosh_pack',
    );
    await tester.pumpAndSettle();

    expect(find.text('SFX_whoosh_pack.wav'), findsOneWidget);
    expect(find.text('mapping_bailarines_v3.mp4'), findsNothing);
  });

  testWidgets('import action previews selected ZIPs without extracting them',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final zip = LibraryAsset.fromZip(
      fileName: 'cinematic-text-effects-2023-11-27-05-27-57-utc.zip',
      sizeBytes: 2 * 1024 * 1024,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: VaultLibraryPreview(zipPicker: () async => [zip]),
      ),
    );
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();

    expect(find.text('Cinematic Text Effects'), findsOneWidget);
    expect(find.text('1 ZIP de Envato'), findsOneWidget);
    expect(find.text('2.0 MB'), findsOneWidget);
    expect(
      find.textContaining('No se extrajeron ni modificaron'),
      findsOneWidget,
    );
  });

  test('ZIP filename metadata maps to a display title and local category', () {
    final asset = LibraryAsset.fromZip(
      fileName: 'vintage-lightroom-preset-stbrn-2025-05-05-22-24-15-utc.zip',
      sizeBytes: 1200,
    );

    expect(asset.name, 'Vintage Lightroom Preset Stbrn');
    expect(asset.category, 'Fotos');
    expect(asset.archiveName, endsWith('.zip'));
    expect(asset.duration, '1 KB');
    expect(asset.tags, contains('ENVATO'));
  });

  test('root files preserve their source path and infer the file type', () {
    final asset = LibraryAsset.fromFile(
      fileName: 'brand-guide.pdf',
      sizeBytes: 1200,
      sourcePath: '/tmp/vault-dam-fixtures/brand-guide.pdf',
    );

    expect(asset.name, 'brand-guide.pdf');
    expect(asset.category, 'Documentos');
    expect(asset.sourcePath, '/tmp/vault-dam-fixtures/brand-guide.pdf');
  });

  testWidgets('asset details reveal the selected original in Finder',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const sourcePath = '/tmp/vault-dam-fixtures/finder-route-test.zip';
    String? revealedPath;
    final zip = LibraryAsset.fromZip(
      fileName: 'finder-route-test.zip',
      sizeBytes: 1200,
      sourcePath: sourcePath,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: VaultLibraryPreview(
          zipPicker: () async => [zip],
          revealSource: (path) async => revealedPath = path,
          showSampleAssets: false,
        ),
      ),
    );
    await tester.tap(find.text('Importar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Finder Route Test'));
    await tester.tap(find.text('Finder Route Test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar en Finder'));
    await tester.pumpAndSettle();

    expect(revealedPath, sourcePath);
  });

  testWidgets('favorite action adds featured asset to favorites section',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VaultDamUiPrototype());
    await tester.tap(find.byTooltip('Marcar como favorito').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favoritos'));
    await tester.pumpAndSettle();

    expect(find.text('mapping_bailarines_v3.mp4'), findsOneWidget);
    expect(find.text('intro_conexion7d_master.mov'), findsNothing);
  });

  testWidgets('category chips filter the recent asset grid', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VaultDamUiPrototype());
    await tester.tap(find.text('Audio', skipOffstage: false).first);
    await tester.pumpAndSettle();

    expect(find.text('SFX_whoosh_pack.wav'), findsOneWidget);
    expect(find.text('church_sermon_loop.mp4'), findsNothing);
  });
}

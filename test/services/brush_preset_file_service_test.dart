import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_preset.dart';
import 'package:quick_animaker_v2/src/models/brush_preset_id.dart';
import 'package:quick_animaker_v2/src/models/brush_settings.dart';
import 'package:quick_animaker_v2/src/services/brush_preset_defaults.dart';
import 'package:quick_animaker_v2/src/services/brush_preset_file_service.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'brush_preset_file_service_test',
    );
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  String pathIn(String fileName) => '${tempDirectory.path}/$fileName';

  group('BrushPresetFileService', () {
    test('missing file yields the built-in defaults', () async {
      final service = BrushPresetFileService(filePath: pathIn('missing.json'));

      final presets = await service.loadOrDefaults();

      expect(presets, defaultBrushPresets);
      // Loading must not create the file; defaults are only persisted when
      // the user actually saves.
      expect(File(pathIn('missing.json')).existsSync(), isFalse);
    });

    test('save then load round-trips the library', () async {
      final service = BrushPresetFileService(
        filePath: pathIn('nested/dir/presets.json'),
      );
      final presets = [
        BrushPreset(
          id: const BrushPresetId('user-1'),
          name: 'My Pen',
          // Groups (import source files) must survive the round trip.
          group: '불투명 수채',
          settings: BrushSettings(
            size: 7,
            hardness: 0.9,
            roundness: 0.4,
            angleDegrees: 45,
            pressureSize: true,
          ),
        ),
        defaultBrushPresets.first,
      ];

      await service.save(presets);

      expect(await service.loadOrDefaults(), presets);
    });

    test('an explicitly saved empty library stays empty on load', () async {
      final service = BrushPresetFileService(filePath: pathIn('empty.json'));

      await service.save(const []);

      expect(await service.loadOrDefaults(), isEmpty);
    });

    test('corrupt file falls back to the built-in defaults', () async {
      final path = pathIn('corrupt.json');
      await File(path).writeAsString('{not json');
      final service = BrushPresetFileService(filePath: path);

      expect(await service.loadOrDefaults(), defaultBrushPresets);
    });

    test('valid json with wrong shape falls back to the defaults', () async {
      final path = pathIn('wrong_shape.json');
      await File(path).writeAsString(jsonEncode({'presets': 'nope'}));
      final service = BrushPresetFileService(filePath: path);

      expect(await service.loadOrDefaults(), defaultBrushPresets);
    });

    test('older library versions gain newly added built-ins on load', () async {
      final path = pathIn('v1.json');
      // A version-1 library saved before the sampled-tip built-ins existed:
      // it holds one user preset and one (kept) old built-in.
      final userPreset = BrushPreset(
        id: const BrushPresetId('user-1'),
        name: 'Mine',
        settings: BrushSettings(size: 3),
      );
      await File(path).writeAsString(
        jsonEncode({
          'version': 1,
          'presets': [userPreset.toJson(), defaultBrushPresets.first.toJson()],
        }),
      );
      final service = BrushPresetFileService(filePath: path);

      final loaded = await service.loadOrDefaults();

      // Existing entries stay first and unduplicated; the built-ins the old
      // file lacks (e.g. Chalk/Splatter) are appended.
      expect(loaded.first, userPreset);
      expect(loaded.where((p) => p.id == defaultBrushPresets.first.id), [
        defaultBrushPresets.first,
      ]);
      final loadedIds = loaded.map((p) => p.id).toSet();
      for (final builtin in defaultBrushPresets) {
        expect(loadedIds, contains(builtin.id));
      }
    });

    test(
      'current-version libraries do not resurrect deleted built-ins',
      () async {
        final path = pathIn('v_current.json');
        final service = BrushPresetFileService(filePath: path);
        // Save a library missing most built-ins at the CURRENT version: the
        // user deleted them, so loading must not bring them back.
        await service.save([defaultBrushPresets.last]);

        final loaded = await service.loadOrDefaults();

        expect(loaded, [defaultBrushPresets.last]);
      },
    );

    test(
      'duplicate preset ids in a saved library are healed on load',
      () async {
        // The pre-fix ABR importer could persist duplicate ids when several
        // brushes shared one tip; duplicate ids crash the preset chips.
        final path = pathIn('duplicates.json');
        final duplicated = BrushPreset(
          id: const BrushPresetId('abr-shared'),
          name: 'Variant A',
          settings: BrushSettings(size: 5),
        );
        await File(path).writeAsString(
          jsonEncode({
            'version': BrushPresetFileService.libraryVersion,
            'presets': [
              duplicated.toJson(),
              duplicated.copyWith(name: 'Variant B').toJson(),
              duplicated.copyWith(name: 'Variant C').toJson(),
            ],
          }),
        );
        final service = BrushPresetFileService(filePath: path);

        final loaded = await service.loadOrDefaults();

        expect(loaded.map((p) => p.id.value), [
          'abr-shared',
          'abr-shared-2',
          'abr-shared-3',
        ]);
        expect(loaded.map((p) => p.name), [
          'Variant A',
          'Variant B',
          'Variant C',
        ]);
      },
    );

    test('default path points into the per-user app-data directory', () {
      final path = BrushPresetFileService.defaultBrushPresetFilePath();
      expect(path, endsWith('quick_animaker_v2/brush_presets.json'));
    });
  });

  group('defaultBrushPresets', () {
    test('are non-empty with unique ids and names', () {
      expect(defaultBrushPresets, isNotEmpty);
      final ids = defaultBrushPresets.map((preset) => preset.id).toSet();
      final names = defaultBrushPresets.map((preset) => preset.name).toSet();
      expect(ids.length, defaultBrushPresets.length);
      expect(names.length, defaultBrushPresets.length);
    });

    test('every default round-trips through json', () {
      for (final preset in defaultBrushPresets) {
        expect(BrushPreset.fromJson(preset.toJson()), preset);
      }
    });

    test('include sampled-tip presets carrying their masks', () {
      final chalk = defaultBrushPresets.firstWhere(
        (preset) => preset.name == 'Chalk',
      );
      final splatter = defaultBrushPresets.firstWhere(
        (preset) => preset.name == 'Splatter',
      );
      expect(chalk.settings.tipMask, isNotNull);
      expect(chalk.settings.tipMask!.id, 'builtin-chalk');
      expect(splatter.settings.tipMask, isNotNull);
      expect(splatter.settings.tipMask!.id, 'builtin-splatter');
    });
  });
}

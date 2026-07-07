import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../../models/brush_preset.dart';
import '../../models/brush_preset_id.dart';
import '../../models/brush_settings.dart';
import '../../services/abr/abr_decoder.dart';
import '../../services/brush_preset_file_service.dart';
import '../../services/sut/sut_decoder.dart';

/// A picked brush file: display name plus raw bytes.
typedef BrushFilePick = ({String name, Uint8List bytes});

/// Opens a brush file picker; `null` when the user cancels.
typedef BrushFilePicker = Future<BrushFilePick?> Function();

/// Production picker: the platform open-file dialog filtered to the
/// supported brush formats.
Future<BrushFilePick?> _openBrushFileDialog() async {
  const typeGroup = XTypeGroup(
    label: 'Brushes (Photoshop, Clip Studio)',
    extensions: ['abr', 'sut', 'sutg'],
  );
  final file = await openFile(acceptedTypeGroups: const [typeGroup]);
  if (file == null) {
    return null;
  }
  final bytes = await File(file.path).readAsBytes();
  return (name: file.name, bytes: bytes);
}

/// The brush preset library: the preset list, the active (highlighted)
/// preset and every mutation on them — save/rename/reorder/delete plus
/// ABR/SUT file import — with fire-and-forget persistence to the app-level
/// preset file. Pure data controller; user messaging stays with the UI
/// (mutations that want a snackbar return the message text).
class BrushPresetLibrary extends ChangeNotifier {
  BrushPresetLibrary({
    BrushPresetFileService? fileService,
    BrushFilePicker? filePicker,
  }) : _fileService = fileService ?? BrushPresetFileService(),
       _filePicker = filePicker ?? _openBrushFileDialog;

  final BrushPresetFileService _fileService;
  final BrushFilePicker _filePicker;

  List<BrushPreset> _presets = const <BrushPreset>[];
  BrushPresetId? _activePresetId;
  bool _disposed = false;

  List<BrushPreset> get presets => _presets;

  /// The last-applied (or last-saved) preset, highlighted in the list.
  /// Tweaking settings keeps the highlight; deleting the preset clears it.
  BrushPresetId? get activePresetId => _activePresetId;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> load() async {
    final presets = await _fileService.loadOrDefaults();
    _presets = presets;
    _notify();
  }

  void markActive(BrushPresetId? id) {
    if (_activePresetId == id) {
      return;
    }
    _activePresetId = id;
    _notify();
  }

  /// Saves the given settings as a new preset and makes it active.
  void saveCurrent(BrushSettings settings) {
    final preset = BrushPreset(
      id: BrushPresetId('user-${DateTime.now().millisecondsSinceEpoch}'),
      name: _nextPresetName(),
      settings: settings,
    );
    _presets = [..._presets, preset];
    _activePresetId = preset.id;
    _notify();
    _persist();
  }

  void rename(BrushPresetId id, String name) {
    _presets = [
      for (final preset in _presets)
        preset.id == id ? preset.copyWith(name: name) : preset,
    ];
    _notify();
    _persist();
  }

  void reorder(List<BrushPreset> presets) {
    _presets = List.of(presets);
    _notify();
    _persist();
  }

  void delete(BrushPresetId id) {
    _presets = [
      for (final preset in _presets)
        if (preset.id != id) preset,
    ];
    if (_activePresetId == id) {
      _activePresetId = null;
    }
    _notify();
    _persist();
  }

  /// Runs the pick→decode→merge import flow. Returns the user-facing result
  /// message, or `null` when the picker was cancelled.
  Future<String?> importFromFile() async {
    final BrushFilePick? pick;
    try {
      pick = await _filePicker();
    } catch (error) {
      return 'Could not open the file: $error';
    }
    if (pick == null || _disposed) {
      return null;
    }

    final lowerName = pick.name.toLowerCase();
    final baseName = pick.name.contains('.')
        ? pick.name.substring(0, pick.name.lastIndexOf('.'))
        : pick.name;
    final List<BrushPreset> imported;
    final List<String> warnings;
    try {
      if (lowerName.endsWith('.sut') || lowerName.endsWith('.sutg')) {
        final result = await _decodeSutBytes(pick.bytes, sourceName: baseName);
        imported = result.presets;
        warnings = result.warnings;
      } else {
        final result = decodeAbrBrushFile(pick.bytes, sourceName: baseName);
        imported = result.presets;
        warnings = result.warnings;
      }
    } on AbrDecodeException catch (error) {
      return error.message;
    } on SutDecodeException catch (error) {
      return error.message;
    } on Exception {
      return 'This file could not be read as a brush file.';
    }
    if (_disposed) {
      return null;
    }
    // Imported brushes group under their source file, mirroring Clip
    // Studio's sub-tool groups (re-importing keeps them together).
    final grouped = [
      for (final preset in imported) preset.copyWith(group: baseName),
    ];
    // Re-importing replaces presets with the same id (same brush/tip).
    final importedIds = {for (final preset in grouped) preset.id};
    _presets = [
      for (final preset in _presets)
        if (!importedIds.contains(preset.id)) preset,
      ...grouped,
    ];
    _notify();
    _persist();
    final summary = imported.length == 1
        ? 'Imported 1 brush from "${pick.name}".'
        : 'Imported ${imported.length} brushes from "${pick.name}".';
    return warnings.isEmpty
        ? summary
        : '$summary (${warnings.length} entries with warnings)';
  }

  /// The SQLite reader needs a file path; work on a scratch copy so the
  /// user's original brush file is never opened for writing or locked.
  Future<SutImportResult> _decodeSutBytes(
    Uint8List bytes, {
    required String sourceName,
  }) async {
    final directory = await Directory.systemTemp.createTemp('sut_import');
    try {
      final file = File('${directory.path}/import.sut');
      await file.writeAsBytes(bytes, flush: true);
      return await decodeSutBrushFile(
        filePath: file.path,
        sourceName: sourceName,
      );
    } finally {
      unawaited(
        directory.delete(recursive: true).catchError((Object _) => directory),
      );
    }
  }

  String _nextPresetName() {
    final names = {for (final preset in _presets) preset.name};
    var index = _presets.length + 1;
    while (names.contains('Preset $index')) {
      index += 1;
    }
    return 'Preset $index';
  }

  void _persist() {
    // Fire-and-forget: preset persistence must never block or crash the
    // editor; a failed write just leaves the in-memory library unsaved.
    unawaited(_fileService.save(_presets).catchError((Object _) {}));
  }
}

import '../../models/attached_layer_resolve.dart';
import '../../models/cut.dart';
import '../../models/export_overrides.dart';
import '../../models/export_spec.dart';
import '../../models/layer.dart';
import '../../models/layer_kind.dart';

/// The Cels tab's resolved layer set for one cut: AUTO RULES first, the
/// cut's manual DELTA last (v10 ⑥ "규칙 적용 후 델타만") — so switching
/// presets re-evaluates the rules while the hand exceptions survive, and
/// Reset just drops the delta.
class ExportCelsSelection {
  const ExportCelsSelection({
    required this.celLayers,
    required this.instructionLayers,
  });

  /// Drawing layers whose authored cels export, in cut stack order.
  final List<Layer> celLayers;

  /// Instruction layers (지시 레이어 — PAN etc.) exporting as image cels,
  /// in cut stack order.
  final List<Layer> instructionLayers;

  bool includes(Layer layer) =>
      celLayers.any((candidate) => candidate.id == layer.id) ||
      instructionLayers.any((candidate) => candidate.id == layer.id);
}

/// Resolves which of [cut]'s layers the Cels export covers under [spec]'s
/// rules and the cut's manual [delta].
///
/// Rule order:
/// 1. Kind gate — camera never; SE never (SE cels are timing data, not
///    pictures); instruction rows iff [CelsExportSpec.includeInstructionLayers].
/// 2. Drawing rows: visible, `onTimesheet` when [CelsExportSpec.onTimesheetOnly],
///    and the attach gates (synced/free) for attach rows.
/// 3. Folder expansion — [CelsExportSpec.includeFolderMembers] pulls every
///    same-folder drawing row a selected row shares a folder with.
/// 4. [delta] wins last, per layer id — a forced include overrides even
///    visibility (hidden ≠ empty; the user asked for that cel).
ExportCelsSelection resolveExportCelsSelection({
  required Cut cut,
  required CelsExportSpec spec,
  ExportCelsCutDelta? delta,
}) {
  final included = <int, bool>{};
  final layers = cut.layers;

  bool baseRule(Layer layer) {
    switch (layer.kind) {
      case LayerKind.camera:
      case LayerKind.se:
        return false;
      case LayerKind.instruction:
        if (!spec.includeInstructionLayers) {
          return false;
        }
        return !spec.onTimesheetOnly || layer.onTimesheet;
      case LayerKind.animation:
      case LayerKind.storyboard:
      case LayerKind.art:
        if (!layer.isVisible) {
          return false;
        }
        if (spec.onTimesheetOnly && !layer.onTimesheet) {
          return false;
        }
        if (isAttachedLayer(layer)) {
          return isSyncedAttachedLayer(layer)
              ? spec.includeSyncedAttach
              : spec.includeFreeAttach;
        }
        return true;
    }
  }

  for (var i = 0; i < layers.length; i += 1) {
    included[i] = baseRule(layers[i]);
  }

  if (spec.includeFolderMembers) {
    final includedFolders = {
      for (var i = 0; i < layers.length; i += 1)
        if (included[i]! && layers[i].folderId != null) layers[i].folderId!,
    };
    for (var i = 0; i < layers.length; i += 1) {
      final layer = layers[i];
      if (included[i]! ||
          layer.folderId == null ||
          !includedFolders.contains(layer.folderId)) {
        continue;
      }
      if (layerKindHoldsDrawings(layer.kind) &&
          layer.kind != LayerKind.se &&
          layer.isVisible) {
        included[i] = true;
      }
    }
  }

  final overrides = delta?.layerOverrides ?? const {};
  for (var i = 0; i < layers.length; i += 1) {
    final forced = overrides[layers[i].id];
    if (forced != null) {
      // The kind gates stay hard: camera/SE rows never export as cels.
      final kind = layers[i].kind;
      if (kind == LayerKind.camera || kind == LayerKind.se) {
        continue;
      }
      included[i] = forced;
    }
  }

  final celLayers = <Layer>[];
  final instructionLayers = <Layer>[];
  for (var i = 0; i < layers.length; i += 1) {
    if (!included[i]!) {
      continue;
    }
    final layer = layers[i];
    if (layer.kind == LayerKind.instruction) {
      instructionLayers.add(layer);
    } else {
      celLayers.add(layer);
    }
  }
  return ExportCelsSelection(
    celLayers: celLayers,
    instructionLayers: instructionLayers,
  );
}

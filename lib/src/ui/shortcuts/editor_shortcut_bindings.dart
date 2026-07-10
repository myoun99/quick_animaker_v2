import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'editor_action_registry.dart';
import 'shortcut_activator_codec.dart';
import 'shortcut_settings_store.dart';

/// The LIVE shortcut bindings: registry defaults merged with the user's
/// persisted overrides. Notifies on every change so the app-level
/// Shortcuts map, the menu labels and the settings dialog all rebuild
/// from one source.
class EditorShortcutBindings extends ChangeNotifier {
  EditorShortcutBindings({
    this.store,
    List<EditorActionDefinition>? definitions,
  }) : definitions = definitions ?? editorActionDefinitions;

  /// Null disables persistence (tests, and FLUTTER_TEST runs).
  final ShortcutSettingsStore? store;

  final List<EditorActionDefinition> definitions;

  final Map<String, List<SingleActivator>> _overrides = {};

  EditorActionDefinition? definitionFor(String actionId) {
    for (final definition in definitions) {
      if (definition.id == actionId) {
        return definition;
      }
    }
    return null;
  }

  /// The action's LIVE activators (override or defaults). An override may
  /// be an empty list = the action is deliberately unbound.
  List<SingleActivator> activatorsFor(String actionId) {
    return _overrides[actionId] ??
        definitionFor(actionId)?.defaultActivators ??
        const [];
  }

  /// The first live activator — what menu items show as their shortcut
  /// label; null while unbound.
  SingleActivator? primaryActivatorFor(String actionId) {
    final activators = activatorsFor(actionId);
    return activators.isEmpty ? null : activators.first;
  }

  bool isOverridden(String actionId) => _overrides.containsKey(actionId);

  /// The app-level Shortcuts map: every live activator → the action's
  /// intent. On a conflict (one activator bound to several actions) the
  /// LAST registry entry wins here; [conflictedActionIds] surfaces the
  /// clash to the settings dialog.
  Map<ShortcutActivator, Intent> get shortcuts {
    final map = <ShortcutActivator, Intent>{};
    for (final definition in definitions) {
      for (final activator in activatorsFor(definition.id)) {
        map[activator] = EditorActionIntent(definition.id);
      }
    }
    return map;
  }

  /// Action ids whose activators collide with another action's (the
  /// settings dialog highlights them).
  Set<String> get conflictedActionIds {
    final byActivator = <String, List<String>>{};
    for (final definition in definitions) {
      for (final activator in activatorsFor(definition.id)) {
        byActivator
            .putIfAbsent(activatorKey(activator), () => [])
            .add(definition.id);
      }
    }
    return {
      for (final ids in byActivator.values)
        if (ids.length > 1) ...ids,
    };
  }

  /// Replaces [actionId]'s activators; a value equal to the defaults
  /// clears the override. Persists and notifies.
  void setActivators(String actionId, List<SingleActivator> activators) {
    final defaults = definitionFor(actionId)?.defaultActivators ?? const [];
    final matchesDefaults =
        activators.length == defaults.length &&
        [
          for (var i = 0; i < activators.length; i += 1)
            activatorsEqual(activators[i], defaults[i]),
        ].every((equal) => equal);
    if (matchesDefaults) {
      _overrides.remove(actionId);
    } else {
      _overrides[actionId] = List.unmodifiable(activators);
    }
    _persist();
    notifyListeners();
  }

  void resetAction(String actionId) {
    if (_overrides.remove(actionId) != null) {
      _persist();
      notifyListeners();
    }
  }

  void resetAll() {
    if (_overrides.isEmpty) {
      return;
    }
    _overrides.clear();
    _persist();
    notifyListeners();
  }

  /// Loads persisted overrides (unknown action ids and malformed entries
  /// are dropped — an app update or corrupt file never breaks bindings).
  Future<void> restore() async {
    final payload = await store?.load();
    final overridesJson = payload?['overrides'];
    if (overridesJson is! Map) {
      return;
    }
    _overrides.clear();
    for (final entry in overridesJson.entries) {
      final actionId = entry.key;
      if (actionId is! String || definitionFor(actionId) == null) {
        continue;
      }
      final listJson = entry.value;
      if (listJson is! List) {
        continue;
      }
      _overrides[actionId] = List.unmodifiable([
        for (final activatorJson in listJson)
          ?singleActivatorFromJson(activatorJson),
      ]);
    }
    notifyListeners();
  }

  void _persist() {
    final store = this.store;
    if (store == null) {
      return;
    }
    unawaited(
      store.save({
        'overrides': {
          for (final entry in _overrides.entries)
            entry.key: [
              for (final activator in entry.value)
                singleActivatorToJson(activator),
            ],
        },
      }),
    );
  }
}

/// The app-level ShortcutManager: bare-key shortcuts (no Ctrl/Meta) stand
/// down while a text field has focus, so typing 'b' into a rename dialog
/// never switches tools. Modifier shortcuts still resolve — but any the
/// field itself handles (Ctrl+Z text undo) are consumed below us first.
class EditorShortcutManager extends ShortcutManager {
  EditorShortcutManager({super.shortcuts});

  @override
  KeyEventResult handleKeypress(BuildContext context, KeyEvent event) {
    if (_editableTextHasFocus &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    return super.handleKeypress(context, event);
  }

  bool get _editableTextHasFocus {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      return false;
    }
    return focusContext.widget is EditableText;
  }
}

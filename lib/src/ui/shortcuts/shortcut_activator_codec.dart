import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// (De)serialization + display labels for [SingleActivator] — the shape
/// the shortcut override store persists ({key: logical key id, ctrl/shift/
/// alt/meta flags, false omitted}).
Map<String, Object?> singleActivatorToJson(SingleActivator activator) => {
  'key': activator.trigger.keyId,
  if (activator.control) 'ctrl': true,
  if (activator.shift) 'shift': true,
  if (activator.alt) 'alt': true,
  if (activator.meta) 'meta': true,
};

/// Null on malformed/unknown entries (a corrupt override entry must not
/// fail the editor — the action keeps its remaining activators).
SingleActivator? singleActivatorFromJson(Object? json) {
  if (json is! Map) {
    return null;
  }
  final keyId = json['key'];
  if (keyId is! int) {
    return null;
  }
  final trigger =
      LogicalKeyboardKey.findKeyByKeyId(keyId) ?? LogicalKeyboardKey(keyId);
  return SingleActivator(
    trigger,
    control: json['ctrl'] == true,
    shift: json['shift'] == true,
    alt: json['alt'] == true,
    meta: json['meta'] == true,
  );
}

/// 'Ctrl+Shift+Z' style display label (dialog chips + menu shortcut
/// labels resolve special keys to readable glyphs).
String singleActivatorLabel(SingleActivator activator) {
  final parts = <String>[
    if (activator.control) 'Ctrl',
    if (activator.alt) 'Alt',
    if (activator.shift) 'Shift',
    if (activator.meta) 'Meta',
    _triggerLabel(activator.trigger),
  ];
  return parts.join('+');
}

String _triggerLabel(LogicalKeyboardKey trigger) {
  if (trigger == LogicalKeyboardKey.space) {
    return 'Space';
  }
  if (trigger == LogicalKeyboardKey.arrowLeft) {
    return '←';
  }
  if (trigger == LogicalKeyboardKey.arrowRight) {
    return '→';
  }
  if (trigger == LogicalKeyboardKey.arrowUp) {
    return '↑';
  }
  if (trigger == LogicalKeyboardKey.arrowDown) {
    return '↓';
  }
  if (trigger == LogicalKeyboardKey.comma) {
    return ',';
  }
  if (trigger == LogicalKeyboardKey.period) {
    return '.';
  }
  final label = trigger.keyLabel;
  return label.isEmpty ? trigger.debugName ?? '?' : label.toUpperCase();
}

/// Value equality for activators (SingleActivator has none of its own):
/// the settings dialog and the merge logic compare trigger + modifiers.
bool activatorsEqual(SingleActivator a, SingleActivator b) =>
    a.trigger == b.trigger &&
    a.control == b.control &&
    a.shift == b.shift &&
    a.alt == b.alt &&
    a.meta == b.meta;

/// A map key with value equality for conflict detection.
String activatorKey(SingleActivator a) =>
    '${a.trigger.keyId}:${a.control}:${a.shift}:${a.alt}:${a.meta}';

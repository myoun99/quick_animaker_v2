import 'package:flutter/widgets.dart';

/// An [IndexedStack] whose children build LAZILY and rebuild only when
/// their own state slice changes (R18 UI-4).
///
/// The tool panels' per-switch rebuild was measurably the bulk of the
/// tool-switch jank (frozen-panel experiment: 16–27 → 8–10 janks): every
/// brush⟷eraser switch rebuilt the whole settings/library subtree from
/// scratch. Here each key's subtree is built once, kept alive offstage,
/// and a switch back to it is a pure index flip — it rebuilds only when
/// [stateOf] no longer equals the state it was built with.
///
/// SAFETY BY CONSTRUCTION: a cached child is reused only when its
/// captured state compares EQUAL (by value) to the current one, so
/// closures inside it can never act on semantically stale data. Slices
/// must implement value `==` (records and value classes do).
class KeyedKeepAliveStack<K, S> extends StatefulWidget {
  const KeyedKeepAliveStack({
    super.key,
    required this.keys,
    required this.activeKey,
    required this.stateOf,
    required this.builder,
  });

  /// Stable child order; must contain [activeKey]. Never-visited keys
  /// hold an empty placeholder.
  final List<K> keys;

  final K activeKey;

  /// The CURRENT state slice the active child's content depends on.
  final S Function() stateOf;

  /// Builds the active key's subtree with the current state (the caller
  /// closes over it).
  final Widget Function(BuildContext context) builder;

  @override
  State<KeyedKeepAliveStack<K, S>> createState() =>
      _KeyedKeepAliveStackState<K, S>();
}

class _KeyedKeepAliveStackState<K, S> extends State<KeyedKeepAliveStack<K, S>> {
  final Map<K, Widget> _children = {};
  final Map<K, S> _states = {};

  @override
  Widget build(BuildContext context) {
    final key = widget.activeKey;
    final state = widget.stateOf();
    final cached = _children[key];
    if (cached == null || _states[key] != state) {
      _children[key] = KeyedSubtree(
        key: ValueKey<K>(key),
        child: widget.builder(context),
      );
      _states[key] = state;
    }
    return IndexedStack(
      index: widget.keys.indexOf(key),
      children: [
        for (final k in widget.keys)
          _children[k] ?? SizedBox.shrink(key: ValueKey<K>(k)),
      ],
    );
  }
}

import 'dart:ui' as ui;

import '../core/image_utils.dart';

/// A single reversible change to the document.
sealed class HistoryEntry {
  const HistoryEntry({required this.label});

  /// Short description of the change, used by the Undo/Redo menu items.
  final String label;

  int get memoryBytes;

  void dispose();
}

/// Replaces the pixels inside [rect] of one layer.
///
/// Every drawing tool produces one of these. Only the touched rectangle is
/// stored, because keeping whole-canvas snapshots would blow the memory budget
/// after a handful of brush strokes on a large image.
final class RegionEdit extends HistoryEntry {
  const RegionEdit({
    required super.label,
    required this.layerIndex,
    required this.rect,
    required this.before,
    required this.after,
  });

  final int layerIndex;
  final ui.Rect rect;
  final ui.Image before;
  final ui.Image after;

  @override
  int get memoryBytes =>
      ImageUtils.memoryBytes(before) + ImageUtils.memoryBytes(after);

  @override
  void dispose() {
    before.dispose();
    after.dispose();
  }
}

/// Replaces a layer's bitmap wholesale, possibly changing its size.
///
/// Used by resize, rotate, crop, skew and colour adjustments — operations where
/// there is no small dirty rectangle to exploit.
final class CanvasEdit extends HistoryEntry {
  const CanvasEdit({
    required super.label,
    required this.layerIndex,
    required this.before,
    required this.after,
  });

  final int layerIndex;
  final ui.Image before;
  final ui.Image after;

  @override
  int get memoryBytes =>
      ImageUtils.memoryBytes(before) + ImageUtils.memoryBytes(after);

  @override
  void dispose() {
    before.dispose();
    after.dispose();
  }
}

/// Bounded undo/redo stack.
///
/// Depth is governed by a memory budget rather than a step count, so small
/// edits on a small image give a very deep history while whole-canvas edits on
/// a huge image give a shallow one — which is the behaviour users actually
/// want, and keeps the process from being killed by the OOM reaper.
class History {
  History({required this.budgetBytes});

  /// Ceiling for the combined size of both stacks.
  int budgetBytes;

  final List<HistoryEntry> _undo = <HistoryEntry>[];
  final List<HistoryEntry> _redo = <HistoryEntry>[];

  int _bytes = 0;

  bool get canUndo => _undo.isNotEmpty;

  bool get canRedo => _redo.isNotEmpty;

  int get usedBytes => _bytes;

  int get undoDepth => _undo.length;

  int get redoDepth => _redo.length;

  /// Label of the change that [takeUndo] would reverse, for the menu item.
  String? get undoLabel => _undo.isEmpty ? null : _undo.last.label;

  String? get redoLabel => _redo.isEmpty ? null : _redo.last.label;

  /// Records a change the caller has already applied to the document.
  ///
  /// Doing so invalidates the redo stack, exactly as in any editor: once you
  /// draw after undoing, the branch you undid is gone.
  void push(HistoryEntry entry) {
    _disposeAll(_redo);
    _undo.add(entry);
    _bytes += entry.memoryBytes;
    _evictToBudget();
  }

  /// Moves the newest change onto the redo stack and returns it, so the caller
  /// can restore its `before` pixels.
  HistoryEntry? takeUndo() {
    if (_undo.isEmpty) return null;
    final entry = _undo.removeLast();
    _redo.add(entry);
    return entry;
  }

  /// Moves the newest undone change back and returns it, so the caller can
  /// reapply its `after` pixels.
  HistoryEntry? takeRedo() {
    if (_redo.isEmpty) return null;
    final entry = _redo.removeLast();
    _undo.add(entry);
    return entry;
  }

  void clear() {
    _disposeAll(_undo);
    _disposeAll(_redo);
    _bytes = 0;
  }

  /// Drops the oldest undo entries until the stacks fit the budget.
  ///
  /// The newest entry is never evicted: a single edit larger than the whole
  /// budget still has to be undoable once, or the user would be stuck with a
  /// change they cannot reverse.
  void _evictToBudget() {
    while (_bytes > budgetBytes && _undo.length > 1) {
      final evicted = _undo.removeAt(0);
      _bytes -= evicted.memoryBytes;
      evicted.dispose();
    }
  }

  void _disposeAll(List<HistoryEntry> stack) {
    for (final entry in stack) {
      _bytes -= entry.memoryBytes;
      entry.dispose();
    }
    stack.clear();
  }
}

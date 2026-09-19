import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:paint/controller/history.dart';
import 'package:paint/core/image_utils.dart';

/// A 1x1 image, the cheapest thing the history can hold.
Future<ui.Image> _pixel() =>
    ImageUtils.filled(1, 1, const ui.Color(0xFF000000));

Future<RegionEdit> _edit({String label = 'test'}) async {
  return RegionEdit(
    label: label,
    layerIndex: 0,
    rect: const ui.Rect.fromLTWH(0, 0, 1, 1),
    before: await _pixel(),
    after: await _pixel(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('History', () {
    test('starts empty', () {
      final history = History(budgetBytes: 1024);

      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
      expect(history.undoLabel, isNull);
    });

    test('push then undo moves the entry onto the redo stack', () async {
      final history = History(budgetBytes: 1024)..push(await _edit());

      expect(history.canUndo, isTrue);
      expect(history.canRedo, isFalse);

      final undone = history.takeUndo();

      expect(undone, isNotNull);
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isTrue);
    });

    test('redo moves the entry back', () async {
      final history = History(budgetBytes: 1024)..push(await _edit());
      history.takeUndo();

      expect(history.takeRedo(), isNotNull);
      expect(history.canUndo, isTrue);
      expect(history.canRedo, isFalse);
    });

    test('a new edit discards the redo branch', () async {
      final history = History(budgetBytes: 1024)
        ..push(await _edit(label: 'first'));
      history.takeUndo();
      expect(history.canRedo, isTrue);

      history.push(await _edit(label: 'second'));

      expect(history.canRedo, isFalse, reason: 'branch dropped');
      expect(history.undoLabel, 'second');
    });

    test('evicts the oldest entries once over budget', () async {
      // Each 1x1 RegionEdit holds two images: 2 * 1 * 1 * 4 = 8 bytes.
      final history = History(budgetBytes: 24);
      for (var i = 0; i < 6; i++) {
        history.push(await _edit(label: 'edit$i'));
      }

      expect(history.usedBytes, lessThanOrEqualTo(24));
      expect(history.undoDepth, lessThan(6));
      expect(
        history.undoLabel,
        'edit5',
        reason: 'the newest edit always survives',
      );
    });

    test('never evicts the only entry, however large', () async {
      final history = History(budgetBytes: 1)..push(await _edit());

      expect(history.canUndo, isTrue, reason: 'a single edit stays undoable');
    });

    test('clear empties both stacks', () async {
      final history = History(budgetBytes: 1024)..push(await _edit());
      history.takeUndo();
      history.push(await _edit());

      history.clear();

      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
      expect(history.usedBytes, 0);
    });

    test('reports memory for the images it holds', () async {
      final entry = RegionEdit(
        label: 'big',
        layerIndex: 0,
        rect: const ui.Rect.fromLTWH(0, 0, 10, 10),
        before: await ImageUtils.filled(10, 10, const ui.Color(0xFF000000)),
        after: await ImageUtils.filled(10, 10, const ui.Color(0xFF000000)),
      );

      // 10 * 10 * 4 bytes per image, two images.
      expect(entry.memoryBytes, 800);
    });
  });
}

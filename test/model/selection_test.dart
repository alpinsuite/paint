import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:paint/model/selection.dart';

void main() {
  group('Selection', () {
    test('a fresh rectangle selection is anchored and untransformed', () {
      final selection = Selection.rectangle(
        const ui.Rect.fromLTWH(10, 10, 40, 20),
      );

      expect(selection.isFloating, isFalse);
      expect(selection.isTransformed, isFalse);
      expect(selection.currentBounds, selection.originalBounds);
    });

    test('contains follows the shape, not the bounding box', () {
      // A triangle: its bounding box corner is outside the shape itself.
      final path = ui.Path()
        ..moveTo(0, 0)
        ..lineTo(100, 0)
        ..lineTo(0, 100)
        ..close();
      final selection = Selection(
        path: path,
        originalBounds: path.getBounds(),
        currentBounds: path.getBounds(),
      );

      expect(selection.contains(const ui.Offset(10, 10)), isTrue);
      expect(
        selection.contains(const ui.Offset(90, 90)),
        isFalse,
        reason: 'inside the bounding box but outside the triangle',
      );
    });

    test('movedBy shifts the current bounds only', () {
      final selection = Selection.rectangle(
        const ui.Rect.fromLTWH(0, 0, 10, 10),
      ).movedBy(const ui.Offset(5, -3));

      expect(selection.currentBounds, const ui.Rect.fromLTWH(5, -3, 10, 10));
      expect(selection.originalBounds, const ui.Rect.fromLTWH(0, 0, 10, 10));
      expect(selection.isTransformed, isTrue);
    });

    test('contains tracks the selection after a move', () {
      final selection = Selection.rectangle(
        const ui.Rect.fromLTWH(0, 0, 10, 10),
      ).movedBy(const ui.Offset(100, 0));

      expect(selection.contains(const ui.Offset(5, 5)), isFalse);
      expect(selection.contains(const ui.Offset(105, 5)), isTrue);
    });

    group('resized', () {
      test('a corner handle moves both of its edges', () {
        final selection = Selection.rectangle(
          const ui.Rect.fromLTWH(0, 0, 10, 10),
        ).resized(SelectionHandle.bottomRight, const ui.Offset(5, 5));

        expect(selection.currentBounds, const ui.Rect.fromLTRB(0, 0, 15, 15));
      });

      test('an edge handle moves only its own edge', () {
        final selection = Selection.rectangle(
          const ui.Rect.fromLTWH(0, 0, 10, 10),
        ).resized(SelectionHandle.centerLeft, const ui.Offset(4, 99));

        expect(selection.currentBounds, const ui.Rect.fromLTRB(4, 0, 10, 10));
      });

      test('edges are not allowed to cross', () {
        final selection = Selection.rectangle(
          const ui.Rect.fromLTWH(0, 0, 10, 10),
        ).resized(SelectionHandle.centerLeft, const ui.Offset(500, 0));

        expect(selection.currentBounds.width, greaterThan(0));
        expect(
          selection.currentBounds.left,
          lessThan(selection.currentBounds.right),
        );
      });
    });

    group('handleAt', () {
      final selection = Selection.rectangle(
        const ui.Rect.fromLTWH(0, 0, 100, 50),
      );

      test('finds a corner within tolerance', () {
        expect(
          selection.handleAt(const ui.Offset(2, 2), 5),
          SelectionHandle.topLeft,
        );
        expect(
          selection.handleAt(const ui.Offset(100, 50), 5),
          SelectionHandle.bottomRight,
        );
      });

      test('finds an edge midpoint', () {
        expect(
          selection.handleAt(const ui.Offset(50, 0), 5),
          SelectionHandle.topCenter,
        );
      });

      test('returns null well away from any handle', () {
        expect(selection.handleAt(const ui.Offset(50, 25), 5), isNull);
      });
    });

    test('transformedPath scales with the bounds', () {
      final selection = Selection.rectangle(
        const ui.Rect.fromLTWH(0, 0, 10, 10),
      ).resized(SelectionHandle.bottomRight, const ui.Offset(10, 10));

      expect(
        selection.transformedPath.getBounds(),
        const ui.Rect.fromLTRB(0, 0, 20, 20),
      );
    });

    test('a zero-size selection reports itself empty', () {
      final selection = Selection.rectangle(const ui.Rect.fromLTWH(5, 5, 0, 0));

      expect(selection.isEmpty, isTrue);
    });
  });
}

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:paint/controller/viewport_controller.dart';

/// A controller with a settled viewport and image size.
///
/// [updateGeometry] fits the image the first time it sees one, so tests that
/// care about a specific zoom set it explicitly afterwards.
ViewportController controllerWith({
  ui.Size viewport = const ui.Size(1000, 800),
  ui.Size image = const ui.Size(400, 300),
}) {
  return ViewportController()..updateGeometry(viewport: viewport, image: image);
}

void main() {
  group('ViewportController', () {
    test('fits the image the first time it is given one', () {
      final controller = controllerWith(
        viewport: const ui.Size(1000, 800),
        image: const ui.Size(4000, 3000),
      );

      // 4000 wide into 1000 minus padding.
      expect(controller.zoom, lessThan(1));
      expect(controller.zoom, greaterThan(0));
    });

    test('fitting never enlarges past actual size', () {
      final controller = controllerWith(
        viewport: const ui.Size(2000, 2000),
        image: const ui.Size(10, 10),
      );

      expect(
        controller.zoom,
        1.0,
        reason: 'a tiny image should not be blown up to fill the window',
      );
    });

    group('zoomTo', () {
      test('clamps to the supported range', () {
        final controller = controllerWith()..zoomTo(9999);
        expect(controller.zoom, ViewportController.maxZoom);

        controller.zoomTo(0.0000001);
        expect(controller.zoom, ViewportController.minZoom);
      });

      test('keeps the image point under the focal point fixed', () {
        final controller = controllerWith()..zoomTo(1);
        const focus = ui.Offset(620, 410);
        final before = controller.toImage(focus);

        controller.zoomTo(8, focalPoint: focus);

        final after = controller.toImage(focus);
        expect(after.dx, closeTo(before.dx, 0.001));
        expect(after.dy, closeTo(before.dy, 0.001));
      });

      test('a no-op zoom does not move the view', () {
        final controller = controllerWith()..zoomTo(2);
        final origin = controller.origin;

        controller.zoomTo(2);

        expect(controller.origin, origin);
      });
    });

    group('zoomIn and zoomOut', () {
      test('walk through the preset steps', () {
        final controller = controllerWith()..zoomTo(1);

        controller.zoomIn();
        expect(controller.zoom, 2);

        controller.zoomOut();
        expect(controller.zoom, 1);
      });

      test('stop at the ends of the range', () {
        final controller = controllerWith()..zoomTo(ViewportController.maxZoom);
        controller.zoomIn();
        expect(controller.zoom, ViewportController.maxZoom);

        controller.zoomTo(ViewportController.minZoom);
        controller.zoomOut();
        expect(controller.zoom, ViewportController.minZoom);
      });

      test('leave an off-step zoom on a step', () {
        final controller = controllerWith()..zoomTo(1.37);

        controller.zoomIn();

        expect(ViewportController.zoomSteps, contains(controller.zoom));
      });
    });

    group('coordinates', () {
      test('screen and image round-trip', () {
        final controller = controllerWith()..zoomTo(3.5);
        const point = ui.Offset(123.5, 45.25);

        final roundTripped = controller.toImage(controller.toScreen(point));

        expect(roundTripped.dx, closeTo(point.dx, 0.0001));
        expect(roundTripped.dy, closeTo(point.dy, 0.0001));
      });

      test('the image screen rectangle scales with the zoom', () {
        final controller = controllerWith(image: const ui.Size(400, 300))
          ..zoomTo(2);

        expect(controller.imageScreenRect.width, 800);
        expect(controller.imageScreenRect.height, 600);
      });
    });

    group('panning', () {
      test('is ignored while the image fits, so it stays centred', () {
        final controller = controllerWith(
          viewport: const ui.Size(1000, 800),
          image: const ui.Size(100, 100),
        )..zoomTo(1);
        final centred = controller.origin;

        controller.panBy(const ui.Offset(300, 200));

        expect(
          controller.origin,
          centred,
          reason: 'an image smaller than the viewport is always centred',
        );
      });

      test('moves the view once the image is larger than the viewport', () {
        final controller = controllerWith()..zoomTo(10);
        final before = controller.origin;

        controller.panBy(const ui.Offset(-50, -40));

        expect(controller.origin, isNot(before));
      });

      test('never pushes the image entirely off screen', () {
        final controller = controllerWith(
          viewport: const ui.Size(1000, 800),
          image: const ui.Size(400, 300),
        )..zoomTo(10);

        controller.panBy(const ui.Offset(-100000, -100000));

        final rect = controller.imageScreenRect;
        expect(
          rect.right,
          greaterThan(0),
          reason: 'some of the image must remain on screen',
        );
        expect(rect.bottom, greaterThan(0));

        controller.panBy(const ui.Offset(100000, 100000));

        final other = controller.imageScreenRect;
        expect(other.left, lessThan(1000));
        expect(other.top, lessThan(800));
      });
    });

    test('a new image of a different size is re-fitted', () {
      final controller = controllerWith(image: const ui.Size(100, 100))
        ..zoomTo(6);

      controller.updateGeometry(
        viewport: const ui.Size(1000, 800),
        image: const ui.Size(8000, 6000),
      );

      expect(
        controller.zoom,
        lessThan(1),
        reason: 'opening a large image should fit it rather than keep 600%',
      );
    });

    test('notifies listeners when the zoom changes', () {
      final controller = controllerWith();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.zoomTo(4);

      expect(notifications, greaterThan(0));
    });
  });
}

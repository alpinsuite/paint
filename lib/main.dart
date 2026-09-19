// Paint — a simple, easy-to-use image editor for Linux.
// Copyright (C) 2026 rbuache
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
// more details.
//
// You should have received a copy of the GNU General Public License along
// with this program. If not, see <https://www.gnu.org/licenses/>.
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'controller/canvas_controller.dart';
import 'controller/document_controller.dart';
import 'controller/selection_controller.dart';
import 'controller/update_controller.dart';
import 'controller/viewport_controller.dart';
import 'core/app_version.dart';
import 'core/settings/settings_controller.dart';
import 'io/file_service.dart';
import 'io/image_codecs.dart';
import 'model/tool_settings.dart';

/// Entry point. [args] carries a file path when the app is launched from a
/// file manager or with `paint image.png`.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  final settings = await SettingsController.load();
  final documents = DocumentController(undoBudgetMb: settings.undoBudgetMb);
  final toolSettings = ToolSettings();
  final viewport = ViewportController();
  final selections = SelectionController(documents: documents);
  final files = FileService(documents: documents, settings: settings);

  // Open the file named on the command line, or start on a blank canvas of the
  // size the user last chose.
  final requested = args.where(
    (arg) => !arg.startsWith('-') && ImageCodecs.formatForPath(arg) != null,
  );
  var opened = false;
  if (requested.isNotEmpty) {
    opened = await files.openPath(requested.first) is FileSucceeded;
  }
  if (!opened) {
    final size = settings.defaultImageSize;
    await documents.newDocument(
      width: size.width.round(),
      height: size.height.round(),
    );
  }

  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      size: Size(1280, 820),
      minimumSize: Size(720, 520),
      center: true,
      title: 'Paint',
      // The title bar is drawn by the application instead, so the menus,
      // the document name and the window buttons share one themed row.
      // See lib/ui/window_bar.dart.
      titleBarStyle: TitleBarStyle.hidden,
    ),
    () async {
      // Intercept the close button so unsaved changes can be rescued.
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    },
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider<DocumentController>.value(value: documents),
        ChangeNotifierProvider<ToolSettings>.value(value: toolSettings),
        ChangeNotifierProvider<ViewportController>.value(value: viewport),
        ChangeNotifierProvider<SelectionController>.value(value: selections),
        Provider<FileService>.value(value: files),
        ChangeNotifierProvider<CanvasController>(
          create: (_) => CanvasController(
            documents: documents,
            settings: toolSettings,
            viewport: viewport,
            selections: selections,
          ),
        ),
        ChangeNotifierProvider<UpdateController>(
          create: (_) =>
              UpdateController(settings: settings, currentVersion: appVersion),
        ),
      ],
      child: const PaintApp(),
    ),
  );
}

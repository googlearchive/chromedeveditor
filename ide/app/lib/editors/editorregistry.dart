// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to manage the list of open editors, and persist their state (like
 * their selection and scroll position) across sessions.
 */
library spark.editors.registry;

import 'dart:async';

import 'editor.dart';
import '../workspace.dart';

/// An registry the delegate editor provider request to registered
/// [EditorProvider]s base on file name.
class EditorRegistry extends EditorProvider {
  Map<RegExp, EditorProvider> registry = {};
  final EditorProvider defaultProvider;

  EditorRegistry(this.defaultProvider);

  void registerProvider(RegExp regexp, EditorProvider provider) {
    registry[regexp] = provider;
  }

  EditorProvider getProvider(String fileName) {
    for (var key in registry.keys) {
      if (key.hasMatch(fileName)) {
        return registry[key];
      }
    }
    return defaultProvider;
  }

/// Returns `true` if file is previously opened.
  bool isFileOpened(File file) =>
      getProvider(file.name).isFileOpened(file);

  /// Creates an editor session for the file. Returns `null` if fails.
  EditorSession getEditorSessionForFile(File file) =>
      getProvider(file.name).getEditorSessionForFile(file);

  /// Restore an editor session from map; Returns `null` if fails.
  EditorSession restorEditorSessionFromMap(Map map, Workspace ws) {
    if (!map.containsKey('file')) return null;
    File file = ws.restoreResource(map['file']);
    if (file == null) return null;
    return getProvider(file.name).restorEditorSessionFromMap(map, ws);
  }

  /// Inform the editor provider that a file is closed.
  Future close(EditorSession session) =>
      getProvider(session.file.name).close(session);
}

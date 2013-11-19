// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to manage the list of open editors, and persist their state (like
 * their selection and scroll position) across sessions.
 */
library spark.editors;

import 'dart:html' as html;

import 'workspace.dart';

/**
 * Classes implement this interface provides/refreshes editors for [Resource]s.
 * TODO(ikarienator): Abstract [AceEditor] so we can support more editor types.
 */
abstract class EditorProvider {
  Editor createEditorForFile(Resource file);
  void selectFileForEditor(Editor editor, Resource file);
  void close(Resource file);
}

abstract class Editor {
  /// The root element to put the editor in.
  html.Element get rootElement;

  /// Gets/sets the current session.
  EditorState state;

  /// Resize the editor.
  void resize();
}

abstract class EditorState {
  /// File combined with the editor.
  File get file;

  /// Deserialize the state of an editor.
  /// Returns `true` iff success.
  bool fromMap(Workspace workspace, Map map);

  /// Serializes the state of an editor.
  Map toMap();
}

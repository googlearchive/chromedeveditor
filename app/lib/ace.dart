// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ace;

import 'dart:html';
import 'dart:js' as js;

import 'package:ace/ace.dart' as ace;

import 'workspace.dart' as workspace;

class AceEditor {
  ace.Editor _aceEditor;
  workspace.File _file;

  static bool get available => js.context['ace'] != null;

  AceEditor() {
    _aceEditor = ace.edit(query('#editorArea'));
    _aceEditor.theme = new ace.Theme('ace/theme/ambiance');
  }

  String getPathInfo() {
    // TODO: show full path of file, not just name
    if (_file != null) return _file.name;
    return '[new file]';
  }

  void newFile() {
    _file = null;
    _setContents('', new ace.Mode('ace/mode/text'));
  }

  void save() {
    if (_file != null) {
      _file.setContents(_aceEditor.value);
      _aceEditor.focus();
    }
  }

  void saveAs(workspace.File file) {
    _file = file;
    save();
  }

  void setContent(workspace.File file) {
    _file = file;
    _file.getContents().then((String contents) {
      _setContents(contents, new ace.Mode.forFile(_file.name));
    });
  }

  void setTheme(String theme) {
    _aceEditor.theme = new ace.Theme(theme);
  }

  void _setContents(String string, ace.Mode mode) {
    _aceEditor.setValue(string, 0);
    _aceEditor.session.mode = mode;
    _aceEditor.navigateFileStart();
    _aceEditor.focus();
  }
}
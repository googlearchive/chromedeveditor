// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ace;

import 'dart:html';

import 'package:ace/ace.dart' as ace;
import 'package:chrome_gen/chrome_app.dart' as chrome_gen;

class AceEditor {
  ace.Editor _aceEditor;
  chrome_gen.ChromeFileEntry _file;

  AceEditor() {
    _aceEditor = ace.edit(querySelector('#editorArea'));
    _aceEditor.theme = new ace.Theme('ace/theme/ambiance');
  }

  String getPathInfo() {
    // TODO: show full path of file, not just name
    if (_file != null) return _file.fullPath;
    return '[new file]';
  }

  void newFile() {
    _file = null;
    _setContents('', new ace.Mode('ace/mode/text'));
  }

  void save() {
    if (_file != null){
      _file.writeText(_aceEditor.value);
      _aceEditor.focus();
    }
  }

  void saveAs(chrome_gen.ChromeFileEntry file) {
    _file = file;
    save();
  }

  void setContent(chrome_gen.ChromeFileEntry file) {
    _file = file;
    _file.readText().then((String contents) {
      _setContents(contents, new ace.Mode.forFile(file.name));
    });
  }

  void setTheme(String theme){
    _aceEditor.theme = new ace.Theme(theme);
  }

  void _setContents(String string, ace.Mode mode) {
    _aceEditor.setValue(string, 0);
    _aceEditor.session.mode = mode;
    _aceEditor.navigateFileStart();
    _aceEditor.focus();
  }
}
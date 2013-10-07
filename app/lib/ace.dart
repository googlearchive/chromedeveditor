// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ace;

import 'dart:html';

import 'package:ace/ace.dart' as ace;
import 'package:chrome/app.dart' as chrome;


class AceEditor {

  ace.Editor _aceEditor;

  AceEditor() {
    _aceEditor = ace.edit(query('#editorArea'));
  }

  void setContent(chrome.FileEntry file){
    file.readText().then((String contents) {
    _aceEditor.setValue(contents, 0);
    _aceEditor.session.mode = new ace.Mode.forFile(file.name);
    _aceEditor.navigateFileStart();
    _aceEditor.focus();
    });
  }

}
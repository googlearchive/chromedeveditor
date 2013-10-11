// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark;

import 'dart:async';
import 'dart:html';

import 'package:chrome/app.dart' as chrome;

import 'lib/ace.dart';
import 'lib/utils.dart';

void main() {
  Spark spark = new Spark();
}

class Spark {
  AceEditor editor;

  Spark() {
    document.title = appName;

    query("#newFile").onClick.listen(newFile);
    query("#openFile").onClick.listen(openFile);
    query("#saveFile").onClick.listen(saveFile);
    query("#saveAsFile").onClick.listen(saveAsFile);

    editor = new AceEditor();
    chrome.app.window.current.onClosed.listen(handleWindowClosed);
  }

  String get appName => i18n('app_name');

  void handleWindowClosed(data) {

  }

  void newFile(_) {
    editor.newFile();
    updatePath();
  }

  void openFile(_) {
    chrome.fileSystem.chooseEntry(type: 'openWritableFile').then((chrome.FileEntry file) {
      if (file != null) {
        file.readText().then((String contents) {
          editor.setContent(file);
          updatePath();
        });
      }
    });

  }

  void saveAsFile(_) {
    //TODO: don't show error message if operation cancelled
    chrome.fileSystem.chooseEntry(type: 'saveFile').then((chrome.FileEntry file) {
      editor.saveAs(file);
      updatePath();
    }).catchError((_) => updateError('Error on save as'));
  }

  void saveFile(_) {
    editor.save();
  }

  void updateError(String string) {
    query("#error").innerHtml = string;
  }

  void updatePath() {
    print(editor.getPathInfo());
    query("#path").innerHtml = editor.getPathInfo();
  }
}

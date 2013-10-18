// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark;

import 'dart:async';
import 'dart:html';

import 'package:chrome/app.dart' as chrome;

import 'lib/ace.dart';
import 'lib/utils.dart';
import 'lib/file_item_view.dart';
import 'lib/splitview.dart';

void main() {
  Spark spark = new Spark();
}

class Spark {
  AceEditor editor;
  SplitView _splitView;
  List _filesViews;

  Spark() {
    document.title = appName;

    query("#newFile").onClick.listen(newFile);
    query("#openFile").onClick.listen(openFile);
    query("#saveFile").onClick.listen(saveFile);
    query("#saveAsFile").onClick.listen(saveAsFile);
    //query("#editorTheme").onChange.listen(setTheme);

    editor = new AceEditor();
    editor.setTheme('ace/theme/textmate');
    chrome.app.window.current.onClosed.listen(handleWindowClosed);

    // Some dummy files are added in the left panel.
    _filesViews = new List();
    _filesViews.add(new FileItemView('background.js'));
    _filesViews.add(new FileItemView('index.html'));
    _filesViews.add(new FileItemView('index.js'));
    _filesViews.add(new FileItemView('manifest.json'));
    _filesViews.add(new FileItemView('longlonglong_filename.js'));

    _splitView = new SplitView(query('#splitview'));
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

  void setTheme(_){
    editor.setTheme((query("#editorTheme") as SelectElement).value);
  }

  void updateError(String string) {
    query("#error").innerHtml = string;
  }

  void updatePath() {
    print(editor.getPathInfo());
    query("#path").innerHtml = editor.getPathInfo();
  }
}

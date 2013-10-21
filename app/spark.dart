// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark;

import 'dart:async';
import 'dart:html';

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;

import 'lib/ace.dart';
import 'lib/utils.dart';
import 'lib/file_item_view.dart';
import 'lib/preferences.dart' as preferences;
import 'lib/splitview.dart';
import 'lib/workspace.dart';

void main() {
  Spark spark = new Spark();
}

class Spark {
  AceEditor editor;
  Workspace workspace;
  SplitView _splitView;
  List _filesViews;

  Spark() {
    document.title = appName;

    query("#newFile").onClick.listen(newFile);
    query("#openFile").onClick.listen(openFile);
    query("#saveFile").onClick.listen(saveFile);
    query("#saveAsFile").onClick.listen(saveAsFile);
    query("#editorTheme").onChange.listen(setTheme);

    workspace = new Workspace(preferences.PreferenceStore.createLocal());
    editor = new AceEditor();
    editor.setTheme('ace/theme/textmate');

    // Some dummy files are added in the left panel.
    _filesViews = new List();
    _filesViews.add(new FileItemView('background.js'));
    _filesViews.add(new FileItemView('index.html'));
    _filesViews.add(new FileItemView('index.js'));
    _filesViews.add(new FileItemView('manifest.json'));
    _filesViews.add(new FileItemView('longlonglong_filename.js'));

    _splitView = new SplitView(query('#splitview'));

    chrome_gen.app_window.onClosed.listen(handleWindowClosed);
  }

  String get appName => i18n('app_name');

  void handleWindowClosed(_) {

  }

  void newFile(_) {
    editor.newFile();
    updatePath();
  }

  void openFile(_) {
    chrome_gen.ChooseEntryOptions options = new chrome_gen.ChooseEntryOptions(
        type: chrome_gen.ChooseEntryType.OPEN_WRITABLE_FILE);
    chrome_gen.fileSystem.chooseEntry(options).then((chrome_gen.ChooseEntryResult result) {
      chrome_gen.ChromeFileEntry entry = result.entry;

      if (entry != null) {
        workspace.link(entry).then((file) {
          editor.setContent(file);
          updatePath();
        });

      }
    });

  }

  void saveAsFile(_) {
    //TODO: don't show error message if operation cancelled
    chrome_gen.ChooseEntryOptions options = new chrome_gen.ChooseEntryOptions(
        type: chrome_gen.ChooseEntryType.SAVE_FILE);

    chrome_gen.fileSystem.chooseEntry(options).then((chrome_gen.ChooseEntryResult result) {
      chrome_gen.ChromeFileEntry entry = result.entry;
      workspace.link(entry).then((file) {
      editor.saveAs(file);
      updatePath();
      });
    }).catchError((_) => updateError('Error on save as'));
  }

  void saveFile(_) {
    editor.save();
  }

  void setTheme(_) {
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

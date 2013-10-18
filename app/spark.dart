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
import 'lib/splitview.dart'

void main() {
  Spark spark = new Spark();
}

class Spark {
  AceEditor editor;
  Splitter _splitter;

  Spark() {
    document.title = appName;

    query("#newFile").onClick.listen(newFile);
    query("#openFile").onClick.listen(openFile);
    query("#saveFile").onClick.listen(saveFile);
    query("#saveAsFile").onClick.listen(saveAsFile);
    query("#editorTheme").onChange.listen(setTheme);

    editor = new AceEditor();
    chrome.app.window.current.onClosed.listen(handleWindowClosed);

    new FileItemView('background.js');
    new FileItemView('index.html');
    new FileItemView('index.js');
    new FileItemView('manifest.json');
    new FileItemView('longlonglong_filename.js');
  }

  String get appName => i18n('app_name');
  
  _splitter = new SplitView(query('#splitter'));

  /*
  bool _resizeStarted = false;
  int _resizeStartX;
  int _initialPositionX;
  
  void resizeDownHandler(MouseEvent event) {
    Element splitter = query('#splitter');
    if (splitter.offsetWidth > splitter.offsetHeight) {
      // splitter is horizontal.
      if (_isMouseLocationInElement(event, query('#splitter .splitter-handle'), 0, 0)) {
        _resizeStarted = true;
      }
    } else {
      // splitter is vertical.
      if (_isMouseLocationInElement(event, query('#splitter .splitter-handle'), 0, 0)) {
        _resizeStarted = true;
      }
    }
    if (_resizeStarted) {
      _resizeStartX = event.screenX;
      _initialPositionX = splitter.offsetLeft;
    }
  }

  void resizeMoveHandler(MouseEvent event) {
    if (_resizeStarted) {
      int value = _initialPositionX + event.screenX - _resizeStartX;
      if (value > query('#splitview').clientWidth - 200) {
        value = query('#splitview').clientWidth - 200;
      }
      if (value < 100) {
        value = 100;
      }
      setSplitterPosition(value);
    }
  }

  void resizeUpHandler(MouseEvent event) {
    if (_resizeStarted) {
      _resizeStarted = false;
    }
  }

  void setSplitterPosition(int position) {
    query('#fileViewArea').style.width = position.toString() + 'px';
    query('#splitter').style.left = position.toString() + 'px';
    query('#editorArea').style.left = (position + 1).toString() + 'px';
    query('#editorArea').style.width = 'calc(100% - ' + (position + 1).toString() + 'px)';
  }
  */

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

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

  var editor;

  Spark() {
    document.title = appName;
    print(appName);

//    ParagraphElement p = new ParagraphElement();
//    p.innerHtml = appName;
//    p.style.fontSize = '36pt';
//    p.style.marginTop = '100px';
//    p.style.textAlign = 'center';
//    p.style.color = '#999999';
//    p.style.fontFamily = '"Helvetica Neue", Helvetica, Arial, sans-serif';
//    p.style.textShadow = '0 1px 2px';
//    document.body.children.add(p);

    query("#openFile")
    ..onClick.listen(openFile);

    editor = new AceEditor();
    chrome.app.window.current.onClosed.listen(handleWindowClosed);
  }

  String get appName => i18n('app_name');

  void handleWindowClosed(data) {
    // TODO:
    //print('handleWindowClosed');
  }

  void openFile(MouseEvent event){
    chrome.fileSystem.chooseEntry(type: 'openWritableFile').then((chrome.FileEntry file) {
      if (file != null) {
        file.readText().then((String contents) {
          editor.setContent(file);
        });
      }
    });
  }
}
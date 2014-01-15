// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ace_test;

import 'dart:async';
import 'dart:html';

import 'package:ace/ace.dart' as ace;
import 'package:unittest/unittest.dart';

import '../lib/ace.dart';
import '../lib/workspace.dart' as workspace;

defineTests() {
  group('ace', () {
    // This essentially tests that the ace codebase is available.
    test('is available', () {
      expect(AceManager.available, true);
    });
  });
}

class MockAceManager implements AceManager {
  /// The element to put the editor in.
  final Element parentElement = null;
  workspace.File currentFile = null;

  MockAceManager();

  EditSession createEditSession(String text, String fileName) {
    return new MockEditSession(fileName);
  }

  Point get cursorPosition => new Point(0, 0);
  void set cursorPosition(Point position) {}
  ace.EditSession get currentSession => null;
  void focus() { }
  void resize() { }
  void setTheme(String theme) { }
  void switchTo(EditSession session, [workspace.File file]) { }
  set theme(String value) { }
  String get theme => null;
  Future<String> getKeyBinding() => new Future.value(null);
  void setKeyBinding(String name) { }
  void setMarkers(List<workspace.Marker> markers) { }
  void clearMarkers() { }
  void selectNextMarker() { }
  void selectPrevMarker() { }
}

class MockAceEditor implements TextEditor {
  AceManager aceManager;
  workspace.File file;

  MockAceEditor([this.aceManager]);

  Element get element => aceManager.parentElement;

  void activate() { }
  void resize() { }
  void focus() { }

  bool get dirty => false;

  set dirty(bool value) { }

  Stream get onDirtyChange => null;

  Future save() { }

  void setSession(ace.EditSession value) { }
}

class MockEditSession implements EditSession {
  final String name;
  int scrollTop;
  StreamController _changeController = new StreamController.broadcast();

  MockEditSession(this.name);

  Stream get onChange => _changeController.stream;

  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

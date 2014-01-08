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
      expect(AceContainer.available, true);
    });
  });
}

class MockAceContainer implements AceContainer {
  /// The element to put the editor in.
  final Element parentElement = null;
  workspace.File currentFile = null;

  MockAceContainer();

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
  clearAnnotations() { }
  List<ace.Annotation> setMarkers(List<workspace.Marker> markers) { }
}

class MockAceEditor implements AceEditor {
  AceContainer aceContainer;
  workspace.File file;

  MockAceEditor([this.aceContainer]);

  Element get element => aceContainer.parentElement;

  void resize() { }

  void focus() { }
}

class MockEditSession implements EditSession {
  final String name;
  int scrollTop;
  StreamController _changeController = new StreamController.broadcast();

  MockEditSession(this.name);

  Stream get onChange => _changeController.stream;

  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

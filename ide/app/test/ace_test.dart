// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ace_test;

import 'dart:async';
import 'dart:html';

import 'package:unittest/unittest.dart';

import '../lib/ace.dart';

main() {
  group('ace', () {
    // This essentially tests that the ace codebase is available.
    test('is available', () {
      expect(AceEditor.available, true);
    });
  });
}

class MockAceEditor implements AceEditor {
  /// The element to put the editor in.
  final Element parentElement = null;

  MockAceEditor();

  EditSession createEditSession(String text, String fileName) {
    return new MockEditSession(fileName);
  }

  void focus() { }
  void resize() { }
  void setTheme(String theme) { }
  void switchTo(EditSession session) { }
  set theme(String value) { }
  String get theme => null;
  Future<String> getKeyBinding() => new Future.value(null);
  void setKeyBinding(String name) { }
}

class MockEditSession implements EditSession {
  final String name;
  int scrollTop;
  StreamController _changeController = new StreamController.broadcast();

  MockEditSession(this.name);

  Stream get onChange => _changeController.stream;

  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

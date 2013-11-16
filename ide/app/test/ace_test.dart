// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ace_test;

import 'dart:async';
import 'dart:html';

import 'package:unittest/unittest.dart';
import 'package:ace/ace.dart' as ace;

import '../lib/editors/ace.dart';
import '../lib/editors/editor.dart';

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
  final Element rootElement = null;
  EditorSession _session;

  MockAceEditor();

  void focus() { }
  void resize() { }
  void setTheme(String theme) { }

  bool get readOnly => false;
  set readOnly(bool value) => false;

  EditorSession get session => _session;
  set session(EditorSession value) => _session = value;

  set theme(String value) { }
  String get theme => null;

  ace.EditSession createEditSession(String text, String fileName) =>
      ace.createEditSession(text, new ace.Mode.forFile(fileName));
}

class MockEditSession implements ace.EditSession {
  final String name;
  int scrollTop;
  StreamController _changeController = new StreamController.broadcast();

  MockEditSession(this.name);

  Stream get onChange => _changeController.stream;

  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

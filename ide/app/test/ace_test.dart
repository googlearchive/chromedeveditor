// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ace_test;

import 'dart:async';
import 'dart:html';

import 'package:unittest/unittest.dart';

import '../lib/ace.dart';

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

  MockAceContainer();

  EditSession createEditSession(String text, String fileName) {
    return new MockEditSession(fileName);
  }

  void focus() { }
  void resize() { }
  void setTheme(String theme) { }
  void switchTo(EditSession session) { }
  set theme(String value) { }
  String get theme => null;
}

class MockAceEditor implements AceEditor {
  AceContainer aceContainer;

  MockAceEditor([this.aceContainer]);

  Element get parentElement => aceContainer.parentElement;
}

class MockEditSession implements EditSession {
  final String name;
  int scrollTop;
  StreamController _changeController = new StreamController.broadcast();

  MockEditSession(this.name);

  Stream get onChange => _changeController.stream;

  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

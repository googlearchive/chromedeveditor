// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.actions_test;

import 'dart:async';
import 'dart:html';

import 'package:unittest/unittest.dart';

import '../lib/actions.dart';

main() {
  group('actions', () {
    test('KeyBinding 1', () {
      KeyBinding binding = new KeyBinding('alt-o');
      expect(binding.getDescription(), 'Alt+O');
      var event = new KeyEvent('keyDown', altKey: true, keyCode: KeyCode.O);
      expect(binding.matches(event), true);
      event = new KeyEvent('keyDown', ctrlKey: true, keyCode: KeyCode.O);
      expect(binding.matches(event), false);
    });
    test('KeyBinding 2', () {
      KeyBinding binding = new KeyBinding('alt-shift-f4');
      expect(binding.getDescription(), 'Alt+Shift+F4');
      var event = new KeyEvent(
          'keyDown', altKey: true, shiftKey: true, keyCode: KeyCode.F4);
      expect(binding.matches(event), true);
      event = new KeyEvent(
          'keyDown', altKey: true, shiftKey: false, keyCode: KeyCode.F4);
      expect(binding.matches(event), false);
    });

    test('Action disable fires changes', () {
      Completer completer = new Completer();
      MockAction action = new MockAction();
      action.onChange.first.then((_) {
        expect(true, true);
        completer.complete(null);
      });
      action.enabled = false;
      return completer.future;
    });

    test('ActionManager', () {
      ActionManager manager = new ActionManager();
      MockAction action = new MockAction();
      manager.registerAction(action);
      expect(manager.getActions().length, 1);
      var event = new KeyEvent('keyDown', altKey: true, keyCode: KeyCode.O);
      manager.handleKeyEvent(event);
      expect(action.wasCalled, true);
      action.wasCalled = false;
      action.enabled = false;
      manager.handleKeyEvent(event);
      expect(action.wasCalled, false);
    });
  });
}

class MockAction extends Action {
  bool wasCalled = false;

  MockAction(): super('mock-action', 'Mock Action') {
    defaultBinding('alt-o');
  }

  invoke() => wasCalled = true;
}

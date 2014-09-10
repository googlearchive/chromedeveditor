// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library cde_common.actions_test;

import 'dart:async';

import 'package:cde_common/actions.dart';
import 'package:unittest/unittest.dart';

void defineTests() {
  group('ActionExecutor', () {
    ActionExecutor history;
    MockAction action = new MockAction('mock action');

    setUp(() {
      history = new ActionExecutor();
    });

    test('peform', () {
      history.perform(action);
      expect(history.canUndo, true);
      expect(action.executed, true);
      history.undo();
      expect(history.canUndo, false);
      expect(action.executed, false);
      history.redo();
      expect(history.canUndo, true);
      expect(action.executed, true);
    });

    test('peform removing actions', () {
      MockAction action2 = new MockAction('mock action 2');

      history.perform(action);
      history.undo();
      history.perform(action2);
      expect(history.canUndo, true);
      history.undo();
      expect(history.canUndo, false);
    });

    test('change events', () {
      Future f = streamTester(() {
        return history.onChanged.take(2).toList().then((list) {
          expect(list.length, 2);
        });
      });

      history.perform(action);
      history.undo();

      return f;
    });
  });
}

class MockAction extends Action {
  final bool canUndo;

  MockAction(String description, {this.canUndo: true}) : super(description);

  bool executed = false;

  void execute() {
    executed = true;
  }

  void undo() {
    executed = false;
  }
}

class AsyncMockAction extends Action {
  AsyncMockAction(String description) : super(description);

  bool executed = false;

  Future execute() {
    return new Future(() {
      executed = true;
    });
  }
}

Future streamTester(Future doTest()) {
  Completer completer = new Completer();

  doTest().then((_) {
    completer.complete();
  }).catchError((e) {
    completer.completeError(e);
  });

  return completer.future;
}

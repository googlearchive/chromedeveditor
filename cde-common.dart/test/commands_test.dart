// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library cde_common.commands_test;

import 'dart:async';

import 'package:cde_common/commands.dart';
import 'package:unittest/unittest.dart';

void defineTests() {
  group('CommandHistory', () {
    CommandHistory history;
    MockCommand command = new MockCommand('mock command');

    setUp(() {
      history = new CommandHistory();
    });

    test('peform', () {
      history.perform(command);
      expect(history.canUndo, true);
      expect(command.executed, true);
      history.undo();
      expect(history.canUndo, false);
      expect(command.executed, false);
      history.redo();
      expect(history.canUndo, true);
      expect(command.executed, true);
    });

    test('peform removing commands', () {
      MockCommand command2 = new MockCommand('mock command 2');

      history.perform(command);
      history.undo();
      history.perform(command2);
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

      history.perform(command);
      history.undo();

      return f;
    });
  });
}

class MockCommand extends Command {
  final bool canUndo;

  MockCommand(String description, {this.canUndo: true}) : super(description);

  bool executed = false;

  void execute() {
    executed = true;
  }

  void undo() {
    executed = false;
  }
}

class AsyncMockCommand extends Command {
  AsyncMockCommand(String description) : super(description);

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

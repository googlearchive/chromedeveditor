// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library cde_workbench.commands_test;

import 'dart:async';

import 'package:cde_workbench/commands.dart';
import 'package:cde_workbench/context.dart';
import 'package:unittest/unittest.dart';

void defineTests() {
  group('commands', () {
    test('Command ctor', () {
      Command cmd = new MockCommand('foo', 'Foo');
      expect(cmd.id, 'foo');
      expect(cmd.description, 'Foo');
      expect(cmd.args.map((arg) => arg.toString()).join(' '), '');
    });

    test('Command ctor 2', () {
      Command cmd = new MockCommand('foo', 'Foo', '%s %s [%i %s]');
      expect(cmd.id, 'foo');
      expect(cmd.description, 'Foo');
      expect(cmd.args.map((arg) => arg.toString()).join(' '),
          'string string num (optional) string (optional)');
    });
  });
}

class MockCommand extends Command {
  MockCommand(String id, String description, [String argsDescription]) :
      super(id, description: description, argsDescription: argsDescription);

  Action createAction(Context context, List<String> args) {
    return new MockAction(description);
  }
}

class MockAction extends Action {
  MockAction(String name) : super(name);

  bool executed = false;

  void execute() {
    executed = true;
  }
}

class AsyncMockAction extends Action {
  AsyncMockAction(String name) : super(name);

  bool executed = false;

  Future execute() {
    return new Future(() {
      executed = true;
    });
  }
}

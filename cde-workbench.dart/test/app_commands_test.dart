// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library cde_workbench.commands_test;

import 'dart:async';

import 'package:cde_workbench/app_commands.dart';
import 'package:cde_workbench/context.dart';
import 'package:unittest/unittest.dart';

void defineTests() {
  group('commands', () {
    test('AppCommand ctor', () {
      AppCommand cmd = new MockAppCommand('foo', 'Foo');
      expect(cmd.id, 'foo');
      expect(cmd.description, 'Foo');
      expect(cmd.args.map((arg) => arg.toString()).join(' '), '');
    });

    test('AppCommand ctor 2', () {
      AppCommand cmd = new MockAppCommand(
          'foo', 'Foo', '%s %s [%i %s]');
      expect(cmd.id, 'foo');
      expect(cmd.description, 'Foo');
      expect(cmd.args.map((arg) => arg.toString()).join(' '),
          'string string num (optional) string (optional)');
    });
  });
}

class MockAppCommand extends AppCommand {
  MockAppCommand(String id, String description, [String argsDescription]) :
      super(id, description: description, argsDescription: argsDescription);

  Command createCommand(Context context, List<String> args) {
    return new MockCommand(description);
  }
}

class MockCommand extends Command {
  MockCommand(String description) : super(description);

  bool executed = false;

  void execute() {
    executed = true;
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

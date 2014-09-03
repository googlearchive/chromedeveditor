// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:cde_common/common.dart';
import 'package:cde_core/core.dart';
import 'package:cde_workbench/cde_workbench.dart';
import 'package:cde_workbench/context.dart';
import 'package:cde_workbench/app_commands.dart';
import 'package:polymer/polymer.dart';

CdeWorkbench get _workbench => Dependencies.instance[CdeWorkbench];

@CustomTag('example-app')
class ExampleApp extends CdeWorkbench {
  ExampleApp.created() : super.created();

  void ready() {
    super.ready();

    CommandManager commands = Dependencies.instance[CommandManager];
    commands.addCommand(AppCommand.create('do-foo', () {
      _workbench.showDialog('Foo', 'Bar!');
    }));
    commands.addCommand(AppCommand.create('do-bar', () {
      _workbench.showMessage('Foo bar!');
    }));
  }
}

class FooAppCommand extends AppCommand {
  FooAppCommand() : super('do-foo');

  Command createCommand(Context context, List<String> args) {
    return new FooCommand();
  }
}

class FooCommand extends Command {
  FooCommand() : super('foo');

  void execute() {
    CdeWorkbench workbench = Dependencies.instance[CdeWorkbench];
    workbench.showDialog('Foo', 'Bar!');
  }
}

class BarAppCommand extends AppCommand {
  BarAppCommand() : super('do-bar');

  Command createCommand(Context context, List<String> args) {
    return new BarCommand();
  }
}

class BarCommand extends Command {
  BarCommand() : super('bar');

  void execute() {
    CdeWorkbench workbench = Dependencies.instance[CdeWorkbench];
    workbench.showMessage('Foo bar!');
  }
}

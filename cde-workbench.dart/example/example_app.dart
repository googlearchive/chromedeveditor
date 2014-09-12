// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//import 'package:cde_common/common.dart';
import 'package:cde_core/core.dart';
import 'package:cde_workbench/cde_workbench.dart';
import 'package:cde_workbench/keys.dart';
import 'package:cde_workbench/commands.dart';
import 'package:polymer/polymer.dart';

CdeWorkbench get _workbench => Dependencies.instance[CdeWorkbench];

@CustomTag('example-app')
class ExampleApp extends CdeWorkbench {
  ExampleApp.created() : super.created();

  void ready() {
    // Looks like this is already called by Polymer. Confusing.
    super.ready();

    CommandManager commands = Dependencies.instance[CommandManager];
    commands.bind('do-foo', () => _workbench.showDialog('Foo', 'Bar!'));
    commands.bind('do-bar', () => _workbench.showMessage('Foo bar!'));

    Keys keys = Dependencies.instance[Keys];
    keys.bind('macctrl-a', 'do-foo');
    keys.bind('macctrl-s', 'do-bar');

    keys.bind(r'ctrl-\', 'show-commandbar');
    commands.bind('show-commandbar', () => _workbench.showMessage('Command bar!'));
  }
}

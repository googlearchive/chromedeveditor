// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:cde_core/dependencies.dart';
//import 'package:cde_workbench/cde_workbench.dart';
import 'package:cde_workbench/commands.dart';
import 'package:polymer/polymer.dart';

@CustomTag('cde-icon-button')
class CdeIconButton extends PolymerElement {
  @published String icon;
  @published String command;

  CdeIconButton.created() : super.created();

  void handleTap() {
    print('handleTap: ${command}');

    CommandManager commands = Dependencies.instance[CommandManager];
    // TODO: get the current context
    commands.executeCommand(null, command);
  }
}

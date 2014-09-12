// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'package:cde_core/dependencies.dart';
import 'package:cde_workbench/commands.dart';
import 'package:polymer/polymer.dart';

@CustomTag('cde-paper-item')
class CdePaperItem extends PolymerElement {
  @published String command;

  CdePaperItem.created() : super.created();

  void handleTap() {
    CommandManager commands = Dependencies.instance[CommandManager];
    // TODO: get the current context
    commands.executeCommand(null, command);
  }
}

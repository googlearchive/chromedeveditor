// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library cde_workbench.workbench;

import 'dart:async';

import 'package:cde_common/common.dart';
import 'package:cde_core/core.dart';
import 'package:cde_workbench/commands.dart';
import 'package:cde_workbench/keys.dart';
import 'package:paper_elements/paper_dialog.dart';
import 'package:paper_elements/paper_toast.dart';
import 'package:polymer/polymer.dart';

/**
 * A Polymer cde-workbench element.
 */
@CustomTag('cde-workbench')
class CdeWorkbench extends PolymerElement {
  CdeWorkbench.created() : super.created();

  bool _readyCalled = false;

  void ready() {
    super.ready();

    if (!_readyCalled) {
      _readyCalled = true;

      Dependencies deps = new Dependencies();
      Dependencies.setGlobalInstance(deps);

      deps[CdeWorkbench] = this;
      deps[ActionExecutor] = new ActionExecutor();
      deps[CommandManager] = new CommandManager();
      deps[Notifier] = new CdeNotifier(this);
      deps[Keys] = new Keys();
    }
  }

  void showDialog(String title, String message) {
    PaperDialog dialog = $['simpleDialog'];
    dialog.heading = title;
    dialog.querySelector('p').text = message;
    dialog.opened = true;
  }

  void showMessage(String message) {
    PaperToast toast = $['toast'];
    toast.text = message;
    toast.show();
  }

  Future<bool> askUserOkCancel(String title, String message,
      {String okButtonLabel, String cancelButtonLabel}) {
    if (okButtonLabel == null) okButtonLabel = "OK";
    if (cancelButtonLabel == null) cancelButtonLabel = "Cancel";

    PaperDialog dialog = $['okCancelDialog'];
    dialog.heading = title;
    dialog.querySelector('p').text = message;
    dialog.querySelector('paper-button[autofocus]').attributes['label'] =
        okButtonLabel;
    dialog.querySelector('paper-button:not([autofocus])').attributes['label'] =
        cancelButtonLabel;
    dialog.opened = true;

    // TODO: Implement - return a value.
    return new Future.value(true);
  }

  void displayError(String message) {
    PaperDialog dialog = $['simpleDialog'];
    dialog.heading = '';
    dialog.querySelector('p').text = message;
    dialog.opened = true;
  }
}

class CdeNotifier implements Notifier {
  final CdeWorkbench workbench;

  CdeNotifier(this.workbench);

  Future<bool> askUserOkCancel(String title, String message,
      {String okButtonLabel, String cancelButtonLabel}) {
    return workbench.askUserOkCancel(title, message,
        okButtonLabel: okButtonLabel, cancelButtonLabel: cancelButtonLabel);
  }

  void displayError(String message) {
    workbench.displayError(message);
  }

  void displaySuccess(String message) {
    workbench.showMessage(message);
  }

  void showDialog(String title, String message) {
    workbench.showDialog(title, message);
  }
}

// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This library defines action and key binding related classes.
 */
library cde_workbench.keys;

import 'dart:html';

import 'package:cde_core/core.dart';
import 'package:cde_workbench/commands.dart';

final bool _isMac =
    window.navigator.appVersion.toLowerCase().contains('macintosh');

/**
 * Map key events into commands.
 */
class Keys {
  CommandManager _commandManager;
  Map<String, String> _bindings = {};

  Keys([this._commandManager]) {
    if (_commandManager == null) {
      _commandManager = Dependencies.instance[CommandManager];
    }
    assert(_commandManager != null);

    document.onKeyDown.listen(_handleKeyEvent);
  }

  void bind(String key, String command) {
    _bindings[key] = command;
  }

  void _handleKeyEvent(KeyboardEvent event) {
    //if (event.charCode == 0) return;

    KeyEvent k = new KeyEvent.wrap(event);

    if (event.keyCode < 27) return;

    if (!event.altKey && !event.ctrlKey && !event.metaKey) {
      return;
    }

    print('${k.keyCode}, ${k.charCode}, ${k.which}');

    // TODO: we need to call this if the event is handled -
    String key = printKeyEvent(k);

    if (_handleKey(key)) {
      event.preventDefault();
    }
  }

  bool _handleKey(String key) {
    String command = _bindings[key];

    if (command != null) {
      // TODO: get the current context
      _commandManager.executeCommand(null, command);
      return true;
    } else {
      return false;
    }
  }
}

/**
 * Convert [event] into a string (e.g., `ctrl-s`).
 */
String printKeyEvent(KeyEvent event) {
  // TODO: unit test this

  StringBuffer buf = new StringBuffer();

  // shift ctrl alt
  if (event.shiftKey) buf.write('shift-');
  if (event.ctrlKey) buf.write(_isMac ? 'macctrl-' : 'ctrl-');
  if (event.metaKey) buf.write(_isMac ? 'ctrl-' : 'meta-');
  if (event.altKey) buf.write('alt-');

  // TODO: improve this key event handling
  //buf.write(new String.fromCharCodes([event.charCode]).toLowerCase());
  buf.write(new String.fromCharCodes([event.keyCode]).toLowerCase());

  print(buf.toString());

  return buf.toString();
}

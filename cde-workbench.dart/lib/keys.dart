// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This library defines action and key binding related classes.
 */
library cde_workbench.keys;

import 'dart:async';
import 'dart:html';

/**
 * TODO:
 */
class Keys {
  StreamController _controller;
  StreamSubscription _streamSub;

  bool _isMac;

  final Set<int> _functionKey = new Set.from(
    [KeyCode.F1, KeyCode.F2, KeyCode.F3, KeyCode.F4, KeyCode.F5, KeyCode.F6,
     KeyCode.F7, KeyCode.F8, KeyCode.F9, KeyCode.F10, KeyCode.F11,
     KeyCode.F12]);

  Keys() {
    _isMac = window.navigator.appVersion.toLowerCase().contains('macintosh');

    _controller = new StreamController.broadcast(onListen: () {
      _streamSub = document.onKeyDown.listen(_handleKeyEvent);
    }, onCancel: () {
      _streamSub.cancel();
    });
  }

  /**
   * TODO:
   */
  Stream<String> get onKey => _controller.stream;

  void _handleKeyEvent(KeyboardEvent event) {
    if (!event.altKey && !event.ctrlKey && !event.metaKey &&
        !_isFunctionEvent(event.keyCode)) {
      return;
    }

    _controller.add(printKeyEvent(event));
  }

  bool _isFunctionEvent(int keyCode) => _functionKey.contains(keyCode);
}

/**
 * Convert [event] into a string (e.g., `ctrl-s`).
 */
String printKeyEvent(KeyboardEvent event) {
  // TODO: unit test this

  StringBuffer buf = new StringBuffer();

  // shift ctrl alt
  if (event.shiftKey) buf.write('shift-');
  if (event.ctrlKey) buf.write('ctrl-');
  if (event.metaKey) buf.write('macctrl-');
  if (event.altKey) buf.write('alt-');

  buf.write(new String.fromCharCode(event.charCode).toLowerCase());

  return buf.toString();
}

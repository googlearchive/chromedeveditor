// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * TODO:
 */
library spark.actions;

import 'dart:async';
import 'dart:html';

// TODO: add some tests

/**
 * TODO:
 */
class ActionManager {
  Map<String, Action> _actionMap = {};

  ActionManager();

  void registerAction(Action action) {
    _actionMap[action.id] = action;
  }

  Action getAction(String id) => _actionMap[id];

  Iterable<Action> getActions() => _actionMap.values;

  void handleKeyEvent(KeyEvent event) {
    if (!event.altKey && !event.ctrlKey && !event.metaKey) {
      return;
    }

    for (Action action in getActions()) {
      if (action.matches(event)) {
        event.preventDefault();

        if (action.enabled) {
          action.invoke();
        }
      }
    }
  }
}

Map<String, int> _bindingMap = {
  "META": KeyCode.META,
  "CTRL": _isMac() ? KeyCode.META : KeyCode.CTRL,
  "MACCTRL": KeyCode.CTRL,
  "ALT": KeyCode.ALT,
  "SHIFT": KeyCode.SHIFT,

  "F1": KeyCode.F1,
  "F2": KeyCode.F2,
  "F3": KeyCode.F3,
  "F4": KeyCode.F4,
  "F5": KeyCode.F5,
  "F6": KeyCode.F6,
  "F7": KeyCode.F7,
  "F8": KeyCode.F8,
  "F9": KeyCode.F9,
  "F10": KeyCode.F10,
  "F11": KeyCode.F11,
  "F12": KeyCode.F12,

  "TAB": KeyCode.TAB
};

/**
 * TODO:
 */
class KeyBinding {
  Set<int> modifiers = new Set();
  int keyCode;

  KeyBinding(String str) {
    List<String> codes = str.toUpperCase().split('-');

    for (String str in codes.getRange(0, codes.length - 1)) {
      modifiers.add(_codeFor(str));
    }

    keyCode = _codeFor(codes[codes.length - 1]);
  }

  bool matches(KeyEvent event) {
    if (event.keyCode != keyCode) {
      return false;
    }

    if (event.ctrlKey != modifiers.contains(KeyCode.CTRL)) {
      return false;
    }

    if (event.metaKey != modifiers.contains(KeyCode.META)) {
      return false;
    }

    if (event.altKey != modifiers.contains(KeyCode.ALT)) {
      return false;
    }

    if (event.shiftKey != modifiers.contains(KeyCode.SHIFT)) {
      return false;
    }

    return true;
  }

  String getDescription() {
    List<String> desc = new List<String>();

    if (modifiers.contains(KeyCode.CTRL)) {
      desc.add(_descriptionOf(KeyCode.CTRL));
    }

    if (modifiers.contains(KeyCode.META)) {
      desc.add(_descriptionOf(KeyCode.META));
    }

    if (modifiers.contains(KeyCode.ALT)) {
      desc.add(_descriptionOf(KeyCode.ALT));
    }

    if (modifiers.contains(KeyCode.SHIFT)) {
      desc.add(_descriptionOf(KeyCode.SHIFT));
    }

    desc.add(_descriptionOf(keyCode));

    return desc.join('+');
  }

  int _codeFor(String str) {
    if (_bindingMap[str] != null) {
      return _bindingMap[str];
    }

    return str.codeUnitAt(0);
  }

  String _descriptionOf(int code) {
    if (_isMac() && code == KeyCode.META) {
      return "Cmd";
    }

    if (code == KeyCode.META) {
      return "Meta";
    }

    if (code == KeyCode.CTRL) {
      return "Ctrl";
    }

    for (String key in _bindingMap.keys) {
      if (code == _bindingMap[key]) {
        return key; //toTitleCase(key);
      }
    }

    return new String.fromCharCode(code);
  }
}

/**
 * TODO:
 */
abstract class Action {
  StreamController<Action> _controller = new StreamController.broadcast();

  String id;
  String name;
  bool _enabled = true;

  KeyBinding binding;

  Action(this.id, this.name);

  void defaultBinding(String str) {
    if (binding == null) {
      binding = new KeyBinding(str);
    }
  }

  void linuxBinding(String str) {
    if (_isLinuxLike()) {
      binding = new KeyBinding(str);
    }
  }

  void macBinding(String str) {
    if (_isMac()) {
      binding = new KeyBinding(str);
    }
  }

  void winBinding(String str) {
    if (_isWin()) {
      binding = new KeyBinding(str);
    }
  }

  void invoke();

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (_enabled != value) {
      _enabled = value;

      _controller.add(this);
    }
  }

  bool matches(KeyEvent event) {
    return binding == null ? false : binding.matches(event);
  }

  /**
   * This event is fired when the action enablement state changes.
   */
  Stream<Action> get onChange => _controller.stream;

  String getBindingDescription() {
    return binding == null ? null : binding.getDescription();
  }

  String toString() => 'Action: ${name}';
}

bool _isMac() => _platform().indexOf('mac') != -1;
bool _isWin() => _platform().indexOf('win') != -1;
bool _isLinuxLike() => !_isMac() && !_isWin();

String _platform() {
  String str = window.navigator.platform;
  return (str != null) ? str.toLowerCase() : '';
}

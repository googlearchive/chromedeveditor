// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This library defines action and key binding related classes.
 */
library spark.actions;

import 'dart:async';
import 'dart:html';

/**
 * The ActionManager class is used to manage a set of actions.
 */
class ActionManager {
  Map<String, Action> _actionMap = {};

  /**
   * Register this [ActionManager] as a key event listener for the global
   * [document].
   */
  void registerKeyListener() {
    document.onKeyDown.listen(handleKeyEvent);
  }

  /**
   * Register a new [Action] with this [ActionManager].
   */
  Action registerAction(Action action) => _actionMap[action.id] = action;

  /**
   * Return the [Action] with the given ID.
   */
  Action getAction(String id) => _actionMap[id];

  /**
   * Return an [Iterable] of all the registered [Actions]s.
   */
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

/**
 * A [Map] to convert from the textual description of a key to its key code.
 */
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
 * This class represents a key and a set of key modifiers.
 */
class KeyBinding {
  Set<int> modifiers = new Set();
  int keyCode;

  /**
   * Create a new [KeyBinding] using the given textual description. Some
   * examples of key binding text are `ctrl-shift-f4`, and `ctrl-o`, and
   * `alt-f1`.
   *
   * Valid key modifiers are `meta`, `ctrl`, `macctrl`, `alt`, and `shift`.
   */
  KeyBinding(String str) {
    List<String> codes = str.toUpperCase().split('-');

    for (String str in codes.getRange(0, codes.length - 1)) {
      modifiers.add(_codeFor(str));
    }

    keyCode = _codeFor(codes[codes.length - 1]);
  }

  /**
   * Returns whether this binding matches the given key event.
   */
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

  /**
   * Returns a user-consumable description of this key binding. Examples are
   * `Shift+O` and `Ctrl+Shift+F4`.
   */
  String getDescription() {
    List<String> desc = [];

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

    if (_isMac() && modifiers.length == 1 && modifiers.first == KeyCode.META) {
      return desc.join();
    } else {
      return desc.join('+');
    }
  }

  int _codeFor(String str) {
    if (_bindingMap[str] != null) {
      return _bindingMap[str];
    }

    return str.codeUnitAt(0);
  }

  String _descriptionOf(int code) {
    if (code == KeyCode.META) {
      if (_isMac()) {
        return '⌘'; // "Cmd";
      } else {
        return "Meta";
      }
    }

    if (code == KeyCode.CTRL) {
      return "Ctrl";
    }

    for (String key in _bindingMap.keys) {
      if (code == _bindingMap[key]) {
        return _toTitleCase(key);
      }
    }

    return new String.fromCharCode(code);
  }

  String toString() => getDescription();
}

/**
 * An abstract representation of an action. Actions have:
 *
 *  * names
 *  * ids
 *  * key-bindings
 *  * enablement states
 *
 * They can be listened to in order to know when their enablement state changes.
 */
abstract class Action {
  StreamController<Action> _controller = new StreamController.broadcast();

  String id;
  String name;
  KeyBinding binding;

  bool _enabled = true;

  Action(this.id, this.name);

  /**
   * Set a default (cross-platform) binding.
   */
  void defaultBinding(String str) {
    if (binding == null) {
      binding = new KeyBinding(str);
    }
  }

  /**
   * Set a Linux (and Linux-OS like) specific binding.
   */
  void linuxBinding(String str) {
    if (_isLinuxLike()) {
      binding = new KeyBinding(str);
    }
  }

  /**
   * Set a Mac specific binding.
   */
  void macBinding(String str) {
    if (_isMac()) {
      binding = new KeyBinding(str);
    }
  }

  /**
   * Set a Windows specific binding.
   */
  void winBinding(String str) {
    if (_isWin()) {
      binding = new KeyBinding(str);
    }
  }

  /**
   * Run this action.
   */
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

String _toTitleCase(String str) {
  if (str.length < 2) {
    return str.toUpperCase();
  } else {
    return '${str[0].toUpperCase()}${str.substring(1).toLowerCase()}';
  }
}

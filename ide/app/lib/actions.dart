// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This library defines action and key binding related classes.
 */
library spark.actions;

import 'dart:async';
import 'dart:html';

import 'platform_info.dart';
import 'utils.dart';

/**
 * Create a blank, separator menu item.
 */
Element createMenuSeparator() => new LIElement()..classes.add('divider');

/**
 * Create a menu item from the given action. The menu item will have the
 * action's name, keybinding, and disablement state. Selecting the menu item
 * will call the action's `invoke()` method.
 */
Element createMenuItem(Action action, {Object context, bool showAccelerator: true}) {
  LIElement li = new LIElement();

  AnchorElement a = new AnchorElement()
      ..text = action.name
      ..classes.toggle('disabled', !action.enabled);

  if (showAccelerator) {
    SpanElement span = new SpanElement()
        ..text = action.getBindingDescription()
        ..classes.add('pull-right');
    a.children.add(span);
  }

  li.children.add(a);
  li.onClick.listen((_) => action.invoke(context));

  return li;
}

/**
 * Given a list of actions (possibly from [ActionManager.getContextActions])
 * return a menu element representing those actions.
 */
Element createContextMenu(List<ContextAction> actions, Object context,
                          {bool pullRight: false}) {
  UListElement ul = new UListElement()
      ..classes.add('dropdown-menu')
      ..classes.toggle('pull-right', pullRight)
      ..attributes['role'] = 'menu';
  fillContextMenu(ul, actions, context);
  return ul;
}

/**
 * Given a list of actions (possibly from [ActionManager.getContextActions])
 * fill a menu element with items representing those actions.
 */
void fillContextMenu(UListElement ul,
                     List<ContextAction> actions,
                     Object context) {
  String category = null;

  for (ContextAction action in actions) {
    if (category != null && action.category != category) {
      ul.children.add(createMenuSeparator());
    }
    category = action.category;

    ul.children.add(
        createMenuItem(action, context: context, showAccelerator: false));
  }
}

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

  bool _isSingleKeyEvent(int keyCode) {
    final Set<int> _allowedKey = new Set.from(
      [KeyCode.F1, KeyCode.F2, KeyCode.F3, KeyCode.F4, KeyCode.F5, KeyCode.F6,
       KeyCode.F7, KeyCode.F8, KeyCode.F9, KeyCode.F10, KeyCode.F11,
       KeyCode.F12]);
    return _allowedKey.contains(keyCode);
  }

  void handleKeyEvent(KeyboardEvent event) {
    if (!event.altKey && !event.ctrlKey && !event.metaKey &&
        !_isSingleKeyEvent(event.keyCode)) {
      return;
    }

    for (Action action in getActions()) {
      if (action.matchesEvent(event)) {
        event.preventDefault();

        if (action.enabled) {
          action.invoke();
        }
      }
    }
  }

  /**
   * Return a list of all context menu actions that apply to the given [object].
   * The list is returned in the order that the context menu actions were
   * defined, with a stable sort by action category. So, all actions in the
   * same category ('resource', 'transfer', ...) will be grouped together.
   */
  List<ContextAction> getContextActions(Object object) {
    List list = [];

    for (Action action in getActions()) {
      if (action is ContextAction && action.appliesTo(object)) {
        list.add(action);
      }
    }

    List sorted = [];

    // Sort the actions by category; keep the categories in their original order.
    while (list.isNotEmpty) {
      String category = list.first.category;
      sorted.addAll(list.where((a) => a.category == category));
      list.removeWhere((a) => a.category == category);
    }

    return sorted;
  }
}

/**
 * This class represents a key and a set of key modifiers.
 */
class KeyBinding {
  static Map<String, int> __bindingMap;

  /**
   * A [Map] to convert from the textual description of a key to its key code.
   */
  static Map<String, int> get _bindingMap {
    // NOTE: Initialize the map dynamically because it uses PlatformInfo.isMac,
    // which is not available immediately upon startup.
    if (__bindingMap == null) {
      __bindingMap = {
          "META": KeyCode.META,
          "CTRL": PlatformInfo.isMac ? KeyCode.META : KeyCode.CTRL,
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

          "LEFT": KeyCode.LEFT,
          "RIGHT": KeyCode.RIGHT,

          "SPACE": KeyCode.SPACE,
          "ENTER": KeyCode.ENTER,
          "TAB": KeyCode.TAB,
          "[" : KeyCode.OPEN_SQUARE_BRACKET,
          "]" : KeyCode.CLOSE_SQUARE_BRACKET,
          "." : KeyCode.PERIOD,
          "," : KeyCode.COMMA
      };
    }
    return __bindingMap;
  }

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

    keyCode = _codeFor(codes.last);
  }

  /**
   * Returns whether this binding matches the given key event.
   */
  bool matches(KeyboardEvent event) {
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

    if (PlatformInfo.isMac && modifiers.length == 1 && modifiers.first == KeyCode.META) {
      return desc.join();
    } else {
      return desc.join('+');
    }
  }

  int _codeFor(String str) {
    if (_bindingMap[str] != null) {
      return _bindingMap[str];
    }

    // Look for specific hex key codes.
    if (str.startsWith('0x')) {
      return int.parse(str.substring(2), radix: 16);
    }

    return str.codeUnitAt(0);
  }

  String _descriptionOf(int code) {
    if (code == KeyCode.META) {
      if (PlatformInfo.isMac) {
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
        return toTitleCase(key);
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
  List<KeyBinding> bindings = [];

  bool _enabled = true;

  Action(this.id, this.name);

  /**
   * Add a key binding to this [Action] instance. If an OS specific key binding
   * is provided, and we're on the indicated platform, then that key binding
   * will be used. Otherwise, the [defaultBinding] will be used.
   */
  void addBinding(String defaultBinding,
                  {String macBinding, String linuxBinding, String winBinding}) {
    if (macBinding != null && PlatformInfo.isMac) {
      bindings.add(new KeyBinding(macBinding));
    } else if (winBinding != null && PlatformInfo.isWin) {
      bindings.add(new KeyBinding(winBinding));
    } else if (linuxBinding != null && PlatformInfo.isLinux) {
      bindings.add(new KeyBinding(linuxBinding));
    } else {
      bindings.add(new KeyBinding(defaultBinding));
    }
  }

  /**
   * Run this action. An optional [context] paramater is passed in for some
   * action invocations. This is used in the case of context menu invocations;
   * [context] will be the object to act on.
   */
  void invoke([Object context]);

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (_enabled != value) {
      _enabled = value;
      _controller.add(this);
    }
  }

  bool matchesEvent(KeyboardEvent event) {
    return bindings.any((binding) => binding.matches(event));
  }

  /**
   * This event is fired when the action enablement state changes.
   */
  Stream<Action> get onChange => _controller.stream;

  String getBindingDescription() {
    return bindings.isEmpty ? null : bindings.first.getDescription();
  }

  String toString() => 'Action: ${name}';
}

/**
 * An [Action] subclass that can indicate whether it applies in certain
 * contexts. See also [Action.getContextMenu].
 */
abstract class ContextAction extends Action {
  ContextAction(String id, String name): super(id, name);

  /**
   * The logical category for the context action. This is used to group like
   * actions together, and provide visual separtion between other categories.
   * Example categories are `resource` and `transfer`.
   */
  String get category;

  /**
   * Returns whether this action applies to the given context object. This
   * generally means whether the action can act on the object in general. So
   * an action may report that it can act on the given object, even if in a
   * particular circumstance the action is disabled.
   */
  bool appliesTo(Object object);
}

String _toTitleCase(String str) {
  if (str.length < 2) {
    return str.toUpperCase();
  } else {
    return '${str[0].toUpperCase()}${str.substring(1).toLowerCase()}';
  }
}

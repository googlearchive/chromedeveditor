// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.menu_button;

import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';
import '../spark_button/spark_button.dart';
import '../spark_menu/spark_menu.dart';
// TODO(ussuri): Temporary. See the comment below.
import '../spark_overlay/spark_overlay.dart';

@CustomTag("spark-menu-button")
class SparkMenuButton extends SparkWidget {
  @published dynamic selected;
  @published String valueAttr = '';
  @published bool opened = false;
  @published bool responsive = false;
  @published String arrow = 'none';
  static final List<String> _SUPPORTED_ARROWS = [
    'none', 'top-center', 'top-left', 'top-right'
  ];

  SparkButton _button;
  SparkOverlay _overlay;
  SparkMenu _menu;

  /**
   * The state of the menu on `mouseDown`.
   */
  bool _mouseDownOpened;

  SparkMenuButton.created(): super.created();

  @override
  void attached() {
    super.attached();

    assert(_SUPPORTED_ARROWS.contains(arrow));

    _overlay = $['overlay'];
    // TODO(ussuri): This lets _overlay handle ESC but breaks _button's
    // active state when menu is open.
    //SparkWidget.enableKeyboardEvents(_overlay);

    _menu = $['menu'];

    final ContentElement buttonCont = $['button'];
    assert(buttonCont.getDistributedNodes().isNotEmpty);
    _button = buttonCont.getDistributedNodes().first;
    _button
        ..onMouseDown.listen(mouseDownHandler)
        ..onClick.listen(clickHandler)
        ..onFocus.listen(focusHandler)
        ..onBlur.listen(blurHandler);
  }

  /**
   * Update 'opened' state.
   */
  void _toggle(bool newOpened) {
    if (newOpened != opened) {
      opened = newOpened;
      // TODO(ussuri): A hack to make #overlay and #button see
      // changes in 'opened'. Data binding via {{opened}} in the HTML wasn't
      // detected. deliverChanges() here fix #overlay, but not #button.
      // setAttr() fixes #button, but break #overlay. See BUG #2252.
      _overlay..opened = newOpened..deliverChanges();
      _button.setAttr('active', newOpened);
      if (newOpened) {
        // Enforce focused state so the button can accept keyboard events.
        focus();
        _menu.resetState();
      }
    }
  }

  /**
   * The menu state should be toggle on click.
   * Hovewer what is a single click the from user's perspective is a sequence
   * of DOM events: mouseDown, focus, mouseUp, click.
   * We force the menu open on `focus`, so we need to remember the [opened]
   * state on `mouseDown` into [_mouseDownOpened] and use in [clickHandler].
   */
  void mouseDownHandler(Event e) {
    _mouseDownOpened = opened;
  }

  /**
   * Toggles [opened] state depending on [_mouseDownOpened].
   */
  void clickHandler(Event e) => _toggle(!_mouseDownOpened);

  void focusHandler(Event e) => _toggle(true);

  void blurHandler(FocusEvent e) {
    var target = e.relatedTarget;
    if (target != null && !contains(target)) {
      _toggle(false);
    }
  }

  void menuActivateHandler(CustomEvent e, var details) {
    if (details['isSelected']) {
      _toggle(false);
    }
  }

  void keyDownHandler(KeyboardEvent e) {
    bool stopPropagation = true;

    // If the menu is opened, give it a chance to handle the keystroke,
    // e.g. select the current item on ENTER or SPACE.
    if (opened && _menu.maybeHandleKeyStroke(e.keyCode)) {
      e.preventDefault();
    }

    // Continue handling the keystroke regardless of whether the menu has
    // handled it: we might still to take an action (e.g. close the menu on
    // ENTER).
    switch (e.keyCode) {
      case KeyCode.UP:
      case KeyCode.DOWN:
      case KeyCode.PAGE_UP:
      case KeyCode.PAGE_DOWN:
      case KeyCode.ENTER:
        _toggle(true);
        break;
      case KeyCode.ESC:
        _toggle(false);
        break;
      default:
        stopPropagation = false;
        break;
    }

    if (stopPropagation) {
      e.stopPropagation();
    }
  }
}

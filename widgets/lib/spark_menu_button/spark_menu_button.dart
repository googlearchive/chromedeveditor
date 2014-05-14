// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.menu_button;

import 'dart:async';
import 'dart:html';

import 'package:polymer/polymer.dart';

import '../common/spark_widget.dart';
import '../spark_button/spark_button.dart';
import '../spark_menu/spark_menu.dart';
// TODO(ussuri): Temporary. See the comment below.
import '../spark_overlay/spark_overlay.dart';

@CustomTag("spark-menu-button")
class SparkMenuButton extends SparkWidget {
  @published String icon = "";
  @published dynamic selected;
  @published String valueAttr = "";
  @published bool opened = false;
  @published bool responsive = false;
  @published String valign = "center";

  SparkButton _button;
  SparkOverlay _overlay;
  SparkMenu _menu;
  bool _disableClickHandler = false;
  Timer _timer;

  SparkMenuButton.created(): super.created();

  @override
  void enteredView() {
    super.enteredView();

    _button = $['button'];
    _overlay = $['overlay'];
    _menu = $['menu'];
  }

  /**
   * Toggle the opened state of the dropdown.
   */
  void _toggle(bool inOpened) {
    if (inOpened != opened) {
      opened = inOpened;
      // TODO(ussuri): A temporary plug to make #overlay and #button see
      // changes in 'opened'. Data binding via {{opened}} in the HTML isn't
      // detected. deliverChanges() fixes #overlay, but not #button.
      _overlay.opened = inOpened;
      _button.active = inOpened;
      if (opened) {
        // Enforce focused state so the button can accept keyboard events.
        focus();
        _menu.resetState();
      }
    }
  }

  void clickHandler(Event e) {
    if (_disableClickHandler) return;
    _toggle(!opened);
  }

  void focusHandler(Event e) => _toggle(true);

  void blurHandler(Event e) {
    _toggle(false);
    _disableClickHandler = true;
    if (_timer != null) _timer.cancel();
    _timer = new Timer(const Duration(milliseconds: 300), () {
      _disableClickHandler = false;
    });
  }

  /**
   * Handle the on-opened event from the dropdown. It will be fired e.g. when
   * mouse is clicked outside the dropdown (with autoClosedDisabled == false).
   */
  void overlayOpenedHandler(CustomEvent e) {
    // Autoclosing is the only event we're interested in.
    if (e.detail == false) {
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

    if (_menu.maybeHandleKeyStroke(e.keyCode)) {
      e.preventDefault();
    }

    switch (e.keyCode) {
      case KeyCode.UP:
      case KeyCode.DOWN:
      case KeyCode.PAGE_UP:
      case KeyCode.PAGE_DOWN:
      case KeyCode.ENTER:
        if (!opened) opened = true;
        break;
      case KeyCode.ESC:
        this.blur();
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

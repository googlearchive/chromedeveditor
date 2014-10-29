// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui_access;

import 'dart:async';
import 'dart:html';

import 'package:spark_widgets/spark_dialog/spark_dialog.dart';
import 'package:spark_widgets/spark_dialog_button/spark_dialog_button.dart';
import 'package:spark_widgets/spark_menu_button/spark_menu_button.dart';
import 'package:spark_widgets/spark_menu_item/spark_menu_item.dart';
import 'package:spark_widgets/spark_button/spark_button.dart';
import 'package:spark_widgets/spark_modal/spark_modal.dart';
import 'package:spark_widgets/spark_overlay/spark_overlay.dart';
import 'package:spark_widgets/common/spark_widget.dart';

import '../../spark_polymer_ui.dart';

class SparkDomAccess {
  static SparkDomAccess _instance;

  SparkMenuButton get menu => getUIElement("#mainMenu");
  Stream get onMenuTransitioned => _menuOverlay.on['transition-end'];

  SparkPolymerUI get _ui => document.querySelector('#topUi');
  SparkButton get _sparkMenuButton => getUIElement("#mainMenu > spark-button");
  SparkOverlay get _menuOverlay => menu.getShadowDomElement("#overlay");

  Element getUIElement(String selectors) => _ui.getShadowDomElement(selectors);

  static SparkDomAccess get instance {
    if (_instance == null) _instance = new SparkDomAccess._internal();
    return _instance;
  }

  SparkDomAccess._internal();

  void _sendMouseEvent(Element element, String eventType) {
    Rectangle<int> bounds = element.getBoundingClientRect();
    element.dispatchEvent(new MouseEvent(eventType,
        clientX: bounds.left.toInt() + bounds.width ~/ 2,
        clientY: bounds.top.toInt() + bounds.height ~/ 2));
  }

  void _sendKeyEvent(Element element, String eventType, int keyCode) {
    Rectangle<int> bounds = element.getBoundingClientRect();
    element.dispatchEvent(new KeyEvent(eventType, keyCode: keyCode));
  }

  Future selectSparkMenu() {
    Future transitionFuture = onMenuTransitioned.first;
    var sparkMenuButton = _sparkMenuButton;
    clickElement(sparkMenuButton);
    return transitionFuture;
  }

  void clickElement(Element element) {
    _sendMouseEvent(element, "mouseover");
    _sendMouseEvent(element, "mousedown");
    _sendMouseEvent(element, "click");
    _sendMouseEvent(element, "mouseup");
  }

  // TODO(ericarnold): This doesn't work
  void sendKey(Element element, int keyCode) {
    var streamDown = KeyEvent.keyDownEvent.forTarget(document.body);
    var streamPress = KeyEvent.keyPressEvent.forTarget(document.body);
    var streamUp = KeyEvent.keyUpEvent.forTarget(document.body);

    // TODO(ericarnold): Add keydown for modifiers for this character
    streamDown.add(new KeyEvent('keydown', keyCode: keyCode));
    streamPress.add(new KeyEvent('keypress', keyCode: keyCode));
    streamUp.add(new KeyEvent('keyup', keyCode: keyCode));
    // TODO(ericarnold): Add keyup for modifiers for this character
  }

  Future sendString(InputElement input, String text, [bool useKeys]) {
    input.focus();
    if (!useKeys) {
      input.dispatchEvent(new TextEvent('textInput', data: text));
    } else {
      text.codeUnits.forEach((int keyCode) => sendKey(input, keyCode));
    }
    return new Future.value();
  }
}

class SparkUIAccess {
  static SparkUIAccess _instance;

  OkCancelDialogAccess okCancelDialog = new OkCancelDialogAccess();
  AboutDialogAccess aboutDialog = new AboutDialogAccess();
  NewProjectDialogAccess newProjectDialog = new NewProjectDialogAccess();
  DialogAccess gitCloneDialog = new DialogAccess("gitCloneDialog");

  MenuItemAccess newProjectMenu;
  MenuItemAccess gitCloneMenu;
  MenuItemAccess aboutMenu;

  static SparkUIAccess get instance {
    if (_instance == null) _instance = new SparkUIAccess._internal();
    return _instance;
  }

  SparkUIAccess._internal() {
    newProjectMenu = new MenuItemAccess("project-new", newProjectDialog);
    gitCloneMenu = new MenuItemAccess("git-clone", gitCloneDialog);
    aboutMenu = new MenuItemAccess("help-about", aboutDialog);
  }
}

class MenuItemAccess {
  final String _menuItemId;
  DialogAccess _dialogAccess = null;

  DialogAccess get dialogAccess => _dialogAccess;

  SparkUIAccess get _sparkUiAccess => SparkUIAccess.instance;
  SparkDomAccess get _sparkDomAccess => SparkDomAccess.instance;

  SparkMenuItem get _menuItem => _getMenuItem(_menuItemId);

  MenuItemAccess(this._menuItemId, [DialogAccess linkedDialogAccess]) {
    _dialogAccess = (linkedDialogAccess == null) ? null : linkedDialogAccess;
  }

  void select() => _sparkDomAccess.clickElement(_menuItem);

  SparkMenuItem _getMenuItem(String id) =>
      _sparkDomAccess.menu.querySelector("spark-menu-item[action-id=$id]");
}

class DialogAccess {
  final String id;

  SparkModal get modalElement => _dialog.getShadowDomElement("#modal");
  bool get opened => modalElement.opened;
  SparkWidget get closingXButton => _getBySelector("#closingX");

  bool get fullyVisible {
    Rectangle<int> bounds = modalElement.getBoundingClientRect();
    var elementFromPoint = _sparkDomAccess._ui.shadowRoot.elementFromPoint(
        bounds.left.toInt() + bounds.width ~/ 2,
        bounds.top.toInt() + bounds.height ~/ 2);
    SparkDialog dialog = _dialog;
    return elementFromPoint == _dialog || _dialog.contains(elementFromPoint);
  }

  Stream get onTransitionComplete => transitionCompleteController.stream;
  StreamController transitionCompleteController = new StreamController.broadcast();

  SparkUIAccess get _sparkUiAccess => SparkUIAccess.instance;

  SparkDomAccess get _sparkDomAccess => SparkDomAccess.instance;
  SparkDialog get _dialog => _sparkDomAccess.getUIElement("#$id");
  List<SparkDialogButton> get _dialogButtons =>
      _dialog.querySelectorAll("spark-dialog-button");

  DialogAccess(this.id) {
    SparkModal m = modalElement;
    m.on['transition-end'].listen((e) {
      transitionCompleteController.add(e);
    });
  }

  void clickButton(SparkWidget button) => _sparkDomAccess.clickElement(button);
//  void clickButtonWithTitle(String title) => clickButton(_getButtonByTitle(title));
//  void clickButtonWithSelector(String query) =>
//      clickButton(_getButtonBySelector(query));

  SparkWidget _getButtonByTitle(String title) =>
      _dialogButtons.firstWhere((b) => b.text.toLowerCase() == title.toLowerCase());

  Element _getBySelector(String query) {
    Element button = _dialog.querySelector(query);

    if (button == null) button = _dialog.getShadowDomElement(query);

    if (button == null) throw "Could not find button with selector $query";

    return button;
  }
}

class OkCancelDialogAccess extends DialogAccess {
  SparkDialogButton get okButton => _getButtonByTitle("ok");
  SparkDialogButton get cancelButton => _getButtonByTitle("cancel");

  OkCancelDialogAccess() : super("okCancelDialog");

  void clickOkButton() => _sparkDomAccess.clickElement(okButton);
  void clickCancelButton() => _sparkDomAccess.clickElement(cancelButton);
}

class AboutDialogAccess extends DialogAccess {
  SparkDialogButton get doneButton => _getButtonByTitle("done");

  AboutDialogAccess() : super("aboutDialog");

  void clickDoneButton() => _sparkDomAccess.clickElement(doneButton);
}

class NewProjectDialogAccess extends DialogAccess {
  SparkDialogButton get createButton => _getButtonByTitle("Create");
  SparkDialogButton get cancelButton => _getButtonByTitle("Cancel");
  Element get nameField => _getBySelector("#name");

  NewProjectDialogAccess() : super("newProjectDialog");

  void clickCreateButton() => _sparkDomAccess.clickElement(createButton);

  void setNameField(String text) {
    var nameField = this.nameField;
    _sparkDomAccess.sendString(nameField, text, false);
  }
}

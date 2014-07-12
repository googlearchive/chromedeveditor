// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.workspace_test;

import 'dart:async';
import 'dart:html';

import 'package:spark_widgets/spark_dialog/spark_dialog.dart';
import 'package:spark_widgets/spark_dialog_button/spark_dialog_button.dart';
import 'package:spark_widgets/spark_menu_button/spark_menu_button.dart';
import 'package:spark_widgets/spark_menu_item/spark_menu_item.dart';
import 'package:spark_widgets/spark_button/spark_button.dart';
import 'package:spark_widgets/spark_modal/spark_modal.dart';
import 'package:spark_widgets/common/spark_widget.dart';

import 'package:unittest/unittest.dart';

import '../../spark_polymer_ui.dart';

class SparkUIAccess {
  static SparkUIAccess _instance;

  factory SparkUIAccess() {
    if (_instance == null) _instance = new SparkUIAccess._internal();
    return _instance;
  }

  SparkUIAccess._internal();

  SparkPolymerUI get _ui => document.querySelector('#topUi');
  Element getUIElement(String selectors) => _ui.getShadowDomElement(selectors);
  void _sendMouseEvent(Element element, String eventType) {
    Rectangle<int> bounds = element.getBoundingClientRect();
    element.dispatchEvent(new MouseEvent(eventType,
        clientX: bounds.left.toInt() + bounds.width ~/ 2,
        clientY:bounds.top.toInt() + bounds.height ~/ 2));
  }

  SparkButton get _menuButton => getUIElement("#mainMenu > spark-button");

  SparkMenuButton get menu => getUIElement("#mainMenu");
  void selectMenu() => _menuButton.click();

  MenuItemAccess newProjectMenu =
      new MenuItemAccess("project-new", "newProjectDialog");

  void clickElement(Element element) {
    _sendMouseEvent(element, "mouseover");
    _sendMouseEvent(element, "click");
  }
}

class MenuItemAccess {
  String _menuItemId;
  DialogAccess _dialog = null;

  MenuItemAccess(this._menuItemId, [String _dialogId]) {
    if (_dialogId != null) {
      _dialog = new DialogAccess(_dialogId);
    }
  }

  SparkUIAccess get _sparkAccess => new SparkUIAccess();

  List<SparkMenuItem> get _menuItems => _sparkAccess.menu.querySelectorAll("spark-menu-item");
  SparkMenuItem _getMenuItem(String id) {
      return _menuItems.firstWhere((SparkMenuItem item) =>
          item.attributes["action-id"] == id);
  }

  SparkMenuItem get _menuItem => _menuItems.firstWhere((SparkMenuItem item) =>
      item.attributes["action-id"] == _menuItemId);

  DialogAccess get dialog => _dialog;

  void select() => _sparkAccess.clickElement(_menuItem);
}

class DialogAccess {
  String _id;
  SparkUIAccess get _sparkAccess => new SparkUIAccess();

  DialogAccess(this._id);

  SparkDialog get _dialog => _sparkAccess.getUIElement("#$_id");

  SparkModal get _modalElement => _dialog.getShadowDomElement("#modal");

  List<SparkDialogButton> get _dialogButtons =>
      _dialog.querySelectorAll("spark-dialog-button");


  SparkWidget _getButtonByTitle(String title) {
    for (SparkWidget button in _dialogButtons) {
      if (button.text.toLowerCase() == title.toLowerCase()) {
        return button;
      }
    }

    throw "Could not find button with title $title";
  }

  SparkWidget _getButtonById(String id) {
    SparkWidget button = _dialog.querySelector("#$id");

    if (button == null) button = _dialog.getShadowDomElement("#$id");

    if (button == null) throw "Could not find button with id id";

    return button;
  }

  String get id => _id;

  bool get opened => _modalElement.opened;

  void clickButtonWithTitle(String title) =>
      _sparkAccess.clickElement(_getButtonByTitle(title));

  void clickButtonWithId(String id) =>
      _sparkAccess.clickElement(_getButtonById(id));
}

class DialogTester {
  DialogAccess dialogAccess;

  DialogTester(this.dialogAccess);

  bool get functionallyOpened => dialogAccess.opened;

  bool get visuallyOpened {
    CssStyleDeclaration style = dialogAccess._modalElement.getComputedStyle();
    String opacity = style.opacity;
    String display = style.display;
    String visibility = style.visibility;

    return int.parse(opacity) > 0 && display != "none" && visibility == "visible";
  }

  void clickClosingX() => dialogAccess.clickButtonWithId("closingX");
}

class SparkUITester {
  SparkUIAccess get sparkAccess => new SparkUIAccess();

  SparkUITester();

  Future openAndCloseWithX(MenuItemAccess menuItem) {
    DialogTester dialogTester = new DialogTester(menuItem.dialog);

    expect(dialogTester.functionallyOpened, false);
    expect(dialogTester.visuallyOpened, false);

    menuItem.select();

    return new Future.delayed(const Duration(milliseconds: 1000)).then((_){
      expect(dialogTester.functionallyOpened, true);
      expect(dialogTester.visuallyOpened, true);
      dialogTester.clickClosingX();
    }).then((_) => new Future.delayed(const Duration(milliseconds: 1000))
    ).then((_) {
      expect(dialogTester.functionallyOpened, false);
      expect(dialogTester.visuallyOpened, false);
    });
  }
}

defineTests() {
//  group('first run', () {
//    test('ensure about dialog open', () {
//      ModalUITester modalTester = new ModalUITester("aboutDialog");
//      expect(modalTester.functionallyOpened, true);
//      expect(modalTester.visuallyOpened, true);
//    });
//
//    test('close dialog', () {
//      ModalUITester modalTester = new ModalUITester("aboutDialog");
//      modalTester.clickButtonWithTitle("done");
//      expect(modalTester.functionallyOpened, false);
//
//      return new Future.delayed(const Duration(milliseconds: 1000)).then((_){
//        expect(modalTester.visuallyOpened, false);
//      });
//    });
//  });
  SparkUITester sparkTester = new SparkUITester();

  group('new-project dialog', () {
    test('open and close the dialog via x button', () {
      sparkTester.openAndCloseWithX(sparkTester.sparkAccess.newProjectMenu);
    });
  });

//  group('git-clone dialog', () {
//    test('open and close the dialog via x button', () {
//      sparkTester.openAndCloseWithX("gitCloneDialog", sparkTester.newProjectMenu);
//    });
//  });
//
//  group('about dialog', () {
//    test('open and close the dialog via x button', () {
//      sparkTester.openAndCloseWithX("aboutDialog");
//    });
//  });
//
}

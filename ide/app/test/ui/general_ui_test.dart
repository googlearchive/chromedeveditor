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
import 'package:unittest/unittest.dart';

import '../../spark_polymer_ui.dart';

class UITester {
  SparkPolymerUI get ui => document.querySelector('#topUi');
  Element getUIElement(String selectors) => ui.getShadowDomElement(selectors);
  void sendMouseEvent(Element element, String eventType) {
    Rectangle<int> bounds = element.getBoundingClientRect();
    element.dispatchEvent(new MouseEvent(eventType,
        clientX: bounds.left.toInt() + bounds.width ~/ 2,
        clientY:bounds.top.toInt() + bounds.height ~/ 2));
  }

  void clickElement(Element element) {
    sendMouseEvent(element, "mouseover");
    sendMouseEvent(element, "click");
  }
}

class SparkUITester extends UITester {
  SparkMenuButton get menu => getUIElement("#mainMenu");
  SparkButton get menuButton => getUIElement("#mainMenu > spark-button");
  void selectMenu() => menuButton.click();
  List<SparkMenuItem> get menuItems => menu.querySelectorAll("spark-menu-item");
  SparkMenuItem getMenuItem(String id) {
      return menuItems.firstWhere((SparkMenuItem item) =>
          item.attributes["action-id"] == id);
  }
  SparkMenuItem get newProjectMenu => getMenuItem("project-new");
  void selectNewProject() {
    SparkMenuItem item = newProjectMenu;
    clickElement(item);
  }
}

class ModalUITester extends UITester {
  String id;

  SparkDialog get dialog => getUIElement("#$id");
  SparkModal get modalElement => dialog.getShadowDomElement("#modal");
  bool get functionallyOpened => modalElement.opened;

  bool get visuallyOpened {
    CssStyleDeclaration style = modalElement.getComputedStyle();
    String opacity = style.opacity;
    String display = style.display;
    String visibility = style.visibility;

    return int.parse(opacity) > 0 && display != "none" && visibility == "visible";
  }

  List<SparkDialogButton> get buttons =>
      dialog.querySelectorAll("spark-dialog-button");

  ModalUITester(this.id);

  SparkDialogButton getButton(String title) {
    for (SparkDialogButton button in buttons) {
      if (button.text.toLowerCase() == title.toLowerCase()) {
        return button;
      }
    }

    throw "Could not find button with title $title";
  }

  void clickButton(String title) => clickElement(getButton(title));
}

defineTests() {
  /*
  group('first run', () {
    test('ensure about dialog open', () {
      ModalUITester modalTester = new ModalUITester("aboutDialog");
      expect(modalTester.functionallyOpened, true);
      expect(modalTester.visuallyOpened, true);
    });

    test('close dialog', () { // 10 26107
      ModalUITester modalTester = new ModalUITester("aboutDialog");
      modalTester.clickButton("done");
      expect(modalTester.functionallyOpened, false);

      return new Future.delayed(const Duration(milliseconds: 1000)).then((_){
        expect(modalTester.visuallyOpened, false);
      });
    });
  });
  */
  group('dialogs', () {
    test('ensure about dialog open', () {
      SparkUITester sparkTester = new SparkUITester();
      sparkTester.selectMenu();
      return new Future.delayed(const Duration(milliseconds: 2000)).then((_){
        sparkTester.selectNewProject();
      });
    });
  });

}

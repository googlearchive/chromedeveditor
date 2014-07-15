// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui_testing;

import 'dart:async';
import 'dart:html';

import 'package:spark_widgets/spark_dialog/spark_dialog.dart';
import 'package:spark_widgets/spark_dialog_button/spark_dialog_button.dart';
import 'package:spark_widgets/spark_modal/spark_modal.dart';
import 'package:unittest/unittest.dart';

import '../../spark_polymer_ui.dart';

class UITester {
  SparkPolymerUI get ui => document.querySelector('#topUi');
  Element getUIElement(String selectors) => ui.getShadowDomElement(selectors);
}

class ModalUITester extends UITester {
  final String id;

  ModalUITester(this.id);

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

  SparkDialogButton getButton(String title) {
    for (SparkDialogButton button in buttons) {
      if (button.text.toLowerCase() == title.toLowerCase()) {
        return button;
      }
    }

    throw "Could not find button with title $title";
  }

  void clickButton(String title) {
    SparkDialogButton button = getButton(title);
    Rectangle<int> bounds = button.getBoundingClientRect();
    button.dispatchEvent(new MouseEvent("click",
        clientX: bounds.left.toInt() + 1, clientY:bounds.top.toInt() + 1));
  }
}

defineTests() {
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
}

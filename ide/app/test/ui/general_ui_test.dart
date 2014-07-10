// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.workspace_test;

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
  String id;

  SparkDialog get dialog => getUIElement("#$id");
  SparkModal get modalElement => dialog.getShadowDomElement("#modal");
  bool get opened => modalElement.opened;
  List<SparkDialogButton> get buttons =>
      dialog.querySelectorAll("spark-dialog-button");

  ModalUITester(this.id);

  SparkDialogButton getButton(String title) {
    for (SparkDialogButton button in buttons) {
      if (button.title.toLowerCase() == title.toLowerCase()) {
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
      expect(modalTester.opened, true);
    });

    test('close dialog', () {
      ModalUITester modalTester = new ModalUITester("aboutDialog");
      modalTester.clickButton("done");
      expect(modalTester.opened, true);
    });
  });
}

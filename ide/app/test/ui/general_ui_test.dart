// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.workspace_test;

import 'package:spark_widgets/spark_dialog_button/spark_dialog_button.dart';
import 'package:spark_widgets/spark_modal/spark_modal.dart';
import '../../spark_polymer_ui.dart';
import 'package:unittest/unittest.dart';
import 'package:spark_widgets/spark_dialog/spark_dialog.dart';
import 'dart:html';


defineTests() {
  SparkPolymerUI getUi() => document.querySelector('#topUi');
  Element getUIElement(String selectors) => getUi().getShadowDomElement(selectors);

  group('first run', () {
    test('ensure about dialog open', () {
      SparkDialog dialog = getUIElement('#aboutDialog');
      SparkModal modalEl = dialog.getShadowDomElement("#modal");
      expect(modalEl.opened, true);
    });

    test('close dialog', () {
      SparkDialog dialog = getUIElement('#aboutDialog');

      List<Element> buttonElements = dialog.querySelectorAll("spark-dialog-button");
      for (SparkDialogButton element in buttonElements) {
        Rectangle<int> bounds = element.getBoundingClientRect();
        element.dispatchEvent(new MouseEvent("click",
            clientX: bounds.left.toInt() + 1, clientY:bounds.top.toInt() + 1));
      }

      SparkModal modalEl = dialog.getShadowDomElement("#modal");
      expect(modalEl.opened, false);
    });
  });
}

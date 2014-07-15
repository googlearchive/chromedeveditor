// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.general_ui_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import 'ui_testing.dart';

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

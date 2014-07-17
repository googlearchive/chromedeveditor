// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.workspace_test;

import 'dart:async';
import 'dart:html';

import 'package:spark_widgets/spark_modal/spark_modal.dart';
import 'package:unittest/unittest.dart';

import "ui_access.dart";

class DialogTester {
  DialogAccess dialogAccess;

  DialogTester(this.dialogAccess);

  bool get functionallyOpened => dialogAccess.opened;

  bool get visuallyOpened {
//    SparkModal modalElement = dialogAccess.modalElement;
//    CssStyleDeclaration style = modalElement.getComputedStyle();
//    String opacity = style.opacity;
//    String display = style.display;
//    String visibility = style.visibility;

//    return int.parse(opacity) > 0 && display != "none" && visibility == "visible";
    return dialogAccess.fullyVisible;
  }

  void clickClosingX() => dialogAccess.clickButtonWithId("closingX");
}

class SparkUITester {
  SparkUITester();

  Future openAndCloseWithX(MenuItemAccess menuItem) {
    DialogTester dialogTester = new DialogTester(menuItem.dialog);

    expect(dialogTester.functionallyOpened, false);
    expect(dialogTester.visuallyOpened, false);

    menuItem.select();

    return menuItem.dialog.onTransitionComplete.first.then((_){
      expect(dialogTester.visuallyOpened, true);
      expect(dialogTester.functionallyOpened, true);
      dialogTester.clickClosingX();
    }).then((_) => new Future.delayed(const Duration(milliseconds: 1))
    ).then((_) => menuItem.dialog.onTransitionComplete.first
    ).then((_) {
      expect(dialogTester.functionallyOpened, false);
      expect(dialogTester.visuallyOpened, false);
    });
  }
}

defineTests() {
  SparkUITester sparkTester = new SparkUITester();
  SparkMenuAccess menuAccess = new SparkMenuAccess();

  group('first run', () {
//    test('ensure about dialog open', () {
//      ModalUITester modalTester = new ModalUITester("aboutDialog");
//      expect(modalTester.functionallyOpened, true);
//      expect(modalTester.visuallyOpened, true);
//    });

    test('close dialog', () {
      if (!modalTester.functionallyOpened) return;
      ModalUITester modalTester = new ModalUITester("aboutDialog");
      modalTester.clickButtonWithTitle("done");
      expect(modalTester.functionallyOpened, false);

      return new Future.delayed(const Duration(milliseconds: 1000)).then((_){
        expect(modalTester.visuallyOpened, false);
      });
    });
  });

  group('new-project dialog', () {
    test('open and close the dialog via x button', () {
      return sparkTester.openAndCloseWithX(menuAccess.newProjectMenu);
    });
  });

  group('git-clone dialog', () {
    test('open and close the dialog via x button', () {
      return sparkTester.openAndCloseWithX(menuAccess.gitCloneMenu);
    });
  });

  group('about dialog', () {
    test('open and close the dialog via x button', () {
      return sparkTester.openAndCloseWithX(menuAccess.gitCloneMenu);
    });
  });
}

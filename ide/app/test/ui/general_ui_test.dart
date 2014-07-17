// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.workspace_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import "ui_access.dart";

class DialogTester {
  DialogAccess dialogAccess;

  bool get functionallyOpened => dialogAccess.opened;

  bool get visuallyOpened {
    return dialogAccess.fullyVisible;
  }

  DialogTester(this.dialogAccess);

  void clickClosingX() => dialogAccess.clickButtonWithId("closingX");
  void clickCancelButton() => dialogAccess.clickButtonWithTitle("cancel");
}

class SparkUITester {
  SparkUIAccess get sparkAccess => new SparkUIAccess();

  SparkUITester();

  Future _open(DialogTester dialogTester, MenuItemAccess menuItem) {
    expect(dialogTester.functionallyOpened, false);
    expect(dialogTester.visuallyOpened, false);

    return sparkAccess.selectMenu().then((_){
      menuItem.select();
    }).then((_) => menuItem.dialog.onTransitionComplete.first
    ).then((_){
      expect(dialogTester.visuallyOpened, true);
      expect(dialogTester.functionallyOpened, true);
      // Let any other transitions finish
    }).then((_) => new Future.delayed(Duration.ZERO));
  }

  Future openAndCloseWithX(MenuItemAccess menuItem) {
    DialogTester dialogTester = new DialogTester(menuItem.dialog);
    return _open(dialogTester, menuItem).then((_) {
      dialogTester.clickClosingX();
      return menuItem.dialog.onTransitionComplete.first;
    }).then((_) {
      expect(dialogTester.functionallyOpened, false);
      expect(dialogTester.visuallyOpened, false);
    }).then((_) => new Future.delayed(Duration.ZERO));
  }

  Future openAndClose(MenuItemAccess menuItem) {
    DialogTester dialogTester = new DialogTester(menuItem.dialog);
    return _open(dialogTester, menuItem).then((_) {
      dialogTester.clickCancelButton();
      return menuItem.dialog.onTransitionComplete.first;
    }).then((_) {
      expect(dialogTester.functionallyOpened, false);
      expect(dialogTester.visuallyOpened, false);
    }).then((_) => new Future.delayed(Duration.ZERO));
  }
}

defineTests() {
  SparkUITester sparkTester = new SparkUITester();
  SparkUIAccess sparkAccess = new SparkUIAccess();

  group('first run', () {
    // TODO(ericarnold): Disabled for local testing
//    test('ensure about dialog open', () {
//      ModalUITester modalTester = new ModalUITester("aboutDialog");
//      expect(modalTester.functionallyOpened, true);
//      expect(modalTester.visuallyOpened, true);
//    });

    test('close dialog', () {
      DialogTester dialogTester = new DialogTester(sparkAccess.aboutDialog);
      if (!dialogTester.functionallyOpened) return null;
      dialogTester.dialogAccess.clickButtonWithTitle("done");
      expect(dialogTester.functionallyOpened, false);

      return new Future.delayed(const Duration(milliseconds: 1000)).then((_){
        expect(dialogTester.visuallyOpened, false);
      });
    });
  });

  group('new-project dialog', () {
    test('open and close the dialog via x button', () {
      return sparkTester.openAndCloseWithX(sparkAccess.newProjectMenu).then((_) {
        return sparkTester.openAndCloseWithX(sparkAccess.newProjectMenu);
      });
    });
  });

  group('git-clone dialog', () {
    test('open and close the dialog via x button', () {
      return sparkTester.openAndCloseWithX(sparkAccess.gitCloneMenu).then((_) {
        return sparkTester.openAndClose(sparkAccess.newProjectMenu);
      });
    });
  });

  group('about dialog', () {
    test('open and close the dialog via x button', () {
      return sparkTester.openAndCloseWithX(sparkAccess.aboutMenu);
    });
  });
}

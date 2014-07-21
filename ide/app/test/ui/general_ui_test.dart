// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.general_ui_test;

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

  void clickClosingX() => dialogAccess.clickButtonWithSelector("#closingX");
  void clickButtonWithTitle(String title) => dialogAccess.clickButtonWithTitle(title);
}

class SparkUITester {
  SparkUIAccess get sparkAccess => new SparkUIAccess();

  SparkUITester();

  Future _open(DialogTester dialogTester, MenuItemAccess menuItem) {
    expect(dialogTester.functionallyOpened, false);
    expect(dialogTester.visuallyOpened, false);

    return sparkAccess.selectMenu().then((_) {
      menuItem.select();
    }).then((_) => dialogTester.dialogAccess.onTransitionComplete.first
    // Let any other transitions finish
    ).then((_) => new Future.delayed(Duration.ZERO)
    ).then((_) {
      expect(dialogTester.visuallyOpened, true);
      expect(dialogTester.functionallyOpened, true);
    });
  }

  Future openAndCloseWithX(MenuItemAccess menuItem, [DialogAccess dialog]) {
    DialogTester dialogTester =
        new DialogTester(dialog != null ? dialog : menuItem.dialogAccess);
    return _open(dialogTester, menuItem).then((_) {
      dialogTester.clickClosingX();
      return dialogTester.dialogAccess.onTransitionComplete.first;
    }).then((_) {
      expect(dialogTester.functionallyOpened, false);
      expect(dialogTester.visuallyOpened, false);
    }).then((_) => new Future.delayed(Duration.ZERO));
  }

  Future openAndCloseWithButton(MenuItemAccess menuItem, String buttonTitle,
                                [DialogAccess dialog]) {
    DialogTester dialogTester =
        new DialogTester(dialog != null ? dialog : menuItem.dialogAccess);
    return _open(dialogTester, menuItem).then((_) {
      dialogTester.clickButtonWithTitle(buttonTitle);
      return dialogTester.dialogAccess.onTransitionComplete.first;
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
      dialogTester.clickButtonWithTitle("done");
      expect(dialogTester.functionallyOpened, false);

      return new Future.delayed(const Duration(milliseconds: 1000)).then((_) {
        expect(dialogTester.visuallyOpened, false);
      });
    });
  });

  group('Menu items with no projects folder selected', () {
    test('New project menu item', () {
      return sparkTester.openAndCloseWithX(sparkAccess.newProjectMenu,
          sparkAccess.okCancelDialog).then((_) {
            return sparkTester.openAndCloseWithButton(sparkAccess.newProjectMenu,
                "cancel", sparkAccess.okCancelDialog);
          });
    });

    test('Git clone menu item', () {
      return sparkTester.openAndCloseWithX(sparkAccess.gitCloneMenu,
          sparkAccess.okCancelDialog).then((_) {
            return sparkTester.openAndCloseWithButton(sparkAccess.gitCloneMenu,
                "cancel", sparkAccess.okCancelDialog);
          });
    });
  });

  group('about dialog', () {
    test('open and close the dialog via x button', () {
      return sparkTester.openAndCloseWithX(sparkAccess.aboutMenu).then((_) {
        return sparkTester.openAndCloseWithButton(sparkAccess.aboutMenu, "done");
      });
    });
  });
}

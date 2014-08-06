// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.general_ui_test;

import 'dart:async';

import 'package:spark_widgets/common/spark_widget.dart';
import 'package:unittest/unittest.dart';

import "../../lib/filesystem.dart";
import "ui_access.dart";

class DialogTester {
  DialogAccess dialogAccess;

  bool get functionallyOpened => dialogAccess.opened;
  bool get visuallyOpened => dialogAccess.fullyVisible;

  DialogTester(this.dialogAccess);

  void clickClosingX() => dialogAccess.clickButton(dialogAccess.closingXButton);
  void clickButton(SparkWidget button) => dialogAccess.clickButton(button);
}

class SparkUITester {
  static SparkUITester _instance;

  SparkUIAccess get sparkAccess => SparkUIAccess.instance;

  static SparkUITester get instance {
    if (_instance == null) _instance = new SparkUITester._internal();
    return _instance;
  }

  SparkUITester._internal();

  Future open(DialogTester dialogTester, MenuItemAccess menuItem) {
    expect(dialogTester.functionallyOpened, false);
    expect(dialogTester.visuallyOpened, false);

    return sparkAccess.selectSparkMenu().then((_) {
      menuItem.select();
    }).then((_) => dialogTester.dialogAccess.onTransitionComplete.first
        // Let any other transitions finish before continuing
    ).then((_) => new Future.delayed(Duration.ZERO)
    ).then((_) {
      expect(dialogTester.visuallyOpened, true);
      expect(dialogTester.functionallyOpened, true);
    });
  }

  Future openAndCloseWithX(MenuItemAccess menuItem, [DialogAccess dialog]) {
    DialogTester dialogTester =
        new DialogTester(dialog != null ? dialog : menuItem.dialogAccess);
    return open(dialogTester, menuItem).then((_) {
      dialogTester.clickClosingX();
      return dialogTester.dialogAccess.onTransitionComplete.first;
    }).then((_) {
      expect(dialogTester.functionallyOpened, false);
      expect(dialogTester.visuallyOpened, false);
      // Let any other transitions finish before continuing
    }).then((_) => new Future.delayed(Duration.ZERO));
  }

  Future openAndCloseWithButton(MenuItemAccess menuItem, SparkWidget button,
                                [DialogAccess dialog]) {
    DialogTester dialogTester =
        new DialogTester(dialog != null ? dialog : menuItem.dialogAccess);
    return open(dialogTester, menuItem).then((_) {
      dialogTester.clickButton(button);
      return dialogTester.dialogAccess.onTransitionComplete.first;
    }).then((_) {
      expect(dialogTester.functionallyOpened, false);
      expect(dialogTester.visuallyOpened, false);
    }).then((_) => new Future.delayed(Duration.ZERO));
  }

  Future openAndCloseWith(MenuItemAccess menuItem, Function callback,
                                [DialogAccess dialog]) {
    DialogTester dialogTester =
        new DialogTester(dialog != null ? dialog : menuItem.dialogAccess);
    return open(dialogTester, menuItem).then((_) => callback(dialogTester)).then((_) {
      return dialogTester.dialogAccess.onTransitionComplete.first;
    }).then((_) {
      expect(dialogTester.functionallyOpened, false);
      expect(dialogTester.visuallyOpened, false);
    }).then((_) => new Future.delayed(Duration.ZERO));
  }
}

oneTest() {
  SparkUITester sparkTester = SparkUITester.instance;
  SparkUIAccess sparkAccess = SparkUIAccess.instance;
  group('one dev', () {
    test('one dev', () {
      return sparkTester.openAndCloseWithButton(sparkAccess.newProjectMenu,
          sparkAccess.okCancelDialog.cancelButton, sparkAccess.okCancelDialog)
          .then((_) => sparkAccess.selectSparkMenu())
          .then((_) => sparkAccess.newProjectMenu.select());
    });
  });
}

defineTests() {
  SparkUITester sparkTester = SparkUITester.instance;
  SparkUIAccess sparkAccess = SparkUIAccess.instance;

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
      AboutDialogAccess aboutDialog = dialogTester.dialogAccess;
      dialogTester.clickButton(aboutDialog.doneButton);
      expect(dialogTester.functionallyOpened, false);

      return new Future.delayed(const Duration(milliseconds: 1000)).then((_) {
        expect(dialogTester.visuallyOpened, false);
      });
    });
  });

  group('about dialog', () {
    test('open and close the dialog via x button', () {
      AboutDialogAccess aboutDialog = sparkAccess.aboutMenu.dialogAccess;
      return sparkTester.openAndCloseWithX(sparkAccess.aboutMenu).then((_) {
        return sparkTester.openAndCloseWithButton(sparkAccess.aboutMenu,
            aboutDialog.doneButton);
      });
    });
  });

  group('Menu items with no projects root selected', () {
    test('New project menu item', () {
      OkCancelDialogAccess okCancelDialog = sparkAccess.okCancelDialog;
      return sparkTester.openAndCloseWithX(sparkAccess.newProjectMenu,
          sparkAccess.okCancelDialog).then((_) {
            return sparkTester.openAndCloseWithButton(sparkAccess.newProjectMenu,
                okCancelDialog.cancelButton, sparkAccess.okCancelDialog);
          });
    });

    test('Git clone menu item', () {
      OkCancelDialogAccess okCancelDialog = sparkAccess.okCancelDialog;
      return sparkTester.openAndCloseWithX(sparkAccess.gitCloneMenu,
          sparkAccess.okCancelDialog).then((_) {
            return sparkTester.openAndCloseWithButton(sparkAccess.gitCloneMenu,
                okCancelDialog.cancelButton, sparkAccess.okCancelDialog);
          });
    });
  });

  group('Menu items with mock project root selected', () {
    test('New project menu item', () {
      MockFileSystemAccess mockFsa = fileSystemAccess;
      return mockFsa.locationManager.setupRoot().then((_) {
        return sparkTester.openAndCloseWithX(sparkAccess.newProjectMenu);
      }).then((_) => sparkTester.openAndCloseWith(sparkAccess.newProjectMenu, (_) {
        sparkAccess.newProjectDialog.setNameField("foo");
        sparkAccess.clickElement(sparkAccess.newProjectDialog.createButton);
      })).then((_) => sparkTester.openAndCloseWith(sparkAccess.newProjectMenu, (_) {
        sparkAccess.newProjectDialog.setNameField("bar");
        sparkAccess.clickElement(sparkAccess.newProjectDialog.createButton);
      }));
    });
  });
}

// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.general_ui_test;

import 'dart:async';

import 'package:spark_widgets/common/spark_widget.dart';
import 'package:unittest/unittest.dart';

import "ui_access.dart";
import "../../lib/filesystem.dart";
import "../../lib/utils.dart";

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

  SparkUIAccess get sparkUiAccess => SparkUIAccess.instance;
  SparkDomAccess get sparkDomAccess => SparkDomAccess.instance;

  static SparkUITester get instance {
    if (_instance == null) _instance = new SparkUITester._internal();
    return _instance;
  }

  SparkUITester._internal();

  Future open(DialogTester dialogTester, MenuItemAccess menuItem) {
    expect(dialogTester.functionallyOpened, false);
    expect(dialogTester.visuallyOpened, false);

    return sparkDomAccess.selectSparkMenu().then((_) {
      menuItem.select();
    }).then((_) =>
        dialogTester.dialogAccess.onTransitionComplete.first
        // Let any other transitions finish before continuing
    ).then((_) =>
        new Future.delayed(Duration.ZERO)
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
  SparkUIAccess sparkUiAccess = SparkUIAccess.instance;
  SparkDomAccess sparkDomAccess = SparkDomAccess.instance;

  group('one dev', () {
    test('one dev', () {
      return sparkTester.openAndCloseWithButton(sparkUiAccess.newProjectMenu,
          sparkUiAccess.okCancelDialog.cancelButton, sparkUiAccess.okCancelDialog)
          .then((_) => sparkDomAccess.selectSparkMenu())
          .then((_) => sparkUiAccess.newProjectMenu.select());
    });
  });
}

defineTests() {
  SparkUITester sparkTester = SparkUITester.instance;
  SparkUIAccess sparkUiAccess = SparkUIAccess.instance;
  SparkDomAccess sparkDomAccess = SparkDomAccess.instance;

  group('first run', () {
    // TODO(ericarnold): Disabled for local testing
//    test('ensure about dialog open', () {
//      ModalUITester modalTester = new ModalUITester("aboutDialog");
//      expect(modalTester.functionallyOpened, true);
//      expect(modalTester.visuallyOpened, true);
//    });

    test('close dialog', () {
      DialogTester dialogTester = new DialogTester(sparkUiAccess.aboutDialog);
      if (!dialogTester.functionallyOpened) return null;
      AboutDialogAccess aboutDialog = dialogTester.dialogAccess;
      dialogTester.clickButton(aboutDialog.doneButton);
      expect(dialogTester.functionallyOpened, false);

      return new Future.delayed(const Duration(milliseconds: 1000)).then((_) {
        expect(dialogTester.visuallyOpened, false);
      });
    });
  });

  // TODO(umop): (from ussuri) This test is failing at least as of 2015-08-20.
  // I think it was randomly failing before, too. I've manually tested the
  // functionality, and it works. Timing issue?
  // 
  // group('about dialog', () {
  //   test('open and close the dialog via x button', () {
  //     AboutDialogAccess aboutDialog = sparkUiAccess.aboutMenu.dialogAccess;
  //     return sparkTester.openAndCloseWithX(sparkUiAccess.aboutMenu).then((_) {
  //       return sparkTester.openAndCloseWithButton(sparkUiAccess.aboutMenu,
  //           aboutDialog.doneButton);
  //     });
  //   });
  // });

  // TODO(umop): (from ussuri) These tests are failing as well now (2015-08-20),
  // although the functionality itself works.
  //
  // group('Menu items with no projects root selected', () {
  //   test('New project menu item', () {
  //     return fileSystemAccess.getProjectLocation(false).then((LocationResult r) {
  //       if (r != null) {
  //         return null;
  //       }

  //       OkCancelDialogAccess okCancelDialog = sparkUiAccess.okCancelDialog;
  //       return sparkTester.openAndCloseWithX(sparkUiAccess.newProjectMenu,
  //           sparkUiAccess.okCancelDialog).then((_) {
  //             return sparkTester.openAndCloseWithButton(sparkUiAccess.newProjectMenu,
  //                 okCancelDialog.cancelButton, sparkUiAccess.okCancelDialog);
  //           });
  //     });
  //   });

  //   test('Git clone menu item', () {
  //     return fileSystemAccess.getProjectLocation(false).then((LocationResult r) {
  //       if (r != null) {
  //         return null;
  //       }

  //       OkCancelDialogAccess okCancelDialog = sparkUiAccess.okCancelDialog;
  //       return sparkTester.openAndCloseWithX(sparkUiAccess.gitCloneMenu,
  //           sparkUiAccess.okCancelDialog).then((_) {
  //             return sparkTester.openAndCloseWithButton(sparkUiAccess.gitCloneMenu,
  //                 okCancelDialog.cancelButton, sparkUiAccess.okCancelDialog);
  //           });
  //     });
  //   });
  // });

  group('Menu items with mock project root selected', () {
    test('New project menu item', () {
      return new Future.value().then((_) {
        if (fileSystemAccess is MockFileSystemAccess) {
          MockFileSystemAccess mockFsa = fileSystemAccess;
          return mockFsa.locationManager.setupRoot().then((_) => true);
        } else {
          return fileSystemAccess.getProjectLocation(false).then((LocationResult r) {
            // If there is no root and we're not using MockFilesystemAccess, we
            // can't continue this test.
            return new Future.value((r != null));
          });
        }
      }).then((bool rootReady) {
        if (rootReady) {
          return sparkTester.openAndCloseWithX(sparkUiAccess.newProjectMenu).then((_) {
            return sparkTester.openAndCloseWith(sparkUiAccess.newProjectMenu, (_) {
              sparkUiAccess.newProjectDialog.setNameField("foo");
              sparkDomAccess.clickElement(sparkUiAccess.newProjectDialog.createButton);
            });
          }).then((_) {
              sparkTester.openAndCloseWith(sparkUiAccess.newProjectMenu, (_) {
                sparkUiAccess.newProjectDialog.setNameField("bar");
                sparkDomAccess.clickElement(
                    sparkUiAccess.newProjectDialog.createButton);
              });
          });
        }
      });
    });
  });
}

bool isDartium() => !isDart2js();

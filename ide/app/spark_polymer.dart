// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer;

import 'dart:html';

import 'package:bootjack/bootjack.dart' as bootjack;
import 'package:polymer/polymer.dart' as polymer;

import 'spark.dart';
import 'lib/actions.dart';
import 'lib/polymer_ui/spark_polymer_ui.dart';

void main() {
  isTestMode().then((testMode) {
    polymer.initPolymer().run(() {
      SparkPolymer spark = new SparkPolymer(testMode);
      spark.start();
    });
  });
}

class SparkPolymer extends Spark {
  SparkPolymerUI _ui;

  SparkPolymer(bool developerMode)
      : _ui = document.querySelector('#topUi') as SparkPolymerUI,
        super(developerMode);

  @override
  Element getUIElement(String selectors) => _ui.getShadowDomElement(selectors);


  // Dialogs are located inside <spark-polymer-ui> shadowDom.
  @override
  Element getDialogElement(String selectors) =>
      _ui.getShadowDomElement(selectors);

  //
  // Override some parts of the parent's ctor:
  //

  @override
  String get appName => super.appName + "Polymer";

  @override
  void initAnalytics() => super.initAnalytics();

  @override
  void initWorkspace() => super.initWorkspace();

  @override
  void createEditorComponents() => super.createEditorComponents();

  @override
  void initEditorManager() => super.initEditorManager();

  @override
  void initEditorArea() => super.initEditorArea();

  // We're using a Polymer-based splitview, so disable the default.
  @override
  void initSplitView() => null;

  @override
  void initFilesController() => super.initFilesController();

  @override
  void initLookAndFeel() {
    // Init the Bootjack library (a wrapper around Bootstrap).
    bootjack.Bootjack.useDefault();
  }

  @override
  void createActions() => super.createActions();

  @override
  void initToolbar() => super.initToolbar();

  @override
  void buildMenu() {
    // TODO(ussuri): This is a temporary hack just to test the functionality
    // triggered from the menu. This will be replaced by spark-menu ASAP.
    UListElement ul = getUIElement('#hotdogMenu ul');

    ul.children.add(createMenuItem(actionManager.getAction('file-open')));
    ul.children.add(createMenuItem(actionManager.getAction('folder-open')));
    ul.children.add(createMenuItem(actionManager.getAction('file-close')));
    ul.children.add(createMenuItem(actionManager.getAction('file-delete')));

    ul.children.add(createMenuSeparator());

    // Theme control.
    // NOTE: Disabled because doing this resulted in a crash.
//    Element theme = ul.querySelector('#changeTheme');
//    ul.children.remove(theme);
//    ul.children.add(theme);
    ul.querySelector('#themeLeft').onClick.listen((e) => aceThemeManager.dec(e));
    ul.querySelector('#themeRight').onClick.listen((e) => aceThemeManager.inc(e));

    // Key binding control.
//    Element keys = ul.querySelector('#changeKeys');
//    ul.children.remove(keys);
//    ul.children.add(keys);
    ul.querySelector('#keysLeft').onClick.listen((e) => aceKeysManager.dec(e));
    ul.querySelector('#keysRight').onClick.listen((e) => aceKeysManager.inc(e));

    if (developerMode) {
      ul.children.add(createMenuSeparator());
      ul.children.add(createMenuItem(actionManager.getAction('run-tests')));
      ul.children.add(createMenuItem(actionManager.getAction('git-clone')));
    }

    ul.children.add(createMenuSeparator());
    ul.children.add(createMenuItem(actionManager.getAction('help-about')));
  }

  //
  // - End parts of the parent's ctor.
  //

  // TODO(terry): Hookup overlay dialog.
  @override
  void showStatus(String text, {bool error: false}) {
    // TEMP:
    //Element element = querySelector("#status");
    //element.text = text;
    //SparkOverlay overlay = querySelector("#spark-dialog");
    //if (overlay != null) {
    //  overlay.toggle();
    //}
  }
}

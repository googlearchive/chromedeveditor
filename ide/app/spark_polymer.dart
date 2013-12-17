// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer;

import 'dart:async';
import 'dart:html';

import 'package:bootjack/bootjack.dart' as bootjack;
import 'package:polymer/polymer.dart' as polymer;
import 'package:spark_widgets/spark-overlay/spark-overlay.dart' as widgets;

import 'spark.dart';
import 'lib/actions.dart';
import 'lib/polymer_ui/spark_polymer_ui.dart';

SparkPolymer spark = null;

void main() {
  isTestMode().then((testMode) {
    polymer.initPolymer().run(() {
      createSparkZone().runGuarded(() {
        spark = new SparkPolymer._(testMode);
        spark.start();
      });
    });
  });
}

class SparkPolymerDialog implements SparkDialog {
  widgets.SparkOverlay _dialogElement;

  SparkPolymerDialog(Element dialogElement)
      : _dialogElement = dialogElement;

  void show() => _dialogElement.toggle();

  void hide() => _dialogElement.toggle();

  Element get element => _dialogElement;
}

class SparkPolymer extends Spark {
  SparkPolymerUI _ui;

  SparkPolymer._(bool developerMode)
      : _ui = document.querySelector('#topUi') as SparkPolymerUI,
        super(developerMode);

  @override
  Element getUIElement(String selectors) => _ui.getShadowDomElement(selectors);

  @override
  Element getUIElementFromPoint(polymer.PolymerElement elem, int x, int y) =>
      elem.shadowRoot.elementFromPoint(x, y);

  // Dialogs are located inside <spark-polymer-ui> shadowDom.
  @override
  Element getDialogElement(String selectors) =>
      _ui.getShadowDomElement(selectors);

  @override
  SparkDialog createDialog(Element dialogElement) =>
      new SparkPolymerDialog(dialogElement);

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
    // TODO(ussuri): This is a temporary hack. This will be replaced by the
    // preferences dialog.
    UListElement oldMenu = getUIElement('#hotdogMenu ul');

    // Theme control.
    oldMenu.querySelector('#themeLeft').onClick.listen(
        (e) => aceThemeManager.dec(e));
    oldMenu.querySelector('#themeRight').onClick.listen(
        (e) => aceThemeManager.inc(e));

    // Key binding control.
    oldMenu.querySelector('#keysLeft').onClick.listen(
        (e) => aceKeysManager.dec(e));
    oldMenu.querySelector('#keysRight').onClick.listen(
        (e) => aceKeysManager.inc(e));
  }

  void onMenuSelected(var event, Map<String, dynamic> detail) {
    final item = detail['item'];
    final actionId = item.attributes['actionId'];
    var action = actionManager.getAction(actionId);
    assert(action != null);
    action.invoke();
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

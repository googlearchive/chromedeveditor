// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer;

import 'dart:async';
import 'dart:html';

import 'package:bootjack/bootjack.dart' as bootjack;
import 'package:polymer/polymer.dart' as polymer;

// BUG(ussuri): https://github.com/dart-lang/spark/issues/500
import 'packages/spark_widgets/spark_button/spark_button.dart';
import 'packages/spark_widgets/spark_overlay/spark_overlay.dart';
import 'packages/spark_widgets/spark_splitter/spark_splitter.dart';

import 'spark.dart';
import 'spark_polymer_ui.dart';
import 'lib/actions.dart';

void main() {
  isTestMode().then((testMode) {
    polymer.initPolymer().run(() {
      createSparkZone().runGuarded(() {
        SparkPolymer spark = new SparkPolymer._(testMode);
        spark.start();
      });
    });
  });
}

class SparkPolymerDialog implements SparkDialog {
  SparkOverlay _dialogElement;

  SparkPolymerDialog(Element dialogElement)
      : _dialogElement = dialogElement {
    // TODO(ussuri): Encapsulate backdrop in SparkOverlay.
    _dialogElement.on['opened'].listen((event) {
      var appModal = querySelector("#modalBackdrop");
      appModal.style.display = event.detail ? "block" : "none";
    });
  }

  void show() => _dialogElement.toggle();

  // TODO(ussuri): Currently, this never gets called (the dialog closes in
  // another way). Make symmetrical when merging Polymer and non-Polymer.
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
  String get appName => super.appName;

  @override
  void initAnalytics() => super.initAnalytics();

  @override
  void initWorkspace() => super.initWorkspace();

  @override
  void createEditorComponents() => super.createEditorComponents();

  @override
  void initActivitySpinner() => super.initActivitySpinner();

  @override
  void initEditorManager() => super.initEditorManager();

  @override
  void initEditorArea() => super.initEditorArea();

  @override
  void initSplitView() {
    syncPrefs.getValue('splitViewPosition').then((String position) {
      if (position != null) {
        int value = int.parse(position, onError: (_) => 0);
        if (value != 0) {
          (getUIElement('#splitter') as SparkSplitter).targetSize = value;
        }
      }
    });
  }

  @override
  void initSaveStatusListener() => super.initSaveStatusListener();

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
  void initToolbar() {
    super.initToolbar();

    _bindButtonToAction('openFile', 'file-open');
    _bindButtonToAction('newFile', 'file-new');
    _bindButtonToAction('runButton', 'application-run');
  }

  @override
  void buildMenu() {}

  //
  // - End parts of the parent's ctor.
  //

  @override
  void onSplitViewUpdate(int position) {
    syncPrefs.setValue('splitViewPosition', position.toString());
  }

  void _bindButtonToAction(String buttonId, String actionId) {
    SparkButton button = getUIElement('#${buttonId}');
    Action action = actionManager.getAction(actionId);
    action.onChange.listen((_) {
      button.active = action.enabled;
    });
    button.onClick.listen((_) {
      if (action.enabled) action.invoke();
    });
    button.active = action.enabled;
  }
}

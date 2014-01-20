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
import 'lib/jobs.dart';

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
      SparkPolymer.backdropShowing = event.detail;
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

  Future<bool> invokeSystemDialog(dialogFuture) {
    backdropShowing = true;
    Timer timer =
        new Timer(new Duration(milliseconds: 100), () =>
            (dialogFuture.whenComplete(() =>
                backdropShowing = false)));
  }

  Future<bool> _beforeSystemModal() {
    Completer completer = new Completer();
    backdropShowing = true;

    Timer timer =
        new Timer(new Duration(milliseconds: 100), () {
          completer.complete();
        });

    return completer.future;
  }

  Future<bool> _systemModalComplete() {
    backdropShowing = false;
  }

  Future<bool> openFolder() {
    _beforeSystemModal().then((_) =>
        super.openFolder().whenComplete(() => _systemModalComplete()));
  }

  Future<bool> openFile() {
    _beforeSystemModal().then((_) =>
        super.openFile().whenComplete(() => _systemModalComplete()));
  }

  Future<bool> newFileAs() {
    _beforeSystemModal().then((_) =>
        super.newFileAs().whenComplete(() => _systemModalComplete()));
  }

  static set backdropShowing(bool showing) {
    var appModal = querySelector("#modalBackdrop");
    appModal.style.display = showing ? "block" : "none";
  }

  static bool get backdropShowing {
    var appModal = querySelector("#modalBackdrop");
    return (appModal.style.display != "none");
  }

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
  void initSaveStatusListener() {
    super.initSaveStatusListener();

    statusComponent = getUIElement('#sparkStatus');

    // Listen for save events.
    eventBus.onEvent('filesSaved').listen((_) {
      statusComponent.temporaryMessage = 'all changes saved';
    });

    // Listen for job manager events.
    jobManager.onChange.listen((JobManagerEvent event) {
      if (event.started) {
          statusComponent.spinning = true;
          statusComponent.progressMessage = event.job.name;
      } else if (event.finished) {
        statusComponent.spinning = false;
        statusComponent.progressMessage = null;
      }
    });

    // Listen for editing area name change events.
    editorArea.onNameChange.listen((name) {
      if (editorArea.shouldDisplayName) {
        statusComponent.defaultMessage = name;
      } else {
        statusComponent.defaultMessage = null;
      }
    });
  }

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

    _bindButtonToAction('gitClone', 'git-clone');
    _bindButtonToAction('newProject', 'project-new');
    _bindButtonToAction('runButton', 'application-run');
  }

  @override
  void buildMenu() {
    // TODO: hide the 'run-tests' menu item if not in developer mode

  }

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

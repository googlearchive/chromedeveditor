// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer;

import 'dart:async';
import 'dart:html';

import 'package:polymer/polymer.dart' as polymer;

// BUG(ussuri): https://github.com/dart-lang/spark/issues/500
import 'packages/spark_widgets/spark_button/spark_button.dart';
import 'packages/spark_widgets/spark_overlay/spark_overlay.dart';

import 'spark.dart';
import 'spark_polymer_ui.dart';
import 'lib/actions.dart';
import 'lib/app.dart';
import 'lib/event_bus.dart';
import 'lib/jobs.dart';

class _TimeLogger {
  final _stepStopwatch = new Stopwatch()..start();
  final _elapsedStopwatch = new Stopwatch()..start();

  void _log(String message) {
    // NOTE: standard [Logger] didn't work reliably here.
    print('[INFO] spark.startup: $message');
  }

  void logStep(String message) {
    _log('$message: ${_stepStopwatch.elapsedMilliseconds}ms.');
    _stepStopwatch.reset();
  }

  void logElapsed(String message) {
    _log('$message: ${_elapsedStopwatch.elapsedMilliseconds}ms.');
  }
}

void main() {
  final logger = new _TimeLogger();

  isTestMode().then((testMode) {
    logger.logStep('testMode retrieved');

    polymer.initPolymer().run(() {
      logger.logStep('Polymer initialized');

      // Don't set up the zone exception handler if we're running in dev mode.
      final Function maybeRunGuarded =
          testMode ? (f) => f() : createSparkZone().runGuarded;

      maybeRunGuarded(() {
        SparkPolymer spark = new SparkPolymer._(testMode);

        logger.logStep('Spark created');

        spark.start();

        logger.logStep('Spark started');

        // NOTE: This even is unused right now, but it will be soon. For now
        // we're just interested in its timing.
        polymer.Polymer.onReady.then((_) {
          logger.logStep('Polymer.onReady fired');
          logger.logElapsed('Total startup time');
        });
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

  @override
  void show() {
    if (!_dialogElement.opened) {
      _dialogElement.toggle();
    }
  }

  // TODO(ussuri): Currently, this never gets called (the dialog closes in
  // another way). Make symmetrical when merging Polymer and non-Polymer.
  @override
  void hide() => _dialogElement.toggle();

  @override
  Element get element => _dialogElement;
}

class SparkPolymer extends Spark {
  SparkPolymerUI _ui;

  Future openFolder() {
    return _beforeSystemModal()
        .then((_) => super.openFolder())
        .then((_) => _systemModalComplete())
        .catchError((e) => _systemModalComplete());
  }

  Future openFile() {
    return _beforeSystemModal()
        .then((_) => super.openFile())
        .then((_) => _systemModalComplete())
        .catchError((e) => _systemModalComplete());
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
        super(developerMode) {
    _ui.developerMode = developerMode;
    addParticipant(new _AppSetupParticipant());
  }

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
          (getUIElement('#splitView') as dynamic).targetSize = value;
        }
      }
    });
  }

  @override
  void initSaveStatusListener() {
    super.initSaveStatusListener();

    statusComponent = getUIElement('#sparkStatus');

    // Listen for save events.
    eventBus.onEvent(BusEventType.EDITOR_MANAGER__FILES_SAVED).listen((_) {
      statusComponent.temporaryMessage = 'All changes saved';
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
      statusComponent.defaultMessage =
          editorArea.shouldDisplayName ? name : null;
    });
  }

  @override
  void initFilesController() => super.initFilesController();

  @override
  void createActions() => super.createActions();

  @override
  void initToolbar() {
    super.initToolbar();

    _bindButtonToAction('gitClone', 'git-clone');
    _bindButtonToAction('newProject', 'project-new');
    _bindButtonToAction('runButton', 'application-run');
    _bindButtonToAction('pushButton', 'application-push');
  }

  @override
  void buildMenu() => super.buildMenu();

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

  void unveil() {
    // TODO(devoncarew) We'll want to switch over to using the polymer
    // 'unresolved' or 'polymer-unveil' attributes, once these start working.
    DivElement element = document.querySelector('#splashScreen');

    if (element != null) {
      element.classes.add('closeSplash');
      new Timer(new Duration(milliseconds: 300), () {
        element.parent.children.remove(element);
      });
    }
  }

  Future _beforeSystemModal() {
    backdropShowing = true;

    return new Future.delayed(new Duration(milliseconds: 100));
  }

  void _systemModalComplete() {
    backdropShowing = false;
  }
}

class _AppSetupParticipant extends LifecycleParticipant {
  /**
   * Update the Polymer UI with async info from the Spark app instance.
   */
  Future applicationStarted(Application application) {
    SparkPolymer app = application;
    app._ui.chromeOS = app.platformInfo.isCros;
    return new Future.value();
  }
}

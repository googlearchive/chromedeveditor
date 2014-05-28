// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer;

import 'dart:async';
import 'dart:html';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:polymer/polymer.dart' as polymer;
import 'package:spark_widgets/spark_button/spark_button.dart';
import 'package:spark_widgets/spark_modal/spark_modal.dart';

import 'spark.dart';
import 'spark_flags.dart';
import 'spark_polymer_ui.dart';
import 'lib/actions.dart';
import 'lib/app.dart';
import 'lib/event_bus.dart';
import 'lib/jobs.dart';
import 'lib/platform_info.dart';
import 'lib/workspace.dart' as ws;

class _TimeLogger {
  final _stepStopwatch = new Stopwatch()..start();
  final _elapsedStopwatch = new Stopwatch()..start();

  void _log(String type, String message) {
    // NOTE: standard [Logger] didn't work reliably here.
    print('[$type] spark.startup: $message');
  }

  void logStep(String message) {
    _log('INFO', '$message: ${_stepStopwatch.elapsedMilliseconds}ms.');
    _stepStopwatch.reset();
  }

  void logElapsed(String message) {
    _log('INFO', '$message: ${_elapsedStopwatch.elapsedMilliseconds}ms.');
  }

  void logError(String error) {
    _log('ERROR', 'Error: $error');
  }
}

final _logger = new _TimeLogger();

@polymer.initMethod
void main() {
  // app.json stores global per-app flags and is overwritten by the build
  // process (`grind deploy`).
  // user.json can be manually added to override some of the flags from app.json
  // or add new flags that will survive the build process.
  final List<Future<String>> flagsReaders = [
      HttpRequest.getString(chrome.runtime.getURL('app.json')),
      HttpRequest.getString(chrome.runtime.getURL('user.json'))
  ];
  SparkFlags.initFromFiles(flagsReaders).then((_) {
    // Don't set up the zone exception handler if we're running in dev mode.
    final Function maybeRunGuarded =
        SparkFlags.developerMode ? (f) => f() : createSparkZone().runGuarded;

    maybeRunGuarded(() {
      SparkPolymer spark = new SparkPolymer._();
      spark.start();
    });
  }).catchError((error) {
    _logger.logError(error);
  });
}

// TODO(devoncarew): We need to de-couple a request to close the dialog
// from actually closing it. So, cancel() => close(), and
// performOk() => close(), but subclasses can override.
class SparkPolymerDialog implements SparkDialog {
  SparkModal _dialogElement;

  SparkPolymerDialog(Element dialogElement)
      : _dialogElement = dialogElement {
    // TODO(ussuri): Encapsulate backdrop in SparkModal.
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
  void hide() {
    if (_dialogElement.opened) _dialogElement.toggle();
  }

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

  Future importFolder([List<ws.Resource> resources]) {
    return _beforeSystemModal()
        .then((_) => super.importFolder(resources))
        .whenComplete(() => _systemModalComplete());
  }

  Future importFile([List<ws.Resource> resources]) {
    return _beforeSystemModal()
        .then((_) => super.importFile(resources))
        .whenComplete(() => _systemModalComplete());
  }

  static set backdropShowing(bool showing) {
    var appModal = querySelector("#modalBackdrop");
    appModal.style.display = showing ? "block" : "none";
  }

  static bool get backdropShowing {
    var appModal = querySelector("#modalBackdrop");
    return (appModal.style.display != "none");
  }

  SparkPolymer._() : super() {
    addParticipant(new _SparkSetupParticipant());
  }

  void uiReady() {
    assert(_ui == null);
    _ui = document.querySelector('#topUi');
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
  // Override some parts of the parent's init():
  //

  @override
  void initAnalytics() => super.initAnalytics();

  @override
  void initWorkspace() => super.initWorkspace();

  @override
  void initAceManager() => super.initAceManager();

  @override
  void initEditorManager() => super.initEditorManager();

  @override
  void initEditorArea() => super.initEditorArea();

  @override
  void initSplitView() {
    syncPrefs.getValue('splitViewPosition', '300').then((String position) {
      int value = int.parse(position, onError: (_) => null);
      if (value != null) {
        _ui.splitViewPosition = value;
        _ui.deliverChanges();
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
    // When nothing had to be saved, show the same feedback to make the user
    // happy.
    eventBus.onEvent(BusEventType.EDITOR_MANAGER__NO_MODIFICATIONS).listen((_) {
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
  }

  @override
  void initFilesController() => super.initFilesController();

  @override
  void createActions() => super.createActions();

  @override
  void initToolbar() {
    super.initToolbar();

    _bindButtonToAction('runButton', 'application-run');
    _bindButtonToAction('leftNav', 'navigate-back');
    _bindButtonToAction('rightNav', 'navigate-forward');
  }

  @override
  void buildMenu() => super.buildMenu();

  @override
  Future restoreWorkspace() => super.restoreWorkspace();

  @override
  Future restoreLocationManager() => super.restoreLocationManager();

  @override
  void menuActivateEventHandler(CustomEvent event) {
    _ui.onMenuSelected(event, event.detail);
  }

  //
  // - End parts of the parent's init().
  //

  @override
  void onSplitViewUpdate(int position) {
    syncPrefs.setValue('splitViewPosition', position.toString());
  }

  void _bindButtonToAction(String buttonId, String actionId) {
    SparkButton button = getUIElement('#${buttonId}');
    Action action = actionManager.getAction(actionId);
    action.onChange.listen((_) {
      button.disabled = !action.enabled;
      button.deliverChanges();
    });
    button.onClick.listen((_) {
      if (action.enabled) action.invoke();
    });
    button.disabled = !action.enabled;
  }

  @override
  void unveil() {
    super.unveil();

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

  @override
  void refreshUI() {
    _ui.refreshFromModel();
  }

  Future _beforeSystemModal() {
    backdropShowing = true;

    return new Future.delayed(new Duration(milliseconds: 100));
  }

  void _systemModalComplete() {
    backdropShowing = false;
  }
}

class _SparkSetupParticipant extends LifecycleParticipant {
  Future applicationStarting(Application app) {
    final SparkPolymer spark = app;
    return PlatformInfo.init().then((_) {
      return polymer.Polymer.onReady.then((_) {
        spark.uiReady();
        return spark.init();
      });
    });
  }

  Future applicationStarted(Application app) {
    final SparkPolymer spark = app;
    spark._ui.modelReady(spark);
    spark.unveil();
    _logger.logStep('Spark started');
    _logger.logElapsed('Total startup time');
    return new Future.value();
  }

  Future applicationClosed(Application app) {
    final SparkPolymer spark = app;
    spark.editorManager.persistState();
    spark.launchManager.dispose();
    spark.localPrefs.flush();
    spark.syncPrefs.flush();
    return new Future.value();
  }
}

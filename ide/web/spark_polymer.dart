// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_polymer;

import 'dart:async';
import 'dart:html';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:polymer/polymer.dart' as polymer;
import 'package:spark_widgets/spark_button/spark_button.dart';
import 'package:spark_widgets/spark_dialog/spark_dialog.dart';
import 'package:spark_widgets/spark_splitter/spark_splitter.dart';

import 'spark.dart';
import 'spark_polymer_ui.dart';
import 'lib/actions.dart';
import 'lib/app.dart';
import 'lib/event_bus.dart';
import 'lib/jobs.dart';
import 'lib/platform_info.dart';
import 'lib/preferences.dart';
import 'lib/spark_flags.dart';
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

void main() {
  polymer.initPolymer().run(() {
    // user.json can be manually added to override some of the default flags.
    // user.json is not tracked by git.
    final List<Future<String>> flagsReaders = [
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
  });
}

// TODO(devoncarew): We need to de-couple a request to close the dialog
// from actually closing it. So, cancel() => close(), and
// performOk() => close(), but subclasses can override.
class SparkPolymerDialog implements Dialog {
  SparkDialog _dialogElement;

  SparkPolymerDialog(Element dialogElement)
      : _dialogElement = dialogElement {
    // TODO(ussuri): Encapsulate backdrop in SparkModal.
    _dialogElement.on['transition-start'].listen((event) {
      SparkPolymer.backdropShowing = event.detail['opening'];
    });
  }

  @override
  void show() => _dialogElement.show();

  @override
  void hide() => _dialogElement.hide();

  @override
  SparkDialog get dialog => _dialogElement;

  @override
  Element getElement(String selectors) =>
      _dialogElement.querySelector(selectors);

  @override
  List<Element> getElements(String selectors) =>
      _dialogElement.querySelectorAll(selectors);

  @override
  Element getShadowDomElement(String selectors) =>
      _dialogElement.shadowRoot.querySelector(selectors);

  @override
  bool get activityVisible => _dialogElement.activityVisible;

  @override
  void set activityVisible(bool visible) {
    _dialogElement.activityVisible = visible;
  }
}

class SparkPolymer extends Spark {
  SparkPolymerUI _ui;

  Future<SparkJobStatus> openFolder(chrome.DirectoryEntry entry) {
    return _beforeSystemModal()
        .then((_) => super.openFolder(entry))
        .then((status) {
          _systemModalComplete();
          return status;
        }).catchError((e) => _systemModalComplete());
  }

  Future openFile() {
    return _beforeSystemModal()
        .then((_) => super.openFile())
        .then((_) => _systemModalComplete())
        .catchError((e) => _systemModalComplete());
  }

  Future<SparkJobStatus> importFolder([List<ws.Resource> resources]) {
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
  Dialog createDialog(Element dialogElement) =>
      new SparkPolymerDialog(dialogElement);

  //
  // Override some parts of the parent's init():
  //

  @override
  void initEditorManager() {
    super.initEditorManager();

    // TODO(ussuri): Redo once the TODO before #aceContainer in *.html is done.
    final SparkSplitter outlineResizer = getUIElement('#outlineResizer');
    syncPrefs.getValue('outlineSize', '200').then((String position) {
      int value = int.parse(position, onError: (_) => null);
      if (value != null) {
        // TODO(ussuri): BUG #2252. Note: deliverChanges() here didn't work
        // in deployed code, unlike the similar snippet below.
        outlineResizer
            ..targetSize = value
            ..targetSizeChanged();
      }
    });
    outlineResizer.on['update'].listen(_onOutlineSizeUpdate);
  }

  @override
  void initSplitView() {
    syncPrefs.getValue('splitViewPosition', '300').then((String position) {
      int value = int.parse(position, onError: (_) => null);
      if (value != null) {
        // TODO(ussuri): BUG #2252.
        _ui
            ..splitViewPosition = value
            ..deliverChanges();
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
      if (event.finished) {
        statusComponent.spinning = false;
        statusComponent.progressMessage = null;
      } else {
        statusComponent.spinning = true;
        statusComponent.progressMessage = event.toString();
      }
    });
  }

  @override
  void initToolbar() {
    super.initToolbar();

    _bindButtonToAction('runButton', 'application-run');
    _bindButtonToAction('leftNav', 'navigate-back');
    _bindButtonToAction('rightNav', 'navigate-forward');
    _bindButtonToAction('settingsButton', 'settings');
  }

  //
  // - End parts of the parent's init().
  //

  @override
  void onSplitViewUpdate(int position) {
    syncPrefs.setValue('splitViewPosition', position.toString());
  }

  // TODO(ussuri): Redo once the TODO before #aceContainer in *.html is done.
  void _onOutlineSizeUpdate(CustomEvent e) {
    syncPrefs.setValue('outlineSize', e.detail['targetSize'].toString());
    // The top-level [spark-split-view] in [_ui] also listens to the same event.
    e.stopImmediatePropagation();
  }

  void _bindButtonToAction(String buttonId, String actionId) {
    SparkButton button = getUIElement('#${buttonId}');
    Action action = actionManager.getAction(actionId);
    action.onChange.listen((_) {
      // TODO(ussuri): This and similar line below should be
      // `button.disabled = ...`, however in dart2js version
      // Polymer refused to see and apply such changes; HTML attr here works.
      // See original version under git tag 'before-button-hack-to-fix-states'.
      button.setAttr('disabled', !action.enabled);
    });
    button.onClick.listen((_) {
      if (action.enabled) action.invoke();
    });
    button.setAttr('disabled', !action.enabled);
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
  static final String FIRST_RUN_PREF = 'firstRun';

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
    final PreferenceStore prefs = spark.localPrefs;

    spark._ui.modelReady(spark);
    spark.unveil();

    _logger.logStep('Chrome Dev Editor started');
    _logger.logElapsed('Total startup time');

    prefs.getValue(FIRST_RUN_PREF).then((String value) {
      if (value != 'false') {
        new Future.delayed(new Duration(milliseconds: 500), () {
          spark.actionManager.getAction('help-about').invoke();
        });
      }

      prefs.setValue(FIRST_RUN_PREF, false.toString());
    });

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

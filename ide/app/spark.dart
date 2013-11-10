// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html';

import 'package:bootjack/bootjack.dart' as bootjack;
import 'package:chrome_gen/chrome_app.dart' as chrome_gen;

import 'lib/ace.dart';
import 'lib/actions.dart';
import 'lib/analytics.dart' as analytics;
import 'lib/app.dart';
import 'lib/utils.dart';
import 'lib/preferences.dart';
import 'lib/ui/files_controller.dart';
import 'lib/ui/files_controller_delegate.dart';
import 'lib/ui/widgets/splitview.dart';
import 'lib/workspace.dart';
import 'spark_test.dart';

/**
 * Returns true if app.json contains a test-mode entry set to true.
 * If app.json does not exit, it returns true.
 */
Future<bool> isTestMode() {
  String url = chrome_gen.runtime.getURL('app.json');
  return HttpRequest.getString(url).then((String contents) {
    bool result = true;
    try {
      Map info = JSON.decode(contents);
      result = info['test-mode'];
    } catch(exception, stackTrace) {
      // If JSON is invalid, assume test mode.
      result = true;
    }
    return result;
  }).catchError((e) {
    return true;
  });
}

void main() {
  isTestMode().then((testMode) {
    if (testMode) {
      // Start the app, show the test UI, and connect to a test server if one is
      // available.
      SparkTest app = new SparkTest();

      app.start().then((_) {
        app.showTestUI();

        app.connectToListener();
      });
    } else {
      // Start the app in normal mode.
      Spark spark = new Spark();
      spark.start();
    }
  });
}

class Spark extends Application implements FilesControllerDelegate {
  // The Google Analytics app ID for Spark.
  static final _ANALYTICS_ID = 'UA-45578231-1';

  AceEditor editor;
  Workspace workspace;
  analytics.Tracker tracker;

  PreferenceStore localPrefs;
  PreferenceStore syncPrefs;

  ActionManager actionManager;

  SplitView _splitView;
  FilesController _filesController;

  PlatformInfo _platformInfo;

  Spark() {
    document.title = appName;

    localPrefs = PreferenceStore.createLocal();
    syncPrefs = PreferenceStore.createSync();

    actionManager = new ActionManager();

    analytics.getService('Spark').then((service) {
      // Init the analytics tracker and send a page view for the main page.
      tracker = service.getTracker(_ANALYTICS_ID);
      tracker.sendAppView('main', newSession: true);
    });

    addParticipant(new _SparkSetupParticipant(this));

    // TODO: this event is not being fired. A bug with chrome apps / Dartium?
    chrome_gen.app.window.onClosed.listen((_) {
      close();
    });

    workspace = new Workspace(localPrefs);

    editor = new AceEditor();

    _splitView = new SplitView(querySelector('#splitview'));
    _filesController = new FilesController(workspace, this);

    setupFileActions();
    setupEditorThemes();

    // Init the bootjack library (a wrapper around bootstrap).
    bootjack.Bootjack.useDefault();

    createActions();
    buildMenu();

    actionManager.registerKeyListener();
  }

  String get appName => i18n('app_name');

  String get appVersion => chrome_gen.runtime.getManifest()['version'];

  PlatformInfo get platformInfo => _platformInfo;

  void setupFileActions() {
    querySelector("#newFile").onClick.listen(newFile);
    querySelector("#openFile").onClick.listen(openFile);
    querySelector("#saveFile").onClick.listen(saveFile);
    querySelector("#saveAsFile").onClick.listen(saveAsFile);
  }

  void setupEditorThemes() {
    syncPrefs.getValue('aceTheme').then((String theme) {
      if (theme != null && AceEditor.THEMES.contains(theme)) {
        editor.theme = theme;
      }
    });
  }

  void newFile(_) {
    editor.newFile();
  }

  void openFile(_) {
    chrome_gen.ChooseEntryOptions options = new chrome_gen.ChooseEntryOptions(
        type: chrome_gen.ChooseEntryType.OPEN_WRITABLE_FILE);
    chrome_gen.fileSystem.chooseEntry(options).then((chrome_gen.ChooseEntryResult result) {
      chrome_gen.ChromeFileEntry entry = result.entry;

      if (entry != null) {
        workspace.link(entry, false).then((file) {
          _filesController.selectLastFile();
          workspace.save();
        });
      }
    }).catchError((e) => null);
  }

  void saveAsFile(_) {
    chrome_gen.ChooseEntryOptions options = new chrome_gen.ChooseEntryOptions(
        type: chrome_gen.ChooseEntryType.SAVE_FILE);

    chrome_gen.fileSystem.chooseEntry(options).then((chrome_gen.ChooseEntryResult result) {
      chrome_gen.ChromeFileEntry entry = result.entry;
      workspace.link(entry, false).then((file) {
        editor.saveAs(file);
        workspace.save();
      });
    }).catchError((e) => null);
  }

  void saveFile(_) {
    editor.save();
  }

  void createActions() {
    actionManager.registerAction(new FileNewAction(this));
    actionManager.registerAction(new FileOpenAction(this));
    actionManager.registerAction(new FileSaveAction(this));
    actionManager.registerAction(new FileExitAction(this));
  }

  void buildMenu() {
    UListElement ul = querySelector('#hotdogMenu ul');

    ul.children.insert(0, _createLIElement(null));
    ul.children.insert(0, _createMenuItem(actionManager.getAction('file-open')));
    ul.children.insert(0, _createMenuItem(actionManager.getAction('file-new')));

    querySelector('#themeLeft').onClick.listen((e) {
      e.stopPropagation();
      _handleChangeTheme(themeLeft: true);
    });
    querySelector('#themeRight').onClick.listen((e) {
      e.stopPropagation();
      _handleChangeTheme(themeLeft: false);
    });

    ul.children.add(_createLIElement(null));

    ul.children.add(_createLIElement('Check For Updates…', _handleUpdateCheck));
    ul.children.add(_createLIElement('About Spark', _handleAbout));
  }

  void showStatus(String text, {bool error: false}) {
    Element element = querySelector("#status");
    element.text = text;
    element.classes.toggle('error', error);
  }

  // Implementation of FilesControllerDelegate interface.
  void openInEditor(Resource file) {
    editor.setContent(file);
  }

  void _handleChangeTheme({bool themeLeft: true}) {
    int index = AceEditor.THEMES.indexOf(editor.theme);
    index = (index + (themeLeft ? -1 : 1)) % AceEditor.THEMES.length;
    String themeName = AceEditor.THEMES[index];
    editor.theme = themeName;
    syncPrefs.setValue('aceTheme', themeName);
  }

  void _handleUpdateCheck() {
    showStatus("Checking for updates...");

    chrome_gen.runtime.requestUpdateCheck().then((chrome_gen.RequestUpdateCheckResult result) {
      if (result.status == 'update_available') {
        // result.details['version']
        showStatus("An update is available.");
      } else {
        showStatus("Application is up to date.");
      }
    }).catchError((_) => showStatus(''));
  }

  void _handleAbout() {
    bootjack.Modal modal = bootjack.Modal.wire(querySelector('#aboutDialog'));
    modal.element.querySelector('#aboutVersion').text = appVersion;
    modal.show();
  }

  LIElement _createLIElement(String title, [Function onClick]) {
    LIElement li = new LIElement();

    if (title == null) {
      li.classes.add('divider');
    } else {
      AnchorElement a = new AnchorElement();
      a.text = title;
      li.children.add(a);
    }

    if (onClick != null) {
      li.onClick.listen((_) => onClick());
    }

    return li;
  }

  LIElement _createMenuItem(Action action) {
    LIElement li = new LIElement();

    AnchorElement a = new AnchorElement();
    a.text = action.name;
    SpanElement span = new SpanElement();
    span.text = action.getBindingDescription();
    span.classes.add('pull-right');
    a.children.add(span);
    li.children.add(a);
    li.onClick.listen((_) => action.invoke());

    return li;
  }
}

class PlatformInfo {
  /**
   * The operating system chrome is running on. One of: "mac", "win", "android",
   * "cros", "linux", "openbsd".
   */
  final String os;

  /**
   * The machine's processor architecture. One of: "arm", "x86-32", "x86-64".
   */
  final String arch;

  /**
   * The native client architecture. This may be different from arch on some
   * platforms. One of: "arm", "x86-32", "x86-64".
   */
  final String nacl_arch;

  PlatformInfo._(this.os, this.arch, this.nacl_arch);

  String toString() => "${os}, ${arch}, ${nacl_arch}";
}

class _SparkSetupParticipant extends LifecycleParticipant {
  Spark spark;

  _SparkSetupParticipant(this.spark);

  Future applicationStarting(Application application) {
    // get platform info
    return chrome_gen.runtime.getPlatformInfo().then((Map m) {
      spark._platformInfo = new PlatformInfo._(m['os'], m['arch'], m['nacl_arch']);
      spark.workspace.restore().then((value) {
        if (spark.workspace.getFiles().length == 0) {
          // No files, just focus the editor.
          spark.editor.focus();
        } else {
          // Select the first file.
          spark._filesController.selectFirstFile();
        }
      });
    });
  }

  Future applicationClosed(Application application) {
    // TODO: flush out any preference info or workspace state?

  }
}

abstract class SparkAction extends Action {
  Spark spark;

  SparkAction(this.spark, String id, String name) : super(id, name);
}

class FileNewAction extends SparkAction {
  FileNewAction(Spark spark) : super(spark, "file-new", "New") {
    defaultBinding("ctrl-n");
  }

  void invoke() {
    // TODO:
    spark.newFile(null);
  }
}

class FileOpenAction extends SparkAction {
  FileOpenAction(Spark spark) : super(spark, "file-open", "Open...") {
    defaultBinding("ctrl-o");
  }

  void invoke() {
    // TODO:
    spark.openFile(null);
  }
}

class FileSaveAction extends SparkAction {
  FileSaveAction(Spark spark) : super(spark, "file-save", "Save") {
    defaultBinding("ctrl-s");
  }

  void invoke() {
    // TODO:
    spark.saveFile(null);
  }
}

class FileExitAction extends SparkAction {
  FileExitAction(Spark spark) : super(spark, "file-exit", "Quit") {
    macBinding("ctrl-q");
    winBinding("ctrl-shift-f4");
  }

  void invoke() {
    spark.close().then((_) {
      chrome_gen.app.window.current().close();
    });
  }
}

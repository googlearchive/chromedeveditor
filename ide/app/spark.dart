// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html';

import 'package:bootjack/bootjack.dart' as bootjack;
import 'package:chrome_gen/chrome_app.dart' as chrome;
import 'package:logging/logging.dart';

import 'lib/ace.dart';
import 'lib/actions.dart';
import 'lib/analytics.dart' as analytics;
import 'lib/app.dart';
import 'lib/editorarea.dart';
import 'lib/editors.dart';
import 'lib/utils.dart';
import 'lib/preferences.dart' as preferences;
import 'lib/tests.dart';
import 'lib/ui/files_controller.dart';
import 'lib/ui/files_controller_delegate.dart';
import 'lib/ui/widgets/splitview.dart';
import 'lib/workspace.dart' as ws;
import 'test/all.dart' as all_tests;

/**
 * Returns true if app.json contains a test-mode entry set to true.
 * If app.json does not exit, it returns true.
 */
Future<bool> isTestMode() {
  String url = chrome.runtime.getURL('app.json');
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
    Spark spark = new Spark(testMode);
    spark.start();
  });
}

class Spark extends Application implements FilesControllerDelegate {
  final bool developerMode;

  // The Google Analytics app ID for Spark.
  static final _ANALYTICS_ID = 'UA-45578231-1';

  AceEditor editor;
  ws.Workspace workspace;
  EditorManager editorManager;
  EditorArea editorArea;
  analytics.Tracker tracker = new analytics.NullTracker();

  preferences.PreferenceStore localPrefs;
  preferences.PreferenceStore syncPrefs;

  ActionManager actionManager;

  SplitView _splitView;
  FilesController _filesController;
  PlatformInfo _platformInfo;
  TestDriver _testDriver;

  Spark(this.developerMode) {
    document.title = appName;

    localPrefs = preferences.localStore;
    syncPrefs = preferences.syncStore;

    actionManager = new ActionManager();

    analytics.getService('Spark').then((service) {
      // Init the analytics tracker and send a page view for the main page.
      tracker = service.getTracker(_ANALYTICS_ID);
      tracker.sendAppView('main');
      _startTrackingExceptions();
    });

    addParticipant(new _SparkSetupParticipant(this));

    // TODO: this event is not being fired. A bug with chrome apps / Dartium?
    chrome.app.window.onClosed.listen((_) {
      close();
    });

    workspace = new ws.Workspace(localPrefs);
    editor = new AceEditor(new DivElement());

    editorManager = new EditorManager(workspace, editor, localPrefs);
    editorManager.loaded.then((_) {
      List<ws.Resource> files = editorManager.files.toList();
      editorManager.files.forEach((file) {
        editorArea.selectFile(file, forceOpen: true, switchesTab: false);
      });
      localPrefs.getValue('lastFileSelection').then((String filePath) {
        if (editorArea.tabs.isEmpty) return;
        if (filePath == null) {
          editorArea.tabs[0].select();
          return;
        }
        ws.Resource resource = workspace.restoreResource(filePath);
        if (resource == null) {
          editorArea.tabs[0].select();
          return;
        }
        editorArea.selectFile(resource, switchesTab: true);
      });
    });

    editorArea = new EditorArea(document.getElementById('editorArea'),
                                editorManager,
                                allowsLabelBar: true);
    editorArea.onSelected.listen((EditorTab tab) {
      _filesController.selectFile(tab.file);
      localPrefs.setValue('lastFileSelection', tab.file.path);
    });
    _filesController = new FilesController(workspace, this);

    setupSplitView();
    setupFileActions();
    setupEditorThemes();

    // Init the bootjack library (a wrapper around bootstrap).
    bootjack.Bootjack.useDefault();

    createActions();
    buildMenu();

    actionManager.registerKeyListener();
  }

  String get appName => i18n('app_name');

  String get appVersion => chrome.runtime.getManifest()['version'];

  PlatformInfo get platformInfo => _platformInfo;

  void setupSplitView() {
    _splitView = new SplitView(querySelector('#splitview'));
    _splitView.onResized.listen((_) {
      editor.resize();
      syncPrefs.setValue('splitViewPosition', _splitView.position.toString());
    });
    syncPrefs.getValue('splitViewPosition').then((String position) {
      if (position != null) {
        int value = int.parse(position, onError: (_) => 0);
        if (value != 0) {
          _splitView.position = value;
        }
      }
    });
  }

  void setupFileActions() {
    querySelector("#newFile").onClick.listen(
        (_) => actionManager.getAction('file-new').invoke());
    querySelector("#openFile").onClick.listen(
        (_) => actionManager.getAction('file-open').invoke());
  }

  void setupEditorThemes() {
    syncPrefs.getValue('aceTheme').then((String theme) {
      if (theme != null && AceEditor.THEMES.contains(theme)) {
        editor.theme = theme;
      }
    });
  }

  void newFile() => notImplemented('Spark.newFile()');

  void openFile() {
    chrome.ChooseEntryOptions options = new chrome.ChooseEntryOptions(
        type: chrome.ChooseEntryType.OPEN_WRITABLE_FILE);
    chrome.fileSystem.chooseEntry(options).then((chrome.ChooseEntryResult result) {
      chrome.ChromeFileEntry entry = result.entry;

      if (entry != null) {
        workspace.link(entry).then((file) {
          editorArea.selectFile(file, forceOpen: true, switchesTab: true);
          workspace.save();
        });
      }
    }).catchError((e) => null);
  }

  void openProject() {
    chrome.ChooseEntryOptions options = new chrome.ChooseEntryOptions(
        type: chrome.ChooseEntryType.OPEN_DIRECTORY);
    chrome.fileSystem.chooseEntry(options).then((chrome.ChooseEntryResult result) {
      chrome.ChromeFileEntry entry = result.entry;

      if (entry != null) {
        workspace.link(entry).then((file) {
          _filesController.selectLastFile();
          workspace.save();
        });
      }
    }).catchError((e) => null);
  }

  void deleteFile() {
    // TODO: handle multiple selection
    var sel = _filesController.getSelection();
    if (sel.isNotEmpty) {
      sel.first.delete();
    }
  }

  void createActions() {
    actionManager.registerAction(new FileNewAction(this));
    actionManager.registerAction(new FileOpenAction(this));
    actionManager.registerAction(new FileSaveAction(this));
    actionManager.registerAction(new FileExitAction(this));
    actionManager.registerAction(new FileDeleteAction(this));
    actionManager.registerAction(new ProjectOpenAction(this));
    actionManager.registerAction(new RunTestsAction(this));
    actionManager.registerAction(new AboutSparkAction(this));
  }

  void buildMenu() {
    UListElement ul = querySelector('#hotdogMenu ul');

    ul.children.add(createMenuItem(actionManager.getAction('file-new')));
    ul.children.add(createMenuItem(actionManager.getAction('file-open')));
    ul.children.add(createMenuItem(actionManager.getAction('project-open')));
    ul.children.add(createMenuItem(actionManager.getAction('file-delete')));
    ul.children.add(createMenuSeparator());

    // theme control
    Element theme = ul.querySelector('#themeControl');
    ul.children.remove(theme);
    ul.children.add(theme);
    querySelector('#themeLeft').onClick.listen((e) {
      e.stopPropagation();
      _handleChangeTheme(themeLeft: true);
    });
    querySelector('#themeRight').onClick.listen((e) {
      e.stopPropagation();
      _handleChangeTheme(themeLeft: false);
    });

    if (developerMode) {
      ul.children.add(createMenuItem(actionManager.getAction('run-tests')));
    }

    ul.children.add(createMenuSeparator());
    ul.children.add(createMenuItem(actionManager.getAction('help-about')));
  }

  void showStatus(String text, {bool error: false}) {
    Element element = querySelector("#status");
    element.text = text;
    element.classes.toggle('error', error);
  }

  // Implementation of FilesControllerDelegate interface.

  void selectInEditor(ws.File file,
                      {bool forceOpen: false, bool replaceCurrent: true}) {
    if (forceOpen || editorManager.isFileOpened(file)) {
      editorArea.selectFile(file, forceOpen: forceOpen,
          replaceCurrent: replaceCurrent);
    }
  }

  List<ContextAction> getActionsFor(ws.Resource resource) {
    return actionManager.getContextActions(resource);
  }

  void notImplemented(String str) => showStatus("Not implemented: ${str}");

  void _handleChangeTheme({bool themeLeft: true}) {
    int index = AceEditor.THEMES.indexOf(editor.theme);
    index = (index + (themeLeft ? -1 : 1)) % AceEditor.THEMES.length;
    String themeName = AceEditor.THEMES[index];
    editor.theme = themeName;
    syncPrefs.setValue('aceTheme', themeName);
  }

  void _startTrackingExceptions() {
    // Handle logged exceptions.
    Logger.root.onRecord.listen((LogRecord r) {
      if (r.level >= Level.SEVERE && r.loggerName != 'spark.tests') {
        // We don't log the error object because of PII concerns.
        // TODO: we need to add a test to verify this
        String error = r.error != null ? r.error.runtimeType.toString() : r.message;
        String desc = '${error}\n${minimizeStackTrace(r.stackTrace)}'.trim();

        if (desc.length > analytics.MAX_EXCEPTION_LENGTH) {
          desc = '${desc.substring(0, analytics.MAX_EXCEPTION_LENGTH - 1)}~';
        }

        tracker.sendException(desc);
      }
    });

    // TODO: currently, there's no way in Dart to handle uncaught exceptions

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
    return chrome.runtime.getPlatformInfo().then((Map m) {
      spark._platformInfo = new PlatformInfo._(m['os'], m['arch'], m['nacl_arch']);
      spark.workspace.restore().then((value) {
        if (spark.workspace.getFiles().length == 0) {
          // No files, just focus the editor.
          spark.editor.focus();
        }
      });
    });
  }

  Future applicationStarted(Application application) {
    if (spark.developerMode) {
      spark._testDriver = new TestDriver(
          all_tests.defineTests, connectToTestListener: true);
    }
  }

  Future applicationClosed(Application application) {
    spark.editorManager.persistState();

    spark.localPrefs.flush();
    spark.syncPrefs.flush();
  }
}

/**
 * The abstract parent class of Spark related actions.
 */
abstract class SparkAction extends Action {
  Spark spark;

  SparkAction(this.spark, String id, String name) : super(id, name);

  void invoke([Object context]) {
    // Send an action event with the 'main' event category.
    spark.tracker.sendEvent('main', id);

    _invoke(context);
  }

  void _invoke([Object context]);
}

class FileNewAction extends SparkAction implements ContextAction {
  FileNewAction(Spark spark) : super(spark, "file-new", "New File") {
    defaultBinding("ctrl-n");
  }

  void _invoke([ws.Folder folder]) {
    if (folder == null) {
      spark.newFile();
    } else {
      // TODO: create a new file in the given folder
      spark.notImplemented('new file');
    }
  }

  String get category => 'resource';

  bool appliesTo(Object object) => object is ws.Folder;
}

class FileOpenAction extends SparkAction {
  FileOpenAction(Spark spark) : super(spark, "file-open", "Open File...") {
    defaultBinding("ctrl-o");
  }

  void _invoke([Object context]) => spark.openFile();
}

class FileSaveAction extends SparkAction {
  FileSaveAction(Spark spark) : super(spark, "file-save", "Save") {
    defaultBinding("ctrl-s");
  }

  void _invoke([Object context]) => spark.editorManager.saveAll();
}

class FileDeleteAction extends SparkAction implements ContextAction {
  FileDeleteAction(Spark spark) : super(spark, "file-delete", "Delete");

  void _invoke([ws.Resource resource]) {
    if (resource == null) {
      //spark.deleteFile();
    } else {
      // TODO: ask the user first
      //resource.delete();
      spark.notImplemented('delete file: ${resource.path}');
      print('deleting ${resource.path}');
    }
  }

  String get category => 'resource';

  bool appliesTo(Object object) => object is ws.Resource;
}

class FileExitAction extends SparkAction {
  FileExitAction(Spark spark) : super(spark, "file-exit", "Quit") {
    macBinding("ctrl-q");
    winBinding("ctrl-shift-f4");
  }

  void _invoke([Object context]) {
    spark.close().then((_) {
      chrome.app.window.current().close();
    });
  }
}

class ProjectOpenAction extends SparkAction {
  ProjectOpenAction(Spark spark) : super(spark, "project-open", "Open Project...");

  void _invoke([Object context]) => spark.openProject();
}


class AboutSparkAction extends SparkAction {
  bootjack.Modal _aboutBox;

  AboutSparkAction(Spark spark) : super(spark, "help-about", "About Spark");

  void _invoke([Object context]) {
    if (_aboutBox == null) {
      _aboutBox = bootjack.Modal.wire(querySelector('#aboutDialog'));

      var checkbox = _aboutBox.element.querySelector('#analyticsCheck');
      checkbox.checked = spark.tracker.service.getConfig().isTrackingPermitted();
      checkbox.onChange.listen((e) {
        spark.tracker.service.getConfig().setTrackingPermitted(checkbox.checked);
      });

      _aboutBox.element.querySelector('#aboutVersion').text = spark.appVersion;
    }

    _aboutBox.show();
  }
}

class RunTestsAction extends SparkAction {
  RunTestsAction(Spark spark) : super(spark, "run-tests", "Run Tests");

  _invoke([Object context]) => spark._testDriver.runTests();
}

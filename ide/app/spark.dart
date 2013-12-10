// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html';
import 'dart:math' as math;

import 'package:bootjack/bootjack.dart' as bootjack;
import 'package:chrome_gen/chrome_app.dart' as chrome;
import 'package:chrome_gen/src/files.dart' as chrome_files;
import 'package:logging/logging.dart';

import 'lib/ace.dart';
import 'lib/actions.dart';
import 'lib/analytics.dart' as analytics;
import 'lib/app.dart';
import 'lib/editorarea.dart';
import 'lib/editors.dart';
import 'lib/git/commands/clone.dart';
import 'lib/git/git.dart';
import 'lib/git/objectstore.dart';
import 'lib/git/options.dart';
import 'lib/preferences.dart' as preferences;
import 'lib/tests.dart';
import 'lib/ui/files_controller.dart';
import 'lib/ui/files_controller_delegate.dart';
import 'lib/ui/widgets/splitview.dart';
import 'lib/utils.dart';
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

  /// The Google Analytics app ID for Spark.
  static final _ANALYTICS_ID = 'UA-45578231-1';

  AceContainer aceContainer;
  ThemeManager aceThemeManager;
  KeyBindingManager aceKeysManager;
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

    initAnalytics();

    addParticipant(new _SparkSetupParticipant(this));

    // TODO: this event is not being fired. A bug with chrome apps / Dartium?
    chrome.app.window.onClosed.listen((_) {
      close();
    });

    initWorkspace();

    createEditorComponents();
    initEditorArea();
    initEditorManager();

    initFilesController();

    initLookAndFeel();

    createActions();
    initToolbar();
    buildMenu();

    initSplitView();
  }

  String get appName => i18n('app_name');

  String get appVersion => chrome.runtime.getManifest()['version'];

  PlatformInfo get platformInfo => _platformInfo;

  // TODO(ussuri): The below two methods are a temporary means to make Spark
  // reusable in SparkPolymer. Once the switch to Polymer is complete, they
  // will go away.

  /**
   * Should extract a UI Element from the underlying DOM. This method
   * is overwritten in SparkPolymer, which encapsulates the UI in a top-level
   * Polymer widget, rather than the top-level document's DOM.
   */
  Element getUIElement(String selectors) =>
      document.querySelector(selectors);

  /**
   * Should extract a dialog Element from the underlying UI's DOM. This is
   * different from [getUIElement] in that it's not currently overridden in
   * SparkPolymer.
   */
  Element getDialogElement(String selectors) =>
      document.querySelector(selectors);

  //
  // Parts of ctor:
  //

  void initAnalytics() {
    analytics.getService('Spark').then((service) {
      // Init the analytics tracker and send a page view for the main page.
      tracker = service.getTracker(_ANALYTICS_ID);
      tracker.sendAppView('main');
      _startTrackingExceptions();
    });
  }

  void initWorkspace() {
    workspace = new ws.Workspace(localPrefs);
  }

  void createEditorComponents() {
    aceContainer = new AceContainer(new DivElement());
    aceThemeManager = new ThemeManager(
        aceContainer, syncPrefs, getUIElement('#changeTheme a span'));
    aceKeysManager = new KeyBindingManager(
        aceContainer, syncPrefs, getUIElement('#changeKeys a span'));
    editorManager = new EditorManager(workspace, aceContainer, localPrefs);
    editorArea = new EditorArea(
        getUIElement('#editorArea'), editorManager, allowsLabelBar: true);
  }

  void initEditorManager() {
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
  }

  void initEditorArea() {
    editorArea.onSelected.listen((EditorTab tab) {
      // We don't change the selection when the file was already selected
      // otherwise, it would break multi-selection (#260).
      if (!_filesController.isFileSelected(tab.file)) {
        _filesController.selectFile(tab.file);
      }
      localPrefs.setValue('lastFileSelection', tab.file.path);
    });
  }

  void initFilesController() {
    _filesController =
        new FilesController(workspace, this, getUIElement('#fileViewArea'));
  }

  void initLookAndFeel() {
    // Init the Bootjack library (a wrapper around Bootstrap).
    bootjack.Bootjack.useDefault();
  }

  void initSplitView() {
    _splitView = new SplitView(getUIElement('#splitview'));
    _splitView.onResized.listen((_) {
      aceContainer.resize();
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

  void createActions() {
    actionManager = new ActionManager();
    actionManager.registerAction(new FileOpenInTabAction(this));
    actionManager.registerAction(new FileNewAsAction(this));
    actionManager.registerAction(new FileNewAction(
        this, getDialogElement('#fileNewDialog')));
    actionManager.registerAction(new FileOpenAction(this));
    actionManager.registerAction(new FileSaveAction(this));
    actionManager.registerAction(new FileExitAction(this));
    actionManager.registerAction(new FileCloseAction(this));
    actionManager.registerAction(new FolderOpenAction(this));
    actionManager.registerAction(new FileRenameAction(
        this, getDialogElement('#renameDialog')));
    actionManager.registerAction(new FileDeleteAction(
        this, getDialogElement('#deleteDialog')));
    actionManager.registerAction(new GitCloneAction(
        this, getDialogElement("#gitCloneDialog")));
    actionManager.registerAction(new RunTestsAction(this));
    actionManager.registerAction(new AboutSparkAction(
        this, getDialogElement('#aboutDialog')));
    actionManager.registerKeyListener();
  }

  void initToolbar() {
    getUIElement("#openFile").onClick.listen(
        (_) => actionManager.getAction('file-open').invoke());
    getUIElement("#newFile").onClick.listen(
        (_) => actionManager.getAction('file-new-as').invoke());
  }

  void buildMenu() {
    UListElement ul = getUIElement('#hotdogMenu ul');

    ul.children.add(createMenuItem(actionManager.getAction('file-open')));
    ul.children.add(createMenuItem(actionManager.getAction('folder-open')));

    ul.children.add(createMenuSeparator());

    // Theme control.
    Element theme = ul.querySelector('#changeTheme');
    ul.children.remove(theme);
    ul.children.add(theme);
    ul.querySelector('#themeLeft').onClick.listen((e) => aceThemeManager.dec(e));
    ul.querySelector('#themeRight').onClick.listen((e) => aceThemeManager.inc(e));

    // Key binding control.
    Element keys = ul.querySelector('#changeKeys');
    ul.children.remove(keys);
    ul.children.add(keys);
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
  // - End parts of ctor.
  //

  /**
   * Allow for creating a new file using the Save as dialog.
   */
  void newFileAs() {
    chrome.ChooseEntryOptions options = new chrome.ChooseEntryOptions(
        type: chrome.ChooseEntryType.SAVE_FILE);
    chrome.fileSystem.chooseEntry(options).then((chrome.ChooseEntryResult res) {
      chrome.ChromeFileEntry entry = res.entry;

      if (entry != null) {
        workspace.link(entry).then((file) {
          editorArea.selectFile(file, forceOpen: true, switchesTab: true);
          workspace.save();
        });
      }
    }).catchError((e) => null);
  }

  void openFile() {
    chrome.ChooseEntryOptions options = new chrome.ChooseEntryOptions(
        type: chrome.ChooseEntryType.OPEN_WRITABLE_FILE);
    chrome.fileSystem.chooseEntry(options).then((chrome.ChooseEntryResult res) {
      chrome.ChromeFileEntry entry = res.entry;

      if (entry != null) {
        workspace.link(entry).then((file) {
          editorArea.selectFile(file, forceOpen: true, switchesTab: true);
          workspace.save();
        });
      }
    }).catchError((e) => null);
  }

  void openFolder() {
    chrome.ChooseEntryOptions options = new chrome.ChooseEntryOptions(
        type: chrome.ChooseEntryType.OPEN_DIRECTORY);
    chrome.fileSystem.chooseEntry(options).then((chrome.ChooseEntryResult res) {
      chrome.ChromeFileEntry entry = res.entry;

      if (entry != null) {
        workspace.link(entry).then((file) {
          _filesController.selectLastFile();
          workspace.save();
        });
      }
    }).catchError((e) => null);
  }

  List<ws.Resource> _getSelection() => _filesController.getSelection();

   void _closeOpenEditor(ws.Resource resource) {
    if (resource is ws.File &&  editorManager.isFileOpened(resource)) {
      editorManager.close(resource);
    }
  }

  void showStatus(String text, {bool error: false}) {
    Element element = getUIElement("#status");
    element.text = text;
    element.classes.toggle('error', error);
  }

  void notImplemented(String str) => showStatus("Not implemented: ${str}");

  //
  // Implementation of FilesControllerDelegate interface:
  //

  void selectInEditor(ws.File file,
                      {bool forceOpen: false,
                       bool replaceCurrent: true,
                       bool switchesTab: true}) {
    if (forceOpen || editorManager.isFileOpened(file)) {
      editorArea.selectFile(file,
          forceOpen: forceOpen,
          replaceCurrent: replaceCurrent,
          switchesTab: switchesTab);
    }
  }

  Element getContextMenuContainer() =>
      getUIElement('#file-item-context-menu');

  List<ContextAction> getActionsFor(List<ws.Resource> resources) =>
      actionManager.getContextActions(resources);

  //
  // - End implementation of FilesControllerDelegate interface.
  //

  void _startTrackingExceptions() {
    // Handle logged exceptions.
    Logger.root.onRecord.listen((LogRecord r) {
      if (r.level >= Level.SEVERE && r.loggerName != 'spark.tests') {
        // We don't log the error object because of PII concerns.
        // TODO: we need to add a test to verify this
        String error =
            r.error != null ? r.error.runtimeType.toString() : r.message;
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
  final String naclArch;

  PlatformInfo._(this.os, this.arch, this.naclArch);

  String toString() => "${os}, ${arch}, ${naclArch}";
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
          spark.aceContainer.focus();
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

class ThemeManager {
  AceContainer aceContainer;
  preferences.PreferenceStore prefs;
  Element _label;

  ThemeManager(this.aceContainer, this.prefs, this._label) {
    prefs.getValue('aceTheme').then((String value) {
      if (value != null) {
        aceContainer.theme = value;
        _updateName(value);
      } else {
        _updateName(aceContainer.theme);
      }
    });
  }

  void inc(Event e) {
   e.stopPropagation();
    _changeTheme(1);
  }

  void dec(Event e) {
    e.stopPropagation();
    _changeTheme(-1);
  }

  void _changeTheme(int direction) {
    int index = AceContainer.THEMES.indexOf(aceContainer.theme);
    index = (index + direction) % AceContainer.THEMES.length;
    String newTheme = AceContainer.THEMES[index];
    prefs.setValue('aceTheme', newTheme);
    _updateName(newTheme);
    aceContainer.theme = newTheme;
  }

  void _updateName(String name) {
    _label.text = capitalize(name.replaceAll('_', ' '));
  }
}

class KeyBindingManager {
  AceContainer aceContainer;
  preferences.PreferenceStore prefs;
  Element _label;

  KeyBindingManager(this.aceContainer, this.prefs, this._label) {
    prefs.getValue('keyBinding').then((String value) {
      if (value != null) {
        aceContainer.setKeyBinding(value);
      }
      _updateName(value);
    });
  }

  void inc(Event e) {
    e.stopPropagation();
    _changeBinding(1);
  }

  void dec(Event e) {
    e.stopPropagation();
    _changeBinding(-1);
  }

  void _changeBinding(int direction) {
    aceContainer.getKeyBinding().then((String name) {
      int index = math.max(AceContainer.KEY_BINDINGS.indexOf(name), 0);
      index = (index + direction) % AceContainer.KEY_BINDINGS.length;
      String newBinding = AceContainer.KEY_BINDINGS[index];
      prefs.setValue('keyBinding', newBinding);
      _updateName(newBinding);
      aceContainer.setKeyBinding(newBinding);
    });
  }

  void _updateName(String name) {
    _label.text = 'Keys: ' + (name == null ? 'default' : capitalize(name));
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

  /**
   * Returns true if `object` is a list and all items are [Resource].
   */
  bool _isResourceList(Object object) {
    if (object is! List) {
      return false;
    }
    List items = object as List;
    return items.every((r) => r is ws.Resource);
  }

  /**
   * Returns true if `object` is a list with a single item and this item is a
   * [Resource].
   */
  bool _isSingleResource(Object object) {
    if (!_isResourceList(object)) {
      return false;
    }
    List<ws.Resource> resources = object as List<ws.Resource>;
    return resources.length == 1;
  }

  /**
   * Returns true if `object` is a list with a single item and this item is a
   * [Folder].
   */
  bool _isSingleFolder(Object object) {
    if (!_isSingleResource(object)) {
      return false;
    }
    List<ws.Resource> resources = object as List;
    return (object as List).first is ws.Folder;
  }

  /**
   * Returns true if `object` is a list of top-level [Resource].
   */
  bool _isTopLevel(Object object) {
    if (!_isResourceList(object)) {
      return false;
    }
    List<ws.Resource> resources = object as List;
    return resources.every((ws.Resource r) => r.isTopLevel);
  }

  /**
   * Returns true if `object` is a list of File.
   */
  bool _isFileList(Object object) {
    if (!_isResourceList(object)) {
      return false;
    }
    List<ws.Resource> resources = object as List;
    return resources.every((r) => r is ws.File);
  }
}

abstract class SparkActionWithDialog extends SparkAction {
  bootjack.Modal _dialog;

  SparkActionWithDialog(Spark spark,
                        String id,
                        String name,
                        Element dialogElement)
      : super(spark, id, name) {
    dialogElement.querySelector("[primary]").onClick.listen((_) => _commit());
    _dialog = bootjack.Modal.wire(dialogElement);
  }

  void _commit();

  void _triggerOnReturn(Element element) {
    element.onKeyDown.listen((event) {
      if (event.keyCode == KeyCode.ENTER) {
        _commit();
        _dialog.hide();
      }
    });
  }
}

class FileOpenInTabAction extends SparkAction implements ContextAction {
  FileOpenInTabAction(Spark spark) :
      super(spark, "file-open-in-tab", "Open in New Tab");

  void _invoke([List<ws.File> files]) {
    bool forceOpen = files.length > 1;
    files.forEach((ws.File file) {
      spark.selectInEditor(file, forceOpen: true, replaceCurrent: false);
    });
  }

  String get category => 'tab';

  bool appliesTo(Object object) => _isFileList(object);
}

class FileNewAction extends SparkActionWithDialog implements ContextAction {
  InputElement _nameElement;
  ws.Folder folder;

  FileNewAction(Spark spark, Element dialog)
      : super(spark, "file-new", "New File…", dialog) {
    defaultBinding("ctrl-n");
    _nameElement = _dialog.element.querySelector("#fileName");
    _triggerOnReturn(_nameElement);
  }

  void _invoke([List<ws.Folder> folders]) {
    if (folders != null && folders.isNotEmpty) {
      folder = folders.first;
      _nameElement.value = '';
      _dialog.show();
    }
  }

  // called when user validates the dialog
  void _commit() {
    var name = _nameElement.value;
    if (name.isNotEmpty) {
      folder.createNewFile(name).then((file) =>
          spark.selectInEditor(file, forceOpen: true, replaceCurrent: true));
    }
  }

  String get category => 'resource';

  bool appliesTo(Object object) => _isSingleFolder(object);
}

class FileOpenAction extends SparkAction {
  FileOpenAction(Spark spark) : super(spark, "file-open", "Open File…") {
    defaultBinding("ctrl-o");
  }

  void _invoke([Object context]) => spark.openFile();
}

class FileNewAsAction extends SparkAction {
  FileNewAsAction(Spark spark) : super(spark, "file-new-as", "New File…");

  void _invoke([Object context]) => spark.newFileAs();
}


class FileSaveAction extends SparkAction {
  FileSaveAction(Spark spark) : super(spark, "file-save", "Save") {
    defaultBinding("ctrl-s");
  }

  void _invoke([Object context]) => spark.editorManager.saveAll();
}

class FileDeleteAction extends SparkActionWithDialog implements ContextAction {
  List<ws.Resource> _resources;
  // TODO: Add _messageElement.

  FileDeleteAction(Spark spark, Element dialog)
      : super(spark, "file-delete", "Delete", dialog);

  void _invoke([List<ws.Resource> resources]) {
    if (resources == null) {
      var sel = spark._filesController.getSelection();
      if (sel.isNotEmpty) {
        _resources = sel;
        _setMessageAndShow();
      }
    } else {
      _resources = resources;
      _setMessageAndShow();
    }
  }

  void _setMessageAndShow() {
    if (_resources.length == 1) {
      _dialog.element.querySelector("#message").text =
          "Are you sure you want to delete '${_resources.first.name}'?";
    } else {
      _dialog.element.querySelector("#message").text =
          "Are you sure you want to delete ${_resources.length} files?";
    }
    
    _deleteDialog.$element.on('shown.bs.modal', (e) {
      e.target.querySelector("#deleteOkButton").focus();
    });

    
    _deleteDialog.show();
  }

  void _commit() {
    _resources.forEach((ws.Resource resource) {
      resource.delete();
    });
    _resources = null;
  }

  String get category => 'resource-delete';

  bool appliesTo(Object object) => _isResourceList(object);
}

class FileRenameAction extends SparkActionWithDialog implements ContextAction {
  ws.Resource resource;
  InputElement _nameElement;

  FileRenameAction(Spark spark, Element dialog)
      : super(spark, "file-rename", "Rename…", dialog) {
    _nameElement = _dialog.element.querySelector("#fileName");
    _triggerOnReturn(_nameElement);
  }

  void _invoke([List<ws.Resource> resources]) {
   if (resources != null && resources.isNotEmpty) {
     resource = resources.first;
     _nameElement.value = resource.name;
     _dialog.show();
   }
  }

  void _commit() {
    if (_nameElement.value.isNotEmpty) {
      spark._closeOpenEditor(resource);
      resource.rename(_nameElement.value);
    }
  }

  String get category => 'resource';

  bool appliesTo(Object object) => _isSingleResource(object) && !_isTopLevel(object);
}

class FileCloseAction extends SparkAction implements ContextAction {
  FileCloseAction(Spark spark) : super(spark, "file-close", "Close");

  void _invoke([List<ws.Resource> resources]) {
    if (resources == null) {
      resources = spark._getSelection();
    }

    for (ws.Resource resource in resources) {
      spark._closeOpenEditor(resource);
      resource.workspace.unlink(resource);
    }

    spark.workspace.save();
  }

  String get category => 'resource';

  bool appliesTo(Object object) => _isTopLevel(object);
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

class FolderOpenAction extends SparkAction {
  FolderOpenAction(Spark spark) : super(spark, "folder-open", "Open Folder…");

  void _invoke([Object context]) => spark.openFolder();
}

class GitCloneAction extends SparkActionWithDialog {
  InputElement _projectNameElement;
  InputElement _repoUrlElement;

  GitCloneAction(Spark spark, Element dialog)
      : super(spark, "git-clone", "Git Clone…", dialog) {
    _projectNameElement = _dialog.element.querySelector("#gitProjectName");
    _repoUrlElement = _dialog.element.querySelector("#gitRepoUrl");
    _triggerOnReturn(_repoUrlElement);
  }

  void _invoke([Object context]) {
    _dialog.show();
  }

  void _commit() {
    // TODO(grv): add verify checks.
    _gitClone(_projectNameElement.value, _repoUrlElement.value, spark);
  }

  void _gitClone(String projectName, String url, Spark spark) {
    getGitTestFileSystem().then((chrome_files.CrFileSystem fs) {
      fs.root.createDirectory(projectName).then((chrome.DirectoryEntry dir) {
        GitOptions options = new GitOptions();
        options.root = dir;
        options.repoUrl = url;
        options.depth = 1;
        options.store = new ObjectStore(dir);
        Clone clone = new Clone(options);
        options.store.init().then((_) {
          clone.clone().then((_) {
            spark.workspace.link(dir).then((folder) {
              spark._filesController.selectLastFile();
              spark.workspace.save();
            });
          });
        });
      });
    });
  }
}

class AboutSparkAction extends SparkActionWithDialog {
  bool _initialized = false;

  AboutSparkAction(Spark spark, Element dialog)
      : super(spark, "help-about", "About Spark", dialog);

  void _invoke([Object context]) {
    if (!_initialized) {
      var checkbox = _dialog.element.querySelector('#analyticsCheck');
      checkbox.checked =
          spark.tracker.service.getConfig().isTrackingPermitted();
      checkbox.onChange.listen((e) {
        spark.tracker.service.getConfig()
            .setTrackingPermitted(checkbox.checked);
      });

      _dialog.element.querySelector('#aboutVersion').text = spark.appVersion;

      _initialized = true;
    }

    _dialog.show();
  }

  void _commit() {
    // Nothing to do for this dialog.
  }
}

class RunTestsAction extends SparkAction {
  RunTestsAction(Spark spark) : super(spark, "run-tests", "Run Tests");

  _invoke([Object context]) => spark._testDriver.runTests();
}

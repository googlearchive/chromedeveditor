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
import 'package:dquery/dquery.dart';

import 'lib/ace.dart';
import 'lib/jobs.dart';
import 'lib/actions.dart';
import 'lib/analytics.dart' as analytics;
import 'lib/app.dart';
import 'lib/editorarea.dart';
import 'lib/editors.dart';
import 'lib/event_bus.dart';
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

analytics.Tracker _analyticsTracker = new analytics.NullTracker();

void main() {
  isTestMode().then((testMode) {
    createSparkZone().runGuarded(() {
      Spark spark = new Spark(testMode);
      spark.start();
    });
  });
}

/**
 * Returns true if app.json contains a test-mode entry set to true. If app.json
 * does not exit, it returns true.
 */
Future<bool> isTestMode() {
  String url = chrome.runtime.getURL('app.json');
  return HttpRequest.getString(url).then((String contents) {
    bool result = true;
    try {
      Map info = JSON.decode(contents);
      result = info['test-mode'];
    } catch (exception, stackTrace) {
      // If JSON is invalid, assume test mode.
      result = true;
    }
    return result;
  }).catchError((e) {
    return true;
  });
}

/**
 * Create a [Zone] that logs uncaught exceptions.
 */
Zone createSparkZone() {
  var errorHandler = (self, parent, zone, error, stackTrace) {
    _handleUncaughtException(error, stackTrace);
  };
  var specification = new ZoneSpecification(handleUncaughtError: errorHandler);
  return Zone.current.fork(specification: specification);
}

class MockJob extends Job {
  MockJob() : super("Mock job");

  Future<Job> run(ProgressMonitor monitor) {
    monitor.start("Mock job...", 10);
    Completer completer = new Completer();
    new Timer(new Duration(seconds: 5), () {
      completer.complete(this);
    });
    return completer.future;
  }
}

class Spark extends Application implements FilesControllerDelegate {
  /// The Google Analytics app ID for Spark.
  static final _ANALYTICS_ID = 'UA-45578231-1';

  final bool developerMode;

  JobManager jobManager;
  ActivitySpinner activitySpinner;

  AceContainer aceContainer;
  ThemeManager aceThemeManager;
  KeyBindingManager aceKeysManager;
  ws.Workspace workspace;
  EditorManager editorManager;
  EditorArea editorArea;
  final EventBus eventBus = new EventBus();

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

    initJobManager();

    createEditorComponents();
    initEditorArea();
    initEditorManager();

    initFilesController();

    initLookAndFeel();

    createActions();
    initToolbar();
    buildMenu();

    initSplitView();
    initSaveStatusListener();

    window.onFocus.listen((Event e) {
      // When the user switch to an other application, he might change the
      // content of the workspace from other applications.
      // For that reason, when the user switch back to Spark, we want to check
      // whether the content of the workspace changed.
      workspace.refresh();
    });
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

  SparkDialog createDialog(Element dialogElement) =>
      new SparkBootjackDialog(dialogElement);


  //
  // Parts of ctor:
  //

  void initAnalytics() {
    analytics.getService('Spark').then((service) {
      // Init the analytics tracker and send a page view for the main page.
      _analyticsTracker = service.getTracker(_ANALYTICS_ID);
      _analyticsTracker.sendAppView('main');

      // Track logged exceptions.
      Logger.root.onRecord.listen((LogRecord r) {
        if (r.level >= Level.SEVERE && r.loggerName != 'spark.tests') {
          _handleUncaughtException(r.error, r.stackTrace);
        }
      });
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
    editorManager = new EditorManager(
        workspace, aceContainer, localPrefs, eventBus);
    editorArea = new EditorArea(
        getUIElement('#editorArea'),
        getUIElement('#editedFilename'),
        editorManager,
        allowsLabelBar: true);
  }

  void initJobManager() {
    activitySpinner = new ActivitySpinner(this);
    activitySpinner.setShowing(false);

    jobManager = new JobManager();
    jobManager.onChange.listen(onJobManagerData);
  }

  void onJobManagerData(JobManagerEvent event) {
    bool showSpinner = (event.finished != true);
    this.activitySpinner.setShowing(showSpinner);
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

  void initSaveStatusListener() {
    Element element = getUIElement('#saveStatus');
    Timer timer = new Timer(new Duration(seconds: 0), () => null);

    eventBus.onEvent('fileModified').listen((_) {
      //element.text = 'text modified…';
      element.text = '';
      timer.cancel();
    });

    eventBus.onEvent('filesSaved').listen((_) {
      element.text = 'all changes saved';
      timer.cancel();
      timer = new Timer(new Duration(seconds: 3), () => (element.text = ''));
    });
  }

  void createActions() {
    actionManager = new ActionManager();
    actionManager.registerAction(new FileOpenInTabAction(this));
    actionManager.registerAction(new FileNewAsAction(this));
    actionManager.registerAction(new FileNewAction(
        this, getDialogElement('#fileNewDialog')));
    actionManager.registerAction(new FolderNewAction(
        this, getDialogElement('#folderNewDialog')));
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
    getUIElement("#progressBar").onClick.listen(
        (_) => testProgressBar());
  }

  void testProgressBar() {
    MockJob job;
    Element button = getUIElement("#progressBar");
    String buttonTitle = button.text;
    int stage = int.parse(buttonTitle);
    getUIElement("#progressBar").text = (3 - stage).toString();

    switch (stage) {
      case 1:
        job = new MockJob();
        jobManager.schedule(job);
        break;

      case 2:
        break;
    }
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
          _filesController.selectFile(file);
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

  void showStatus(String text) {
    Element element = getUIElement("#saveStatus");
    element.text = text;
  }

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

class ActivitySpinner {
  Element element;

  static ActivitySpinner _instance;

  factory ActivitySpinner(Spark spark) {
    if (_instance == null) {
      _instance = new ActivitySpinner._internal(spark);
    }
    return _instance;
  }

  void setShowing(bool showing) {
    element.style.opacity = showing ? '1' : '0';
  }

  ActivitySpinner._internal(Spark spark) {
    element = spark.getUIElement('#activitySpinner');
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
    _label.text = 'Theme: ' + capitalize(name.replaceAll('_', ' '));
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
    _analyticsTracker.sendEvent('main', id);

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

abstract class SparkDialog {
  void show();
  void hide();
  Element get element;
}

class SparkBootjackDialog implements SparkDialog {
  bootjack.Modal _dialog;

  SparkBootjackDialog(Element dialogElement) {
    _dialog = bootjack.Modal.wire(dialogElement);

    _dialog.$element.on('shown.bs.modal', (event) {
      final Element dialog = event.target;
      Element elementToFocus = dialog.querySelector('[focused]');

      if (elementToFocus != null) {
        elementToFocus.focus();
      }
    });
  }

  void show() => _dialog.show();

  void hide() => _dialog.hide();

  Element get element => _dialog.element;
}

abstract class SparkActionWithDialog extends SparkAction {
  SparkDialog _dialog;

  SparkActionWithDialog(Spark spark,
                        String id,
                        String name,
                        Element dialogElement)
      : super(spark, id, name) {
    _dialog = spark.createDialog(dialogElement);
    _dialog.element.querySelector("[primary]").onClick.listen((_) => _commit());
  }

  void _commit();

  Element getElement(String selectors) =>
      _dialog.element.querySelector(selectors);

  Element _triggerOnReturn(String selectors) {
    var element = _dialog.element.querySelector(selectors);
    element.onKeyDown.listen((event) {
      if (event.keyCode == KeyCode.ENTER) {
        _commit();
        _dialog.hide();
      }
    });
    return element;
  }

  void _show() => _dialog.show();
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
    _nameElement = _triggerOnReturn("#fileNewName");
  }

  void _invoke([List<ws.Folder> folders]) {
    if (folders != null && folders.isNotEmpty) {
      folder = folders.first;
      _nameElement.value = '';
      _show();
    }
  }

  // called when user validates the dialog
  void _commit() {
    var name = _nameElement.value;
    if (name.isNotEmpty) {
      folder.createNewFile(name).then((file) {
        // Delay a bit to allow the files view to process the new file event.
        // TODO: This is due to a race condition in when the files view receives
        // the resource creation event; we should remove the possibility for
        // this to occur.
        Timer.run(() {
          spark.selectInEditor(file, forceOpen: true, replaceCurrent: true);
        });
      });
    }
  }

  String get category => 'resource';

  bool appliesTo(Object object) => _isSingleFolder(object);
}

class FolderNewAction extends SparkActionWithDialog implements ContextAction {
  InputElement _nameElement;
  ws.Folder folder;

  FolderNewAction(Spark spark, Element dialog)
      : super(spark, "folder-new", "New Folder…", dialog) {
    defaultBinding("ctrl-shift-n");
    _nameElement = _triggerOnReturn("#folderName");
  }

  void _invoke([List<ws.Folder> folders]) {
    if (folders != null && folders.isNotEmpty) {
      folder = folders.first;
      _nameElement.value = '';
      _show();
    }
  }

  // called when user validates the dialog
  void _commit() {
    var name = _nameElement.value;
    if (name.isNotEmpty) {
      folder.createNewFolder(name).then((folder) {
        // Delay a bit to allow the files view to process the new file event.
        Timer.run(() {
          spark._filesController.selectFile(folder);
        });
      });
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
      getElement("#message").text =
          "Are you sure you want to delete '${_resources.first.name}'?";
    } else {
      getElement("#message").text =
          "Are you sure you want to delete ${_resources.length} files?";
    }

    _show();
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
    _nameElement = _triggerOnReturn("#renameFileName");
  }

  void _invoke([List<ws.Resource> resources]) {
   if (resources != null && resources.isNotEmpty) {
     resource = resources.first;
     _nameElement.value = resource.name;
     _show();
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
    _projectNameElement = getElement("#gitProjectName");
    _repoUrlElement = _triggerOnReturn("#gitRepoUrl");
  }

  void _invoke([Object context]) {
    _show();
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
              spark._filesController.selectFile(folder);
              spark.workspace.save();
            });
          });
        });
      });
    });
  }
}

// TODO(terry):  When only polymer overlays are used remove _initialized and
//               isPolymer's defintion and usage.
class AboutSparkAction extends SparkActionWithDialog {
  bool _initialized = false;

  AboutSparkAction(Spark spark, Element dialog)
      : super(spark, "help-about", "About Spark", dialog);

  void _invoke([Object context]) {
    if (!_initialized) {
      var checkbox = getElement('#analyticsCheck');
      checkbox.checked = _isTrackingPermitted;
      checkbox.onChange.listen((e) => _isTrackingPermitted = checkbox.checked);

      getElement('#aboutVersion').text = spark.appVersion;

      _initialized = true;
    }

    _show();
  }

  void _commit() {
    // Nothing to do for this dialog.
  }
}

class RunTestsAction extends SparkAction {
  RunTestsAction(Spark spark) : super(spark, "run-tests", "Run Tests");

  _invoke([Object context]) => spark._testDriver.runTests();
}

// analytics code

void _handleUncaughtException(error, StackTrace stackTrace) {
  // We don't log the error object itself because of PII concerns.
  String errorDesc = error != null ? error.runtimeType.toString() : '';
  String desc = '${errorDesc}\n${minimizeStackTrace(stackTrace)}'.trim();

  _analyticsTracker.sendException(desc);
}

bool get _isTrackingPermitted =>
    _analyticsTracker.service.getConfig().isTrackingPermitted();

set _isTrackingPermitted(bool value) =>
    _analyticsTracker.service.getConfig().setTrackingPermitted(value);

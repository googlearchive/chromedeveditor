// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html' hide File;

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:spark_widgets/spark_dialog/spark_dialog.dart';
import 'package:spark_widgets/spark_dialog_button/spark_dialog_button.dart';
import 'package:spark_widgets/spark_progress/spark_progress.dart';
import 'package:spark_widgets/spark_status/spark_status.dart';

import 'lib/ace.dart';
import 'lib/actions.dart';
import 'lib/analytics.dart' as analytics;
import 'lib/apps/app_utils.dart';
import 'lib/builder.dart';
import 'lib/dart/dart_builder.dart';
import 'lib/editors.dart';
import 'lib/editor_area.dart';
import 'lib/event_bus.dart';
import 'lib/exception.dart';
import 'lib/javascript/js_builder.dart';
import 'lib/json/json_builder.dart';
import 'lib/jobs.dart';
import 'lib/launch.dart';
import 'lib/mobile/deploy.dart';
import 'lib/navigation.dart';
import 'lib/package_mgmt/pub.dart';
import 'lib/package_mgmt/bower.dart';
import 'lib/platform_info.dart';
import 'lib/preferences.dart' as preferences;
import 'lib/services.dart';
import 'lib/scm.dart';
import 'lib/templates/templates.dart';
import 'lib/tests.dart';
import 'lib/utils.dart';
import 'lib/ui/files_controller.dart';
import 'lib/ui/polymer/commit_message_view/commit_message_view.dart';
import 'lib/utils.dart' as utils;
import 'lib/webstore_client.dart';
import 'lib/workspace.dart' as ws;
import 'lib/workspace_utils.dart' as ws_utils;
import 'test/all.dart' as all_tests;

import 'spark_flags.dart';
import 'spark_model.dart';

analytics.Tracker _analyticsTracker = new analytics.NullTracker();
final NumberFormat _nf = new NumberFormat.decimalPattern();

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

abstract class Spark
    extends SparkModel
    implements AceManagerDelegate, Notifier {

  /// The Google Analytics app ID for Spark.
  static final _ANALYTICS_ID = 'UA-45578231-1';

  Services services;
  final JobManager jobManager = new JobManager();
  SparkStatus statusComponent;
  preferences.SparkPreferences prefs;

  AceManager _aceManager;
  ThemeManager _aceThemeManager;
  KeyBindingManager _aceKeysManager;
  AceFontManager _aceFontManager;
  ws.Workspace _workspace;
  ScmManager scmManager;
  EditorManager _editorManager;
  EditorArea _editorArea;
  LaunchManager _launchManager;
  PubManager _pubManager;
  BowerManager _bowerManager;
  ActionManager _actionManager;
  ProjectLocationManager _projectLocationManager;
  NavigationManager _navigationManager;

  EventBus _eventBus;

  FilesController _filesController;

  // Extensions of files that will be shown as text.
  Set<String> _textFileExtensions = new Set.from(
      ['.cmake', '.gitignore', '.prefs', '.txt']);

  Spark() {
    document.title = appName;
  }

  /**
   * The main initialization sequence.
   *
   * Uses [querySelector] to extract HTML elements from the underlying
   * [document], so it should be called only after all those elements become
   * available. In particular with Polymer, that means when the Polymer custom
   * elements in the [document] become upgraded, which is indicated by the
   * [Polymer.onReady] event.
   */
  Future init() {
    initPreferences();
    initEventBus();

    initAnalytics();

    initWorkspace();
    initPackageManagers();
    initServices();
    initScmManager();

    initAceManager();
    initEditorManager();
    initEditorArea();
    initNavigationManager();

    createActions();

    initFilesController();

    initToolbar();
    buildMenu();
    initSplitView();
    initSaveStatusListener();

    initLaunchManager();

    window.onFocus.listen((Event e) {
      // When the user switch to an other application, he might change the
      // content of the workspace from other applications. For that reason, when
      // the user switch back to Spark, we want to check whether the content of
      // the workspace changed.
      _refreshOpenFiles();
    });

    // Add various builders.
    addBuilder(new DartBuilder(this.services));
    if (SparkFlags.performJavaScriptAnalysis) {
      addBuilder(new JavaScriptBuilder());
    }
    addBuilder(new JsonBuilder());

    return restoreWorkspace().then((_) {
      return restoreLocationManager().then((_) {
        // Location manager might have overridden the Ace-related flags from
        // "<project location>/.spark.json".
        initAceManagers();
      });
    });
  }

  //
  // SparkModel interface:
  //

  AceManager get aceManager => _aceManager;
  ThemeManager get aceThemeManager => _aceThemeManager;
  KeyBindingManager get aceKeysManager => _aceKeysManager;
  AceFontManager get aceFontManager => _aceFontManager;
  ws.Workspace get workspace => _workspace;
  EditorManager get editorManager => _editorManager;
  EditorArea get editorArea => _editorArea;
  LaunchManager get launchManager => _launchManager;
  PubManager get pubManager => _pubManager;
  BowerManager get bowerManager => _bowerManager;
  ActionManager get actionManager => _actionManager;
  ProjectLocationManager get projectLocationManager => _projectLocationManager;
  NavigationManager get navigationManager => _navigationManager;
  EventBus get eventBus => _eventBus;

  preferences.PreferenceStore get localPrefs => preferences.localStore;
  preferences.PreferenceStore get syncPrefs => preferences.syncStore;

  //
  // - End SparkModel interface.
  //

  String get appName => utils.i18n('app_name');

  String get appVersion => chrome.runtime.getManifest()['version'];

  /**
   * Get the currently selected [Resource].
   */
  ws.Resource get currentResource => focusManager.currentResource;

  /**
   * Get the [File] currently being edited.
   */
  ws.File get currentEditedFile => focusManager.currentEditedFile;

  /**
   * Get the currently selected [Project].
   */
  ws.Project get currentProject => focusManager.currentProject;

  // TODO(ussuri): The below two methods are a temporary means to make Spark
  // reusable in SparkPolymer. Once the switch to Polymer is complete, they
  // will go away.

  /**
   * Should extract a UI Element from the underlying DOM. This method
   * is overwritten in SparkPolymer, which encapsulates the UI in a top-level
   * Polymer widget, rather than the top-level document's DOM.
   */
  Element getUIElement(String selectors) {
    final Element elt = document.querySelector(selectors);
    assert(elt != null);
    return elt;
  }

  /**
   * Should extract a dialog Element from the underlying UI's DOM. This is
   * different from [getUIElement] in that it's not currently overridden in
   * SparkPolymer.
   */
  Element getDialogElement(String selectors) {
    final Element elt = document.querySelector(selectors);
    assert(elt != null);
    return elt;
  }

  Dialog createDialog(Element dialogElement);

  //
  // Parts of init():
  //

  void initPreferences() {
    prefs = new preferences.SparkPreferences(localPrefs);
  }

  void initServices() {
    services = new Services(this.workspace, _pubManager);
  }

  void initEventBus() {
    _eventBus = new EventBus();
    _eventBus.onEvent(BusEventType.ERROR_MESSAGE).listen(
        (ErrorMessageBusEvent event) {
      showErrorMessage(event.title, event.error.toString());
    });
  }

  void initAnalytics() {
    // Init the analytics tracker and send a page view for the main page.
    analytics.getService('Spark').then((service) {
      _analyticsTracker = service.getTracker(_ANALYTICS_ID);
      _analyticsTracker.sendAppView('main');
    });

    // Track logged exceptions.
    Logger.root.onRecord.listen((LogRecord r) {
      if (!SparkFlags.developerMode && r.level <= Level.INFO) return;

      print(r.toString() + (r.error != null ? ', ${r.error}' : ''));

      if (r.level >= Level.SEVERE) {
        _handleUncaughtException(r.error, r.stackTrace);
      }
    });
  }

  void initWorkspace() {
    _workspace = new ws.Workspace(localPrefs, jobManager);
  }

  void initScmManager() {
    scmManager = new ScmManager(_workspace);
  }

  void initLaunchManager() {
    // TODO(ussuri): Switch to MetaPackageManager as soon as it's done.
    _launchManager = new LaunchManager(_workspace, services,
        pubManager, bowerManager, this);
  }

  void initNavigationManager() {
    _navigationManager = new NavigationManager(_editorManager);
    _navigationManager.onNavigate.listen((NavigationLocation location) {
      _selectFile(location.file).then((_) {
        if (location.selection != null) {
          nextTick().then((_) => _selectLocation(location));
        }
      });
    });
  }

  void _selectLocation(NavigationLocation location) {
    for (Editor editor in editorManager.editors) {
      if (editor.file == location.file) {
        if (editor is TextEditor) {
          editor.select(location.selection);
        }
        return;
      }
    }
  }

  void initPackageManagers() {
    _pubManager = new PubManager(workspace);
    _bowerManager = new BowerManager(workspace);
  }

  void initAceManager() {
    _aceManager = new AceManager(new DivElement(), this, services, localPrefs);

    syncPrefs.getValue('textFileExtensions').then((String value) {
      if (value != null) {
        _textFileExtensions.addAll(JSON.decode(value));
      }
    });
  }

  void initAceManagers() {
    _aceThemeManager = new ThemeManager(
        aceManager, syncPrefs, getUIElement('#changeTheme .settings-value'));
    _aceKeysManager = new KeyBindingManager(
        aceManager, syncPrefs, getUIElement('#changeKeys .settings-value'));
    _aceFontManager = new AceFontManager(
        aceManager, syncPrefs, getUIElement('#changeFont .settings-value'));
  }

  void initEditorManager() {
    _editorManager = new EditorManager(
        workspace, aceManager, prefs, eventBus, services);

    editorManager.loaded.then((_) {
      List<ws.Resource> files = editorManager.files.toList();
      editorManager.files.forEach((file) {
        editorArea.selectFile(file, forceOpen: true, switchesTab: false,
            replaceCurrent: false);
      });
      localPrefs.getValue('lastFileSelection').then((String fileUuid) {
        if (editorArea.tabs.isEmpty) return;
        if (fileUuid == null) {
          editorArea.tabs[0].select();
          return;
        }
        ws.Resource resource = workspace.restoreResource(fileUuid);
        if (resource == null) {
          editorArea.tabs[0].select();
          return;
        }
        _openFile(resource);
      });
    });
  }

  void initEditorArea() {
    _editorArea = new EditorArea(querySelector('#editorArea'), editorManager,
        workspace, allowsLabelBar: true);

    _editorArea.onSelected.listen((EditorTab tab) {
      // We don't change the selection when the file was already selected
      // otherwise, it would break multi-selection (#260).
      if (!_filesController.isFileSelected(tab.file)) {
        _filesController.selectFile(tab.file);
      }
      localPrefs.setValue('lastFileSelection', tab.file.uuid);
      focusManager.setEditedFile(tab.file);
    });
  }

  void initFilesController() {
    _filesController = new FilesController(
        workspace, actionManager, scmManager, eventBus,
        querySelector('#file-item-context-menu'),
        querySelector('#fileViewArea'));
    eventBus.onEvent(BusEventType.FILES_CONTROLLER__SELECTION_CHANGED)
        .listen((FilesControllerSelectionChangedEvent event) {
      focusManager.setCurrentResource(event.resource);
      if (event.resource is ws.File) {
        _openFile(event.resource);
      }
    });
    eventBus.onEvent(BusEventType.FILES_CONTROLLER__PERSIST_TAB)
        .listen((FilesControllerPersistTabEvent event) {
      editorArea.persistTab(event.file);
    });
  }

  void initSplitView() {
    // Overridden in spark_polymer.dart.
  }

  void initSaveStatusListener() {
    // Overridden in spark_polymer.dart.
  }

  void createActions() {
    _actionManager = new ActionManager();

    actionManager.registerAction(new NextMarkerAction(this));
    actionManager.registerAction(new PrevMarkerAction(this));
    actionManager.registerAction(new FileOpenAction(this));
    actionManager.registerAction(new FileNewAction(this, getDialogElement('#fileNewDialog')));
    actionManager.registerAction(new FolderNewAction(this, getDialogElement('#folderNewDialog')));
    actionManager.registerAction(new FolderOpenAction(this));
    actionManager.registerAction(new NewProjectAction(this, getDialogElement('#newProjectDialog')));
    actionManager.registerAction(new FileSaveAction(this));
    actionManager.registerAction(new PubGetAction(this));
    actionManager.registerAction(new PubUpgradeAction(this));
    actionManager.registerAction(new BowerGetAction(this));
    actionManager.registerAction(new BowerUpgradeAction(this));
    actionManager.registerAction(new ApplicationRunAction(this));
    actionManager.registerAction(new DeployToMobileAction(this, getDialogElement('#mobileDeployDialog')));
    actionManager.registerAction(new CompileDartAction(this));
    actionManager.registerAction(new GitCloneAction(this, getDialogElement("#gitCloneDialog")));
    if (SparkFlags.showGitPull) {
      actionManager.registerAction(new GitPullAction(this));
    }
    actionManager.registerAction(new GitBranchAction(this, getDialogElement("#gitBranchDialog")));
    actionManager.registerAction(new GitCheckoutAction(this, getDialogElement("#gitCheckoutDialog")));
    actionManager.registerAction(new GitAddAction(this));
    actionManager.registerAction(new GitResolveConflictsAction(this));
    actionManager.registerAction(new GitCommitAction(this, getDialogElement("#gitCommitDialog")));
    actionManager.registerAction(new GitRevertChangesAction(this));
    actionManager.registerAction(new GitPushAction(this, getDialogElement("#gitPushDialog")));
    actionManager.registerAction(new RunTestsAction(this));
    actionManager.registerAction(new SettingsAction(this, getDialogElement('#settingsDialog')));
    actionManager.registerAction(new AboutSparkAction(this, getDialogElement('#aboutDialog')));
    actionManager.registerAction(new FileRenameAction(this, getDialogElement('#renameDialog')));
    actionManager.registerAction(new ResourceRefreshAction(this));
    // The top-level 'Close' action is removed for now: #1037.
    //actionManager.registerAction(new ResourceCloseAction(this));
    actionManager.registerAction(new TabCloseAction(this));
    actionManager.registerAction(new TabPreviousAction(this));
    actionManager.registerAction(new TabNextAction(this));
    actionManager.registerAction(new SpecificTabAction(this));
    actionManager.registerAction(new TabLastAction(this));
    actionManager.registerAction(new FileExitAction(this));
    actionManager.registerAction(new WebStorePublishAction(this, getDialogElement('#webStorePublishDialog')));
    actionManager.registerAction(new SearchAction(this));
    actionManager.registerAction(new FormatAction(this));
    actionManager.registerAction(new FocusMainMenuAction(this));
    actionManager.registerAction(new ImportFileAction(this));
    actionManager.registerAction(new ImportFolderAction(this));
    actionManager.registerAction(new FileDeleteAction(this));
    actionManager.registerAction(new ProjectRemoveAction(this));
    actionManager.registerAction(new TopLevelFileRemoveAction(this));
    actionManager.registerAction(new PropertiesAction(this, getDialogElement("#propertiesDialog")));
    actionManager.registerAction(new GotoDeclarationAction(this));
    actionManager.registerAction(new HistoryAction.back(this));
    actionManager.registerAction(new HistoryAction.forward(this));
    actionManager.registerAction(new ToggleOutlineVisibilityAction(this));
    actionManager.registerAction(new SendFeedbackAction(this));

    actionManager.registerKeyListener();
  }

  void initToolbar() {
    // Overridden in spark_polymer.dart.
  }

  void buildMenu() {
    // Overridden in spark_polymer.dart.
  }

  void menuActivateEventHandler(CustomEvent event) {
    // Overridden in spark_polymer.dart.
  }

  Future restoreWorkspace() {
    return workspace.restore().then((value) {
      if (workspace.getFiles().length == 0) {
        // No files, just focus the editor.
        aceManager.focus();
      }
    });
  }

  Future restoreLocationManager() {
    return ProjectLocationManager.restoreManager(this).then((manager) {
      _projectLocationManager = manager;
    });
  }

  //
  // - End parts of init().
  //

  void addBuilder(Builder builder) {
    workspace.builderManager.builders.add(builder);
  }

  Future openFile() {
    chrome.ChooseEntryOptions options = new chrome.ChooseEntryOptions(
        type: chrome.ChooseEntryType.OPEN_WRITABLE_FILE);
    return chrome.fileSystem.chooseEntry(options).then((chrome.ChooseEntryResult res) {
      chrome.ChromeFileEntry entry = res.entry;

      if (entry != null) {
        workspace.link(new ws.FileRoot(entry)).then((ws.Resource file) {
          _openFile(file);
          _aceManager.focus();
          workspace.save();
        });
      }
    });
  }

  Future openFolder() {
    return _selectFolder().then((chrome.DirectoryEntry entry) {
      if (entry != null) {
        _OpenFolderJob job = new _OpenFolderJob(entry, this);
        jobManager.schedule(job);
      }
    });
  }

  Future importFile([List<ws.Resource> resources]) {
    chrome.ChooseEntryOptions options = new chrome.ChooseEntryOptions(
        type: chrome.ChooseEntryType.OPEN_FILE);
    return chrome.fileSystem.chooseEntry(options).then(
        (chrome.ChooseEntryResult res) {
      chrome.ChromeFileEntry entry = res.entry;

      if (entry != null) {
        ws.Folder folder = resources.first;
        folder.importFileEntry(entry).catchError((e) {
          showErrorMessage('Error while importing file', e);
        });
      }
    });
  }

  Future importFolder([List<ws.Resource> resources]) {
    chrome.ChooseEntryOptions options = new chrome.ChooseEntryOptions(
        type: chrome.ChooseEntryType.OPEN_DIRECTORY);
    return chrome.fileSystem.chooseEntry(options).then(
        (chrome.ChooseEntryResult res) {
      chrome.DirectoryEntry entry = res.entry;
      if (entry != null) {
        ws.Folder folder = resources.first;
        folder.importDirectoryEntry(entry).catchError((e) {
          showErrorMessage('Error while importing folder', e);
        });
      }
    });
  }

  void showSuccessMessage(String message) {
    statusComponent.temporaryMessage = message;
  }

  Dialog _errorDialog;

  void showMessage(String title, String message) {
    showErrorMessage(title, message);
  }

  void unveil() {
    if (SparkFlags.developerMode) {
      RunTestsAction action = actionManager.getAction('run-tests');
      action.checkForTestListener();
    }
  }

  Editor getCurrentEditor() {
    ws.File file = editorManager.currentFile;
    for (Editor editor in editorManager.editors) {
      if (editor.file == file) return editor;
    }
    return null;
  }

  // TODO(ussuri): The whole show...Message/Dialog() family: polymerize,
  // generalize and offload to SparkPolymerUI.

  /**
   * Show a model error dialog.
   */
  void showErrorMessage(String title, String message) {
    // TODO(ussuri): Polymerize.
    if (_errorDialog == null) {
      _errorDialog = createDialog(getDialogElement('#errorDialog'));
      _errorDialog.getElement("[dismiss]").onClick.listen(_hideBackdropOnClick);
      _errorDialog.getShadowDomElement("#closingX").onClick.listen(_hideBackdropOnClick);
    }

    // TODO(ussuri): Replace with ...title = title once BUG #2252 is resolved.
    _errorDialog.dialog.setAttr('title', true, title);

    Element container = _errorDialog.getElement('#errorMessage');
    container.children.clear();
    var lines = message.split('\n');
    for(String line in lines) {
      Element lineElement = new Element.p();
      lineElement.text = line;
      container.children.add(lineElement);
    }

    _errorDialog.show();
  }

  void _hideBackdropOnClick(MouseEvent event) {
    querySelector("#modalBackdrop").style.display = "none";
  }

  Dialog _publishedAppDialog;

  void showPublishedAppDialog(String appID) {
    // TODO(ussuri): Polymerize.
    if (_publishedAppDialog == null) {
      _publishedAppDialog = createDialog(getDialogElement('#webStorePublishedDialog'));
      _publishedAppDialog.getElement("[submit]").onClick.listen(_hideBackdropOnClick);
      _publishedAppDialog.getElement("#webStorePublishedAction").onClick.listen((MouseEvent event) {
        window.open('https://chrome.google.com/webstore/detail/${appID}',
            '_blank');
        _hideBackdropOnClick(event);
      });
    }
    _publishedAppDialog.show();
  }

  Dialog _uploadedAppDialog;

  void showUploadedAppDialog(String appID) {
    // TODO(ussuri): Polymerize.
    if (_uploadedAppDialog == null) {
      _uploadedAppDialog = createDialog(getDialogElement('#webStoreUploadedDialog'));
      _uploadedAppDialog.getElement("[submit]").onClick.listen(_hideBackdropOnClick);
      _uploadedAppDialog.getElement("#webStoreUploadedAction").onClick.listen((MouseEvent event) {
        window.open('https://chrome.google.com/webstore/developer/edit/${appID}',
            '_blank');
        _hideBackdropOnClick(event);
      });
    }
    _uploadedAppDialog.show();
  }

  Dialog _okCancelDialog;
  Completer<bool> _okCancelCompleter;

  Future<bool> askUserOkCancel(String message,
      {String okButtonLabel: 'OK', String title}) {
    // TODO(ussuri): Polymerize.
    if (_okCancelDialog == null) {
      _okCancelDialog = createDialog(getDialogElement('#okCancelDialog'));
      _okCancelDialog.getElement('#okText').onClick.listen((_) {
        if (_okCancelCompleter != null) {
          _okCancelCompleter.complete(true);
          _okCancelCompleter = null;
        }
      });
      _okCancelDialog.dialog.on['opened'].listen((event) {
        if (event.detail == false) {
          if (_okCancelCompleter != null) {
            _okCancelCompleter.complete(false);
            _okCancelCompleter = null;
          }
        }
      });
    }

    // TODO(ussuri): Replace with ...title = title once BUG #2252 is resolved.
    _okCancelDialog.dialog.setAttr('title', true, title);

    Element container = _okCancelDialog.getElement('#okCancelMessage');
    container.children.clear();
    var lines = message.split('\n');
    for (String line in lines) {
      Element lineElement = new Element.p();
      lineElement.text = line;
      container.children.add(lineElement);
    }

    _okCancelDialog.getElement('#okText').text = okButtonLabel;

    _okCancelCompleter = new Completer();
    _okCancelDialog.show();
    return _okCancelCompleter.future;
  }

  // TODO(ussuri): Find a better way to achieve this (the global progress
  // indicator?).
  void setGitSettingsResetDoneVisible(bool enabled) {
    getUIElement('#gitResetSettingsDone').style.display =
        enabled ? 'block' : 'none';
  }

  List<ws.Resource> _getSelection() => _filesController.getSelection();

  ws.Folder _getFolder([List<ws.Resource> resources]) {
    if (resources != null && resources.isNotEmpty) {
      if (resources.first.isFile) {
        return resources.first.parent;
      } else {
        return resources.first;
      }
    } else {
      if (focusManager.currentResource != null) {
        ws.Resource resource = focusManager.currentResource;
        if (resource.isFile) {
          if (resource.project != null) {
            return resource.parent;
          }
        } else {
          return resource;
        }
      }
    }
    return null;
  }

  void _closeOpenEditor(ws.Resource resource) {
    if (resource is ws.File &&  editorManager.isFileOpened(resource)) {
      editorArea.closeFile(resource);
    }
  }

  /**
   * Refreshes the file name on an opened editor tab.
   */
  void _renameOpenEditor(ws.Resource renamedResource) {
    if (renamedResource is ws.File && editorManager.isFileOpened(renamedResource)) {
      editorArea.renameFile(renamedResource);
    }
  }

  Future _openFile(ws.Resource resource) {
    if (currentEditedFile == resource) return new Future.value();

    if (resource is ws.File) {
      navigationManager.gotoLocation(new NavigationLocation(resource));
      return new Future.value();
    } else {
      return _selectFile(resource);
    }
  }

  Future _selectFile(ws.Resource resource) {
    if (resource.isFile) {
      return editorArea.selectFile(resource);
    } else {
      _filesController.selectFile(resource);
      _filesController.setFolderExpanded(resource);
      return new Future.value();
    }
  }

  //
  // Implementation of AceManagerDelegate interface:
  //

  void setShowFileAsText(String filename, bool enabled) {
    String extension = path.extension(filename);
    if (extension.isEmpty) extension = filename;

    if (enabled) {
      _textFileExtensions.add(extension);
    } else {
      _textFileExtensions.remove(extension);
    }

    syncPrefs.setValue('textFileExtensions',
        JSON.encode(_textFileExtensions.toList()));
  }

  bool canShowFileAsText(String filename) {
    String extension = path.extension(filename);

    // Whitelist files that don't have a period or that start with one. Ex.,
    // `AUTHORS`, `.gitignore`.
    if (extension.isEmpty) return true;

    return _aceManager.isFileExtensionEditable(extension) ||
        _textFileExtensions.contains(extension);
  }

  void openEditor(ws.File file, {Span selection}) {
    navigationManager.gotoLocation(new NavigationLocation(file, selection));
  }

  //
  // - End implementation of AceManagerDelegate interface.
  //

  Timer _filterTimer = null;

  Future<bool> filterFilesList(String searchString) {
    final completer = new Completer<bool>();

    if ( _filterTimer != null) {
      _filterTimer.cancel();
      _filterTimer = null;
    }

    _filterTimer = new Timer(new Duration(milliseconds: 500), () {
      _filterTimer = null;
      completer.complete(_reallyFilterFilesList(searchString));
    });

    return completer.future;
  }

  bool _reallyFilterFilesList(String searchString) {
    return _filesController.performFilter(searchString);
  }

  void _refreshOpenFiles() {
    // In order to scope how much work we do when Spark re-gains focus, we only
    // refresh the active projects. This lets us capture changed files and
    // deleted files. For any other changes it is the user's responsibility to
    // explicitly refresh the affected project.
    Set<ws.Resource> resources = new Set.from(
        editorManager.files.map((r) => r.project != null ? r.project : r));
    resources.forEach((ws.Resource r) => r.refresh());
  }
}

/**
 * Used to manage the default location to create new projects.
 *
 * This class also abstracts a bit other the differences between Chrome OS and
 * Windows/Mac/linux.
 */
class ProjectLocationManager {
  LocationResult _projectLocation;
  final Spark _spark;

  /**
   * Create a ProjectLocationManager asynchronously, restoring the default
   * project location from the given preferences.
   */
  static Future<ProjectLocationManager> restoreManager(Spark spark) {
    //localPrefs, workspace
    return spark.localPrefs.getValue('projectFolder').then((String folderToken) {
      if (folderToken == null) {
        return new ProjectLocationManager._(spark);
      }

      return chrome.fileSystem.restoreEntry(folderToken).then((chrome.Entry entry) {
        return _initFlagsFromProjectLocation(entry).then((_) {
          return new ProjectLocationManager._(spark,
              new LocationResult(entry, entry, false));
        });
      }).catchError((e) {
        return new ProjectLocationManager._(spark);
      });
    });
  }

  /**
   * Try to read and set the highest precedence developer flags from
   * "<project_location>/.spark.json".
   */
  static Future _initFlagsFromProjectLocation(chrome.DirectoryEntry projDir) {
    return projDir.getFile('.spark.json').then(
        (chrome.ChromeFileEntry flagsFile) {
      return SparkFlags.initFromFile(flagsFile.readText());
    }).catchError((_) {
      // Ignore missing file.
      return new Future.value();
    });
  }

  //this._prefs, this._workspace
  ProjectLocationManager._(this._spark, [this._projectLocation]);

  /**
   * Returns the default location to create new projects in. For Chrome OS, this
   * will be the sync filesystem. This method can return `null` if the user
   * cancels the folder selection dialog.
   */
  Future<LocationResult> getProjectLocation() {
    if (_projectLocation != null) {
      // Check if the saved location exists. If so, return it. Otherwise, get a
      // new location.
      return _projectLocation.exists().then((bool value) {
        if (value) {
          return _projectLocation;
        } else {
          _projectLocation = null;
          return getProjectLocation();
        }
      });
    }

    // On Chrome OS, use the sync filesystem.
    if (PlatformInfo.isCros && _spark.workspace.syncFsIsAvailable) {
      return chrome.syncFileSystem.requestFileSystem().then((fs) {
        var entry = fs.root;
        return new LocationResult(entry, entry, true);
      });
    }

    // Show a dialog with explaination about what this folder is for.
    return _showRequestFileSystemDialog().then((bool accepted) {
      if (!accepted) {
        return null;
      }
      // Display a dialog asking the user to choose a default project folder.
      return _selectFolder(suggestedName: 'projects').then((entry) {
        if (entry == null) {
          return null;
        }

        _projectLocation = new LocationResult(entry, entry, false);
        _spark.localPrefs.setValue('projectFolder',
            chrome.fileSystem.retainEntry(entry));
        return _projectLocation;
      });
    });
  }

  Future<bool> _showRequestFileSystemDialog() {
    return _spark.askUserOkCancel('Please choose a folder to store your Spark projects.',
        okButtonLabel: 'Choose Folder', title: 'Choose top-level workspace folder');
  }

  /**
   * This will create a new folder in default project location. It will attempt
   * to use the given [defaultName], but will disambiguate it if necessary. For
   * example, if `defaultName` already exists, the created folder might be named
   * something like `defaultName-1` instead.
   */
  Future<LocationResult> createNewFolder(String defaultName) {
    return getProjectLocation().then((LocationResult root) {
      return root == null ? null : _create(root, defaultName, 1);
    });
  }

  Future<LocationResult> _create(
      LocationResult location, String baseName, int count) {
    String name = count == 1 ? baseName : '${baseName}-${count}';

    return location.parent.createDirectory(name, exclusive: true).then((dir) {
      return new LocationResult(location.parent, dir, location.isSync);
    }).catchError((_) {
      if (count > 50) {
        throw "Error creating project '${baseName}.'";
      } else {
        return _create(location, baseName, count + 1);
      }
    });
  }
}

class LocationResult {
  /**
   * The parent Entry. This can be useful for persistng the info across
   * sessions.
   */
  final chrome.DirectoryEntry parent;

  /**
   * The created location.
   */
  final chrome.DirectoryEntry entry;

  /**
   * Whether the entry was created in the sync filesystem.
   */
  final bool isSync;

  LocationResult(this.parent, this.entry, this.isSync);

  /**
   * The name of the created entry.
   */
  String get name => entry.name;

  Future<bool> exists() {
    if (isSync) return new Future.value(true);

    return entry.getMetadata().then((_) {
      return true;
    }).catchError((e) {
      return false;
    });
  }
}

/**
 * Allows a user to select a folder on disk. Returns the selected folder
 * entry. Returns `null` in case the user cancels the action.
 */
Future<chrome.DirectoryEntry> _selectFolder({String suggestedName}) {
  Completer completer = new Completer();
  chrome.ChooseEntryOptions options = new chrome.ChooseEntryOptions(
      type: chrome.ChooseEntryType.OPEN_DIRECTORY);
  if (suggestedName != null) options.suggestedName = suggestedName;
  chrome.fileSystem.chooseEntry(options).then((chrome.ChooseEntryResult res) {
    completer.complete(res.entry);
  }).catchError((e) => completer.complete(null));
  return completer.future;
}

/**
 * The abstract parent class of Spark related actions.
 */
abstract class SparkAction extends Action {
  final Spark spark;

  SparkAction(this.spark, String id, String name) : super(id, name);

  void invoke([Object context]) {
    // Send an action event with the 'main' event category.
    _analyticsTracker.sendEvent('main', id);

    try {
      _invoke(context);
    } catch (e) {
      spark.showErrorMessage('Error Invoking ${name}', '${e}');
    }
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
   * [Project].
   */
  bool _isProject(object) {
    if (!_isResourceList(object)) {
      return false;
    }
    return object.length == 1 && object.first is ws.Project;
  }

  /**
   * Returns true if `context` is a list with a single item, the item is a
   * [Project], and that project is under SCM.
   */
  bool _isScmProject(context) =>
      _isProject(context) && isUnderScm(context.first);

  /**
   * Returns true if `context` is a list with of items, all in the same project,
   * and that project is under SCM.
   */
  bool _isUnderScmProject(context) {
    if (context is! List) return false;
    if (context.isEmpty) return false;

    ws.Project project = context.first.project;

    if (!isUnderScm(project)) return false;

    for (var resource in context) {
      var resProject = resource.project;
      if (resProject == null || resProject != project) {
        return false;
      }
    }

    return true;
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
   * Returns true if `object` is a top-level [File].
   */
  bool _isTopLevelFile(Object object) {
    if (!_isResourceList(object)) {
      return false;
    }
    List<ws.Resource> resources = object as List;
    return (resources.length == 1) && (resources.first.project == null);
  }

  /**
   * Returns true if `object` is a list of resources and one at least is a
   * top-level [Resource].
   */
  bool _hasTopLevelResource(Object object) {
    if (!_isResourceList(object)) {
      return false;
    }
    List<ws.Resource> resources = object as List;
    return resources.firstWhere((ws.Resource r) => r.isTopLevel,
        orElse: () => null) != null;
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

abstract class Dialog {
  void show();
  void hide();
  SparkDialog get dialog;
  Element getElement(String selectors);
  List<Element> getElements(String selectors);
  Element getShadowDomElement(String selectors);
}

abstract class SparkActionWithDialog extends SparkAction {
  Dialog _dialog;

  SparkActionWithDialog(Spark spark,
                        String id,
                        String name,
                        Element dialogElement)
      : super(spark, id, name) {
    _dialog = spark.createDialog(dialogElement);
    final Element submitBtn = _dialog.getElement("[submit]");
    if (submitBtn != null) {
      submitBtn.onClick.listen((_) => _commit());
    }
  }

  void _commit() => _hide();
  void _cancel() => _hide();

  Element getElement(String selectors) => _dialog.getElement(selectors);

  List<Element> getElements(String selectors) =>
      _dialog.getElements(selectors);

  Element _triggerOnReturn(String selectors, [bool hideDialog = true]) {
    var element = _dialog.getElement(selectors);
    element.onKeyDown.listen((event) {
      if (event.keyCode == KeyCode.ENTER) {
        _commit();
        if (hideDialog) {
          _dialog.hide();
        }
      }
    });
    return element;
  }

  void _show() => _dialog.show();
  void _hide() => _dialog.hide();
}

class FileOpenAction extends SparkAction {
  FileOpenAction(Spark spark) : super(spark, "file-open", "Open File…") {
    addBinding("ctrl-o");
  }

  void _invoke([Object context]) {
    spark.openFile();
  }
}

class FileNewAction extends SparkActionWithDialog implements ContextAction {
  InputElement _nameElement;
  ws.Folder folder;

  FileNewAction(Spark spark, Element dialog)
      : super(spark, "file-new", "New File…", dialog) {
    addBinding("ctrl-n");
    _nameElement = _triggerOnReturn("#fileName");
  }

  void _invoke([List<ws.Resource> resources]) {
    folder = spark._getFolder(resources);
    if (folder != null) {
      _nameElement.value = '';
      _show();
    }
  }

  void _commit() {
    var name = _nameElement.value;
    if (name.isNotEmpty) {
      if (folder != null) {
        folder.createNewFile(name).then((file) {
          // Delay a bit to allow the files view to process the new file event.
          // TODO: This is due to a race condition in when the files view receives
          // the resource creation event; we should remove the possibility for
          // this to occur.
          Timer.run(() {
            spark._openFile(file).then((_) {
              spark.editorArea.persistTab(file);
            });
            spark._aceManager.focus();
          });
        }).catchError((e) {
          spark.showErrorMessage("Error Creating File", e.toString());
        });
      }
    }
  }

  String get category => 'folder';

  bool appliesTo(Object object) => _isSingleResource(object) && !_isTopLevelFile(object);
}

class FileSaveAction extends SparkAction {
  FileSaveAction(Spark spark) : super(spark, "file-save", "Save") {
    addBinding("ctrl-s");
  }

  void _invoke([Object context]) => spark.editorManager.saveAll();
}

class FileDeleteAction extends SparkAction implements ContextAction {
  FileDeleteAction(Spark spark) : super(spark, "file-delete", "Delete");

  void _invoke([List<ws.Resource> resources]) {
    if (resources == null) {
      var sel = spark._filesController.getSelection();
      if (sel.isEmpty) return;
      resources = sel;
    }

    String message;
    if (resources.length == 1) {
      message = "Do you really want to delete '${resources.first.name}'?\nThis will permanently delete this file from disk and cannot be undone.";
    } else {
      message = "Do you really want to delete ${resources.length} files?\nThis will permanently delete the files from disk and cannot be undone.";
    }

    spark.askUserOkCancel(message, okButtonLabel: 'Delete').then((bool val) {
      if (val) {
        spark.workspace.pauseResourceEvents();
        Future.forEach(resources, (ws.Resource r) => r.delete()).catchError((e) {
          String ordinality = resources.length == 1 ? "File" : "Files";
          spark.showErrorMessage("Error while deleting ${ordinality}", e.toString());
        }).whenComplete(() {
          spark.workspace.resumeResourceEvents();
          spark.workspace.save();
        });
      }
    });
  }

  String get category => 'resource';

  bool appliesTo(Object object) => _isResourceList(object) &&
      !_hasTopLevelResource(object);
}

// TODO(ussuri): Convert to SparkActionWithDialog.
class ProjectRemoveAction extends SparkAction implements ContextAction {
  ProjectRemoveAction(Spark spark) : super(spark, "project-remove", "Remove");

  void _invoke([List<ws.Resource> resources]) {
    ws.Project project = resources.first;
    // If project is on sync filesystem, it can only be deleted.
    // It can't be unlinked.
    if (project.isSyncResource()) {
      _deleteProject(project);
      return;
    }

    Dialog _dialog =
        spark.createDialog(spark.getDialogElement('#projectRemoveDialog'));
    _dialog.getElement("#projectRemoveProjectName").text =
        project.name;
    _dialog.getElement("#projectRemoveDeleteButton")
        .onClick.listen((_) => _deleteProject(project));
    _dialog.getElement("#projectRemoveRemoveReferenceButton")
        .onClick.listen((_) => _removeProjectReference(project));
    _dialog.show();
  }

  void _deleteProject(ws.Project project) {
    spark.askUserOkCancel('''
Do you really want to delete "${project.name}"?
This will permanently delete the project contents from disk and cannot be undone.
''', okButtonLabel: 'Delete', title: 'Delete Project from Disk').then((bool val) {
      if (val) {
        // TODO(grv) : scmManger should listen to the delete project event.
        spark.scmManager.removeProject(project);
        project.delete().catchError((e) {
          spark.showErrorMessage("Error while deleting project", e.toString());
        });
        spark.workspace.save();
      }
    });
  }

  void _removeProjectReference(ws.Project project) {
    spark.workspace.unlink(project);
    spark.workspace.save();
  }

  String get category => 'resource';

  bool appliesTo(Object object) => _isProject(object);
}

// TODO(ussuri): 1) Convert to SparkActionWithDialog. 2) This dialog is almost
// the same as ProjectRemoveAction -- combine.
class TopLevelFileRemoveAction extends SparkAction implements ContextAction {
  TopLevelFileRemoveAction(Spark spark) : super(spark, "top-level-file-remove", "Remove");

  void _invoke([List<ws.Resource> resources]) {
    ws.File file = resources.first;

    Dialog _dialog =
        spark.createDialog(spark.getDialogElement('#fileRemoveDialog'));
    _dialog.getElement("#fileRemoveFileName").text =
        file.name;
    _dialog.getElement("#fileRemoveDeleteButton")
        .onClick.listen((_) => _deleteFile(file));
    _dialog.getElement("#fileRemoveRemoveReferenceButton")
        .onClick.listen((_) => _removeFileReference(file));
    _dialog.show();
  }

  void _deleteFile(ws.File file) {
    spark.askUserOkCancel('''
Do you really want to delete "${file.name}"?
This will permanently delete the file from disk and cannot be undone.
''', okButtonLabel: 'Delete', title: 'Delete File from Disk').then((bool val) {
      if (val) {
        file.delete().catchError((e) {
          spark.showErrorMessage("Error while deleting file", e.toString());
        });
        spark.workspace.save();
      }
    });
  }

  void _removeFileReference(ws.File file) {
    spark.workspace.unlink(file);
    spark.workspace.save();
  }

  String get category => 'resource';

  bool appliesTo(Object object) => _isTopLevelFile(object);
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
      resource.rename(_nameElement.value).then((value) {
        spark._renameOpenEditor(resource);
      }).catchError((e) {
        spark.showErrorMessage("Error During Rename", e.toString());
      });
    }
  }

  String get category => 'resource';

  bool appliesTo(Object object) => _isSingleResource(object) && !_isTopLevel(object);
}

class ResourceCloseAction extends SparkAction implements ContextAction {
  ResourceCloseAction(Spark spark) : super(spark, "file-close", "Close");

  void _invoke([List<ws.Resource> resources]) {
    if (resources == null) {
      resources = spark._getSelection();
    }

    for (ws.Resource resource in resources) {
      spark.workspace.unlink(resource);
      if (resource is ws.File) {
        spark._closeOpenEditor(resource);
      } else if (resource is ws.Project) {
        resource.traverse().forEach(spark._closeOpenEditor);
      }
    }

    spark.workspace.save();
  }

  String get category => 'resource';

  bool appliesTo(Object object) => _isTopLevel(object);
}

class TabPreviousAction extends SparkAction {
  TabPreviousAction(Spark spark) : super(spark, "tab-prev", "Previous Tab") {
    addBinding('ctrl-shift-[');
    addBinding('ctrl-shift-tab', macBinding: 'macctrl-shift-tab');
  }

  void _invoke([Object context]) => spark.editorArea.gotoPreviousTab();
}

class TabNextAction extends SparkAction {
  TabNextAction(Spark spark) : super(spark, "tab-next", "Next Tab") {
    addBinding('ctrl-shift-]');
    addBinding('ctrl-tab', macBinding: 'macctrl-tab');
  }

  void _invoke([Object context]) => spark.editorArea.gotoNextTab();
}

class SpecificTabAction extends SparkAction {
  _SpecificTabKeyBinding _binding;

  SpecificTabAction(Spark spark) : super(spark, "tab-goto", "Goto Tab") {
    _binding = new _SpecificTabKeyBinding();
    bindings.add(_binding);
  }

  void _invoke([Object context]) {
    if (_binding.index < 1 && _binding.index > spark.editorArea.tabs.length) {
      return;
    }

    // Ctrl-1 to Ctrl-8. The user types in a 1-based key event; we convert that
    // into a 0-based into into the tabs.
    spark.editorArea.selectedTab = spark.editorArea.tabs[_binding.index - 1];
  }
}

class _SpecificTabKeyBinding extends KeyBinding {
  final int ONE_CODE = '1'.codeUnitAt(0);
  final int EIGHT_CODE = '8'.codeUnitAt(0);

  int index = -1;

  _SpecificTabKeyBinding() : super('ctrl-1');

  bool matches(KeyboardEvent event) {
    // If the user typed in a 1 to an 8, change this binding to match that key.
    // To match completely, the user will need to have used the `ctrl` modifier.
    if (event.keyCode >= ONE_CODE && event.keyCode <= EIGHT_CODE) {
      keyCode = event.keyCode;
      index = keyCode - ONE_CODE + 1;
    }

    return super.matches(event);
  }
}

class TabLastAction extends SparkAction {
  TabLastAction(Spark spark) : super(spark, "tab-last", "Last Tab") {
    addBinding("ctrl-9");
  }

  void _invoke([Object context]) {
    if (spark.editorArea.tabs.isNotEmpty) {
      spark.editorArea.selectedTab = spark.editorArea.tabs.last;
    }
  }
}

class TabCloseAction extends SparkAction {
  TabCloseAction(Spark spark) : super(spark, "tab-close", "Close") {
    addBinding("ctrl-w");
  }

  void _invoke([Object context]) {
    if (spark.editorArea.selectedTab != null) {
      spark.editorArea.remove(spark.editorArea.selectedTab);
    }
  }
}

class FileExitAction extends SparkAction {
  FileExitAction(Spark spark) : super(spark, "file-exit", "Quit") {
    addBinding('ctrl-q', linuxBinding: 'ctrl-shift-q');
  }

  void _invoke([Object context]) {
    spark.close().then((_) {
      chrome.app.window.current().close();
    });
  }
}

class ApplicationRunAction extends SparkAction implements ContextAction {
  ApplicationRunAction(Spark spark) : super(
      spark, "application-run", "Run") {
    addBinding("ctrl-r");
    enabled = false;
    spark.focusManager.onResourceChange.listen((r) => _updateEnablement(r));
  }

  void _invoke([context]) {
    ws.Resource resource;

    if (context == null) {
      resource = spark.focusManager.currentResource;
    } else {
      resource = context.first;
    }

    Completer completer = new Completer();
    ProgressJob job = new ProgressJob("Running application…", completer);
    spark.launchManager.performLaunch(resource, LaunchTarget.LOCAL).then((_) {
      completer.complete();
    }).catchError((e) {
      completer.complete();
      spark.showErrorMessage('Error Running Application', '${e}');
    });
  }

  String get category => 'application';

  bool appliesTo(list) => list.length == 1 && _appliesTo(list.first);

  bool _appliesTo(ws.Resource resource) {
    return spark.launchManager.canLaunch(resource, LaunchTarget.LOCAL);
  }

  void _updateEnablement(ws.Resource resource) {
    enabled = _appliesTo(resource);
  }
}

abstract class PackageManagementAction
    extends SparkAction implements ContextAction {
  PackageManagementAction(Spark spark, String id, String name) :
    super(spark, id, name);

  void _invoke([context]) {
    ws.Resource resource;

    if (context == null) {
      resource = spark.focusManager.currentResource;
    } else {
      // NOTE: [appliesTo] should ensure that this is the right choice.
      resource = context.first;
    }

    // [appliesTo] delegates to [PackageServiceProperties.isPackageResource],
    // which is expected to return true if:
    // - the resourse is a folder that contains a package spec file: this is our
    //   target, a "package dir" by definition.
    // - the resource is a package spec file itself: our target is its parent,
    //   which would fall into the case above if the user clicked on it instead.
    if (resource is ws.File) {
      resource = resource.parent;
    }

    spark.jobManager.schedule(_createJob(resource as ws.Folder));
  }

  String get category => 'application';

  bool appliesTo(list) => list.length == 1 && _appliesTo(list.first);

  bool _appliesTo(ws.Resource resource);

  Job _createJob(ws.Container container);
}

abstract class PubAction extends PackageManagementAction {
  PubAction(Spark spark, String id, String name) : super(spark, id, name);

  bool _appliesTo(ws.Resource resource) =>
      spark.pubManager.properties.isPackageResource(resource);
}

class PubGetAction extends PubAction {
  PubGetAction(Spark spark) : super(spark, "pub-get", "Pub Get");

  Job _createJob(ws.Folder container) => new PubGetJob(spark, container);
}

class PubUpgradeAction extends PubAction {
  PubUpgradeAction(Spark spark) : super(spark, "pub-upgrade", "Pub Upgrade");

  Job _createJob(ws.Folder container) => new PubUpgradeJob(spark, container);
}

abstract class BowerAction extends PackageManagementAction {
  BowerAction(Spark spark, String id, String name) : super(spark, id, name);

  bool _appliesTo(ws.Resource resource) =>
      spark.bowerManager.properties.isPackageResource(resource);
}

class BowerGetAction extends BowerAction {
  BowerGetAction(Spark spark) : super(spark, "bower-install", "Bower Install");

  Job _createJob(ws.Folder container) => new BowerGetJob(spark, container);
}

class BowerUpgradeAction extends BowerAction {
  BowerUpgradeAction(Spark spark) : super(spark, "bower-upgrade", "Bower Update");

  Job _createJob(ws.Folder container) => new BowerUpgradeJob(spark, container);
}

/**
 * A context menu item to compile a Dart file to JavaScript. Currently this is
 * only available for Dart files in a chrome app.
 */
class CompileDartAction extends SparkAction implements ContextAction {
  CompileDartAction(Spark spark) : super(spark, "dart-compile", "Compile to JavaScript");

  void _invoke([context]) {
    ws.Resource resource;

    if (context == null) {
      resource = spark.focusManager.currentResource;
    } else {
      resource = context.first;
    }

    spark.jobManager.schedule(
        new CompileDartJob(spark, resource, resource.name));
  }

  String get category => 'application';

  bool appliesTo(list) => list.length == 1 && _appliesTo(list.first);

  bool _appliesTo(ws.Resource resource) {
    bool isDartFile = resource is ws.File && resource.project != null
        && resource.name.endsWith('.dart');

    if (!isDartFile) return false;

    return resource.parent.getChild('manifest.json') != null;
  }
}

class ResourceRefreshAction extends SparkAction implements ContextAction {
  ResourceRefreshAction(Spark spark) : super(
      spark, "resource-refresh", "Refresh") {
    // On Chrome OS, bind to the dedicated refresh key.
    if (PlatformInfo.isCros) {
      // 168 (0xA8) is the key code of the refresh key on ChromeOS.
      // TODO(devoncarew): Figure out how to get the F3 key event on ChromeOS.
      //addBinding('f5', linuxBinding: '0xA8');
      addBinding('f5', linuxBinding: 'f3');
    } else {
      addBinding('f5');
    }
  }

  void _invoke([context]) {
    List<ws.Resource> resources;

    if (context == null) {
      resources = [spark.focusManager.currentResource];
    } else {
      resources = context;
    }

    ResourceRefreshJob job = new ResourceRefreshJob(resources);
    spark.jobManager.schedule(job);
  }

  String get category => 'resource';

  bool appliesTo(context) => _isSingleFolder(context);
}

class PrevMarkerAction extends SparkAction {
  PrevMarkerAction(Spark spark) : super(
      spark, "marker-prev", "Previous Marker") {
    addBinding("ctrl-shift-p");
  }

  void _invoke([Object context]) {
    spark._aceManager.selectPrevMarker();
  }
}

class NextMarkerAction extends SparkAction {
  NextMarkerAction(Spark spark) : super(
      spark, "marker-next", "Next Marker") {
    // TODO: We probably don't want to bind to 'print'. Perhaps there's a good
    // keybinding we can borrow from Chrome?
    addBinding("ctrl-p");
  }

  void _invoke([Object context]) {
    spark._aceManager.selectNextMarker();
  }
}

class FolderNewAction extends SparkActionWithDialog implements ContextAction {
  InputElement _nameElement;
  ws.Folder folder;

  FolderNewAction(Spark spark, Element dialog)
      : super(spark, "folder-new", "New Folder…", dialog) {
    addBinding("ctrl-shift-n");
    _nameElement = _triggerOnReturn("#folderName");
  }

  void _invoke([List<ws.Folder> folders]) {
    folder = spark._getFolder(folders);
    _nameElement.value = '';
    _show();
  }

  void _commit() {
    final String name = _nameElement.value;
    if (name.isNotEmpty) {
      folder.createNewFolder(name).then((folder) {
        // Delay a bit to allow the files view to process the new file event.
        Timer.run(() {
          spark._filesController.selectFile(folder);
        });
      }).catchError((e) {
        spark.showErrorMessage("Error Creating Folder", e.toString());
      });
    }
  }

  String get category => 'folder';

  bool appliesTo(Object object) => _isSingleFolder(object);
}

class FormatAction extends SparkAction {
  FormatAction(Spark spark) : super(spark, 'edit-format', 'Format') {
    // TODO: I do not like this binding, but can't think of a better one.
    addBinding('ctrl-shift-1');
  }

  void _invoke([Object context]) {
    Editor editor = spark.getCurrentEditor();
    if (editor is TextEditor) {
      editor.format();
    }
  }
}

/// Transfers the focus to the search box
class SearchAction extends SparkAction {
  SearchAction(Spark spark) : super(spark, 'search', 'Search') {
    addBinding('ctrl-shift-f');
  }

  @override
  void _invoke([Object context]) {
    spark.getUIElement('#fileFilter').focus();
  }
}

class GotoDeclarationAction extends SparkAction {
  static const String TIMEOUT_ERROR = "Declaration information not yet available";
  static const String NOT_FOUND_ERROR = "No declaration found";

  AnalyzerService _analysisService;

  GotoDeclarationAction(Spark spark)
      : super(spark, 'navigate-declaration', 'Goto Declaration') {
    addBinding('ctrl-.');
    addBinding('F3');
    _analysisService = spark.services.getService('analyzer');

    // Needed for ACCEL + click support
    spark.aceManager.onGotoDeclaration.listen((_) => gotoDeclaration());
  }

  @override
  void _invoke([Object context]) => gotoDeclaration();

  void gotoDeclaration() {
    Editor editor = spark.getCurrentEditor();
    if (editor is TextEditor) {
      editor.navigateToDeclaration(new Duration(milliseconds: 500)).then(
          (Declaration declaration) {
        if (declaration == null) spark.showSuccessMessage(NOT_FOUND_ERROR);
      }).catchError((TimeoutException e) {
        spark.showSuccessMessage(TIMEOUT_ERROR);
      });
    }
  }
}

class HistoryAction extends SparkAction {
  bool _forward;

  HistoryAction.back(Spark spark) : super(spark, 'navigate-back', 'Back') {
    addBinding('ctrl-[');
    addBinding('ctrl-left');
    _init(false);
  }

  HistoryAction.forward(Spark spark) : super(spark, 'navigate-forward', 'Forward') {
    addBinding('ctrl-]');
    addBinding('ctrl-right');
    _init(true);
  }

  void _init(bool value) {
    _forward = value;
    enabled = false;

    spark.navigationManager.onNavigate.listen((_) {
      if (_forward) {
        enabled = spark.navigationManager.canGoForward();
      } else {
        enabled = spark.navigationManager.canGoBack();
      }
    });
  }

  @override
  void _invoke([Object context]) {
    if (_forward) {
      spark.navigationManager.goForward();
    } else {
      spark.navigationManager.goBack();
    }
  }
}

class FocusMainMenuAction extends SparkAction {
  FocusMainMenuAction(Spark spark)
      : super(spark, 'focusMainMenu', 'Focus Main Menu') {
    addBinding('f10');
  }

  @override
  void _invoke([Object context]) {
    spark.getUIElement('#mainMenu').focus();
  }
}

class NewProjectAction extends SparkActionWithDialog {
  InputElement _nameElt;
  ws.Folder folder;

  static const _KNOWN_JS_PACKAGES = const {
      'polymer': 'Polymer/polymer#master',
      'core-elements': 'Polymer/core-elements#master'
  };
  // Matches: "proj-template", "proj-template;polymer,core-elements".
  static final _TEMPLATE_REGEX = new RegExp(r'([\/\w_-]+)(;(([\w-],?)+))?');

  NewProjectAction(Spark spark, Element dialog)
      : super(spark, "project-new", "New Project…", dialog) {
    _nameElt = _triggerOnReturn("#name");
  }

  void _invoke([context]) {
    _nameElt.value = '';
    _show();
  }

  void _commit() {
    final name = _nameElt.value.trim();

    if (name.isEmpty) return;

    spark.projectLocationManager.createNewFolder(name)
        .then((LocationResult location) {
      if (location == null) {
        return new Future.value();
      }

      ws.WorkspaceRoot root;
      final locationEntry = location.entry;

      if (location.isSync) {
        root = new ws.SyncFolderRoot(locationEntry);
      } else {
        root = new ws.FolderChildRoot(location.parent, locationEntry);
      }

      // TODO(ussuri): Can this no-op `return Future.value()` be removed?
      return new Future.value().then((_) {
        final List<ProjectTemplate> templates = [];

        final globalVars = [
            new TemplateVar('projectName', name),
            new TemplateVar('sourceName', name.toLowerCase())
        ];

        // Add a template for the main project type.
        final SelectElement projectTypeElt = getElement('select[name="type"]');
        final Match match = _TEMPLATE_REGEX.matchAsPrefix(projectTypeElt.value);
        assert(match.groupCount > 0);
        final String templId = match.group(1);
        final String jsDepsStr = match.group(3);

        templates.add(new ProjectTemplate(templId, globalVars));

        // Possibly also add a mix-in template for JS dependencies, if the
        // project type requires them.
        if (jsDepsStr != null) {
          List<String> jsDeps = [];
          for (final depName in jsDepsStr.split(',')) {
            final String depPath = _KNOWN_JS_PACKAGES[depName];
            assert(depPath != null);
            jsDeps.add('"$depName": "$depPath"');
          }
          if (jsDeps.isNotEmpty) {
            final localVars = [
                new TemplateVar('dependencies', jsDeps.join(',\n    '))
            ];
            templates.add(
                new ProjectTemplate("addons/bower_deps", globalVars, localVars));
          }
        }

        return new ProjectBuilder(locationEntry, templates).build();

      }).then((_) {
        return spark.workspace.link(root).then((ws.Project project) {
          spark.showSuccessMessage('Created ${project.name}');
          Timer.run(() {
            spark._openFile(ProjectBuilder.getMainResourceFor(project));

            // Run Pub if the new project has a pubspec file.
            if (spark.pubManager.properties.isFolderWithPackages(project)) {
              spark.jobManager.schedule(new PubGetJob(spark, project));
            }

            // Run Bower if the new project has a bower.json file.
            if (spark.bowerManager.properties.isFolderWithPackages(project)) {
              spark.jobManager.schedule(new BowerGetJob(spark, project));
            }
          });
          spark.workspace.save();
        });
      });
    }).catchError((e) {
      spark.showErrorMessage('Error Creating Project', '${e}');
    });
  }
}

class FolderOpenAction extends SparkAction {
  FolderOpenAction(Spark spark) : super(spark, "folder-open", "Add Folder to Workspace…");

  void _invoke([Object context]) {
    spark.openFolder();
  }
}

class DeployToMobileAction extends SparkActionWithDialog implements ContextAction {
  InputElement _pushUrlElement;
  ws.Container deployContainer;

  DeployToMobileAction(Spark spark, Element dialog)
      : super(spark, "application-push", "Deploy to Mobile", dialog) {
    _pushUrlElement = _triggerOnReturn("#pushUrl");
    enabled = false;
    spark.focusManager.onResourceChange.listen((r) => _updateEnablement(r));

    // When the IP address field is selected, check the `IP` checkbox.
    getElement('#pushUrl').onFocus.listen((e) {
      (getElement('#ip') as InputElement).checked = true;
    });
  }

  Element get _deployDeviceMessage => getElement('#deployCheckDeviceMessage');

  SparkDialogButton get _deployButton => getElement("[submit]");

  void _invoke([context]) {
    ws.Resource resource;

    if (context == null) {
      resource = spark.focusManager.currentResource;
    } else {
      resource = context.first;
    }

    deployContainer = getAppContainerFor(resource);

    if (deployContainer == null) {
      spark.showErrorMessage(
          'Unable to Deploy',
          'Unable to deploy the current selection; please select a Chrome App '
          'to deploy.');
    } else if (!MobileDeploy.isAvailable()) {
      spark.showErrorMessage('Unable to Deploy', 'No USB devices available.');
    } else {
      _toggleProgressVisible(false);
      _show();
    }
  }

  String get category => 'application';

  bool appliesTo(list) => list.length == 1 && _appliesTo(list.first);

  bool _appliesTo(ws.Resource resource) {
    return getAppContainerFor(resource) != null;
  }

  void _updateEnablement(ws.Resource resource) {
    enabled = _appliesTo(resource);
  }

  void _commit() {
    SparkProgress progressComponent = getElement('#deployProgress');
    progressComponent.progressMessage = "Deploying...";
    _toggleProgressVisible(true);

    ProgressMonitor monitor = new ProgressMonitorImpl(progressComponent);

    String type = getElement('input[name="type"]:checked').id;
    bool useAdb = type == 'adb';
    String url = _pushUrlElement.value;

    MobileDeploy deployer = new MobileDeploy(deployContainer, spark.localPrefs);

    // Invoke the deployer methods in Futures in order to capture exceptions.
    Future f = new Future(() {
      return useAdb ?
          deployer.pushAdb(monitor) : deployer.pushToHost(url, monitor);
    });

    monitor.runCancellableFuture(f).then((_) {
      _hide();
      spark.showSuccessMessage('Successfully pushed');
    }).catchError((e) {
      if (e is! UserCancelledException) {
        spark.showMessage('Push Failure', e.toString());
      }
    }).whenComplete(() {
      _toggleProgressVisible(false);
    });
  }

  void _toggleProgressVisible(bool visible) {
    SparkProgress progressComponent = getElement('#deployProgress');
    progressComponent.visible = visible;
    progressComponent.deliverChanges();

    _deployDeviceMessage.style.visibility = visible ? 'visible' : 'hidden';

    _deployButton.disabled = visible;
    _deployButton.deliverChanges();
  }
}

class ProgressMonitorImpl extends ProgressMonitor {
  final SparkProgress _sparkProgress;

  ProgressMonitorImpl(this._sparkProgress) {
    _sparkProgress.onCancelled.listen((_) {
      cancelled = true;
    });
  }

  void start(String title, [num maxWork = 0]) {
    super.start(title, maxWork);

    _sparkProgress.progressMessage = title == null ? '' : title;

    if (maxWork == 0) {
      _sparkProgress.indeterminate = true;
    } else {
      _sparkProgress.value = 0;
    }
  }

  void worked(num amount) {
    super.worked(amount);

    _sparkProgress.value = progress * 100;
  }

  void done() {
    super.done();

    _sparkProgress.value = progress * 100;
  }

  set cancelled(bool val) {
    super.cancelled = val;

    _sparkProgress.indeterminate = true;
  }
}

class PropertiesAction extends SparkActionWithDialog implements ContextAction {
  ws.Resource _selectedResource;
  Element _titleElement;
  HtmlElement _propertiesElement;

  PropertiesAction(Spark spark, Element dialog)
      : super(spark, 'properties', 'Properties…', dialog) {
    // TODO(ussuri): This is a hack. Polymerize.
    _titleElement = dialog.shadowRoot.querySelector('#title');
    _propertiesElement = dialog.querySelector('#body');
  }

  void _invoke([List context]) {
    _selectedResource = context.first;
    final String type = _selectedResource is ws.Project ? 'Project' :
      _selectedResource is ws.Container ? 'Folder' : 'File';
    _titleElement.text = '${type} Properties';
    _propertiesElement.innerHtml = '';
    _buildProperties().then((_) => _show());
  }

  void _commit() => _hide();

  Future _buildProperties() {
    _addProperty(_propertiesElement, 'Name', _selectedResource.name);
    return _getLocation().then((location) {
      _addProperty(_propertiesElement, 'Location', location);
    }).then((_) {
      // Only show repo info for projects.
      if (_selectedResource is! ws.Project) return null;

      GitScmProjectOperations gitOperations =
          spark.scmManager.getScmOperationsFor(_selectedResource.project);

      if (gitOperations != null) {
        return gitOperations.getConfigMap().then((Map<String, dynamic> map) {
          final String repoUrl = map['url'];
          _addProperty(_propertiesElement, 'Repository', repoUrl);
        }).catchError((e) {
          _addProperty(_propertiesElement, 'Repository',
              '<error retrieving Git data>');
        });
      }
    }).then((_) {
      return _selectedResource.entry.getMetadata().then((meta) {
        if (_selectedResource.entry is FileEntry) {
          final String size = _nf.format(meta.size);
          _addProperty(_propertiesElement, 'Size', '$size bytes');
        }

        final String lastModified =
            new DateFormat.yMMMd().add_jms().format(meta.modificationTime);
        _addProperty(_propertiesElement, 'Last Modified', lastModified);
      });
    });
  }

  Future<String> _getLocation() {
    return chrome.fileSystem.getDisplayPath(_selectedResource.entry)
        .catchError((e) {
      // SyncFS from ChromeBook falls in here.
      return _selectedResource.entry.fullPath;
    });
  }

  void _addProperty(HtmlElement parent, String key, String value) {
    // TODO(ussuri): Polymerize.
    Element div = new DivElement()..classes.add('form-group');
    parent.children.add(div);

    Element label = new LabelElement()..text = key;
    Element element = new ParagraphElement()..text = value
        ..className = 'form-control-static'
        ..attributes["selectableTxt"] = "";

    div.children.addAll([label, element]);
  }

  String get category => 'properties';

  bool appliesTo(context) => true;
}

/* Git operations */

class GitCloneAction extends SparkActionWithDialog {
  InputElement _repoUrlElement;

  GitCloneAction(Spark spark, Element dialog)
      : super(spark, "git-clone", "Git Clone…", dialog) {
    _repoUrlElement = _triggerOnReturn("#gitRepoUrl", false);
  }

  void _invoke([Object context]) {
    // Select any previous text in the URL field.
    Timer.run(_repoUrlElement.select);

    _show();
  }

  void _toggleProgressVisible(bool visible) {
    SparkProgress progressComponent = getElement('#cloneProgress');
    progressComponent.visible = visible;
    progressComponent.deliverChanges();
  }

  void _restoreDialog() {
    SparkDialogButton cloneButton = getElement('#clone');
    cloneButton.disabled = false;
    cloneButton.text = "Clone";

    SparkDialogButton closeButton = getElement('#cloneClose');
    closeButton.disabled = false;
    _toggleProgressVisible(false);
  }

  void _commit() {
    SparkProgress progressComponent = getElement('#cloneProgress');
    progressComponent.progressMessage = "Cloning...";
    _toggleProgressVisible(true);

    SparkDialogButton closeButton = getElement('#cloneClose');
    closeButton.disabled = true;
    closeButton.deliverChanges();

    SparkDialogButton cloneButton = getElement('#clone');
    cloneButton.disabled = true;
    cloneButton.text = "Cloning...";
    cloneButton.deliverChanges();

    progressComponent.onCancelled.listen((_) {
      SparkDialogButton cloneButton = getElement('#clone');
      cloneButton.text = "Cancelling...";
    });

    ProgressMonitor monitor = new ProgressMonitorImpl(progressComponent);

    String url = _repoUrlElement.value;
    String projectName;

    if (url.isEmpty) {
      _restoreDialog();
      spark.showErrorMessage('Error in Cloning',
          'Repository url required.');
      return;
    }

    // TODO(grv): Add verify checks.

    // Add `'.git` to the given url unless it ends with `/`.
    if (url.endsWith('/')) {
      projectName = url.substring(0, url.length - 1).split('/').last;
    } else {
      projectName = url.split('/').last;
    }

    if (projectName.endsWith('.git')) {
      projectName = projectName.substring(0, projectName.length - 4);
    }

    _GitCloneTask cloneTask = new _GitCloneTask(url, projectName, spark, monitor);

    cloneTask.run().then((_) {
      spark.showSuccessMessage('Cloned $projectName');
    }).catchError((e) {
      if (e is SparkException && e.errorCode
          == SparkErrorConstants.AUTH_REQUIRED) {
        spark.showErrorMessage('Authorization Required',
          'Authorization required - private git repositories are not yet supported.');
      } else if (e is SparkException &&
          e.errorCode == SparkErrorConstants.GIT_CLONE_CANCEL) {
        spark.showSuccessMessage('Clone cancelled');
      } else if (e is SparkException && e.errorCode
          == SparkErrorConstants.GIT_SUBMODULES_NOT_YET_SUPPORTED) {
        spark.showErrorMessage('Error cloning Git project',
            'Could not clone "${projectName}": '
            'repositories with sub-modules are currently unsupported.');
      } else {
        spark.showErrorMessage('Error cloning Git project',
            'Error while cloning "${projectName}":\n${e}');
      }
    }).whenComplete(() {
      _restoreDialog();
      _hide();
    });
  }
}

class GitPullAction extends SparkAction implements ContextAction {
  GitPullAction(Spark spark) : super(spark, "git-pull", "Pull from Origin");

  void _invoke([context]) {
    var project = context.first.project;
    var operations = spark.scmManager.getScmOperationsFor(project);

    spark.jobManager.schedule(new _GitPullJob(operations, spark));
  }

  String get category => 'git';

  bool appliesTo(context) => _isScmProject(context);
}

class GitAddAction extends SparkAction implements ContextAction {
  GitAddAction(Spark spark) : super(spark, "git-add", "Git Add");
  chrome.Entry entry;

  void _invoke([List<ws.Resource> resources]) {
    ScmProjectOperations operations =
        spark.scmManager.getScmOperationsFor(resources.first.project);
    List<chrome.Entry> files = [];
    resources.forEach((resource) {
      files.add(resource.entry);
    });
    spark.jobManager.schedule(new _GitAddJob(operations, files, spark));
  }

  String get category => 'git';

  bool appliesTo(Object object)
      => _isUnderScmProject(object) && _valid(object);

  bool _valid(List<ws.Resource> resources) {
    return resources.any((resource) =>
      new ScmFileStatus.createFrom(resource.getMetadata('scmStatus'))
          == ScmFileStatus.UNTRACKED);
  }
}

class GitBranchAction extends SparkActionWithDialog implements ContextAction {
  ws.Project project;
  GitScmProjectOperations gitOperations;
  InputElement _branchNameElement;
  SelectElement _selectElement;

  GitBranchAction(Spark spark, Element dialog)
      : super(spark, "git-branch", "Create Branch…", dialog) {
    _branchNameElement = _triggerOnReturn("#gitBranchName");
    _selectElement = getElement("#gitRemoteBranches");
  }

  void _invoke([context]) {
    project = context.first;
    gitOperations = spark.scmManager.getScmOperationsFor(project);

    // Clear out the old select options.
    // TODO (ussuri) : Polymerize.
    _selectElement.length = 0;
    _branchNameElement.value = '';

    _selectElement.onChange.listen((e) {
       int index = _selectElement.selectedIndex;
       if (index != 0) {
         _branchNameElement.value = (_selectElement.children[index]
             as OptionElement).value;
       } else {
         _branchNameElement.value = '';
       }
    });

    gitOperations.getRemoteBranchNames().then((Iterable<String> branchNames) {
      branchNames.toList().sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _selectElement.append(
          new OptionElement(data: "(none)", value: ""));
      for (String branchName in branchNames) {
        _selectElement.append(
            new OptionElement(data: branchName, value: branchName));
      }
      _selectElement.selectedIndex = 0;
    }).then((_) {
      _show();
    });
  }

  void _commit() {
    // TODO(grv): Add verify checks.
    String remoteBranchName = "";
    int selectIndex = _selectElement.selectedIndex;
    remoteBranchName = (_selectElement.children[selectIndex]
        as OptionElement).value;

    _GitBranchJob job = new _GitBranchJob(gitOperations,
        _branchNameElement.value, remoteBranchName, spark);
    spark.jobManager.schedule(job);
    _branchNameElement.disabled = false;
  }

  String get category => 'git';

  bool appliesTo(context) => _isScmProject(context);
}

class GitCommitAction extends SparkActionWithDialog implements ContextAction {
  ws.Project project;
  GitScmProjectOperations gitOperations;
  TextAreaElement _commitMessageElement;
  InputElement _userNameElement;
  InputElement _userEmailElement;
  Element _gitStatusElement;
  DivElement _gitChangeElement;
  bool _needsFillNameEmail;
  String _gitName;
  String _gitEmail;

  List<ws.File> modifiedFileList = [];
  List<ws.File> addedFileList = [];
  List<String> deletedFileList = [];

  GitCommitAction(Spark spark, Element dialog)
      : super(spark, "git-commit", "Commit Changes…", dialog) {
    _commitMessageElement = getElement("#commitMessage");
    _userNameElement = getElement('#gitName');
    _userEmailElement = getElement('#gitEmail');
    _gitStatusElement = getElement('#gitStatus');
    _gitChangeElement = getElement('#gitChangeList');
    getElement('#gitStatusDetail').onClick.listen((e) {
      _gitChangeElement.style.display =
          _gitChangeElement.style.display == 'none' ? 'block' : 'none';
    });
  }

  void _invoke([context]) {
    project = context.first.project;
    gitOperations = spark.scmManager.getScmOperationsFor(project);
    modifiedFileList.clear();
    addedFileList.clear();
    deletedFileList.clear();
    spark.syncPrefs.getValue("git-user-info").then((String value) {
      _gitName = null;
      _gitEmail = null;
      if (value != null) {
        Map<String,String> info = JSON.decode(value);
        _needsFillNameEmail = false;
        _gitName = info['name'];
        _gitEmail = info['email'];
      } else {
        _needsFillNameEmail = true;
      }
      getElement('#gitUserInfo').classes.toggle('hidden', !_needsFillNameEmail);
      _commitMessageElement.value = '';
      _userNameElement.value = '';
      _userEmailElement.value = '';
      _gitChangeElement.text = '';
      _gitChangeElement.style.display = 'none';

      gitOperations.getDeletedFiles().then((List<String> paths) {
        deletedFileList = paths;
        _addGitStatus();
        _show();
      });

    });
  }

  void _addGitStatus() {
    _calculateScmStatus(project);
    _gitChangeElement.innerHtml = '';
    modifiedFileList.forEach((file) {
      _gitChangeElement.innerHtml += 'Modified:&emsp;' + file.path + '<br/>';
    });
    addedFileList.forEach((file){
      _gitChangeElement.innerHtml += 'Added:&emsp;' + file.path + '<br/>';
    });
    deletedFileList.forEach((path){
      _gitChangeElement.innerHtml += 'Deleted:&emsp;' + path + '<br/>';
    });

    final int modifiedCnt = modifiedFileList.length;
    final int addedCnt = addedFileList.length;
    final int deletedCnt = deletedFileList.length;

    if (modifiedCnt + addedCnt + deletedCnt == 0) {
      _gitStatusElement.text = "Nothing to commit.";
    } else {
      _gitStatusElement.text =
          '$modifiedCnt ${(modifiedCnt > 1) ? 'files' : 'file'} modified, ' +
          '$addedCnt ${(addedCnt > 1) ? 'files' : 'file'} added.' +
          '$deletedCnt ${(deletedCnt > 1) ? 'files' : 'file'} deleted.';
    }
  }

  void _calculateScmStatus(ws.Folder folder) {
    folder.getChildren().forEach((resource) {
      if (resource is ws.Folder) {
        if (resource.isScmPrivate()) {
          return;
        }
        _calculateScmStatus(resource);
      } else if (resource is ws.File) {
        ScmFileStatus status = gitOperations.getFileStatus(resource);

        // TODO(grv): Add deleted files to resource.
        if (status == ScmFileStatus.DELETED) {
          deletedFileList.add(resource.path);
        } else if (status == ScmFileStatus.MODIFIED) {
          modifiedFileList.add(resource);
        } else if (status == ScmFileStatus.ADDED) {
          addedFileList.add(resource);
        }
      }
    });
  }

  void _commit() {
    if (_needsFillNameEmail) {
      _gitName = _userNameElement.value;
      _gitEmail = _userEmailElement.value;
      String encoded = JSON.encode({'name': _gitName, 'email': _gitEmail});
      spark.syncPrefs.setValue("git-user-info", encoded).then((_) {
        _startJob();
      });
    } else {
      _startJob();
    }
  }

  void _startJob() {
    // TODO(grv): Add verify checks.
    _GitCommitJob job = new _GitCommitJob(
        gitOperations, _gitName, _gitEmail, _commitMessageElement.value, spark);
    spark.jobManager.schedule(job);
  }

  String get category => 'git';

  bool appliesTo(context) => _isUnderScmProject(context);
}

class GitCheckoutAction extends SparkActionWithDialog implements ContextAction {
  ws.Project project;
  GitScmProjectOperations gitOperations;
  SelectElement _selectElement;

  GitCheckoutAction(Spark spark, Element dialog)
      : super(spark, "git-checkout", "Switch Branch…", dialog) {
    _selectElement = getElement("#gitCheckout");
  }

  void _invoke([List context]) {
    project = context.first;
    gitOperations = spark.scmManager.getScmOperationsFor(project);
    String currentBranchName = gitOperations.getBranchName();
    (getElement('#currentBranchName') as InputElement).value = currentBranchName;

    // Clear out the old select options.
    _selectElement.length = 0;

    gitOperations.getLocalBranchNames().then((List<String> branchNames) {
      branchNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      for (String branchName in branchNames) {
        _selectElement.append(
            new OptionElement(data: branchName, value: branchName));
      }
      _selectElement.selectedIndex = branchNames.indexOf(currentBranchName);
    });

    _show();
  }

  void _commit() {
    // TODO(grv): Add verify checks.
    String branchName = _selectElement.options[
        _selectElement.selectedIndex].value;
    _GitCheckoutJob job = new _GitCheckoutJob(gitOperations, branchName, spark);
    spark.jobManager.schedule(job);
  }

  String get category => 'git';

  bool appliesTo(context) => _isScmProject(context);
}

class GitPushAction extends SparkActionWithDialog implements ContextAction {
  ws.Project project;
  GitScmProjectOperations gitOperations;
  DivElement _commitsList;
  String _gitUsername;
  String _gitPassword;
  bool _needsUsernamePassword;

  GitPushAction(Spark spark, Element dialog)
      : super(spark, "git-push", "Push to Origin…", dialog) {
    _commitsList = getElement('#gitCommitList');
  }

  void _onClose() => _hide();

  void _invoke([context]) {
    getElement("#gitPushClose").onClick.listen((_) => _onClose());
    project = context.first;

    spark.syncPrefs.getValue("git-auth-info").then((String value) {

      if (value != null) {
        Map<String,String> info = JSON.decode(value);
        _needsUsernamePassword = false;
        _gitUsername = info['username'];
        _gitPassword = info['password'];
      } else  {
        _gitUsername = null;
        _gitPassword = null;
        _showAuthDialog(context);
        return;
      }
      gitOperations = spark.scmManager.getScmOperationsFor(project);
      gitOperations.getPendingCommits(_gitUsername, _gitPassword).then(
          (List<CommitInfo> commits) {
        if (commits.isEmpty) {
          spark.showErrorMessage('Push failed', 'No commits to push');
          return;
        }
        // Fill commits.
        _commitsList.innerHtml = '';
        String summaryString =
            commits.length == 1 ? '1 commit' : '${commits.length} commits';
        Element title = document.createElement("h1");
        title.appendText(summaryString);
        _commitsList.append(title);
        commits.forEach((CommitInfo info) {
          CommitMessageView commitView = new CommitMessageView();
          commitView.commitInfo = info;
          _commitsList.children.add(commitView);
        });
        Timer.run(() {
          _show();
        });
      }).catchError((e) {
        spark.showErrorMessage('Push failed', 'Something went wrong.');
      });
    });
  }

  void _push() {
    SparkProgress progressComponent = getElement('#gitPushProgress');
    progressComponent.progressMessage = "Pushing...";
    _toggleProgressVisible(true);

    SparkDialogButton closeButton = getElement('#gitPushClose');
    closeButton.disabled = true;
    closeButton.deliverChanges();

    SparkDialogButton pushButton = getElement('#gitPush');
    pushButton.disabled = true;
    pushButton.deliverChanges();

    ProgressMonitor monitor = new ProgressMonitorImpl(progressComponent);
    _GitPushTask task = new _GitPushTask(gitOperations, _gitUsername, _gitPassword,
        spark, monitor);
    task.run().then((_) {
      spark.showSuccessMessage('Changes pushed successfully');
    }).catchError((e) {
      spark.showErrorMessage('Error while pushing changes', e.toString());
    }).whenComplete(() {
      _restoreDialog();
      _hide();
    });
  }

  void _toggleProgressVisible(bool visible) {
    SparkProgress progressComponent = getElement('#gitPushProgress');
    progressComponent.visible = visible;
    progressComponent.deliverChanges();
  }

  void _restoreDialog() {
    SparkDialogButton pushButton = getElement('#gitPush');
    pushButton.disabled = false;

    SparkDialogButton closeButton = getElement('#gitPushClose');
    closeButton.disabled = false;
    _toggleProgressVisible(false);
  }

  void _commit() {
    _push();
  }

  /// Shows an authentification dialog. Returns false if cancelled.
  void _showAuthDialog(context) {
    Timer.run(() {
      // In a timer to let the previous dialog dismiss properly.
      GitAuthenticationDialog.request(spark).then((info) {
        _gitUsername = info['username'];
        _gitPassword = info['password'];
        _invoke(context);
      }).catchError((e) {
        // Cancelled authentication: do nothing.
      });
    });
  }

  String get category => 'git';

  bool appliesTo(context) => _isScmProject(context);
}

class GitResolveConflictsAction extends SparkAction implements ContextAction {
  GitResolveConflictsAction(Spark spark) :
      super(spark, "git-resolve-conflicts", "Resolve Conflicts");

  void _invoke([context]) {
    ws.Resource file = _getResource(context);
    ScmProjectOperations operations =
        spark.scmManager.getScmOperationsFor(file.project);

    operations.markResolved(file);
  }

  String get category => 'git';

  bool appliesTo(context) => _isUnderScmProject(context) &&
      _isSingleResource(context) && _fileHasConflicts(context);

  bool _fileHasConflicts(context) {
    ws.Resource file = _getResource(context);
    ScmProjectOperations operations =
        spark.scmManager.getScmOperationsFor(file.project);
    return operations.getFileStatus(file) == ScmFileStatus.UNMERGED;
  }

  ws.Resource _getResource(context) {
    if (context is List) {
      return context.isNotEmpty ? context.first : null;
    } else {
      return null;
    }
  }
}

class GitRevertChangesAction extends SparkAction implements ContextAction {
  GitRevertChangesAction(Spark spark) :
      super(spark, "git-revert-changes", "Revert Changes…");

  void _invoke([List resources]) {
    ScmProjectOperations operations =
        spark.scmManager.getScmOperationsFor(resources.first.project);

    String text = (resources.length == 1 ?
        resources.first.name :
        '${resources.length} resources');
    text = 'Revert changes for ${text}?';

    // Show a yes/no dialog.
    spark.askUserOkCancel(text, okButtonLabel: 'Revert').then((bool val) {
      if (val) {
        operations.revertChanges(resources).then((_) {
          resources.first.project.refresh();
        });
      }
    });
  }

  String get category => 'git';

  bool appliesTo(context) => _isUnderScmProject(context) &&
      _filesAreModified(context);

  bool _filesAreModified(List resources) {
    ScmProjectOperations operations =
        spark.scmManager.getScmOperationsFor(resources.first.project);

    for (ws.Resource resource in resources) {
      // TODO: Should we also check UNTRACKED?
      if (operations.getFileStatus(resource) != ScmFileStatus.MODIFIED) {
        return false;
      }
    }

    return true;
  }
}

class CloneTaskCancel extends TaskCancel {

  CloneTaskCancel(ProgressMonitor monitor) : super(monitor);

  void performCancel() {
    ScmProvider scmProvider = getProviderType('git');
    scmProvider.cancelClone();
  }
}

class _GitCloneTask {
  String url;
  String _projectName;
  Spark spark;
  ProgressMonitor _monitor;
  CloneTaskCancel _cancel;

  _GitCloneTask(this.url, this._projectName, this.spark, this._monitor) {
    _cancel = new CloneTaskCancel(_monitor);
  }

  Future run() {

    return spark.projectLocationManager.createNewFolder(_projectName).then(
        (LocationResult location) {
      if (location == null) {
        return new Future.value();
      }

      ScmProvider scmProvider = getProviderType('git');

      return scmProvider.clone(url, location.entry).then((_) {
        ws.WorkspaceRoot root;

        if (location.isSync) {
          root = new ws.SyncFolderRoot(location.entry);
        } else {
          root = new ws.FolderChildRoot(location.parent, location.entry);
        }
        return spark.workspace.link(root).then((ws.Project project) {
          spark.showSuccessMessage('Cloned into ${project.name}');

          Timer.run(() {
            spark._filesController.selectFile(project);
            spark._filesController.setFolderExpanded(project);
          });

          // Run Pub if the new project has a pubspec file.
          if (spark.pubManager.properties.isFolderWithPackages(project)) {
            spark.jobManager.schedule(new PubGetJob(spark, project));
          }

          // Run Bower if the new project has a bower.json file.
          if (spark.bowerManager.properties.isFolderWithPackages(project)) {
            spark.jobManager.schedule(new BowerGetJob(spark, project));
          }

          spark.workspace.save();
        });
      });
    });
  }
}

class _GitPullJob extends Job {
  GitScmProjectOperations gitOperations;
  Spark spark;

  _GitPullJob(this.gitOperations, this.spark) : super("Pulling…");

  Future run(ProgressMonitor monitor) {
    monitor.start(name, 1);

    // TODO: We'll want a way to indicate to the user what files changed and if
    // there were any merge problems.
    return gitOperations.pull().then((_) {
      spark.showSuccessMessage('Pull successful');
    }).catchError((e) {
      spark.showErrorMessage('Git Pull Status', e.toString());
    });
  }
}

class _GitAddJob extends Job {
  GitScmProjectOperations gitOperations;
  Spark spark;
  List<chrome.Entry> files;

  _GitAddJob(this.gitOperations, this.files, this.spark) : super("Adding…");

  Future run(ProgressMonitor monitor) {
    monitor.start(name, 1);
    return gitOperations.addFiles(files).then((_) {
    }).catchError((e) {
      spark.showErrorMessage('Error adding file to git', e.toString());
    });
  }
}

class _GitBranchJob extends Job {
  GitScmProjectOperations gitOperations;
  String _branchName;
  String _remoteBranchName;
  String url;
  Spark spark;

  _GitBranchJob(this.gitOperations, String branchName, this._remoteBranchName,
      this.spark) : super("Creating ${branchName}…") {
    _branchName = branchName;
  }

  Future run(ProgressMonitor monitor) {
    monitor.start(name, 1);

    return gitOperations.createBranch(_branchName, _remoteBranchName).then((_) {
      return gitOperations.checkoutBranch(_branchName).then((_) {
        spark.showSuccessMessage('Created ${_branchName}');
      });
    }).catchError((e) {
      spark.showErrorMessage(
          'Error creating branch ${_branchName}', e.toString());
    });
  }
}

class _GitCommitJob extends Job {
  GitScmProjectOperations gitOperations;
  String _commitMessage;
  String _userName;
  String _userEmail;
  Spark spark;

  _GitCommitJob(this.gitOperations, this._userName, this._userEmail,
      this._commitMessage, this.spark) : super("Committing…");

  Future run(ProgressMonitor monitor) {
    monitor.start(name, 1);

    return gitOperations.commit(_userName, _userEmail, _commitMessage).
        then((_) {
      spark.showSuccessMessage('Committed changes');
    }).catchError((e) {
      spark.showErrorMessage('Error committing changes', e.toString());
    });
  }
}

class _GitCheckoutJob extends Job {
  GitScmProjectOperations gitOperations;
  String _branchName;
  Spark spark;

  _GitCheckoutJob(this.gitOperations, String branchName, this.spark)
      : super("Switching to ${branchName}…") {
    _branchName = branchName;
  }

  Future run(ProgressMonitor monitor) {
    monitor.start(name, 1);

    return gitOperations.checkoutBranch(_branchName).then((_) {
      spark.showSuccessMessage('Switched to branch ${_branchName}');
    }).catchError((e) {
      spark.showErrorMessage('Error switching to ${_branchName}', e.toString());
    });
  }
}

class _OpenFolderJob extends Job {
  Spark spark;
  chrome.DirectoryEntry _entry;

  _OpenFolderJob(chrome.DirectoryEntry entry, this.spark)
      : super("Opening ${entry.fullPath}…") {
    _entry = entry;
  }

  Future run(ProgressMonitor monitor) {
    monitor.start(name, 1);

    return spark.workspace.link(
        new ws.FolderRoot(_entry)).then((ws.Resource resource) {
      Timer.run(() {
        spark._filesController.selectFile(resource);
        spark._filesController.setFolderExpanded(resource);
      });

      // Run Pub if the folder has a pubspec file.
      if (spark.pubManager.properties.isFolderWithPackages(resource)) {
        spark.jobManager.schedule(new PubGetJob(spark, resource));
      }

      // Run Bower if the folder has a bower.json file.
      if (spark.bowerManager.properties.isFolderWithPackages(resource)) {
        spark.jobManager.schedule(new BowerGetJob(spark, resource));
      }

      return spark.workspace.save();
    }).then((_) {
      spark.showSuccessMessage('Opened folder ${_entry.fullPath}');
    }).catchError((e) {
      spark.showErrorMessage('Error opening folder ${_entry.fullPath}',
          e.toString());
    });
  }
}

class _GitPushTask {
  GitScmProjectOperations gitOperations;
  Spark spark;
  String username;
  String password;
  ProgressMonitor monitor;

  _GitPushTask(this.gitOperations, this.username, this.password, this.spark,
      this.monitor);

  Future run() => gitOperations.push(username, password);
}

abstract class PackageManagementJob extends Job {
  final Spark _spark;
  final ws.Container _container;
  final String _commandName;

  PackageManagementJob(this._spark, this._container, this._commandName) :
      super('Getting packages…');

  Future run(ProgressMonitor monitor) {
    monitor.start(name, 1);

    return _run().then((_) {
      _spark.showSuccessMessage("Successfully ran $_commandName");
    }).catchError((e) {
      _spark.showErrorMessage("Error while running $_commandName", e.toString());
    });
  }

  Future _run();
}

class PubGetJob extends PackageManagementJob {
  PubGetJob(Spark spark, ws.Folder container) :
      super(spark, container, 'pub get');

  Future _run() => _spark.pubManager.installPackages(_container);
}

class PubUpgradeJob extends PackageManagementJob {
  PubUpgradeJob(Spark spark, ws.Folder container) :
      super(spark, container, 'pub upgrade');

  Future _run() => _spark.pubManager.upgradePackages(_container);
}

class BowerGetJob extends PackageManagementJob {
  BowerGetJob(Spark spark, ws.Folder container) :
      super(spark, container, 'bower install');

  Future _run() => _spark.bowerManager.installPackages(_container);
}

class BowerUpgradeJob extends PackageManagementJob {
  BowerUpgradeJob(Spark spark, ws.Folder container) :
      super(spark, container, 'bower upgrade');

  Future _run() => _spark.bowerManager.upgradePackages(_container);
}

class CompileDartJob extends Job {
  final Spark spark;
  final ws.File file;

  CompileDartJob(this.spark, this.file, String fileName) :
      super('Compiling ${fileName}…');

  Future run(ProgressMonitor monitor) {
    monitor.start(name, 1);

    CompilerService compiler = spark.services.getService("compiler");

    return compiler.compileFile(file, csp: true).then((CompileResult result) {
      if (!result.getSuccess()) {
        throw result;
      }

      return getCreateFile(file.parent, '${file.name}.js').then((ws.File file) {
        return file.setContents(result.output);
      });
    }).catchError((e) {
      spark.showErrorMessage('Error Compiling ${file.name}', '${e}');
    });
  }

  Future<ws.File> getCreateFile(ws.Folder parent, String name) {
    ws.File file = parent.getChild(name);
    if (file == null) {
      return parent.createNewFile(name);
    } else {
      return new Future.value(file);
    }
  }
}

class ResourceRefreshJob extends Job {
  final List<ws.Project> resources;

  ResourceRefreshJob(this.resources) : super('Refreshing…');

  Future run(ProgressMonitor monitor) {
    List<ws.Project> projects = resources.map((r) => r.project).toSet().toList();

    monitor.start('', projects.length);

    Completer completer = new Completer();

    var consumeProject;
    consumeProject = () {
      ws.Project project = projects.removeAt(0);

      project.refresh().whenComplete(() {
        monitor.worked(1);

        if (projects.isEmpty) {
          completer.complete();
        } else {
          Timer.run(consumeProject);
        }
      });
    };

    Timer.run(consumeProject);

    return completer.future;
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

  void _commit() => _hide();
}

// TODO(ussuri): Polymerize.
class SettingsAction extends SparkActionWithDialog {
  SettingsAction(Spark spark, Element dialog)
      : super(spark, "settings", "Settings", dialog) {
    if (PlatformInfo.isMac) {
      addBinding('ctrl-,');
    }
  }

  void _invoke([Object context]) {
    spark.setGitSettingsResetDoneVisible(false);

    var whitespaceCheckbox = getElement('#stripWhitespace');

    // Wait for each of the following to (simultaneously) complete before
    // showing the dialog:
    Future.wait([
      spark.prefs.onPreferencesReady.then((_) {
        whitespaceCheckbox.checked = spark.prefs.stripWhitespaceOnSave;
      }), new Future.value().then((_) {
        // For now, don't show the location field on Chrome OS; we always use syncFS.
        if (PlatformInfo.isCros) {
          return null;
        } else {
          return _showRootDirectory();
        }
      })
    ]).then((_) {
      _show();
      whitespaceCheckbox.onChange.listen((e) {
        spark.prefs.stripWhitespaceOnSave = whitespaceCheckbox.checked;
      });
    });
  }

  void _commit() => _hide();

  Future _showRootDirectory() {
    return spark.localPrefs.getValue('projectFolder').then((folderToken) {
      if (folderToken == null) {
        getElement('#directoryLabel').text = '';
        return new Future.value();
      }
      return chrome.fileSystem.restoreEntry(folderToken).then((chrome.Entry entry) {
        return chrome.fileSystem.getDisplayPath(entry).then((path) {
          getElement('#directoryLabel').text = path;
        });
      });
    });
  }
}

class RunTestsAction extends SparkAction {
  TestDriver testDriver;

  RunTestsAction(Spark spark) : super(spark, "run-tests", "Run Tests") {
    if (SparkFlags.developerMode) {
      addBinding('ctrl-shift-alt-t');
    }
  }

  void checkForTestListener() => _initTestDriver();

  _invoke([Object context]) {
    if (SparkFlags.developerMode) {
      _initTestDriver();
      testDriver.runTests();
    }
  }

  void _initTestDriver() {
    if (testDriver == null) {
      testDriver = new TestDriver(all_tests.defineTests, spark.jobManager,
          connectToTestListener: true);
    }
  }
}

class WebStorePublishAction extends SparkActionWithDialog {
  bool _initialized = false;
  static final int NEWAPP = 1;
  static final int EXISTING = 2;
  int _type = NEWAPP;
  InputElement _newInput;
  InputElement _existingInput;
  InputElement _appIdInput;
  ws.Resource _resource;

  WebStorePublishAction(Spark spark, Element dialog)
      : super(spark, "webstore-publish", "Publish to Chrome Web Store", dialog) {
    enabled = false;
    spark.focusManager.onResourceChange.listen((r) => _updateEnablement(r));
  }

  void _invoke([Object context]) {
    if (!_initialized) {
      _newInput = getElement('input[value=new]');
      _existingInput = getElement('input[value=existing]');
      _appIdInput = getElement('#appID');
      _enableInput();

      _newInput.onChange.listen((e) => _enableInput());
      _existingInput.onChange.listen((e) => _enableInput());
      _initialized = true;
    }

    _resource = spark.focusManager.currentResource;
    _show();
  }

  void _enableInput() {
    int type = NEWAPP;
    if (_newInput.checked) {
      type = NEWAPP;
    }
    if (_existingInput.checked) {
      type = EXISTING;
    }
    _appIdInput.disabled = (type != EXISTING);
    if (type == EXISTING) {
      _appIdInput.focus();
    }
  }

  void _commit() {
    String appID = null;
    if (_existingInput.checked) {
      appID = _appIdInput.value;
    }
    _WebStorePublishJob job =
        new _WebStorePublishJob(spark, getAppContainerFor(_resource), appID);
    spark.jobManager.schedule(job);
  }

  void _updateEnablement(ws.Resource resource) {
    enabled = getAppContainerFor(resource) != null;
  }
}

class _WebStorePublishJob extends Job {
  ws.Container _container;
  String _appID;
  Spark spark;

  _WebStorePublishJob(this.spark, this._container, this._appID)
      : super("Publishing to Chrome Web Store…");

  Future run(ProgressMonitor monitor) {
    monitor.start(name, _appID == null ? 5 : 6);

    if (_container == null) {
      spark.showErrorMessage('Error while publishing the application',
          'The manifest.json file of the application has not been found.');
      return null;
    }

    return ws_utils.archiveContainer(_container).then((List<int> archivedData) {
      monitor.worked(1);
      WebStoreClient wsc = new WebStoreClient();
      return wsc.authenticate().then((_) {
        monitor.worked(1);
        return wsc.uploadItem(archivedData, identifier: _appID).then((String uploadedAppID) {
          monitor.worked(3);
          if (_appID == null) {
            spark.showUploadedAppDialog(uploadedAppID);
          } else {
            return wsc.publish(uploadedAppID).then((_) {
              monitor.worked(1);
              spark.showPublishedAppDialog(_appID);
            }).catchError((e) {
              monitor.worked(1);
              spark.showUploadedAppDialog(uploadedAppID);
            });
          }
        });
      });
    }).catchError((e) {
      spark.showErrorMessage('Error while publishing the application', e.toString());
    });
  }
}

// TODO: This does not need to extends SparkActionWithDialog - just dialog.
class GitAuthenticationDialog extends SparkActionWithDialog {
  Completer completer;
  static GitAuthenticationDialog _instance;
  bool _initialized = false;

  GitAuthenticationDialog(spark, dialogElement)
      : super(spark, "git-authentication", "Authenticate", dialogElement);

  void _invoke([Object context]) {
    if (!_initialized) {
      _dialog.getElement("[cancel]").onClick.listen((_) => _cancel());
      _initialized = true;
    }

    spark.setGitSettingsResetDoneVisible(false);
    _show();
  }

  void _commit() {
    final String username = (getElement('#gitUsername') as InputElement).value;
    final String password = (getElement('#gitPassword') as InputElement).value;
    final String encoded =
        JSON.encode({'username': username, 'password': password});
    spark.syncPrefs.setValue("git-auth-info", encoded).then((_) {
      completer.complete({'username': username, 'password': password});
      completer = null;
    });
  }

  void _cancel() {
    completer.completeError("cancelled");
    completer = null;
  }

  static Future<Map> request(Spark spark) {
    if (_instance == null) {
      _instance = new GitAuthenticationDialog(spark,
          spark.getDialogElement('#gitAuthenticationDialog'));
    }
    assert(_instance.completer == null);
    _instance.completer = new Completer();
    _instance.invoke();
    return _instance.completer.future;
  }
}

class ImportFileAction extends SparkAction implements ContextAction {
  ImportFileAction(Spark spark) : super(spark, "file-import", "Import File…");

  void _invoke([List<ws.Resource> resources]) {
    spark.importFile(resources);
  }

  String get category => 'folder';

  bool appliesTo(Object object) => _isSingleFolder(object);
}

class ImportFolderAction extends SparkAction implements ContextAction {
  ImportFolderAction(Spark spark) : super(spark, "folder-import", "Add Folder to Workspace…");

  void _invoke([List<ws.Resource> resources]) {
    spark.importFolder(resources);
  }

  String get category => 'folder';

  bool appliesTo(Object object) => _isSingleFolder(object);
}

class ToggleOutlineVisibilityAction extends SparkAction {
  ToggleOutlineVisibilityAction(Spark spark)
      : super(spark, 'toggleOutlineVisibility', 'Toggle Outline') {
    addBinding('alt-o');
  }

  @override
  void _invoke([Object context]) {
    spark._aceManager.outline.toggle();
  }
}

class SendFeedbackAction extends SparkAction {
  SendFeedbackAction(Spark spark)
      : super(spark, 'send-feedback', 'Send Feedback…');

  void _invoke([context]) {
    window.open('https://github.com/dart-lang/spark/issues/new', '_blank');
  }
}

// Analytics code.

void _handleUncaughtException(error, [StackTrace stackTrace]) {
  // We don't log the error object itself because of PII concerns.
  final String errorDesc = error != null ? error.runtimeType.toString() : '';
  final String desc =
      '${errorDesc}\n${utils.minimizeStackTrace(stackTrace)}'.trim();

  _analyticsTracker.sendException(desc);

  window.console.error(error);
  if (stackTrace != null) {
    window.console.error(stackTrace.toString());
  }
}

bool get _isTrackingPermitted =>
    _analyticsTracker.service.getConfig().isTrackingPermitted();

set _isTrackingPermitted(bool value) =>
    _analyticsTracker.service.getConfig().setTrackingPermitted(value);

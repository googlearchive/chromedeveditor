// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:core' hide Resource;
import 'dart:html' hide File;
import 'dart:js' as js;

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:chrome_testing/testing_app.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:spark_widgets/spark_button/spark_button.dart';
import 'package:spark_widgets/spark_dialog/spark_dialog.dart';
import 'package:spark_widgets/spark_dialog_button/spark_dialog_button.dart';
import 'package:spark_widgets/spark_progress/spark_progress.dart';
import 'package:spark_widgets/spark_status/spark_status.dart';

import 'lib/ace.dart';
import 'lib/actions.dart';
import 'lib/analytics.dart' as analytics;
import 'lib/apps/app_manifest_builder.dart';
import 'lib/apps/app_utils.dart';
import 'lib/builder.dart';
import 'lib/commands.dart';
import 'lib/dependency.dart';
import 'lib/decorators.dart';
import 'lib/dart/dart_builder.dart';
import 'lib/editors.dart';
import 'lib/editor_area.dart';
import 'lib/event_bus.dart';
import 'lib/exception.dart';
import 'lib/files_mock.dart';
import 'lib/filesystem.dart' as filesystem;
import 'lib/javascript/js_builder.dart';
import 'lib/json/json_builder.dart';
import 'lib/jobs.dart';
import 'lib/launch.dart';
import 'lib/mobile/android_rsa.dart';
import 'lib/mobile/deploy.dart';
import 'lib/mobile/usb.dart';
import 'lib/navigation.dart';
import 'lib/package_mgmt/package_manager.dart';
import 'lib/package_mgmt/pub.dart';
import 'lib/package_mgmt/bower.dart';
import 'lib/platform_info.dart';
import 'lib/preferences.dart' as preferences;
import 'lib/refactor/csp_fixer.dart';
import 'lib/services.dart';
import 'lib/scm.dart';
import 'lib/spark_flags.dart';
import 'lib/state.dart';
import 'lib/templates/templates.dart';
import 'lib/utils.dart';
import 'lib/ui/commit_message_view/commit_message_view.dart';
import 'lib/ui/files_controller.dart';
import 'lib/ui/search_view_controller.dart';
import 'lib/utils.dart' as utils;
import 'lib/wam/wamfs.dart';
import 'lib/webstore_client.dart';
import 'lib/workspace.dart' as ws;
import 'lib/workspace_utils.dart' as ws_utils;
import 'spark_model.dart';
import 'test/all.dart' as all_tests;

analytics.Tracker _analyticsTracker = new analytics.NullTracker();
final NumberFormat _nf = new NumberFormat.decimalPattern();

/**
 * Create a [Zone] that logs uncaught exceptions.
 */
Zone createSparkZone() {
  Function errorHandler = (self, parent, zone, error, stackTrace) {
    _handleUncaughtException(error, stackTrace);
  };
  ZoneSpecification specification =
      new ZoneSpecification(handleUncaughtError: errorHandler);
  return Zone.current.fork(specification: specification);
}

abstract class Spark
    extends SparkModel
    implements AceManagerDelegate, Notifier, SearchViewControllerDelegate {

  /// The Google Analytics app ID for Spark.
  static final _ANALYTICS_ID = 'UA-45578231-1';

  Services services;
  final JobManager jobManager = new JobManager();
  final Dependencies dependencies = Dependencies.dependency;
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
  ActionManager _actionManager;
  NavigationManager _navigationManager;

  EventBus _eventBus;

  FilesController _filesController;
  SearchViewController _searchViewController;

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
    // Init the dependency manager.
    dependencies[DecoratorManager] = new DecoratorManager();
    dependencies[Notifier] = this;
    dependencies[preferences.PreferenceStore] = localPrefs;


    initEventBus();
    initCommandManager();

    return initPreferences().then((_) {
      return restoreWorkspace().then((_) {
        return restoreLocationManager().then((_) {
          // Besides direct dependencies of the below modules on [Workspace] and
          // [LocationManager], [restoreLocationManager] may also read
          // updated [SparkFlags] from `<project location>/.spark.json`.

          initAnalytics();

          initPackageManagers();
          initServices();
          initScmManager();
          initAceManager();

          initAndroidRSA();

          initEditorManager();
          initNavigationManager();

          createActions();

          initFilesController();

          initLaunchManager();
          initBuilders();

          initToolbar();
          buildMenu();
          initSplitView();
          initSaveStatusListener();

          initSearchController();

          window.onFocus.listen((Event e) {
            // On unfocusing/refocusing CDE, refresh the workspace to account
            // for possible external changes.
            _refreshOpenFiles();
          });
        });
      });
    });
  }

  Future<chrome.ChromeFileEntry> chooseFileEntry() {
    chrome.ChooseEntryOptions options = new chrome.ChooseEntryOptions(
        type: chrome.ChooseEntryType.OPEN_FILE);
    return chrome.fileSystem.chooseEntry(options).then(
        (chrome.ChooseEntryResult res) {
      return res.entry;
    });
  }

  /**
   * This method shows the root directory path in the UI element.
   */
  Future showRootDirectory() {
    return localPrefs.getValue('projectFolder').then((folderToken) {
      if (folderToken == null) {
        getUIElement('#directoryLabel').text = '';
        return new Future.value();
      }
      return chrome.fileSystem.restoreEntry(folderToken).then(
          (chrome.Entry entry) {
        return filesystem.fileSystemAccess.getDisplayPath(entry).then((path) {
          getUIElement('#directoryLabel').text = path;
        });
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
  PubManager get pubManager => dependencies[PubManager];
  BowerManager get bowerManager => dependencies[BowerManager];
  DecoratorManager get decoratorManager => dependencies[DecoratorManager];
  ActionManager get actionManager => _actionManager;
  NavigationManager get navigationManager => _navigationManager;
  EventBus get eventBus => _eventBus;

  preferences.PreferenceStore get localPrefs => preferences.localStore;
  preferences.PreferenceStore get syncPrefs => preferences.syncStore;
  StateManager get stateManager => dependencies[StateManager];
  CommandManager get commands => dependencies[CommandManager];

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
  Element getUIElement(String selectors);

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

  Future initPreferences() {
    prefs = new preferences.SparkPreferences(localPrefs);

    return LocalStateManager.create().then((StateManager state) {
      dependencies[StateManager] = state;
    });
  }

  void initServices() {
    services = new Services(this.workspace, pubManager);
  }

  void initEventBus() {
    _eventBus = new EventBus();
    _eventBus.onEvent(BusEventType.ERROR_MESSAGE).listen(
        (ErrorMessageBusEvent event) {
      showErrorMessage(event.title, message: event.error.toString());
    });
  }

  void initCommandManager() {
    dependencies[CommandManager] = new CommandManager();
    commands.listenToDom(document.body);
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

  void initScmManager() {
    scmManager = new ScmManager(_workspace);
    decoratorManager.addDecorator(new ScmDecorator(scmManager));
  }

  void initLaunchManager() {
    // TODO(ussuri): Switch to MetaPackageManager as soon as it's done.
    _launchManager = new LaunchManager(_workspace, services,
        pubManager, bowerManager, this, new _SparkLaunchController());
  }

  void initNavigationManager() {
    _navigationManager = new NavigationManager(_editorManager);
    _navigationManager.onNavigate.listen((NavigationLocation location) {
      if (location == null) return;

      _selectFile(location.file).then((_) {
        if (location.selection != null) {
          nextTick().then((_) => _selectLocation(location));
        }
      });
    });
    _workspace.onResourceChange.listen((ResourceChangeEvent event) {
      event =
          new ResourceChangeEvent.fromList(event.changes, filterRename: true);
      for (ChangeDelta delta in event.changes) {
        if (delta.isDelete) {
          if (delta.deletions.isNotEmpty) {
            _navigationManager.pause();
            for (ChangeDelta change in delta.deletions) {
              if (change.resource.isFile) {
                _navigationManager.removeFile(change.resource);
              }
            }
            _navigationManager.resume();
            _navigationManager.gotoLocation(_navigationManager.currentLocation);
          } else if (delta.resource.isFile){
            _navigationManager.removeFile(delta.resource);
          }
        }
      }
    });

  }

  void initAndroidRSA() {
    if (isDart2js()) {
      AndroidRSA.loadPlugin();
    }
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
    // Init the Pub manager, and add it to the dependencies tracker.
    PubManager pubManager = new PubManager(workspace);
    dependencies[PubManager] = pubManager;
    decoratorManager.addDecorator(new PubDecorator(pubManager));

    // Init the Bower manager, and add it to the dependencies tracker.
    dependencies[BowerManager] = new BowerManager(workspace);
  }

  void initAceManager() {
    _aceManager = new AceManager(this, services, prefs);

    syncPrefs.getValue('textFileExtensions').then((String value) {
      if (value != null) {
        _textFileExtensions.addAll(JSON.decode(value));
      }
    });

    _aceThemeManager = new ThemeManager(
        _aceManager, prefs, getUIElement('#changeTheme .settings-value'));
    _aceKeysManager = new KeyBindingManager(
        _aceManager, prefs, getUIElement('#changeKeys .settings-value'));
    _aceFontManager = new AceFontManager(
        _aceManager, prefs, getUIElement('#changeFont .settings-value'));
  }

  void initEditorManager() {
    _editorManager = new EditorManager(
        workspace, aceManager, prefs, eventBus, services);

    _editorArea = new EditorArea(getUIElement('#editorArea'), editorManager,
        workspace, allowsLabelBar: true);

    editorManager.loaded.then((_) {
      List<ws.Resource> files = editorManager.files.toList();
      editorManager.files.forEach((file) {
        editorArea.selectFile(file, forceOpen: true, switchesTab: false,
            replaceCurrent: false);
      });

      editorManager.setupOutline(getUIElement('#outlineContainer'));

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

    editorArea.onSelected.listen((EditorTab tab) {
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
        workspace,
        actionManager,
        scmManager,
        eventBus,
        getUIElement('#splitView'),
        getUIElement('#file-item-context-menu'),
        getUIElement('#fileViewArea'));
    _filesController.visibility = true;
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
    getUIElement('#showFileViewButton').onClick.listen((_) {
      Action action = actionManager.getAction('show-files-view');
      action.invoke();
    });
  }

  void initSearchController() {
    _searchViewController = new SearchViewController(
        workspace,
        getUIElement('#leftPanel'),
        getUIElement('#sparkStatus'),
        this);
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
    // TODO(devoncarew): TODO(devoncarew): Removed as per #2348.
    //actionManager.registerAction(new FileOpenAction(this));
    actionManager.registerAction(new FileNewAction(this,
        getDialogElement('#fileNewDialog')));
    actionManager.registerAction(new FolderNewAction(this,
        getDialogElement('#folderNewDialog')));
    actionManager.registerAction(new FolderOpenAction(this,
        getDialogElement('#statusDialog')));
    actionManager.registerAction(new NewProjectAction(this,
        getDialogElement('#newProjectDialog')));
    actionManager.registerAction(new BuildApkAction(this,
        getDialogElement('#buildAPKDialog')));
    actionManager.registerAction(new FileSaveAction(this));
    actionManager.registerAction(new PubGetAction(this));
    actionManager.registerAction(new PubUpgradeAction(this));
    actionManager.registerAction(new BowerGetAction(this));
    actionManager.registerAction(new BowerUpgradeAction(this));
    actionManager.registerAction(new CspFixAction(this));
    actionManager.registerAction(new ApplicationRunAction.run(this));
    actionManager.registerAction(new ApplicationRunAction.deploy(this));
    actionManager.registerAction(new CompileDartAction(this));
    actionManager.registerAction(new GitCloneAction(this,
        getDialogElement("#gitCloneDialog")));
    if (SparkFlags.gitPull) {
      actionManager.registerAction(new GitMergeAction(this,
          getDialogElement("#gitMergeDialog")));
      actionManager.registerAction(new GitPullAction(this,
          getDialogElement('#statusDialog')));
    }
    actionManager.registerAction(new GitBranchAction(this,
        getDialogElement("#gitBranchDialog")));
    actionManager.registerAction(new GitCheckoutAction(this,
        getDialogElement("#gitCheckoutDialog")));
    actionManager.registerAction(new GitAddAction(this,
        getDialogElement('#statusDialog')));
    actionManager.registerAction(new GitResolveConflictsAction(this));
    actionManager.registerAction(new GitCommitAction(this,
        getDialogElement("#gitCommitDialog")));
    actionManager.registerAction(new GitRevertChangesAction(this));
    actionManager.registerAction(new GitPushAction(this,
        getDialogElement("#gitPushDialog")));
    actionManager.registerAction(new RunTestsAction(this));
    actionManager.registerAction(new SettingsAction(this,
        getDialogElement('#settingsDialog')));
    actionManager.registerAction(new AboutSparkAction(this,
        getDialogElement('#aboutDialog')));
    actionManager.registerAction(new FileRenameAction(this,
        getDialogElement('#renameDialog')));
    actionManager.registerAction(new ResourceRefreshAction(this));
    // The top-level 'Close' action is removed for now: #1037.
    //actionManager.registerAction(new ResourceCloseAction(this));
    actionManager.registerAction(new TabCloseAction(this));
    actionManager.registerAction(new TabPreviousAction(this));
    actionManager.registerAction(new TabNextAction(this));
    actionManager.registerAction(new SpecificTabAction(this));
    actionManager.registerAction(new TabLastAction(this));
    actionManager.registerAction(new FileExitAction(this));
    actionManager.registerAction(new WebStorePublishAction(this,
        getDialogElement('#webStorePublishDialog')));
    actionManager.registerAction(new SearchAction(this));
    actionManager.registerAction(new FormatAction(this));
    actionManager.registerAction(new FocusMainMenuAction(this));
    actionManager.registerAction(new ImportFileAction(this));
    actionManager.registerAction(new ImportFolderAction(this,
        getDialogElement('#statusDialog')));
    actionManager.registerAction(new FileDeleteAction(this));
    actionManager.registerAction(new ProjectRemoveAction(this));
    actionManager.registerAction(new TopLevelFileRemoveAction(this));
    actionManager.registerAction(new PropertiesAction(this,
        getDialogElement("#propertiesDialog")));
    actionManager.registerAction(new GotoDeclarationAction(this));
    actionManager.registerAction(new HistoryAction.back(this));
    actionManager.registerAction(new HistoryAction.forward(this));
    actionManager.registerAction(new ToggleOutlineVisibilityAction(this));
    actionManager.registerAction(new SendFeedbackAction(this));
    actionManager.registerAction(new ShowSearchView(this));
    actionManager.registerAction(new ShowFilesView(this));
    actionManager.registerAction(new RunPythonAction(this));
    actionManager.registerAction(new PolymerDesignerAction(this,
        getDialogElement("#polymerDesignerDialog")));

    actionManager.registerKeyListener();

    DeployToMobileDialog._init(this);

    // Bind the 'show-new-project' command to the 'project-new' action.
    commands.registerHandler('show-new-project',
        new FunctionCommandHandler(
            () => actionManager.invokeAction('project-new')));
  }

  void initToolbar() {
    // Overridden in spark_polymer.dart.
  }

  void buildMenu() {
    // Overridden in spark_polymer.dart.
  }

  Future restoreWorkspace() {
    _workspace = new ws.Workspace(localPrefs, jobManager);
    return _workspace.restore();
  }

  Future restoreLocationManager() {
    return filesystem.restoreManager(localPrefs);
  }

  void initBuilders() {
    addBuilder(new DartBuilder(this.services));
    if (SparkFlags.performJavaScriptAnalysis) {
      addBuilder(new JavaScriptBuilder());
    }
    addBuilder(new JsonBuilder());
    addBuilder(new AppManifestBuilder());
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
    return chrome.fileSystem.chooseEntry(options).then(
        (chrome.ChooseEntryResult res) {
      chrome.ChromeFileEntry entry = res.entry;

      if (entry != null) {
        workspace.link(new ws.FileRoot(entry)).then((ws.Resource file) {
          _openFile(file);
          _aceManager.focus();
        });
      }
    });
  }

  Future<SparkJobStatus> openFolder(chrome.DirectoryEntry entry) {
    _OpenFolderJob job = new _OpenFolderJob(entry, this);
    return jobManager.schedule(job);
  }

  Future importFile([List<ws.Resource> resources]) {
    chrome.ChooseEntryOptions options = new chrome.ChooseEntryOptions(
        type: chrome.ChooseEntryType.OPEN_FILE);
    return chrome.fileSystem.chooseEntry(options).then(
        (chrome.ChooseEntryResult res) {
      chrome.ChromeFileEntry entry = res.entry;

      if (entry != null) {
        ws.Folder folder = resources.first;
        return nextTick().then((_) {
          return folder.importFileEntry(entry);
        }).then((File file) {
          navigationManager.gotoLocation(new NavigationLocation(file));
        });
      }
    }).catchError((e) {
      if (!_isCancelledException(e)) throw e;
    });
  }

  Future<SparkJobStatus> importFolder([List<ws.Resource> resources]) {
    chrome.ChooseEntryOptions options = new chrome.ChooseEntryOptions(
           type: chrome.ChooseEntryType.OPEN_DIRECTORY);
    return chrome.fileSystem.chooseEntry(options).then(
        (chrome.ChooseEntryResult res) {
      chrome.DirectoryEntry entry = res.entry;
      if (entry != null) {
        return _startImportFolderJob(resources, entry);
      }
    }).catchError((e) {
      if (!_isCancelledException(e)) throw e;
    });
  }

  bool _isCancelledException(e) => e == "User cancelled";

  Future<SparkJobStatus> _startImportFolderJob(
      [List<ws.Resource> resources, chrome.DirectoryEntry entry]) {
    ws.Folder folder = resources.first;
    return folder.importDirectoryEntry(entry).then((_) {
      return new SparkJobStatus(
          code: SparkStatusCodes.SPARK_JOB_IMPORT_FOLDER_SUCCESS);
    }).catchError((e) {
      showErrorMessage('Error while importing folder', exception: e);
    });
  }

  void showSuccessMessage(String message) {
    statusComponent.temporaryMessage = message;
  }

  Dialog _errorDialog;

  void showMessage(String title, String message) {
    showErrorMessage(title, message: message);
  }

  Completer<bool> _okCompleter;

  Future showMessageAndWait(String title, String message) {
    if (_errorDialog == null) {
      _errorDialog = createDialog(getDialogElement('#errorDialog'));
      _errorDialog.getElement("#errorClose").onClick.listen((_) {
        _dialogWaitComplete();
      });
      _errorDialog.getShadowDomElement("#closingX").onClick.listen((_) {
        _dialogWaitComplete();
      });
    }
    _setErrorDialogText(title, message);

    _okCompleter = new Completer();
    _errorDialog.show();
    return _okCompleter.future;
  }

  void _dialogWaitComplete() {
    _hideBackdropOnClick();
    if (_okCompleter != null) {
      _okCompleter.complete(true);
      _okCompleter = null;
    }
  }

  void unveil() {
    if (SparkFlags.developerMode) {
      RunTestsAction action = actionManager.getAction('run-tests');
      action.checkForTestListener();
    }
  }

  Editor getCurrentEditor() => editorManager.currentEditor;

  // TODO(ussuri): The whole show...Message/Dialog() family: polymerize,
  // generalize and offload to SparkPolymerUI.

  /**
   * Show a model error dialog.
   */
  void showErrorMessage(String title, {String message, var exception}) {
    const String UNKNOWN_ERROR_STRING = 'Unknown error.';

    // TODO(ussuri): Polymerize.
    if (_errorDialog == null) {
      _errorDialog = createDialog(getDialogElement('#errorDialog'));
      _errorDialog.getElement("[dismiss]")
          .onClick.listen(_hideBackdropOnClick);
      _errorDialog.getShadowDomElement("#closingX")
          .onClick.listen(_hideBackdropOnClick);
    }

    if (exception != null && SparkFlags.developerMode) {
      window.console.log(exception);
    }

    String text = message != null ? message + '\n' : '';

    if (exception != null) {
      if (exception is SparkException) {
        text += exception.message;
      } else {
        text += '${exception}';
      }
    }

    if (text.isEmpty) {
      text = UNKNOWN_ERROR_STRING;
    }

    _setErrorDialogText(title, text.trim());
    _errorDialog.show();
  }

  void _setErrorDialogText(String title, String message) {
    _errorDialog.dialog.headerTitle = title;

    Element container = _errorDialog.getElement('#errorMessage');
    container.children.clear();
    List<String> lines = message.split('\n');
    for (String line in lines) {
      Element lineElement = new Element.p();
      lineElement.text = line;
      container.children.add(lineElement);
    }
  }

  void _hideBackdropOnClick([MouseEvent event]) {
    querySelector("#modalBackdrop").style.display = "none";
  }

  Dialog _publishedAppDialog;

  void showPublishedAppDialog(String appID) {
    // TODO(ussuri): Polymerize.
    if (_publishedAppDialog == null) {
      _publishedAppDialog =
          createDialog(getDialogElement('#webStorePublishedDialog'));
      _publishedAppDialog.getElement("[submit]")
          .onClick.listen(_hideBackdropOnClick);
      _publishedAppDialog.getElement("#webStorePublishedAction")
          .onClick.listen((MouseEvent event) {
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
      _uploadedAppDialog =
          createDialog(getDialogElement('#webStoreUploadedDialog'));
      _uploadedAppDialog.getElement("[submit]").onClick.listen(
          _hideBackdropOnClick);
      _uploadedAppDialog.getElement("#webStoreUploadedAction")
          .onClick.listen((MouseEvent event) {
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
      {String okButtonLabel: 'OK', String title: ""}) {
    // TODO(ussuri): Polymerize.
    if (_okCancelDialog == null) {
      _okCancelDialog = createDialog(getDialogElement('#okCancelDialog'));
      _okCancelDialog.getElement('#okText').onClick.listen((_) {
        if (_okCancelCompleter != null) {
          _okCancelCompleter.complete(true);
          _okCancelCompleter = null;
        }
      });
      _okCancelDialog.dialog.on['transition-start'].listen((event) {
        if (!event.detail['opening']) {
          if (_okCancelCompleter != null) {
            _okCancelCompleter.complete(false);
            _okCancelCompleter = null;
          }
        }
      });
    }

    _okCancelDialog.dialog.headerTitle = title;

    Element container = _okCancelDialog.getElement('#okCancelMessage');
    container.children.clear();
    List<String> lines = message.split('\n');
    for (String line in lines) {
      Element lineElement = new Element.p();
      lineElement.text = line;
      container.children.add(lineElement);
    }

    SparkDialogButton okButton = _okCancelDialog.getElement('#okText');
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
      ws.Resource resource = focusManager.currentResource;
      if (resource != null) {
        if (resource is Folder) {
          return resource;
        } else if (resource.parent != null) {
          return resource.parent;
        }
      }
    }
    return null;
  }

  ws.File _getFile([List<ws.Resource> resources]) {
    if (resources != null && resources.isNotEmpty) {
      if (resources.first.isFile) {
        return resources.first;
      }
    } else {
      ws.Resource resource = focusManager.currentResource;
      if (resource != null && resource.isFile) {
        return resource;
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
    if (renamedResource is ws.File &&
        editorManager.isFileOpened(renamedResource)) {
      editorArea.renameFile(renamedResource);
    }
  }

  Future _openFile(ws.Resource resource) {
    if (editorArea.selectedTab != null) {
      if (currentEditedFile == resource) return new Future.value();
    }

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

  Future<Editor> openEditor(ws.File file, {Span selection}) {
    navigationManager.gotoLocation(new NavigationLocation(file, selection));
    // TODO(ussuri): Is there something better than nextTick?
    return nextTick().then((_) => editorManager.currentEditor);
  }

  //
  // - End implementation of AceManagerDelegate interface.
  //

  Timer _filterTimer = null;

  void filterFilesList(String searchString) {
    final completer = new Completer<bool>();

    if ( _filterTimer != null) {
      _filterTimer.cancel();
      _filterTimer = null;
    }

    _filterTimer = new Timer(new Duration(milliseconds: 500), () {
      _filterTimer = null;
      _reallyFilterFilesList(searchString);
    });
  }

  void _reallyFilterFilesList(String searchString) {
    if (searchString != null && searchString.length == 0) {
      searchString = null;
    }

    if (_searchViewController.visibility) {
      _filesController.performFilter(null);
      _searchViewController.performFilter(searchString);
    } else {
      _searchViewController.performFilter(null);
      _filesController.performFilter(searchString);
    }
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

  // TODO(ussuri): Polymerize.
  void setSearchViewVisible(bool visible) {
    InputElement searchField = getUIElement('#fileFilter');
    getUIElement('#searchViewArea').classes.toggle('hidden', !visible);
    getUIElement('#fileViewArea').classes.toggle('hidden', visible);
    searchField.placeholder =
        visible ? 'Search in Files' : 'Filter';
    getUIElement('#showSearchView').attributes['checkmark'] =
        visible ? 'true' : 'false';
    getUIElement('#showFilesView').attributes['checkmark'] =
        !visible ? 'true' : 'false';
    _searchViewController.visibility = visible;
    _filesController.visibility = !visible;
    _reallyFilterFilesList(searchField.value);
    if (!visible) {
      getUIElement('#searchViewPlaceholder').classes.add('hidden');
    }
  }

  // Implementation of SearchViewController

  void searchViewControllerNavigate(
      SearchViewController controller, NavigationLocation location) {
    navigationManager.gotoLocation(location);
  }

  /**
   * Check if this project uses Bower, and if so automatically run a
   * `bower install`.
   */
  Future _checkAutoRunBower(ws.Container container) {
    if (bowerManager.properties.isFolderWithPackages(container)) {
      return jobManager.schedule(new BowerGetJob(this, container));
    } else {
      return new Future.value();
    }
  }

  /**
   * Check if this project uses Pub, and if so automatically run a `pub install`.
   */
  Future _checkAutoRunPub(ws.Container container) {
    if (pubManager.canRunPub(container)) {
      // Don't run pub on Windows (#2743).
      if (PlatformInfo.isWin) {
        // TODO(ussuri): Use Template.showIntro() mechanism instead?
        showMessage(
            'Run Pub Get',
            "This Dart project uses pub packages. Currently, we can't run pub "
            "from the Chrome Dev Editor due to an issue with Windows junction "
            "points. In order to run this project, please install Dart's "
            "command-line tools (available at www.dartlang.org), and run "
            "'pub get'.");
        return new Future.value();
      } else {
        return jobManager.schedule(new PubGetJob(this, container));
      }
    } else {
      return new Future.value();
    }
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

    if (SparkFlags.developerMode) {
      _invoke(context);
    } else {
      try {
        _invoke(context);
      } catch (e) {
        // Throw the exception to the debugger if we're in developer mode.
        if (SparkFlags.developerMode) {
          throw e;
        }
        spark.showErrorMessage('Error while invoking ${name}', exception: e);
      }
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
   * Returns true if `context` is a list of items, all in the same project,
   * and that project is under SCM.
   */
  bool _isUnderScmProject(context) {
    if (context is! List) return false;
    if (context.isEmpty) return false;

    ws.Project project = context.first.project;

    if (!isUnderScm(project)) return false;

    for (var resource in context) {
      ws.Project resProject = resource.project;
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
  bool _isSingleFolder(Object object) =>
      _isSingleResource(object) && (object as List).first is ws.Folder;

  /**
   * Returns true if `object` is a list with a single [File] whose name matches
   * [regex].
   */
  bool _isSingleFileMatchingRegex(Object object, RegExp regex) {
    return _isSingleResource(object) &&
           (object as List).first is ws.File &&
           regex.hasMatch((object as List).first.name);
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
  bool activityVisible;
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
      submitBtn.onClick.listen((e) {
        // Consume the event so that the overlayToggle doesn't close the dialog.
        e..stopPropagation()..preventDefault();
        _commit();
      });
    }

    final Element cancelBtn = _dialog.getElement("[cancel]");
    if (cancelBtn != null) {
      cancelBtn.onClick.listen((e) {
        // Consume the event so that the overlayToggle doesn't close the dialog.
        e..stopPropagation()..preventDefault();
        _cancel();}
      );
    }

    final Element closingXBtn = _dialog.getShadowDomElement("#closingX");
    if (closingXBtn != null) {
      closingXBtn.onClick.listen((Event e) {
        e..stopPropagation()..preventDefault();
        _cancel();
      });
    }
  }

  void _commit() => _hide();
  void _cancel() => _hide();

  Element getElement(String selectors) => _dialog.getElement(selectors);

  List<Element> getElements(String selectors) => _dialog.getElements(selectors);

  Element _triggerOnReturn(String selectors, [bool hideDialog = true]) {
    Element element = _dialog.getElement(selectors);
    element.onKeyDown.listen((event) {
      if (event.keyCode == KeyCode.ENTER) {
        event..stopPropagation()..preventDefault();

        // We do not submit if the dialog is invalid.
        if (!_canSubmit()) return;

        _commit();

        if (hideDialog) _dialog.hide();
      }
    });
    return element;
  }

  bool _canSubmit() => _dialog.dialog.isDialogValid();

  void _show() {
    // TODO(grv) : There is a delay in delivering polymer changes. Remove this
    // once this is fixed.
    Timer.run(() {
      _dialog.show();
    });
  }

  void _hide() => _dialog.hide();

  void _showSuccessStatus(String message) {
    _hide();
    spark.showSuccessMessage(message);
  }
}

abstract class SparkActionWithProgressDialog extends SparkActionWithDialog {
  SparkProgress _progress;
  Element _progressDescriptionElement;

  SparkActionWithProgressDialog(Spark spark,
                                String id,
                                String name,
                                Element dialogElement)
      : super(spark, id, name, dialogElement) {
    this._progress = getElement('#dialogProgress');
    this._progressDescriptionElement = getElement('#progressDescription');
  }

  void _toggleProgressVisible(bool visible) {
    if (_progress != null) {
      _progress.visible = visible;
      _progress.deliverChanges();
    } else {
      _dialog.activityVisible = visible;
    }
  }

  void _setProgressMessage(String description) {
    if (_progress != null) {
      _progress.progressMessage = description;
    } else if (_progressDescriptionElement != null) {
      _progressDescriptionElement.text = description;
    }
  }
}

abstract class SparkActionWithStatusDialog extends SparkActionWithProgressDialog {
  SparkActionWithStatusDialog(Spark spark,
                              String id,
                              String name,
                              Element dialogElement)
      : super(spark, id, name, dialogElement);

  /**
   * Show the status dialog at least for 3 seconds. The dialog is closed when
   * the given future [f] is completed.
   */
  void _waitForJob(
      String title, String progressMessage, Future<SparkJobStatus> f) {
    _dialog.dialog.headerTitle = title;
    _setProgressMessage(progressMessage);
    _toggleProgressVisible(true);
    _show();
    // Show dialog for at least 3 seconds.
    Timer timer = new Timer(new Duration(milliseconds: 3000), () {
      f.then((status) {
        if (status.success && status.message != null) {
          _showSuccessStatus(status.message);
        }
      }).whenComplete(() {
        _setProgressMessage('');
        _toggleProgressVisible(true);
        _hide();
      });
    });
    _show();
  }

  void _showSuccessStatus(String message) {
    _hide();
    spark.showSuccessMessage(message);
  }
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
    super._commit();

    String name = _nameElement.value;
    if (name.isNotEmpty) {
      if (folder != null) {
        folder.createNewFile(name).then((file) {
          // Delay a bit to allow the files view to process the new file event.
          // TODO: This is due to a race condition when the files view receives
          // the resource creation event; we should remove the possibility for
          // this to occur.
          Timer.run(() {
            spark._openFile(file).then((_) {
              spark.editorArea.persistTab(file);
            });
            spark._aceManager.focus();
          });
        }).catchError((e) {
          spark.showErrorMessage("Error while creating file", exception: e);
        });
      }
    }
  }

  String get category => 'folder';

  bool appliesTo(Object object) =>
      _isSingleResource(object) && !_isTopLevelFile(object);
}

class FileSaveAction extends SparkAction {
  FileSaveAction(Spark spark) : super(spark, "file-save", "Save") {
    addBinding("ctrl-s");
  }

  void _invoke([Object context]) => spark.editorManager.saveAll();
}

class FileDeleteAction extends SparkAction implements ContextAction {
  FileDeleteAction(Spark spark) : super(spark, "file-delete", "Delete…");

  void _invoke([List<ws.Resource> resources]) {
    if (resources == null) {
      List<ws.Resource> sel = spark._filesController.getSelection();
      if (sel.isEmpty) return;
      resources = sel;
    }

    String ordinality = (resources.length == 1) ?
        '${resources.first.name}' : '${resources.length} files/folders';
    String message =
        "Do you really want to delete $ordinality?\n"
        "This will permanently delete the files from disk and cannot be undone.";

    spark.askUserOkCancel(message, okButtonLabel: 'Delete', title: 'Delete')
        .then((bool val) {
      if (val) {
        spark.workspace.pauseResourceEvents();
        Future.forEach(resources, (ws.Resource r) => r.delete()).catchError((e) {
          spark.showErrorMessage(
              "Error while deleting ${ordinality}", exception: e);
        }).whenComplete(() {
          spark.workspace.resumeResourceEvents();
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
  ProjectRemoveAction(Spark spark) : super(spark, "project-remove", "Delete/Remove…");

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
    spark.askUserOkCancel(
        'Do you really want to delete "${project.name}"?\n'
        'This will permanently delete the project contents from disk '
        'and cannot be undone.',
        okButtonLabel: 'Delete',
        title: 'Delete Project from Disk').then((bool val) {
      if (val) {
        // TODO(grv): scmManger should listen to the delete project event.
        spark.scmManager.removeProject(project);
        project.delete().catchError((e) {
          spark.showErrorMessage("Error while deleting project", exception: e);
        });
      }
    });
  }

  void _removeProjectReference(ws.Project project) {
    spark.workspace.unlink(project);
  }

  String get category => 'resource';

  bool appliesTo(Object object) => _isProject(object);
}

// TODO(ussuri): 1) Convert to SparkActionWithDialog. 2) This dialog is almost
// the same as ProjectRemoveAction -- combine.
class TopLevelFileRemoveAction extends SparkAction implements ContextAction {
  TopLevelFileRemoveAction(Spark spark)
      : super(spark, "top-level-file-remove", "Delete…");

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
          spark.showErrorMessage("Error while deleting file", exception: e);
        });
      }
    });
  }

  void _removeFileReference(ws.File file) {
    spark.workspace.unlink(file);
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
    super._commit();
    String newName = _nameElement.value;

    if (newName.isNotEmpty) {
      // Check if a file or folder already exist with the new name.
      Iterable<ws.Resource> children = [];
      if (resource.parent != null) {
        children = resource.parent.getChildren();
      }

      if (children.any((ws.Resource r) => r.name == newName)) {
        spark.showErrorMessage(
            'Error during rename', message: 'File or folder already exists.');
        return;
      }
      resource.rename(_nameElement.value).then((value) {
        spark._renameOpenEditor(resource);
      }).catchError((e) {
        spark.showErrorMessage("Error during rename", exception: e);
      });
    }
  }

  String get category => 'resource';

  bool appliesTo(Object object) =>
      _isSingleResource(object) && !_isTopLevel(object);
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
    if (_binding.index < 1 || _binding.index > spark.editorArea.tabs.length) {
      return;
    }

    // Ctrl-1 to Ctrl-8. The user types in a 1-based key event; we convert that
    // into a 0-based into into the tabs.
    spark.editorArea.focusTab(spark.editorArea.tabs[_binding.index - 1]);
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
  LaunchTarget _launchTarget;
  String _launchText;

  ApplicationRunAction.run(Spark spark)
      : super(spark, "application-run", "Run") {
    _launchTarget = LaunchTarget.LOCAL;
    _launchText = 'Running';
    addBinding("ctrl-r");
    enabled = false;
    spark.focusManager.onResourceChange.listen((r) => _updateEnablement(r));
  }

  ApplicationRunAction.deploy(Spark spark) :
      super(spark, "application-push", "Deploy to Mobile…") {
    _launchTarget = LaunchTarget.REMOTE;
    _launchText = 'Deploying';
    enabled = false;
    spark.focusManager.onResourceChange.listen((r) => _updateEnablement(r));
  }

  void _invoke([context]) {
    if (!enabled) {
      spark.showErrorMessage('Unable to deploy',
          message: 'Unable to deploy the current selection; please select an '
          'application to deploy.');
      return;
    }

    ws.Resource resource;

    if (context == null) {
      resource = spark.focusManager.currentResource;
    } else {
      resource = context.first;
    }

    Completer<SparkJobStatus> completer = new Completer<SparkJobStatus>();
    spark.launchManager.performLaunch(resource, _launchTarget).then((_) {
      completer.complete();
    }).catchError((e) {
      completer.complete();
      spark.showErrorMessage('Error ${_launchText} application', exception: e);
    });
  }

  String get category => 'application';

  bool appliesTo(List list) => list.length == 1 && _appliesTo(list.first);

  bool _appliesTo(ws.Resource resource) =>
    spark.launchManager.canLaunch(resource, _launchTarget);

  void _updateEnablement(ws.Resource resource) {
    enabled = (resource != null && _appliesTo(resource));
  }
}

abstract class PackageManagementAction
    extends SparkAction implements ContextAction {
  PackageManagementAction(Spark spark, String id, String name) :
      super(spark, id, name);

  void _invoke([context]) {
    // NOTE: [appliesTo] ensures this is always valid.
    final ws.Resource resource = context.single;
    // [appliesTo] uses [isPackageResource], which guarantees that the below
    // will return a non-null.
    final ws.Folder folder =
        _serviceProperties.getMatchingFolderWithPackages(resource);
    assert(folder != null);

    spark.jobManager.schedule(_createJob(folder)).then((status) {
      // TODO(grv): Take action on the returned status.
    });
  }

  String get category => 'source_manipulation';

  bool appliesTo(List list) =>
      list.length == 1 && _serviceProperties.isPackageResource(list.first);

  PackageServiceProperties get _serviceProperties;

  Job _createJob(ws.Container container);
}

abstract class PubAction extends PackageManagementAction {
  PubAction(Spark spark, String id, String name) : super(spark, id, name);

  PackageServiceProperties get _serviceProperties =>
      spark.pubManager.properties;
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

  PackageServiceProperties get _serviceProperties =>
      spark.bowerManager.properties;
}

class BowerGetAction extends BowerAction {
  BowerGetAction(Spark spark) : super(spark, "bower-install", "Bower Install");

  Job _createJob(ws.Folder container) => new BowerGetJob(spark, container);
}

class BowerUpgradeAction extends BowerAction {
  BowerUpgradeAction(Spark spark) : super(spark, "bower-upgrade", "Bower Update");

  Job _createJob(ws.Folder container) => new BowerUpgradeJob(spark, container);
}

class CspFixAction extends SparkAction implements ContextAction {
  CspFixAction(Spark spark) :
      super(spark, "csp-fix", "Refactor for CSP");

  void _invoke([List context]) {
    if (context == null) {
      context = [spark.focusManager.currentResource];
    }
    context.forEach((ws.Resource resource) {
      spark.jobManager.schedule(new CspFixJob(spark, resource))
        .then((status) {
        // TODO(ussuri): Take action on the returned status.
      });
    });
  }

  String get category => 'source_manipulation';

  bool appliesTo(List list) => CspFixer.mightProcess(list);
}

/**
 * A context menu item to compile a Dart file to JavaScript. Currently this is
 * only available for Dart files in a chrome app.
 */
class CompileDartAction extends SparkAction implements ContextAction {
  CompileDartAction(Spark spark) :
      super(spark, "dart-compile", "Compile to JavaScript");

  void _invoke([context]) {
    ws.Resource resource;

    if (context == null) {
      resource = spark.focusManager.currentResource;
    } else {
      resource = context.first;
    }

    spark.jobManager.schedule(
        new CompileDartJob(spark, resource, resource.name)).catchError((e) {
      spark.showErrorMessage('Error while compiling ${resource.name}', exception: e);
    });
  }

  String get category => 'application';

  bool appliesTo(List list) => list.length == 1 && _appliesTo(list.first);

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
      if (spark.focusManager.currentResource == null) {
        resources = [];
      } else {
        resources = [spark.focusManager.currentResource];
      }
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
    super._commit();

    final String name = _nameElement.value;
    if (name.isNotEmpty) {
      folder.createNewFolder(name).then((folder) {
        // Delay a bit to allow the files view to process the new file event.
        Timer.run(() {
          spark._filesController.selectFile(folder);
        });
      }).catchError((e) {
        spark.showErrorMessage("Error while creating folder", exception: e);
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
      }).catchError((e) {
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

  HistoryAction.forward(Spark spark)
      : super(spark, 'navigate-forward', 'Forward') {
    addBinding('ctrl-]');
    addBinding('ctrl-right');
    _init(true);
  }

  void _init(bool forward) {
    _forward = forward;
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
    spark.editorArea.selectedTab.focus();
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

class BuildApkAction extends SparkActionWithDialog {
  BuildApkAction(Spark spark, Element dialog)
      : super(spark, "application-build", "Build APK…", dialog) {
    getElement('#choosePrivateKey').onClick.listen((_) {
      _selectKey('privateKey');
    });
    getElement('#choosePublicKey').onClick.listen((_) {
      _selectKey('publicKey');
    });
  }

  void _selectKey(String outputField) {
    spark.chooseFileEntry().then((ChromeFileEntry entry) {
      filesystem.fileSystemAccess.getDisplayPath(entry).then((String path) {
        getElement('#$outputField').text = path;
      });
    });
  }

  void _invoke([context]) {
    _show();
  }

  void _commit() {
    super._commit();
    //TODO(albualexandru): add here the binding to the build class
  }
}

class NewProjectAction extends SparkActionWithDialog {
  InputElement _nameElt;
  SelectElement get _typeElt => getElement('select[name="type"]');

  NewProjectAction(Spark spark, Element dialog)
      : super(spark, "project-new", "New Project…", dialog) {
    _nameElt = _triggerOnReturn("#name");
  }

  void _invoke([context]) {
    _nameElt.value = '';
    // Show folder picker if top-level folder is not set.
    filesystem.fileSystemAccess.getProjectLocation().then(
        (filesystem.LocationResult r) {
      if (r != null) {
        _show();
      }
    });
  }

  void _commit() {
    super._commit();

    final name = _nameElt.value.trim();

    if (name.isEmpty) return;

    filesystem.fileSystemAccess.createNewFolder(name).then(
        (filesystem.LocationResult location) {
      if (location == null) {
        return new Future.value();
      }

      ws.WorkspaceRoot root = filesystem.fileSystemAccess.getRootFor(location);
      List<ProjectTemplate> templates;

      // TODO(ussuri): Can this no-op `return Future.value()` be removed?
      return new Future.value().then((_) {
        final globalVars = [
            new TemplateVar('projectName', name),
            new TemplateVar('sourceName', name.toLowerCase())
        ];

        _analyticsTracker.sendEvent('action', 'project-new', _typeElt.value);

        // Add templates to be used to create the project.
        final List<String> ids = _typeElt.value.split('+');
        templates = ids.map((id) => new ProjectTemplate(id, globalVars));

        return new ProjectBuilder(location.entry, templates, spark).build();
      }).then((_) {
        return spark.workspace.link(root).then((ws.Project project) {
          // Give the builders a chance to receive events about changes in the
          // workspace and to schedule their build jobs in the queue.
          Timer.run(() {
            // Wait for the builders to finish before performing tasks that
            // depend on their results. One such dependency is between
            // [_BowerBuilder] and [_checkAutoRunBower].
            spark.workspace.builderManager.waitForAllBuilds().then((_) {
              spark.showSuccessMessage('Created ${project.name}');

              // Wait for Pub and Bower to finish before displaying intros, as
              // they might require some actions on the downloaded packages.
              Future.wait([
                spark._openFile(ProjectBuilder.getMainResourceFor(project)),
                spark._checkAutoRunPub(project),
                spark._checkAutoRunBower(project)
              ]).then((_) {
                // Sequentially displaying intros for all the templates used
                // to create this project.
                templates.forEach((t) => t.showIntro(project, spark));
              });
            });
          });
        });
      });
    }).catchError((e) {
      spark.showErrorMessage('Error while creating project', exception: e);
    });
  }
}

class FolderOpenAction extends SparkActionWithStatusDialog {
  FolderOpenAction(Spark spark, SparkDialog dialog)
      : super(spark, "folder-open", 'Open Folder…', dialog);

  void _invoke([Object context]) {
    _selectFolder().then((chrome.DirectoryEntry entry) {
      if (entry != null) {
        Future f = spark.openFolder(entry);
        _waitForJob(name, 'Adding folder to workspace…', f);
      }
    });
  }
}

class DeployToMobileDialog extends SparkActionWithProgressDialog {
  static DeployToMobileDialog _instance;

  static void _init(Spark spark) {
    _instance = new DeployToMobileDialog(
        spark, spark.getDialogElement('#mobileDeployDialog'));
  }

  /**
   * Open a deploy to mobile dialog with the given resource.
   */
  static void deploy(ws.Resource resource) {
    _instance._invoke([resource]);
  }

  CheckboxInputElement _ipElement;
  CheckboxInputElement _adbElement;
  InputElement _pushUrlElement;
  InputElement _liveDeployCheckBox;
  SelectElement _usbDevices;
  SparkButton _addDeviceButton;
  int _selectedDeviceIndex = -1;
  ws.Container deployContainer;
  ProgressMonitor _monitor;
  ws.Resource _resource;

  DeployToMobileDialog(Spark spark, Element dialog)
      : super(spark, "deploy-app-old", "Deploy to Mobile", dialog) {
    _ipElement = getElement("#ip");
    _adbElement = getElement("#adb");
    _usbDevices = getElement("#usbDevices");
    _liveDeployCheckBox = getElement("#liveDeploy");
    _pushUrlElement = _triggerOnReturn("#pushUrl");
    _addDeviceButton = getElement('#addDevice');

    _ipElement.onChange.listen(_enableInputs);
    _adbElement.onChange.listen(_enableInputs);
    _liveDeployCheckBox.onChange.listen((_) =>
        spark.localPrefs.setValue("live-deployment", _liveDeployCheckBox.checked));
    if (SparkFlags.enableNewUsbApi) {
      _usbDevices.hidden = false;

      _loadUsbDevices();
      _addDeviceButton.onClick.listen((e) {
        _addDevice();
      });
      _usbDevices.onChange.listen((e) {
        _selectedDeviceIndex = _usbDevices.selectedIndex;
      });
    }
    _enableInputs();
  }

  Element get _deployDeviceMessage => getElement('#deployCheckDeviceMessage');

  SparkDialogButton get _deployButton => getElement("[submit]");

  void _invoke([context]) {
    if (context == null) {
      _resource = spark.focusManager.currentResource;
    } else {
      _resource = context.first;
    }

    deployContainer = getAppContainerFor(_resource);

    if (deployContainer == null) {
      spark.showErrorMessage(
          'Unable to deploy',
          message: 'Unable to deploy the current selection; '
                   'please select a Chrome App to deploy.');
    } else if (!MobileDeploy.isAvailable()) {
      spark.showErrorMessage(
          'Unable to deploy', message: 'No USB devices available.');
    } else {
       MobileDeploy deployer = new MobileDeploy(deployContainer, spark.localPrefs);
      _restoreDialog();
      _show();
    }
  }

  Future<List> _loadDevices() => UsbUtil.getDevices();

  void _loadUsbDevices() {
    _usbDevices.length = 0;
    _loadDevices().then((deviceInfos) {
      deviceInfos.forEach((info) {
        String option =
            "(productId:${info['productId']}, vendorId:${info['vendorId']})";
        String value = "${info['productId']}:${info['vendorId']}";
        _usbDevices.append(new OptionElement(data: option, value: value ));
      });
    });
  }

   /**
   * Opens a dialog and provides a list of active adb devices to select from.
   * It allows to select a single device at a time.
  */
  Future _addDevice() {
    return UsbUtil.getUserSelectedDevices().then((devices) {
      _loadUsbDevices();
    });
  }

  void _enableInputs([_]) {
    _pushUrlElement.disabled = !_ipElement.checked;
    _usbDevices.disabled = _ipElement.checked;
    _addDeviceButton.disabled = _ipElement.checked;
  }

  void _toggleProgressVisible(bool visible) {
    super._toggleProgressVisible(visible);
    _deployDeviceMessage.style.visibility = visible ? 'visible' : 'hidden';
  }

  void _commit() {
    _setProgressMessage("Deploying…");
    _toggleProgressVisible(true);
    _deployButton.disabled = true;
    // TODO(ussuri): BUG #2252.
    _deployButton.deliverChanges();

    _monitor = new ProgressMonitorImpl(this);

    String type = getElement('input[name="mobileDeployType"]:checked').id;
    bool useAdb = type == 'adb';
    String url = _pushUrlElement.value;

    MobileDeploy deployer = new MobileDeploy(deployContainer, spark.localPrefs);

    Future f;

    if (useAdb && SparkFlags.enableNewUsbApi == true) {
      int index = _usbDevices.selectedIndex;
       String deviceInfo =
           (_usbDevices.children[index] as OptionElement).value;
       List<String> info = deviceInfo.split(':');
       int productId = int.parse(info[0]);
       int vendorId = int.parse(info[1]);
       f = new Future(() {
         return deployer.pushAdb(_monitor, productId: productId, vendorId: vendorId);
       });
    } else {
      // Invoke the deployer methods in Futures in order to capture exceptions.
      f = new Future(() {
        return useAdb ?
            deployer.pushAdb(_monitor) : deployer.pushToHost(url, _monitor);
      });
    }

    _monitor.runCancellableFuture(f).then((_) {
      _hide();
      ws_utils.setDeploymentTime(deployContainer,
          (new DateTime.now()).millisecondsSinceEpoch);
      if (SparkFlags.liveDeployMode) {
        LiveDeployManager.startLiveDeploy(_resource.project);
      }
      spark.showSuccessMessage('Successfully pushed');
    }).catchError((e) {
      if (e is! UserCancelledException) {
        spark.showMessage('Push Failure', e.toString());
      }
    }).whenComplete(() {
      _restoreDialog();
      _monitor = null;
    });
  }

  void _restoreDialog() {
    _setProgressMessage('');
    _toggleProgressVisible(false);
    _deployButton.disabled = false;
    _deployButton.deliverChanges();
  }

  void _cancel() {
    if (_monitor != null) {
      _monitor.cancelled = true;
    }
    _hide();
  }
}

class ProgressMonitorImpl extends ProgressMonitor {
  final SparkActionWithProgressDialog _dialog;

  ProgressMonitorImpl(this._dialog);

  void start(String title,
             {num maxWork: 0,
              ProgressFormat format: ProgressFormat.NONE}) {
    super.start(title, maxWork: maxWork, format: format);
    _dialog._setProgressMessage(title == null ? '' : title);
  }
}

class PropertiesAction extends SparkActionWithDialog implements ContextAction {
  ws.Resource _selectedResource;
  HtmlElement _propertiesElement;

  PropertiesAction(Spark spark, Element dialog)
      : super(spark, 'properties', 'Properties…', dialog) {
    _propertiesElement = dialog.querySelector('#body');
  }

  void _invoke([List context]) {
    _selectedResource = context.first;
    final String type = _selectedResource is ws.Project ? 'Project' :
      _selectedResource is ws.Container ? 'Folder' : 'File';
    _dialog.dialog.headerTitle = '${type} Properties';
    _propertiesElement.innerHtml = '';
    _buildProperties().then((_) => _show());
  }

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
    return filesystem.fileSystemAccess.getDisplayPath(_selectedResource.entry)
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

  // "Properties" make sense only for a single resource.
  bool appliesTo(context) => _isSingleResource(context);
}

/* Git operations */

class GitCloneAction extends SparkActionWithProgressDialog {
  InputElement _repoUrlElement;
  InputElement _repoUrlCopyInElement;
  bool _cloning = false;
  _GitCloneTask _cloneTask;
  ScmProvider _gitProvider = getProviderType('git');

  GitCloneAction(Spark spark, Element dialog)
      : super(spark, "git-clone", "Git Clone…", dialog) {
    _repoUrlElement = _triggerOnReturn("#gitRepoUrl", false);
    _repoUrlCopyInElement = dialog.querySelector("#gitRepoUrlCopyInBuffer");
  }

  void _copyClipboard() {
    _repoUrlCopyInElement.hidden = false;
    _repoUrlCopyInElement.focus();
    document.execCommand('paste', true, null);
    String tempValue = _repoUrlCopyInElement.value;
    _repoUrlCopyInElement.value = '';
    _repoUrlCopyInElement.hidden = true;
    if (_gitProvider.isScmEndpoint(tempValue)) {
      _repoUrlElement.value = tempValue;
    }
    _repoUrlElement.focus();
  }

  void _invoke([Object context]) {
    // Select any previous text in the URL field.
    Timer.run(_repoUrlElement.select);
    // Show folder picker, if top-level folder is not set.
    filesystem.fileSystemAccess.getProjectLocation().then(
        (filesystem.LocationResult r) {
      if (r != null) {
        _show();
        Timer.run(_copyClipboard);
      }
    });
  }

  void _restoreDialog() {
    SparkDialogButton cloneButton = getElement('#clone');
    cloneButton.disabled = false;
    cloneButton.text = "Clone";

    SparkDialogButton closeButton = getElement('#cloneClose');
    closeButton.disabled = false;
    _toggleProgressVisible(false);
    _setProgressMessage("");
  }

  void _commit() {
    _setProgressMessage("Cloning…");
    _toggleProgressVisible(true);

    SparkDialogButton closeButton = getElement('#cloneClose');

    SparkDialogButton cloneButton = getElement('#clone');
    cloneButton.disabled = true;
    cloneButton.text = "Cloning…";
    cloneButton.deliverChanges();

    String url = _repoUrlElement.value;
    String projectName;

    if (url.isEmpty) {
      _restoreDialog();
      spark.showErrorMessage(
          'Error in cloning', message: 'Repository url required.');
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

    _cloneTask = new _GitCloneTask(url, projectName, spark, null);

    _cloning = true;
    _cloneTask.run().then((_) {
      _showSuccessStatus('Cloned $projectName');
    }).catchError((e) {
      if (e is SparkException &&
          e.errorCode == SparkErrorConstants.GIT_AUTH_REQUIRED) {
        _showAuthDialog();
      } else if (e is SparkException &&
          e.errorCode == SparkErrorConstants.GIT_CLONE_CANCEL) {
        spark.showSuccessMessage('Clone cancelled');
      } else if (e is SparkException &&
          e.errorCode == SparkErrorConstants.GIT_SUBMODULES_NOT_YET_SUPPORTED) {
        spark.showErrorMessage('Error while cloning Git project',
            message: 'Could not clone "${projectName}": ' + e.message);
      } else {
        spark.showErrorMessage('Error while cloning Git project',
            message: 'Error while cloning "${projectName}".', exception: e);
      }
    }).whenComplete(() {
      _cloning = false;
      _restoreDialog();
      _hide();
    });
  }

  /// Shows an authentification dialog. Returns false if cancelled.
  void _showAuthDialog([context]) {
    Timer.run(() {
      // In a timer to let the previous dialog dismiss properly.
      GitAuthenticationDialog.request(spark).then((info) {
        _invoke(context);
      }).catchError((e) {
        // Cancelled authentication: do nothing.
      });
    });
  }

  void _cancel() {
    if (_cloning) {
      _cloneTask.cancel();
    }
    _hide();
  }
}

class GitPullAction
    extends SparkActionWithStatusDialog implements ContextAction {
  GitPullAction(Spark spark, SparkDialog dialog)
      : super(spark, "git-pull", "Pull from Origin", dialog);

  void _invoke([context]) {
    ws.Project project = context.first.project;
    ScmProjectOperations operations =
        spark.scmManager.getScmOperationsFor(project);
    Future f = spark.jobManager.schedule(new _GitPullJob(operations, spark));
    String branchName = operations.getBranchName();
    _waitForJob('Git Pull', 'Updating ${branchName}…', f);
  }

  String get category => 'git';

  bool appliesTo(context) => _isScmProject(context);
}

class GitAddAction
    extends SparkActionWithStatusDialog implements ContextAction {
  GitAddAction(Spark spark, SparkDialog dialog)
      : super(spark, "git-add", "Git Add", dialog);
  chrome.Entry entry;

  void _invoke([List<ws.Resource> resources]) {
    ScmProjectOperations operations =
        spark.scmManager.getScmOperationsFor(resources.first.project);
    List<chrome.Entry> files = [];
    resources.forEach((resource) {
      files.add(resource.entry);
    });

    Future<SparkJobStatus> f = spark.jobManager.schedule(
        new _GitAddJob(operations, files, spark));
    _waitForJob('Git Add', 'Adding files to Git repository…', f);
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

class GitBranchAction
    extends SparkActionWithProgressDialog implements ContextAction {
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
    _branchNameElement.disabled = false;

    _selectElement.onChange.listen((e) {
       int index = _selectElement.selectedIndex;
       String sourceBranchName =
           (_selectElement.children[index] as OptionElement).value;
       if (sourceBranchName.startsWith('origin/')) {
         // A remote branch is prefixed with 'origin/'. Strip it to get the
         // actual branchname.
         _branchNameElement.value = (_selectElement.children[index]
             as OptionElement).value.split('/').last;
       }
    });

    gitOperations.getLocalBranchNames().then((Iterable<String> localBranches) {
      List branches = localBranches.toList();
      branches.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      for (String branch in branches) {
        _selectElement.append(new OptionElement(data: branch, value: branch));
      }

      gitOperations.getRemoteBranchNames().then(
          (Iterable<String> remoteBranches) {
        List branches = remoteBranches.toList();
        branches.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        for (String branch in branches) {
          branch = 'origin/${branch}';
          _selectElement.append(new OptionElement(data: branch, value: branch));
        }
        _selectElement.selectedIndex = 0;
      }).then((_) {
        _show();
      });
    });
  }

  void _commit() {
    String branchName = "";
    int selectIndex = _selectElement.selectedIndex;
    branchName = (_selectElement.children[selectIndex]
        as OptionElement).value;

    _setProgressMessage("Creating branch ${_branchNameElement.value}…");
    _toggleProgressVisible(true);

    SparkDialogButton closeButton = getElement('#gitBranchCancel');
    closeButton.disabled = true;
    closeButton.deliverChanges();

    SparkDialogButton branchButton = getElement('#gitBranch');
    branchButton.disabled = true;
    branchButton.deliverChanges();

    _GitBranchJob job = new _GitBranchJob(
        gitOperations, _branchNameElement.value, branchName, spark);
    spark.jobManager.schedule(job).then((_) {
      _restoreDialog();
      _hide();
    }).catchError((e) {
      spark.showErrorMessage(
          'Error while creating branch ${_branchNameElement.value}', exception: e);
    });
    _branchNameElement.disabled = false;
  }

  void _restoreDialog() {
    SparkDialogButton commitButton = getElement('#gitBranch');
    commitButton.disabled = false;

    SparkDialogButton closeButton = getElement('#gitBranchCancel');
    closeButton.disabled = false;
    _toggleProgressVisible(false);
  }

  String get category => 'git';

  bool appliesTo(context) => _isScmProject(context);
}

class GitMergeAction
    extends SparkActionWithProgressDialog implements ContextAction {
  ws.Project project;
  GitScmProjectOperations gitOperations;
  InputElement _branchNameElement;
  SelectElement _selectElement;

  GitMergeAction(Spark spark, Element dialog)
      : super(spark, "git-merge", "Merge Branch…", dialog) {
    _branchNameElement = _triggerOnReturn("#gitBranchName");
    _selectElement = getElement("#gitBranches");
  }

  void _invoke([context]) {
    project = context.first;
    gitOperations = spark.scmManager.getScmOperationsFor(project);

    // Clear out the old select options.
    // TODO (ussuri) : Polymerize.
    _selectElement.length = 0;
    _branchNameElement.value = gitOperations.getBranchName();
    _branchNameElement.disabled = true;

    gitOperations.getLocalBranchNames().then((Iterable<String> localBranches) {
      List branches = localBranches.toList();
      branches.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      for (String branch in branches) {
        // Filter out current branch.
        if (branch != _branchNameElement.value) {
          _selectElement.append(new OptionElement(data: branch, value: branch));
        }
      }

      gitOperations.getRemoteBranchNames().then(
          (Iterable<String> remoteBranches) {
        List branches = remoteBranches.toList();
        branches.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        for (String branch in branches) {
          branch = 'origin/${branch}';
          _selectElement.append(new OptionElement(data: branch, value: branch));
        }
        _selectElement.selectedIndex = 0;
      }).then((_) {
        _show();
      });
    });
  }

  void _commit() {
    String branchName = "";
    int selectIndex = _selectElement.selectedIndex;
    branchName = (_selectElement.children[selectIndex]
        as OptionElement).value;

    _setProgressMessage("Creating branch ${_branchNameElement.value}…");
    _toggleProgressVisible(true);

    SparkDialogButton closeButton = getElement('#gitBranchCancel');
    closeButton.disabled = true;
    closeButton.deliverChanges();

    SparkDialogButton branchButton = getElement('#gitBranch');
    branchButton.disabled = true;
    branchButton.deliverChanges();

    _GitMergeJob job = new _GitMergeJob(
        gitOperations, _branchNameElement.value, branchName, spark);
    spark.jobManager.schedule(job).then((_) {
      _restoreDialog();
      _hide();
    }).catchError((e) {
      spark.showErrorMessage(
          'Error while creating branch ${_branchNameElement.value}', exception: e);
    });
    _branchNameElement.disabled = false;
  }

  void _restoreDialog() {
    SparkDialogButton commitButton = getElement('#gitBranch');
    commitButton.disabled = false;

    SparkDialogButton closeButton = getElement('#gitBranchCancel');
    closeButton.disabled = false;
    _toggleProgressVisible(false);
  }

  String get category => 'git';

  bool appliesTo(context) => _isScmProject(context);
}

class GitCommitAction
    extends SparkActionWithProgressDialog implements ContextAction {
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
    _commitMessageElement = getElement("#gitCommitMessage");
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
    SparkDialogButton commitButton = getElement('#gitCommit');
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

    SparkDialogButton commitButton = getElement('#gitCommit');
    if (modifiedCnt + addedCnt + deletedCnt == 0) {
      _gitStatusElement.text = "Nothing to commit.";
      commitButton.disabled = true;
      commitButton.deliverChanges();
    } else {
      commitButton.disabled = false;
      commitButton.deliverChanges();
      _gitStatusElement.text =
          '$modifiedCnt ${(modifiedCnt != 1) ? 'files' : 'file'} modified, ' +
          '$addedCnt ${(addedCnt != 1) ? 'files' : 'file'} added, ' +
          '$deletedCnt ${(deletedCnt != 1) ? 'files' : 'file'} deleted.';
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

  void _restoreDialog() {
    SparkDialogButton commitButton = getElement('#gitCommit');
    commitButton.disabled = false;
    commitButton.deliverChanges();

    SparkDialogButton closeButton = getElement('#gitCommitCancel');
    closeButton.disabled = false;
    closeButton.deliverChanges();
    _toggleProgressVisible(false);
  }

  void _commit() {
    SparkDialogButton commitButton = getElement('#gitCommit');
    commitButton.disabled = true;
    commitButton.deliverChanges();

    SparkDialogButton closeButton = getElement('#gitCommitCancel');
    closeButton.disabled = true;
    closeButton.deliverChanges();

    _setProgressMessage("Committing…");
    _toggleProgressVisible(true);

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

  Future _startJob() {
    // TODO(grv): Add verify checks.
    _GitCommitJob commitJob = new _GitCommitJob(
        gitOperations, _gitName, _gitEmail, _commitMessageElement.value, spark);
    return spark.jobManager.schedule(commitJob).then((status) {
      if (status.success && status.message != null) {
        _showSuccessStatus(status.message);
      }
    }).whenComplete(() {
      _restoreDialog();
      _hide();
    }).catchError((e) {
      spark.showErrorMessage('Error while committing changes', exception: e);
    });
  }

  String get category => 'git';

  bool appliesTo(context) => _isUnderScmProject(context);
}

class GitCheckoutAction
    extends SparkActionWithProgressDialog implements ContextAction {
  ws.Project project;
  GitScmProjectOperations gitOperations;
  SelectElement _selectElement;

  GitCheckoutAction(Spark spark, Element dialog)
      : super(spark, "git-checkout", "Switch Branch…", dialog) {
    _selectElement = getElement("#gitCheckoutBranch");
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
    int index =
        _selectElement.selectedIndex == -1 ? 0 : _selectElement.selectedIndex;
    String branchName = _selectElement.options[index].value;
    _setProgressMessage("Checking out ${branchName}…");
    _toggleProgressVisible(true);

    SparkDialogButton closeButton = getElement('#gitCheckoutCancel');
    closeButton.disabled = true;
    closeButton.deliverChanges();

    SparkDialogButton checkoutButton = getElement('#gitCheckout');
    checkoutButton.disabled = true;
    checkoutButton.deliverChanges();

    _GitCheckoutJob job = new _GitCheckoutJob(gitOperations, branchName, spark);
    spark.jobManager.schedule(job).then((_) {
      _restoreDialog();
      _hide();
      spark.showSuccessMessage('Switched to branch ${branchName}');
    }).catchError((e) {
      spark.showErrorMessage('Error while switching to ${branchName}', exception: e);
    });
  }

  void _restoreDialog() {
    SparkDialogButton commitButton = getElement('#gitCheckout');
    commitButton.disabled = false;

    SparkDialogButton closeButton = getElement('#gitCheckoutCancel');
    closeButton.disabled = false;
    _toggleProgressVisible(false);
  }

  String get category => 'git';

  bool appliesTo(context) => _isScmProject(context);
}

class GitPushAction
    extends SparkActionWithProgressDialog implements ContextAction {
  ws.Project project;
  GitScmProjectOperations gitOperations;
  DivElement _commitsList;
  String _gitUsername;
  String _gitPassword;
  bool _needsUsernamePassword;

  GitPushAction(Spark spark, Element dialog)
      : super(spark, "git-push", "Push to Origin…", dialog) {
    _commitsList = getElement('#gitCommitList');
    _triggerOnReturn('#gitPush', false);
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
          spark.showErrorMessage('Push failed', message: 'No commits to push.');
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
      }).catchError((exception) {
        SparkException e = SparkException.fromException(exception);
        if (e.errorCode == SparkErrorConstants.GIT_AUTH_REQUIRED) {
          _handleAuthError(context);
        } else if (e.errorCode == SparkErrorConstants.GIT_HTTP_FORBIDDEN_ERROR) {
          gitOperations.objectStore.then((store) {
            String message = 'Push to ${store.config.url} denied. '
               'Verify that you have push access to the repository.';
            spark.showErrorMessage('Push failed', message: message);
          });
        } else {
          spark.showErrorMessage('Push failed', exception: e);
        }
      });
    });
  }

  void _handleAuthError(context) {
    String message = 'Authorization error. Bad username or password.';

    spark.askUserOkCancel(
        message, okButtonLabel: 'Login Again', title: 'Push failed')
        .then((bool value) {
      if (value) {
        _showAuthDialog(context);
      }
    });
  }

  void _push() {
    _setProgressMessage("Pushing…");
    _toggleProgressVisible(true);

    SparkDialogButton closeButton = getElement('#gitPushClose');
    closeButton.disabled = true;
    closeButton.deliverChanges();

    SparkDialogButton pushButton = getElement('#gitPush');
    pushButton.disabled = true;
    pushButton.deliverChanges();

    _GitPushTask task = new _GitPushTask(
        gitOperations, _gitUsername, _gitPassword, spark, null);
    task.run().then((_) {
      spark.showSuccessMessage('Changes pushed successfully');
    }).catchError((e) {
      spark.showErrorMessage(
          'Error while pushing changes',
          exception: SparkException.fromException(e));
    }).whenComplete(() {
      _restoreDialog();
      _hide();
    });
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
    spark.askUserOkCancel(text, okButtonLabel: 'Revert', title: 'Revert Changes')
        .then((bool val) {
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
      if (!resource.isFile ||
          operations.getFileStatus(resource) != ScmFileStatus.MODIFIED) {
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
  final String url;
  final String _projectName;
  final Spark spark;
  final ProgressMonitor _monitor;

  CloneTaskCancel _cancel;

  _GitCloneTask(this.url, this._projectName, this.spark, this._monitor) {
    _cancel = new CloneTaskCancel(_monitor);
  }

  void cancel() {
    _cancel.performCancel();
  }

  Future run() {
    return filesystem.fileSystemAccess.createNewFolder(_projectName).then(
        (filesystem.LocationResult location) {
      if (location == null) {
        return new Future.value();
      }

      ScmProvider scmProvider = getProviderType('git');

      // TODO(grv): Create a helper function returning git auth information.
      return spark.syncPrefs.getValue("git-auth-info").then((String value) {
        String username;
        String password;
        if (value != null) {
          Map<String, String> info = JSON.decode(value);
          username = info['username'];
          password = info['password'];
        }

        return scmProvider.clone(url, location.entry, username: username,
            password: password).then((_) {
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
            spark._checkAutoRunPub(project);

            // Run Bower if the new project has a bower.json file.
            spark._checkAutoRunBower(project);

            spark.workspace.save();
          });
        }).catchError((e) {
          // Remove the created project folder.
          return location.entry.removeRecursively().then((_) => throw e);
        });
      });
    });
  }
}

class _GitPullJob extends Job {
  GitScmProjectOperations gitOperations;
  Spark spark;

  _GitPullJob(this.gitOperations, this.spark) : super("Pulling…");

  Future<SparkJobStatus> run(ProgressMonitor monitor) {
    monitor.start(name, maxWork: 1);

    return spark.syncPrefs.getValue("git-auth-info").then((String value) {
      String username;
      String password;
      if (value != null) {
        Map<String, String> info = JSON.decode(value);
        username = info['username'];
        password = info['password'];
      }
      // TODO(grv): We'll want a way to indicate to the user what files changed
      // and if there were any merge problems.
      return gitOperations.pull(username, password).then((_) {
        return new SparkJobStatus(
            code: SparkStatusCodes.SPARK_JOB_GIT_PULL_SUCCESS);
      }).catchError((e) {
        e = SparkException.fromException(e);
        spark.showErrorMessage('Git pull status', exception: e);
      });
    });
  }
}

class _GitAddJob extends Job {
  GitScmProjectOperations gitOperations;
  Spark spark;
  List<chrome.Entry> files;

  _GitAddJob(this.gitOperations, this.files, this.spark) : super("Adding…");

  Future<SparkJobStatus> run(ProgressMonitor monitor) {
    monitor.start(name, maxWork: 1);
    return gitOperations.addFiles(files).then((_) {
      return new SparkJobStatus(
          code: SparkStatusCodes.SPARK_JOB_GIT_ADD_SUCCESS);
    });
  }
}

class _GitBranchJob extends Job {
  GitScmProjectOperations gitOperations;
  String _branchName;
  String _sourceBranchName;
  String url;
  Spark spark;

  _GitBranchJob(this.gitOperations, String branchName, this._sourceBranchName,
      this.spark) : super("Creating ${branchName}…") {
    _branchName = branchName;
  }

  Future<SparkJobStatus> run(ProgressMonitor monitor) {
    monitor.start(name, maxWork: 1);

    return spark.syncPrefs.getValue("git-auth-info").then((String value) {
      String username;
      String password;
      if (value != null) {
        Map<String, String> info = JSON.decode(value);
        username = info['username'];
        password = info['password'];
      }
      return gitOperations.createBranch(_branchName, _sourceBranchName,
          username: username, password: password).then((_) {
        return gitOperations.checkoutBranch(_branchName).then((_) {
          spark.showSuccessMessage('Created ${_branchName}');
        });
      }).catchError((e) {
        e = SparkException.fromException(e);
        spark.showErrorMessage('Error while creating branch ${_branchName}', exception : e);
      });
    });
  }
}

class _GitMergeJob extends Job {
  GitScmProjectOperations gitOperations;
  String _branchName;
  String _sourceBranchName;
  String url;
  Spark spark;

  _GitMergeJob(this.gitOperations, String branchName, this._sourceBranchName,
      this.spark) : super("Creating ${branchName}…") {
    _branchName = branchName;
  }

  Future<SparkJobStatus> run(ProgressMonitor monitor) {
    monitor.start(name, maxWork: 1);

    return spark.syncPrefs.getValue("git-auth-info").then((String value) {
      String username;
      String password;
      if (value != null) {
        Map<String, String> info = JSON.decode(value);
        username = info['username'];
        password = info['password'];
      }
      return gitOperations.mergeBranch(_branchName, _sourceBranchName,
          username: username, password: password).then((_) {
      }).catchError((e) {
        e = SparkException.fromException(e);
        spark.showErrorMessage(
            'Error in merging branch ${_branchName}', exception : e);
      });
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

  Future<SparkJobStatus> run(ProgressMonitor monitor) {
    monitor.start(name, maxWork: 1);
    return gitOperations.commit(_userName, _userEmail, _commitMessage).then((_) {
      return new SparkJobStatus(
          code: SparkStatusCodes.SPARK_JOB_GIT_COMMIT_SUCCESS);
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

  Future<SparkJobStatus> run(ProgressMonitor monitor) {
    monitor.start(name, maxWork: 1);
    return gitOperations.checkoutBranch(_branchName);
  }
}

class _OpenFolderJob extends Job {
  Spark spark;
  chrome.DirectoryEntry _entry;

  _OpenFolderJob(chrome.DirectoryEntry entry, this.spark)
      : super("Opening ${entry.fullPath}…") {
    _entry = entry;
  }

  Future<SparkJobStatus> run(ProgressMonitor monitor) {
    monitor.start(name, maxWork: 1);

    return spark.workspace.link(
        new ws.FolderRoot(_entry)).then((ws.Resource resource) {
      Timer.run(() {
        spark._filesController.selectFile(resource);
        spark._filesController.setFolderExpanded(resource);
      });

      // Run Pub if the folder has a pubspec file.
      spark._checkAutoRunPub(resource as Container);

      // Run Bower if the folder has a bower.json file.
      spark._checkAutoRunBower(resource as Container);
    }).then((_) {
      return new SparkJobStatus(message: 'Opened folder ${_entry.fullPath}');
    }).catchError((e) {
      spark.showErrorMessage(
          'Error while opening folder ${_entry.fullPath}', exception: e);
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

  Future<SparkJobStatus> run() => gitOperations.push(username, password);
}

abstract class PackageManagementJob extends Job {
  final Spark _spark;
  final ws.Container _container;
  final String _commandName;

  PackageManagementJob(this._spark, this._container, this._commandName) :
      super('Getting packages…');

  Future<SparkJobStatus> run(ProgressMonitor monitor) {
    monitor.start(name, maxWork: 1);

    return _run(monitor).then((_) {
      _spark.showSuccessMessage("Successfully ran $_commandName");
      // TODO(ussuri): Once there is confidence in CspFixer, perhaps run it here.
    }).catchError((e) {
      _spark.showErrorMessage("Error while running $_commandName", exception: e);
    });
  }

  Future _run(ProgressMonitor monitor);
}

class PubGetJob extends PackageManagementJob {
  PubGetJob(Spark spark, ws.Folder container) :
      super(spark, container, 'pub get');

  Future _run(ProgressMonitor monitor) =>
      _spark.pubManager.installPackages(_container, monitor);
}

class PubUpgradeJob extends PackageManagementJob {
  PubUpgradeJob(Spark spark, ws.Folder container) :
      super(spark, container, 'pub upgrade');

  Future _run(ProgressMonitor monitor) =>
      _spark.pubManager.upgradePackages(_container, monitor);
}

class BowerGetJob extends PackageManagementJob {
  BowerGetJob(Spark spark, ws.Folder container) :
      super(spark, container, 'bower install');

  Future _run(ProgressMonitor monitor) =>
      _spark.bowerManager.installPackages(_container, monitor);
}

class BowerUpgradeJob extends PackageManagementJob {
  BowerUpgradeJob(Spark spark, ws.Folder container) :
      super(spark, container, 'bower upgrade');

  Future _run(ProgressMonitor monitor) =>
      _spark.bowerManager.upgradePackages(_container, monitor);
}

class CspFixJob extends Job {
  final Spark _spark;
  final ws.Resource _resource;

  CspFixJob(this._spark, ws.Resource resource) :
      _resource = resource,
      super('Refactoring ${resource.name} for CSP compatibility…');

  Future<SparkJobStatus> run(ProgressMonitor monitor) {
    return new CspFixer(_resource, monitor).process()
        .then((_) {
      _spark.showSuccessMessage(
        "Successfully refactored ${_resource.name} for CSP");
    }).catchError((e) {
      _spark.showErrorMessage(
        "Error while refactoring ${_resource.name} for CSP", exception: e);
    });
  }
}

class CompileDartJob extends Job {
  final Spark spark;
  final ws.File file;

  CompileDartJob(this.spark, this.file, String fileName) :
      super('Compiling ${fileName}…');

  Future<SparkJobStatus> run(ProgressMonitor monitor) {
    monitor.start(name, maxWork: 1);

    CompilerService compiler = spark.services.getService("compiler");

    return compiler.compileFile(file, csp: true).then((CompileResult result) {
      if (!result.getSuccess()) {
        throw result;
      }

      String newFileName = '${file.name}.js';
      return file.parent.getOrCreateFile(newFileName, true).then((ws.File file) {
        return file.setContents(result.output);
      });
    });
  }
}

class ResourceRefreshJob extends Job {
  final List<ws.Project> resources;

  ResourceRefreshJob(this.resources) : super('Refreshing…');

  Future<SparkJobStatus> run(ProgressMonitor monitor) {
    List<ws.Project> projects = resources.map((r) => r.project).toSet().toList();

    monitor.start('', maxWork: projects.length);

    Completer completer = new Completer();

    Function consumeProject;
    Function refreshNextProject;

    consumeProject = () {
      ws.Project project = projects.removeAt(0);

      project.refresh().whenComplete(() {
        monitor.worked(1);
        refreshNextProject();
      });
    };

    refreshNextProject = () {
      if (projects.isEmpty) {
        completer.complete();
      } else {
        Timer.run(consumeProject);
      }
    };

    refreshNextProject();

    return completer.future;
  }
}

class AboutSparkAction extends SparkActionWithDialog {
  AboutSparkAction(Spark spark, Element dialog)
      : super(spark, "help-about", "About Chrome Dev Editor", dialog) {
    _checkbox.checked = _isTrackingPermitted;
    _checkbox.onChange.listen((e) => _isTrackingPermitted = _checkbox.checked);
  }

  void _invoke([Object context]) {
    _checkbox.checked = _isTrackingPermitted;
    _show();
  }

  void _commit() {
    _hide();
  }

  InputElement get _checkbox => getElement('#analyticsCheck');
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

    InputElement whitespaceCheckbox = getElement('#stripWhitespace');

    // Wait for each of the following to (simultaneously) complete before
    // showing the dialog:
    Future.wait([
      spark.prefs.onPreferencesReady.then((_) {
        whitespaceCheckbox.checked = spark.prefs.stripWhitespaceOnSave.value;
      }), new Future.value().then((_) {
        // For now, don't show the location field on Chrome OS; we always use syncFS.
        if (PlatformInfo.isCros) {
          return null;
        } else {
          return spark.showRootDirectory();
        }
      })
    ]).then((_) {
      _show();
      whitespaceCheckbox.onChange.listen((e) {
        spark.prefs.stripWhitespaceOnSave.value = whitespaceCheckbox.checked;
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
      testDriver = new TestDriver(
          all_tests.defineTests, connectToTestListener: true);
    }
  }
}

class WebStorePublishAction extends SparkActionWithDialog {
  static final int NEWAPP = 1;
  static final int EXISTING = 2;

  bool _initialized = false;
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
    _resource = spark.focusManager.currentResource;

    if (getAppContainerFor(_resource) == null) {
      spark.showErrorMessage(
          'Unable to publish',
          message: 'Unable to publish the current selection; '
                   'please select a Chrome App or Extension to publish.');
      return;
    }

    if (!_initialized) {
      _newInput = getElement('input[value=new]');
      _existingInput = getElement('input[value=existing]');
      _appIdInput = getElement('#appID');
      _enableInput();

      _newInput.onChange.listen((e) => _enableInput());
      _existingInput.onChange.listen((e) => _enableInput());
      _initialized = true;
    }

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
    super._commit();

    String appID = null;
    if (_existingInput.checked) {
      appID = _appIdInput.value;
    }
    _WebStorePublishJob job =
        new _WebStorePublishJob(spark, getAppContainerFor(_resource), appID);
    spark.jobManager.schedule(job).catchError((e) {
      spark.showErrorMessage(
          'Error while publishing the application', exception: e);
    });
  }

  void _updateEnablement(ws.Resource resource) {
    enabled = resource != null && getAppContainerFor(resource) != null;
  }
}

class _WebStorePublishJob extends Job {
  ws.Container _container;
  String _appID;
  Spark spark;

  _WebStorePublishJob(this.spark, this._container, this._appID)
      : super("Publishing to Chrome Web Store…");

  Future<SparkJobStatus> run(ProgressMonitor monitor) {
    monitor.start(name, maxWork: _appID == null ? 5 : 6);

    if (_container == null) {
      throw new SparkException(
          'The manifest.json file of the application has not been found.');
    }

    return ws_utils.archiveContainer(_container).then((List<int> archivedData) {
      monitor.worked(1);
      WebStoreClient wsc = new WebStoreClient();
      return wsc.authenticate().then((_) {
        monitor.worked(1);
        return wsc.uploadItem(archivedData, identifier: _appID).then(
            (String uploadedAppID) {
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
    });
  }
}

// TODO: This does not need to extends SparkActionWithDialog - just dialog.
class GitAuthenticationDialog extends SparkActionWithDialog {
  Completer completer;
  static GitAuthenticationDialog _instance;

  GitAuthenticationDialog(Spark spark, Element dialogElement)
      : super(spark, "git-authentication", "Authenticate", dialogElement) {
    _triggerOnReturn('#gitPassword');
  }

  void _invoke([Object context]) {
    (getElement('#gitUsername') as InputElement).value = '';
    (getElement('#gitPassword') as InputElement).value = '';
    spark.setGitSettingsResetDoneVisible(false);
    _show();
  }

  void _commit() {
    super._commit();

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
    _hide();
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
    spark.importFile(resources).catchError((e) {
      spark.showErrorMessage('Error while importing file', exception: e);
    });
  }

  String get category => 'folder';

  bool appliesTo(Object object) => _isSingleFolder(object);
}

class ImportFolderAction
    extends SparkActionWithStatusDialog implements ContextAction {
  ImportFolderAction(Spark spark, SparkDialog dialog)
      : super(spark, "folder-import", "Import Folder…", dialog);

  void _invoke([List<ws.Resource> resources]) {
    Future<SparkJobStatus> f;
    f = spark.importFolder(resources).then((SparkJobStatus jobStatus) {
      if (jobStatus != null) {
        _waitForJob(name, 'Importing folder…', f);
      }
      return jobStatus;
    }).catchError((e) {
      spark.showErrorMessage('Error while importing file', exception: e);
    });
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

class ShowSearchView extends SparkAction {
  ShowSearchView(Spark spark)
      : super(spark, 'show-search-view', 'Search in Files');

  void _invoke([context]) {
    spark.setSearchViewVisible(true);
  }
}

class ShowFilesView extends SparkAction {
  ShowFilesView(Spark spark) : super(spark, 'show-files-view', 'Filter');

  void _invoke([context]) {
    spark.setSearchViewVisible(false);
  }
}

class _SparkLaunchController implements LaunchController {
  void displayDeployToMobileDialog(Resource launchResource) {
    DeployToMobileDialog.deploy(launchResource);
  }
}

class RunPythonAction extends SparkAction {
  WamFS _fs;
  bool _connected;

  RunPythonAction(Spark spark) : super(spark, 'run-python', 'Run Python') {
    _fs = new WamFS();
  }

  Future _connect() {
    if (_connected) return new Future.value();
    return _fs.connect('bjffolomlcjmflonfneaijabbpnflija', '/saltpig').then((_) {
      _connected = true;
    });
  }

  void _invoke([context]) {
    List<ws.Resource> selection = spark._getSelection();
    if (selection.length == 0) return;
    ws.File file = selection.first;
    if (!file.name.endsWith('.py')) {
      spark.showErrorMessage('Not a Python script',
          message: 'Please select a Python script to run.');
      return;
    }
    file.getContents().then((content) {
      return _connect().then((_) {
        return _fs.writeStringToFile('/saltpig/domfs/foo.py', content).then((_) {
          _fs.executeCommand('/saltpig/exe/python', ['/mnt/html5/foo.py'],
              (String string) {
                print('stdout: ${string}');
              }, (String string) {
                print('stderr: ${string}');
              });
        });
      });
    });
  }
}

class PolymerDesignerAction
    extends SparkActionWithStatusDialog implements ContextAction {
  static final _HTML_FNAME_RE = new RegExp(r'^.+\.(htm|html|HTM|HTML)$');

  js.JsObject _designer;
  File _file;
  HtmlEditor _editor;

  PolymerDesignerAction(Spark spark, SparkDialog dialog)
      : super(spark, "polymer-designer", "Edit in Polymer Designer…", dialog) {
    _designer = new js.JsObject.fromBrowserObject(
        _dialog.getElement('#polymerDesigner'));
    _dialog.getElement('#polymerDesignerClear').onClick.listen(_clearDesign);
    _dialog.getElement('#polymerDesignerRevert').onClick.listen(_revertDesign);

    spark.getUIElement('#openPolymerDesignerButton').onClick.listen((_) {
      _open(spark.editorManager.currentFile);
    });
  }

  void _invoke([List<ws.Resource> resources]) {
    _open(spark._getFile(resources));
  }

  void _open(File file) {
    // Open dialog before reading file to start showing PD's splash.
    _dialog.dialog.headerTitle = "Polymer Designer: ${file.name}";
    _show();

    // Activate existing or open a new editor. The latter gives visibility of
    // changes and a way to recover the old code after exporting from PD.
    spark.openEditor(file).then((editor) {
      _editor = editor;
      _editor.save().then((_) {
        file.getContents().then((String code) {
          _designer.callMethod('load', [code]);
        });
      });
    });
  }

  void _commit() {
    final js.JsObject promise = _designer.callMethod('getCode');
    promise.callMethod('then', [(String code) {
      // Set the new code via [_editor], not [_file] to ensure that the old
      // code is recoverable via undo.
      _editor.replaceContents(code);
      _cleanup();
    }]);

    super._commit();
  }

  void _cancel() {
    _cleanup();
    super._cancel();
  }

  void _revertDesign([_]) {
    _designer.callMethod('revertCode');
  }

  void _clearDesign([_]) {
    _designer.callMethod('setCode', ['']);
  }

  void _cleanup() {
    _designer.callMethod('unload');
    _file = null;
  }

  String get category => 'refactor';

  bool appliesTo(Object object) {
    // NOTE: Flags can get updated from .spark.json after createActions()
    // runs; therefore, can't conditionally create actions using flags there.
    return  SparkFlags.polymerDesigner &&
            _isSingleFileMatchingRegex(object, _HTML_FNAME_RE);
  }
}

// Analytics code.

void _handleUncaughtException(error, [StackTrace stackTrace]) {
  // We don't log the error object itself because of PII concerns.
  final String errorDesc = error != null ? error.runtimeType.toString() : '';
  final String desc =
      '${errorDesc}|${utils.minimizeStackTrace(stackTrace)}'.trim();

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

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
  AceEditor editor;
  Workspace workspace;

  PreferenceStore localPrefs;
  PreferenceStore syncPrefs;

  SplitView _splitView;
  FilesController _filesController;

  PlatformInfo _platformInfo;

  Map<String, Action> _actionMap = {};

  Spark() {
    document.title = appName;

    localPrefs = PreferenceStore.createLocal();
    syncPrefs = PreferenceStore.createSync();

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

    document.onKeyDown.listen(_handleKeyEvent);
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

  void registerAction(Action action) {
    _actionMap[action.id] = action;
  }

  Action getAction(String id) => _actionMap[id];

  Iterable<Action> getActions() => _actionMap.values;

  void newFile(_) {
    editor.newFile();
  }

  void openFile(_) {
    chrome_gen.ChooseEntryOptions options = new chrome_gen.ChooseEntryOptions(
        type: chrome_gen.ChooseEntryType.OPEN_WRITABLE_FILE);
    chrome_gen.fileSystem.chooseEntry(options).then((chrome_gen.ChooseEntryResult result) {
      chrome_gen.ChromeFileEntry entry = result.entry;

      if (entry != null) {
        workspace.link(entry).then((file) {
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
      workspace.link(entry).then((file) {
        editor.saveAs(file);
        workspace.save();
      });
    }).catchError((e) => null);
  }

  void saveFile(_) {
    editor.save();
  }

  void createActions() {
    registerAction(new FileNewAction(this));
    registerAction(new FileOpenAction(this));
    registerAction(new FileSaveAction(this));
    registerAction(new FileExitAction(this));
  }

  void buildMenu() {
    UListElement ul = querySelector('#hotdogMenu ul');

    ul.children.insert(0, _createLIElement(null));
    ul.children.insert(0, _createMenuItem(getAction('file-open')));
    ul.children.insert(0, _createMenuItem(getAction('file-new')));

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

  void _handleKeyEvent(KeyEvent event) {
    if (!event.altKey && !event.ctrlKey && !event.metaKey) {
      return;
    }

    for (Action action in getActions()) {
      if (action.matches(event)) {
        event.preventDefault();

        if (action.enabled) {
          action.invoke();
        }
      }
    }
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

Map<String, int> _bindingMap = {
  "META": KeyCode.META,
  "CTRL": _isMac() ? KeyCode.META : KeyCode.CTRL,
  "MACCTRL": KeyCode.CTRL,
  "ALT": KeyCode.ALT,
  "SHIFT": KeyCode.SHIFT,

  "F1": KeyCode.F1,
  "F2": KeyCode.F2,
  "F3": KeyCode.F3,
  "F4": KeyCode.F4,
  "F5": KeyCode.F5,
  "F6": KeyCode.F6,
  "F7": KeyCode.F7,
  "F8": KeyCode.F8,
  "F9": KeyCode.F9,
  "F10": KeyCode.F10,
  "F11": KeyCode.F11,
  "F12": KeyCode.F12,

  "TAB": KeyCode.TAB
};

class KeyBinding {
  Set<int> modifiers = new Set();
  int keyCode;

  KeyBinding(String str) {
    List<String> codes = str.toUpperCase().split('-');

    for (String str in codes.getRange(0, codes.length - 1)) {
      modifiers.add(_codeFor(str));
    }

    keyCode = _codeFor(codes[codes.length - 1]);
  }

  bool matches(KeyEvent event) {
    if (event.keyCode != keyCode) {
      return false;
    }

    if (event.ctrlKey != modifiers.contains(KeyCode.CTRL)) {
      return false;
    }

    if (event.metaKey != modifiers.contains(KeyCode.META)) {
      return false;
    }

    if (event.altKey != modifiers.contains(KeyCode.ALT)) {
      return false;
    }

    if (event.shiftKey != modifiers.contains(KeyCode.SHIFT)) {
      return false;
    }

    return true;
  }

  String getDescription() {
    List<String> desc = new List<String>();

    if (modifiers.contains(KeyCode.CTRL)) {
      desc.add(_descriptionOf(KeyCode.CTRL));
    }

    if (modifiers.contains(KeyCode.META)) {
      desc.add(_descriptionOf(KeyCode.META));
    }

    if (modifiers.contains(KeyCode.ALT)) {
      desc.add(_descriptionOf(KeyCode.ALT));
    }

    if (modifiers.contains(KeyCode.SHIFT)) {
      desc.add(_descriptionOf(KeyCode.SHIFT));
    }

    desc.add(_descriptionOf(keyCode));

    return desc.join('+');
  }

  int _codeFor(String str) {
    if (_bindingMap[str] != null) {
      return _bindingMap[str];
    }

    return str.codeUnitAt(0);
  }

  String _descriptionOf(int code) {
    if (_isMac() && code == KeyCode.META) {
      return "Cmd";
    }

    if (code == KeyCode.META) {
      return "Meta";
    }

    if (code == KeyCode.CTRL) {
      return "Ctrl";
    }

    for (String key in _bindingMap.keys) {
      if (code == _bindingMap[key]) {
        return key; //toTitleCase(key);
      }
    }

    return new String.fromCharCode(code);
  }
}

abstract class Action {
  StreamController<Action> _controller = new StreamController.broadcast();

  String id;
  String name;
  bool _enabled = true;

  KeyBinding binding;

  Action(this.id, this.name);

  void defaultBinding(String str) {
    if (binding == null) {
      binding = new KeyBinding(str);
    }
  }

  void linuxBinding(String str) {
    if (_isLinux()) {
      binding = new KeyBinding(str);
    }
  }

  void macBinding(String str) {
    if (_isMac()) {
      binding = new KeyBinding(str);
    }
  }

  void winBinding(String str) {
    if (_isWin()) {
      binding = new KeyBinding(str);
    }
  }

  void invoke();

  bool get enabled => _enabled;

  set enabled(bool value) {
    if (_enabled != value) {
      _enabled = value;

      _controller.add(this);
    }
  }

  bool matches(KeyEvent event) {
    return binding == null ? false : binding.matches(event);
  }

  Stream<Action> get onChange => _controller.stream;

  String getBindingDescription() {
    return binding == null ? null : binding.getDescription();
  }

  String toString() => 'Action: ${name}';
}

bool _isLinux() => _platform().indexOf('linux') != -1;
bool _isMac() => _platform().indexOf('mac') != -1;
bool _isWin() => _platform().indexOf('win') != -1;

String _platform() {
  String str = window.navigator.platform;
  return (str != null) ? str.toLowerCase() : '';
}

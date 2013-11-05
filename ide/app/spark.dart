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

  Spark() {
    document.title = appName;

    localPrefs = PreferenceStore.createLocal();
    syncPrefs = PreferenceStore.createSync();

    addParticipant(new _SparkSetupParticipant(this));

    // TODO: this event is not being fired. A bug with chrome apps? Our js
    // interop layer? chrome_gen?
    chrome_gen.app.window.onClosed.listen((_) {
      close();
    });

    workspace = new Workspace(localPrefs);

    editor = new AceEditor();

    _splitView = new SplitView(querySelector('#splitview'));
    _filesController = new FilesController(workspace, this);

    setupFileActions();
    setupEditorThemes();

    bootjack.Bootjack.useDefault();

    buildMenu();
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
      if (theme != null) {
        editor.setTheme(theme);
        (querySelector("#editorTheme") as SelectElement).value = theme;
      }
      querySelector("#editorTheme").onChange.listen(_handleThemeEvent);
    });
  }

  void newFile(_) {
    editor.newFile();
    showStatus('created new file');
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
        showStatus('saved ${file.name}');
        workspace.save();
      });
    }).catchError((e) => null);
  }

  void saveFile(_) {
    editor.save();
  }

  void buildMenu() {
    UListElement ul = querySelector('#hotdogMenu ul');

    // TODO: add a theme changer?

    //ul.children.add(_createLIElement(null));

    ul.children.add(_createLIElement('Check for updates...', _handleUpdateCheck));
    ul.children.add(_createLIElement('About Spark', _handleAbout));
  }

  void _handleThemeEvent(Event e) {
    String aceTheme = (e.target as SelectElement).value;
    editor.setTheme(aceTheme);
    syncPrefs.setValue('aceTheme', aceTheme);
  }

  void showStatus(String text, {bool error: false}) {
    Element element = querySelector("#status");
    element.text = text;
    element.classes.toggle('error', error);
  }

  // Implementation of FilesControllerDelegate interface.
  void openInEditor(Resource file) {
    editor.setContent(file);
    showStatus('saved ${file.name}');
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
    // TODO: show a dialog
    showStatus("${appName} version ${appVersion}");
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

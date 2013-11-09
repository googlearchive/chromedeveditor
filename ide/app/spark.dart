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
import 'lib/tests.dart';
import 'lib/ui/files_controller.dart';
import 'lib/ui/files_controller_delegate.dart';
import 'lib/ui/widgets/splitview.dart';
import 'lib/workspace.dart';
import 'test/all.dart' as all_tests;

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
    // Start the app in normal mode.
    Spark spark = new Spark(testMode);
    spark.start();
  });
}

class Spark extends Application implements FilesControllerDelegate {
  final bool developerMode;
  AceEditor editor;
  Workspace workspace;

  PreferenceStore localPrefs;
  PreferenceStore syncPrefs;

  SplitView _splitView;
  FilesController _filesController;
  PlatformInfo _platformInfo;
  TestDriver _testDriver;

  Spark(this.developerMode) {
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

  void buildMenu() {
    UListElement ul = querySelector('#hotdogMenu ul');

    querySelector('#themeLeft').onClick.listen((e) {
      e.stopPropagation();
      _handleChangeTheme(themeLeft: true);
    });

    querySelector('#themeRight').onClick.listen((e) {
      e.stopPropagation();
      _handleChangeTheme(themeLeft: false);
    });

    if (developerMode) {
      ul.children.add(_createLIElement(null));
      ul.children.add(
          _createLIElement('Run Tests', () => _testDriver.runTests()));
    }

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

  Future applicationStarted(Application application) {
    if (spark.developerMode) {
      spark._testDriver = new TestDriver(
          all_tests.defineTests, connectToTestListener: true);
    }
  }

  Future applicationClosed(Application application) {
    // TODO: flush out any preference info or workspace state?

  }
}

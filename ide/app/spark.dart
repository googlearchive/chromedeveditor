// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html';

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
      /*
       * Start the app, show the test UI, and connect to a test server if one is
       * available.
       */
      SparkTest app = new SparkTest();

      app.start().then((_) {
        app.showTestUI();

        app.connectToListener();
      });
    } else {
      /*
       * Start the app in normal mode.
       */
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

    querySelector("#newFile").onClick.listen(newFile);
    querySelector("#openFile").onClick.listen(openFile);
    querySelector("#saveFile").onClick.listen(saveFile);
    querySelector("#saveAsFile").onClick.listen(saveAsFile);
    querySelector("#editorTheme").onChange.listen(_handleThemeEvent);

    workspace = new Workspace(localPrefs);

    editor = new AceEditor();

    _splitView = new SplitView(querySelector('#splitview'));
    _filesController = new FilesController(workspace, this);

    syncPrefs.getValue('aceTheme').then((String value) {
      if (value != null) {
        editor.setTheme(value);
        (querySelector("#editorTheme") as SelectElement).value = value;
      }
    });
  }

  String get appName => i18n('app_name');

  PlatformInfo get platformInfo => _platformInfo;

  void newFile(_) {
    editor.newFile();
    updatePath('created new file');
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
    });
  }

  void saveAsFile(_) {
    // TODO: don't show error message if operation cancelled
    chrome_gen.ChooseEntryOptions options = new chrome_gen.ChooseEntryOptions(
        type: chrome_gen.ChooseEntryType.SAVE_FILE);

    chrome_gen.fileSystem.chooseEntry(options).then((chrome_gen.ChooseEntryResult result) {
      chrome_gen.ChromeFileEntry entry = result.entry;
      workspace.link(entry).then((file) {
        editor.saveAs(file);
        updatePath('saved ${file.name}');
        workspace.save();
      });
    }).catchError((_) => updateError('Error on save as'));
  }

  void saveFile(_) {
    editor.save();
  }

  void _handleThemeEvent(Event e) {
    String aceTheme = (e.target as SelectElement).value;
    editor.setTheme(aceTheme);
    syncPrefs.setValue('aceTheme', aceTheme);
  }

  void updateError(String string) {
    querySelector("#error").innerHtml = string;
  }

  void updatePath(String text) {
    querySelector("#path").text = text;
  }

  /*
   * Implementation of FilesControllerDelegate interface.
   */

  void openInEditor(Resource file) {
    print('open in editor: ${file.name}');
    editor.setContent(file);
    updatePath('saved ${file.name}');
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

// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark;

import 'dart:async';
import 'dart:html';

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;

import 'lib/ace.dart';
import 'lib/app.dart';
import 'lib/utils.dart';
import 'lib/preferences.dart';
import 'lib/ui/widgets/file_item_view.dart';
import 'lib/ui/widgets/splitview.dart';
import 'lib/workspace.dart';

void main() {
  Spark spark = new Spark();
  spark.start();
}

class Spark extends Application {
  AceEditor editor;
  Workspace workspace;

  PreferenceStore localPrefs;
  PreferenceStore syncPrefs;

  SplitView _splitView;
  FileItemView _filesView;

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

    _filesView = new FileItemView(workspace);
    _splitView = new SplitView(querySelector('#splitview'));

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
          editor.setContent(file);
          updatePath('opened ${file.name}');
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

      // TODO: do any async tasks necessary to create / init the workspace?

    });
  }

  Future applicationClosed(Application application) {
    // TODO: flush out any preference info or workspace state?

    return spark.workspace.save();
  }
}

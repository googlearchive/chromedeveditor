// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.flags;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html';

import 'package:chrome/chrome_app.dart' as chrome;

/**
 * Stores global developer flags.
 */
class SparkFlags {
  bool developerMode;
  bool useLightEditorThemes;
  bool useDarkEditorThemes;
  bool get useEditorThemes => useLightEditorThemes || useDarkEditorThemes;

  static SparkFlags instance;

  SparkFlags._(this.developerMode,
               this.useLightEditorThemes,
               this.useDarkEditorThemes);

  /**
   * Initialize the flags. By default, assume developer mode and a single
   * fixed editor theme.
   */
  static void init({bool developerMode: true,
                    bool lightEditorThemes: false,
                    bool darkEditorThemes: false}) {
    assert(instance == null);
    instance = new SparkFlags._(
        developerMode, lightEditorThemes, darkEditorThemes);
  }

  /**
   * Initialize the flags from a JSON file. If the file does not exit, use
   * the defaults (see [init]).
   */
  static Future initFromFile(String fileName) {
    final String url = chrome.runtime.getURL(fileName);
    return HttpRequest.getString(url).then((String contents) {
      bool result = true;
      Map flagsMap = JSON.decode(contents);
      // Normalize missing/malformed values to bools via x==true.
      init(developerMode: flagsMap['test-mode'] == true,
           lightEditorThemes: flagsMap['light-editor-themes'] == true,
           darkEditorThemes: flagsMap['dark-editor-themes'] == true);
    }).catchError((e) {
      // If JSON is invalid/non-existent, use the defaults.
      init();
    });
  }
}

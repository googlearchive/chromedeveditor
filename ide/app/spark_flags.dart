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
  bool useLightAceThemes;
  bool useDarkAceThemes;
  bool get useAceThemes => useLightAceThemes || useDarkAceThemes;

  static SparkFlags instance;

  SparkFlags._(
      this.developerMode, this.useLightAceThemes, this.useDarkAceThemes);

  /**
   * Initialize the flags. By default, assume developer mode and dark editor
   * themes.
   */
  static void init({bool developerMode: true,
                    bool ligtAceThemes: false,
                    bool darkAceThemes: true}) {
    assert(instance == null);
    instance = new SparkFlags._(developerMode, ligtAceThemes, darkAceThemes);
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
           ligtAceThemes: flagsMap['light-ace-themes'] == true,
           darkAceThemes: flagsMap['dark-ace-themes'] == true);
    }).catchError((e) {
      // If JSON is invalid/non-existent, use the defaults.
      init();
    });
  }
}

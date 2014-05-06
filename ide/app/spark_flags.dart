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
  static SparkFlags instance;

  final bool developerMode;
  final bool useLightAceThemes;
  final bool useDarkAceThemes;
  final bool showGitPull;
  final bool showGitBranch;

  SparkFlags._({
      this.developerMode: false,
      this.useLightAceThemes: false,
      this.useDarkAceThemes: true,
      this.showGitPull: false,
      this.showGitBranch: false});

  bool get useAceThemes => useLightAceThemes || useDarkAceThemes;

  /**
   * Initialize the flags from a JSON file. If the file does not exit, use the
   * defaults.
   */
  static Future initFromFile(String fileName) {
    final String url = chrome.runtime.getURL(fileName);
    return HttpRequest.getString(url).then((String contents) {
      assert(instance == null);

      Map flagsMap = JSON.decode(contents);

      // Normalize missing / malformed values to bools.
      instance = new SparkFlags._(
          developerMode: _flag(flagsMap, 'test-mode'),
          useLightAceThemes: _flag(flagsMap, 'light-ace-themes'),
          useDarkAceThemes: _flag(flagsMap, 'dark-ace-themes'),
          showGitPull: _flag(flagsMap, 'show-git-pull'),
          showGitBranch: _flag(flagsMap, 'show-git-branch'));
    }).catchError((e) {
      // If JSON is invalid / non-existent, use the defaults.
      instance = new SparkFlags._();
    });
  }

  static bool _flag(Map m, String key) => m[key] == true;
}

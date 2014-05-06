// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.flags;

import 'dart:async';
import 'dart:convert' show JSON;

/**
 * Stores global developer flags.
 */
class SparkFlags {
  static final _flags = new Map<String, dynamic>();

  static bool get developerMode => _flags['test-mode'] == true;
  static bool get useLightAceThemes => _flags['light-ace-themes'] == true;
  static bool get useDarkAceThemes => _flags['dark-ace-themes'] == true;
  static bool get useAceThemes => useLightAceThemes || useDarkAceThemes;
  static bool get showGitPull => _flags['show-git-pull'] == true;
  static bool get showGitBranch => _flags['show-git-branch'] == true;

  static void setFlags(Map<String, dynamic> newFlags) {
    if (newFlags != null) _flags.addAll(newFlags);
  }

  /**
   * Initialize the flags from a JSON file. If the file does not exit, use the
   * defaults.
   */
  static Future initFromFile(Future<String> fileReader) {
    return _readFromFile(fileReader).then((Map<String, dynamic> flags) {
      setFlags(flags);
    });
  }

  /**
   * Read flags from a JSON file. If the file does not exit or can't be parsed,
   * return null.
   */
  static Future<Map<String, dynamic>> _readFromFile(Future<String> fileReader) {
    return fileReader.then((String contents) {
      return JSON.decode(contents);
    }).catchError((_) {
      // The JSON file is non-existent or invalid.
      return null;
    });
  }
}

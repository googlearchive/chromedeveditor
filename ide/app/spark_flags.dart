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

  /**
   * Accessors to the currently supported flags.
   */
  // NOTE: '...== true' below are on purpose: missing flags default to false.
  static bool get developerMode => _flags['test-mode'] == true;
  static bool get useLightAceThemes => _flags['light-ace-themes'] == true;
  static bool get useDarkAceThemes => _flags['dark-ace-themes'] == true;
  static bool get useAceThemes => useLightAceThemes || useDarkAceThemes;
  static bool get showWipProjectTemplates => _flags['wip-project-templates'] == true;
  static bool get showGitPull => _flags['show-git-pull'] == true;
  static bool get showGitBranch => _flags['show-git-branch'] == true;
  static bool get performJavaScriptAnalysis => _flags['analyze-javascript'] == true;
  static bool get enableMultiSelect => _flags['enable-multiselect'] == true;
  // Bower:
  static bool get bowerMapComplexVerToLatestStable =>
      _flags['bower-map-complex-ver-to-latest-stable'] == true;
  static Map<String, String> get bowerOverriddenDeps =>
      _flags['bower-override-dependencies'];
  static List<String> get bowerIgnoredDeps =>
      _flags['bower-ignore-dependencies'];

  /**
   * Add new flags to the set, possibly overwriting the existing values.
   * Maps are treated specially, updating the top-level map entries rather
   * than overwriting the whole map.
   */
  static void setFlags(Map<String, dynamic> newFlags) {
    // TODO(ussuri): Also recursively update maps on 2nd level and below.
    if (newFlags == null) return;
    newFlags.forEach((key, newValue) {
      var value;
      var oldValue = _flags[key];
      if (oldValue != null && oldValue is Map && newValue is Map) {
        value = oldValue;
        value.addAll(newValue);
      } else {
        value = newValue;
      }
      _flags[key] = value;
    });
  }

  /**
   * Initialize the flags from a JSON file. If the file does not exit, use the
   * defaults. If some flags have already been set, they will be overwritten.
   */
  static Future initFromFile(Future<String> fileReader) {
    return _readFromFile(fileReader).then((Map<String, dynamic> flags) {
      setFlags(flags);
    });
  }

  /**
   * Initialize the flags from several JSON files. Files should be sorted in the
   * order of precedence, from left to right. Each new file overwrites the
   * prior ones, and the flags
   */
  static Future initFromFiles(List<Future<String>> fileReaders) {
    Iterable<Future<Map<String, dynamic>>> futures =
        fileReaders.map((fr) => _readFromFile(fr));
    return Future.wait(futures).then((List<Map<String, dynamic>> multiFlags) {
      for (final flags in multiFlags) {
        setFlags(flags);
      }
    });
  }

  /**
   * Read flags from a JSON file. If the file does not exit or can't be parsed,
   * return null.
   */
  static Future<Map<String, dynamic>> _readFromFile(Future<String> fileReader) {
    return fileReader.then((String contents) {
      return JSON.decode(contents);
    }).catchError((e) {
      if (e is FormatException) {
        throw 'Config file has invalid format: $e';
      } else {
        return null;
      }
    });
  }
}

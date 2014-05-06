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
  static bool _developerMode;
  static bool _useLightAceThemes;
  static bool _useDarkAceThemes;

  /// The default is true.
  static bool get developerMode => _developerMode != false;
  /// The default is false.
  static bool get useLightAceThemes => _useLightAceThemes == true;
  /// The default is false.
  static bool get useDarkAceThemes => _useDarkAceThemes == true;
  /// The default is true.
  static bool get useAceThemes => useLightAceThemes || useDarkAceThemes;

  /**
   * Initialize the flags. By default, assume developer mode and dark editor
   * themes.
   */
  static void init({bool developerMode,
                    bool lightAceThemes,
                    bool darkAceThemes}) {
    // Overwrite the previous value only if the new one is non-empty.
    if (developerMode != null) _developerMode = developerMode;
    if (lightAceThemes != null) _useLightAceThemes = lightAceThemes;
    if (darkAceThemes != null) _useDarkAceThemes = darkAceThemes;
  }

  /**
   * Initialize the flags from a set of JSON files. File names should be listed
   * in the order of precedence: each file will override values defined in
   * preceding files. If a flag is not defined in any of the the file does not exit, use
   * the defaults (see [init]).
   */
  static Future initFromFiles(List<String> fileNames) {
    Iterable<Future> futures = fileNames.map((fname) => _readFromFile(fname));

    return Future.wait(futures).then((List<Map<String, dynamic>> flagMaps) {
      // Collapse individual maps into a single map, using left-to-right
      // precedence.
      Map<String, dynamic> flagMap = {};
      flagMaps.forEach((fm) => flagMap.addAll(fm));

      // Normalize missing/malformed values to bools via x==true.
      init(developerMode: flagMap['test-mode'],
           lightAceThemes: flagMap['use-light-ace-themes'],
           darkAceThemes: flagMap['use-dark-ace-themes']);
    });
  }

  /**
   * Read flags from a JSON file. If the file does not exit or can't be parsed,
   * return null.
   */
  static Future<Map<String, dynamic>> _readFromFile(String fileName) {
    final String url = chrome.runtime.getURL(fileName);
    return HttpRequest.getString(url).then((String contents) {
      return JSON.decode(contents);
    }).catchError((_) {
      // The JSON file is non-existent or invalid.
      return null;
    });
  }
}

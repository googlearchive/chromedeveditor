// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.flags;

import 'dart:async';
import 'dart:convert' show JSON;

import 'platform_info.dart';

/**
 * Stores global developer flags.
 */
class SparkFlags {
  // Default value of flags. These flags will be first overriden by user.json
  // and then by .spark.json.
  static final Map<String, dynamic> _flags = {
    'test-mode': true,
    'live-deploy-mode': true,
    'bower-map-complex-ver-to-latest-stable': true,
    'enable-polymer-designer': true,

    'enable-git-salt': false,
    'enable-apk-build': false,
    'wip-project-templates': false,
    'analyze-javascript': false,
    'enable-multiselect': false,
    'bower-ignore-dependencies': [
    ],
    'bower-override-dependencies': {
    },
    'bower-use-git-clone': false,
    'package-files-are-editable': false,
    'enable-new-usb-api': true,
    'csp-fixer-max-concurrent-tasks': 20,
    'csp-fixer-backup-original-sources': false
  };

  /**
   * Accessors to the currently supported flags.
   */
  // NOTE: '...== true' below are on purpose: missing flags default to false.
  // NOTE: The flags below are formatted in a uniform fashion for readability.
  static bool get developerMode =>
      _flags['test-mode'] == true;
  static bool get liveDeployMode =>
      _flags['live-deploy-mode'] == true;
  static bool get apkBuildMode =>
      _flags['enable-apk-build'] == true;

  // Editor:
  static bool get enableMultiSelect =>
      _flags['enable-multiselect'] == true;
  static bool get packageFilesAreEditable =>
      _flags['package-files-are-editable'] == true;

  static bool get showWipProjectTemplates =>
      _flags['wip-project-templates'] == true;
  static bool get performJavaScriptAnalysis =>
      _flags['analyze-javascript'] == true;

  // Bower:
  static bool get bowerMapComplexVerToLatestStable =>
      _flags['bower-map-complex-ver-to-latest-stable'] == true;
  static Map<String, String> get bowerOverriddenDeps =>
      _flags['bower-override-dependencies'];
  static List<String> get bowerIgnoredDeps =>
      _flags['bower-ignore-dependencies'];
  static bool get bowerUseGitClone =>
      _flags['bower-use-git-clone'] == true;

  // Git:
  static bool get gitPull =>
      _flags['enable-git-pull'] == true;
  static bool get gitSalt =>
      _flags['enable-git-salt'] == true;

  static bool get polymerDesigner =>
      _flags['enable-polymer-designer'] == true;

  //TODO(grv): Remove the flag once usb api is in chrome stable.
  static bool get enableNewUsbApi =>
      _flags['enable-new-usb-api'] == true && PlatformInfo.chromeVersion >= 40;

  // CspFixer:
  static int get cspFixerMaxConcurrentTasks  =>
      _flags['csp-fixer-max-concurrent-tasks'];
  static bool get cspFixerBackupOriginalSources =>
      _flags['csp-fixer-backup-original-sources'] == true;

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
    return fileReader
      .then((String contents) => JSON.decode(contents))
      .catchError((e) {
        if (e is FormatException) {
          throw 'Config file has invalid format: $e';
        }
      });
  }
}

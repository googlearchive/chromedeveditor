// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.package_mgmt.bower_properties;

import 'dart:convert' show JSON;

import 'package_manager.dart';
import '../workspace.dart';

class BowerProperties extends PackageServiceProperties {
  static const String _CONFIG_FILE = '.bowerrc';
  static const Map<String, dynamic> _DEFAULT_CONFIG = const {
    'directory': 'bower_components'
  };

  Map<String, dynamic> _config = {};

  BowerProperties(Folder container) {
    // Search for all .bowerrc config files from this folder upwards,
    // merging them into _config in a descending order of preference.
    while(container != null) {
      File configFile = container.getChild(_CONFIG_FILE);
      if (configFile != null) {
        configFile.getContents().then((String text) {
          Map<String, dynamic> newConfig = JSON.decode(text);
          // Override possible duplicate keys in higher-level configs with
          // lower-level ones.
          newConfig.addAll(_config);
          _config = newConfig;
        }).catchError((e) {
          if (e is FormatException) {
            throw '$_CONFIG_FILE has invalid format: $e';
          }
        });
      }
      container = container.parent;
    }
    Map<String, dynamic> finalConfig = _DEFAULT_CONFIG;
    finalConfig.addAll(_config);
    _config = finalConfig;
  }

  //
  // PackageServiceProperties virtual interface:
  //

  String get packageServiceName => 'bower';
  String get packageSpecFileName => 'bower.json';
  String get packagesDirName => _config['directory'];

  // Bower doesn't use any of the below nullified properties/methods.

  String get libDirName => null;
  String get packageRefPrefix => null;

  // This will get both the "../" variant and the
  // "baz/bower_components/foo/bar.dart" variant when served over HTTP.
  RegExp get packageRefPrefixRegexp =>
      new RegExp('^(\\.\\./|.*/${packagesDirName}/)(.*)\$');

  void setSelfReference(Project project, String selfReference) {}
  String getSelfReference(Project project) => null;
}

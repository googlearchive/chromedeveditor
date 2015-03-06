// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.package_mgmt.bower_properties;

import 'dart:async';
import 'dart:convert' show JSON;

import 'package_manager.dart';
import '../workspace.dart';

// TODO(ussuri): Make package-private once no longer used outside.
final BowerProperties bowerProperties = new BowerProperties();

class BowerProperties extends PackageServiceProperties {
  static const Map<String, dynamic> _DEFAULT_CONFIG = const {
    'directory': 'bower_components'
  };
  static const String _METADATA_KEY = 'bowerConfig';

  //
  // PackageServiceProperties virtual interface:
  //

  String get packageServiceName => 'bower';
  String get configFileName => '.bowerrc';
  String get packageSpecFileName => 'bower.json';

  String getPackagesDirName(Resource resource) {
    return _getConfig(resource)['directory'];
  }

  // Bower doesn't use any of the below nullified properties/methods.

  String get libDirName => null;
  String get packageRefPrefix => null;

  // This will get both the "../" variant and the
  // "baz/bower_components/foo/bar.dart" variant when served over HTTP.
  RegExp get packageRefPrefixRegexp =>
      new RegExp('^(\\.\\./|.*/${getPackagesDirName}/)(.*)\$');

  void setSelfReference(Project project, String selfReference) {}
  String getSelfReference(Project project) => null;

  /**
   * Store or remove the updated Bower configuration, asynchronously extracted
   * from the .bowerrc file correspondning to the [delta], in [_METADATA_KEY]
   * attached to the file's parent folder.
   */
  Future handleConfigFileChange(ChangeDelta delta) {
    var completer = new Completer<Map<String, dynamic>>();
    final File file = delta.resource;

    if (delta.isDelete ||
        (delta.isRename && file.name != configFileName)) {
      completer.complete(null);
    } else if (delta.isAdd ||
               delta.isChange ||
               (delta.isRename && file.name == configFileName)) {
      file.getContents().then((String text) {
        try {
          completer.complete(text.isEmpty ? {} : JSON.decode(text));
        } on FormatException catch (e) {
          throw '${file.path} has invalid format: $e';
        }
      });
    } else {
      completer.complete();
    }

    return completer.future.then((config) =>
        file.parent.setMetadata(_METADATA_KEY, config));
  }

  /**
   * Walk up the chain of parents of this [resource] and compute the final
   * Bower configuration for it from their associated [_METADATA_KEY]s.
   */
  Map<String, dynamic> _getConfig(Resource resource) {
    // Collect hierarchical local configurations from [resource]'s parents.
    Container container = resource is Folder ? resource : resource.parent;
    var configs = new List<Map<String, dynamic>>();
    while(container is! Workspace) {
      final Map<String, dynamic> config = container.getMetadata(_METADATA_KEY);
      if (config != null) configs.add(config);
      container = container.parent;
    }

    // Merge found configurations in a descending order of precedence: a child's
    // key overrides the same key in a parent.
    // NOTE: this overriding is shallow; it doesn't descend into the values even
    // if they themselves are maps: the only possible map key in a .bowerrc is
    // 'registry', and it seems OK to do this.
    var finalConfig = new Map<String, dynamic>.from(_DEFAULT_CONFIG);
    configs.reversed.forEach((config) => finalConfig.addAll(config));
    return finalConfig;
  }
}

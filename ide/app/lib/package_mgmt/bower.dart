// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Bower services.
 */

// TODO(ussuri): Add tests.

library spark.package_mgmt.bower;

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:logging/logging.dart';

import 'package_manager.dart';
import '../scm.dart';
import '../workspace.dart';

Logger _logger = new Logger('spark.bower');

// TODO(ussuri): Make package-private once no longer used outside.
final bowerProperties = new BowerProperties();

class BowerProperties extends PackageServiceProperties {
  String get packageServiceName => 'bower';
  String get packageSpecFileName => 'bower.json';
  String get packagesDirName => 'bower_packages';

  // Bower doesn't use any of the below nullified properties/methods.

  String get libDirName => null;
  String get packageRefPrefix => null;
  RegExp get packageRefPrefixRegexp => null;

  void setSelfReference(Project project, String selfReference) {}
  String getSelfReference(Project project) => null;
}

class BowerManager extends PackageManager {
  static const _GITHUB_ROOT_URL = 'https://github.com';
  /// E.g.: "Polymer/polymer-elements".
  static const _PACKAGE_SPEC_PATH = '''[-\\w./]+''';
  /// E.g.: "#master", "#1.2.3" (however branches in general are not yet
  /// supported, only "#master" is accepted - see below).
  static const _PACKAGE_SPEC_BRANCH = '''[-\\w.]+''';
  /// E.g.: "Polymer/polymer#master";
  static final RegExp _PACKAGE_SPEC_REGEXP =
      new RegExp('''^($_PACKAGE_SPEC_PATH)(?:#($_PACKAGE_SPEC_BRANCH))?\$''');

  ScmProvider _scmProvider;

  BowerManager(Workspace workspace) :
      _scmProvider = getProviderType('git'),
      super(workspace);

  PackageServiceProperties get properties => bowerProperties;

  PackageBuilder getBuilder() => new _BowerBuilder();

  PackageResolver getResolverFor(Project project) =>
      new _BowerResolver._(project);

  Future installPackages(Project project) {
    return _fetchPackages(project).whenComplete(() {
      return project.refresh();
    }).catchError((e, st) {
      _logger.severe('Error getting Bower packages', e, st);
      return new Future.error(e, st);
    });
  }

  Future upgradePackages(Project project) {
    return new Future.error('Not implemented');
  }

  // TODO(ussuri): Move the actual fetching code to a standalone package akin
  // to tavern.

  Future _fetchPackages(Project project) {
    final chrome.Entry packagesDir =
        project.getChild(properties.packagesDirName).entry;
    final File specFile =
        project.getChild(properties.packageSpecFileName);

    return specFile.getContents().then((String spec) {
      final Map<String, dynamic> specMap = JSON.decode(spec);
      final Map<String, String> deps = specMap['dependencies'];

      final List<Future> futures = [];

      deps.forEach((packageName, packageSpec) {
        futures.add(_fetchPackage(packageName, packageSpec, packagesDir));
      });

      return Future.wait(futures);
    });
  }

  Future _fetchPackage(
      String packageName, String packageSpec,
      chrome.DirectoryEntry packagesDir) {
    final Match m = _PACKAGE_SPEC_REGEXP.matchAsPrefix(packageSpec);
    String path = m.group(1);

    final String branch = m.group(2);

    if (m == null) {
      return new Future.error("Malformed Bower dependency: '$packageSpec'");
    } else if (branch != 'master') {
      return new Future.error(
          "Unsupported branch in Bower dependency: '$packageSpec'."
          " Only 'master' is supported.");
    }

    return packagesDir.createDirectory(packageName).then((destDir) {
      return _scmProvider.clone('$_GITHUB_ROOT_URL/$path', destDir);
    });
  }

  void _handleLog(String line, String level) {
    // TODO: Dial the logging back.
     _logger.info(line);
  }
}

/**
 * A dummy class that currently doesn't resolve anything, since the definition
 * of a Bower package reference in JS code is yet unclear.
 */
class _BowerResolver extends PackageResolver {
  _BowerResolver._(Project project);

  PackageServiceProperties get properties => bowerProperties;

  File resolveRefToFile(String url) => null;

  String getReferenceFor(File file) => null;
}

/**
 * A [Builder] implementation which watches for changes to `bower.json` files
 * and updates the project Bower metadata.
 */
class _BowerBuilder extends PackageBuilder {
  _BowerBuilder();

  PackageServiceProperties get properties => bowerProperties;

  String getPackageNameFromSpec(String spec) {
    final Map<String, dynamic> specMap = JSON.decode(spec);
    return specMap == null ? null : specMap['name'];
  }
}

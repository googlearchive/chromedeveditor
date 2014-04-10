// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Bower services.
 */
library spark.package_mgmt.bower;

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:logging/logging.dart';

import 'package_manager.dart';
import '../scm.dart';
import '../workspace.dart';

Logger _logger = new Logger('spark.bower');

// TODO(ussuri): Add tests.

class BowerProps extends PackageManagerProps {
  static const _PACKAGE_SERVICE_NAME = 'bower';
  static const _PACKAGES_DIR_NAME = 'bower_packages';
  static const _PACKAGE_SPEC_FILE_NAME = 'bower.json';

  static bool isProjectWithPackages(Project project) =>
      PackageManagerProps.isProjectWithPackages(project, _PACKAGE_SPEC_FILE_NAME);

  static bool isPackageResource(Resource resource) =>
      PackageManagerProps.isPackageResource(resource, _PACKAGE_SPEC_FILE_NAME);

  static bool isInPackagesFolder(Resource resource) =>
      PackageManagerProps.isInPackagesFolder(resource, _PACKAGES_DIR_NAME);
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

  PackageBuilder getBuilder() => new _BowerBuilder();

  PackageResolver getResolverFor(Project project) =>
      new BowerResolver._(project);

  Future fetchPackages(Project project) {
    final File specFile = project.getChild(BowerProps._PACKAGE_SPEC_FILE_NAME);
    final Folder packagesDir = project.getChild(BowerProps._PACKAGES_DIR_NAME);

    return _fetchDependencies(specFile.entry, packagesDir.entry).whenComplete(() {
      return project.refresh();
    }).catchError((e, st) {
      _logger.severe('Error getting Bower packages', e, st);
      return new Future.error(e, st);
    });
  }

  // TODO(ussuri): Move the actual fetching code to a standalone package akin
  // to tavern.

  Future _fetchDependencies(
      chrome.ChromeFileEntry specFile, chrome.DirectoryEntry topDestDir) {
    return specFile.readText().then((String spec) {
      final Map<String, dynamic> specMap = JSON.decode(spec);
      final Map<String, String> deps = specMap['dependencies'];

      if (deps == null) return new Future.value();

      final List<Future> futures = [];

      deps.forEach((packageName, packageSpec) {
        futures.add(_fetchPackage(packageName, packageSpec, topDestDir));
      });

      return Future.wait(futures).whenComplete(() {
        final List<Future> subFutures = [];

        deps.forEach((String packageName, String packageSpec) {
          topDestDir.getFile('$packageName/$BowerProps.PACKAGE_SPEC_FILE_NAME')
              .then((chrome.FileEntry subSpecFile) {
            if (subSpecFile != null) {
              subFutures.add(_fetchDependencies(subSpecFile, topDestDir));
            }
          });
        });

        // TODO: This ignores the first-level results in [futures].
        return Future.wait(subFutures);
      });
    }).catchError((e, s) {
      // Ignore: fetch as many dependencies as we can, regardless of errors.
      return new Future.value();
    });
  }

  Future _fetchPackage(
      String name, String spec, chrome.DirectoryEntry rootDestDir) {
    final Match match = _PACKAGE_SPEC_REGEXP.matchAsPrefix(spec);

    if (match == null) {
      return new Future.error("Malformed Bower dependency: '$spec'");
    }

    String path = match.group(1);
    if (!path.endsWith('.git')) {
      path += '.git';
    }
    final String branch = match.group(2);

    if (branch != 'master') {
      return new Future.error(
          "Unsupported branch in Bower dependency: '$spec'."
          " Only 'master' is supported.");
    }

    return rootDestDir.createDirectory(name).then(
        (chrome.DirectoryEntry destDir) {
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
class BowerResolver extends PackageResolver {
  BowerResolver._(Project project);

  String get packageServiceName => BowerProps._PACKAGE_SERVICE_NAME;

  File resolveRefToFile(String url) => null;

  String getReferenceFor(File file) => null;
}

/**
 * A [Builder] implementation which watches for changes to `bower.json` files
 * and updates the project Bower metadata.
 */
class _BowerBuilder extends PackageBuilder {
  _BowerBuilder();

  String get packageSpecFileName => BowerProps._PACKAGE_SPEC_FILE_NAME;

  String get packageServiceName => BowerProps._PACKAGE_SERVICE_NAME;

  String getPackageNameFromSpec(String spec) {
    final Map<String, dynamic> specMap = JSON.decode(spec);
    return specMap == null ? null : specMap['name'];
  }
}

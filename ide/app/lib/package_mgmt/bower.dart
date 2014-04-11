// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Bower services.
 */

// TODO(ussuri): Add tests.

library spark.package_mgmt.bower;

import 'dart:async';
import 'dart:html' as html;
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
  BowerManager(Workspace workspace) : super(workspace);

  PackageServiceProperties get properties => bowerProperties;

  PackageBuilder getBuilder() => new _BowerBuilder();

  PackageResolver getResolverFor(Project project) =>
      new _BowerResolver._(project);

  Future installPackages(Project project) {
    final File specFile = project.getChild(properties.packageSpecFileName);
    // The client is expected to call us only when the project has bower.json.
    assert(specFile != null);

    return project.getOrCreateFolder(properties.packagesDirName, true)
        .then((Folder packagesDir) {
      final _BowerFetcher fetcher = new _BowerFetcher(packagesDir.entry);

      return fetcher.getDependencies(specFile.entry).whenComplete(() {
        return project.refresh();
      }).catchError((e, st) {
        _logger.severe('Error getting Bower packages', e, st);
        return new Future.error(e, st);
      });
    });
  }

  Future upgradePackages(Project project) {
    return new Future.error('Not implemented');
  }
}

class _BowerFetcher {
  static const _GITHUB_ROOT_URL = 'https://github.com';
  static const _GITHUB_USER_CONTENT_URL = 'https://raw.githubusercontent.com';
  /// E.g.: "Polymer/polymer-elements".
  static const _PACKAGE_SPEC_PATH = '''[-\\w./]+''';
  /// E.g.: "#master", "#1.2.3".
  static const _PACKAGE_SPEC_BRANCH = '''[-\\w.]+''';
  /// E.g.: "Polymer/polymer#master";
  static final RegExp _PACKAGE_SPEC_REGEXP =
      new RegExp('''^($_PACKAGE_SPEC_PATH)(?:#($_PACKAGE_SPEC_BRANCH))?\$''');

  static final ScmProvider _scmProvider = getProviderType('git');
  chrome.DirectoryEntry _packagesDir;

  _BowerFetcher(this._packagesDir);

  Future getDependencies(chrome.ChromeFileEntry specFile) {
    return specFile.readText().then((String spec) {
      final Map<String, dynamic> specMap = JSON.decode(spec);
      final Map<String, String> deps = specMap['dependencies'];

      if (deps == null) return new Future.value();

      final List<Future> futures = [];

      deps.forEach((packageName, packageSpec) {
        futures.add(_fetchPackage(packageName, packageSpec, _packagesDir));
      });

      return Future.wait(futures).whenComplete(() {
        final List<Future> subFutures = [];

        deps.forEach((String packageName, String packageSpec) {
          final String subSpecFname =
              '$packageName/${bowerProperties.packageSpecFileName}';
          _packagesDir.getFile(subSpecFname).then((chrome.FileEntry subSpecFile) {
            if (subSpecFile != null) {
              subFutures.add(getDependencies(subSpecFile));
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
      String packageName,
      String packageSpec,
      chrome.DirectoryEntry packagesDir) {
    final Match match = _PACKAGE_SPEC_REGEXP.matchAsPrefix(packageSpec);
    if (match == null) {
      return new Future.error("Malformed Bower dependency: '$packageSpec'");
    }
    final String path = match.group(1);
    // NOTE: This can be null, but _scmProvider.clone() can handle that.
    final String branch = match.group(2);

    return packagesDir.createDirectory(packageName).then((destDir) {
      final String url = '$_GITHUB_ROOT_URL/$path';
      return _scmProvider.clone(url, destDir, branchName: branch);
    });
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

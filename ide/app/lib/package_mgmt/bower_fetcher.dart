// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Bower package fetcher.
 */

// TODO(ussuri): Add comments.

library spark.package_mgmt.bower_fetcher;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html' as html;

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:logging/logging.dart';

import '../scm.dart';

Logger _logger = new Logger('spark.bower_fetcher');

class BowerFetcher {
  static final ScmProvider _git = getProviderType('git');

  final chrome.DirectoryEntry _packagesDir;
  final String _packageSpecFileName;

  Map<String, _Package> _allDeps = {};

  BowerFetcher(this._packagesDir, this._packageSpecFileName);

  Future fetchDependencies(chrome.ChromeFileEntry specFile) {
    return specFile.readText().then((spec) {
      return _gatherAllDeps(spec).then((_) {
        return _fetchAllDeps();
      });
    });
  }

  Future _gatherAllDeps(String spec) {
    List<_Package> deps = _parseDepsFromSpec(spec);

    List<Future> futures = [];

    deps.forEach((_Package package) {
      // TODO(ussuri): Handle conflicts: same names, different specs.
      if (!_allDeps.containsKey(package.name)) {
        _allDeps[package.name] = package;

        final Future f = _readRemoteSpecFile(package).then((String depSpec) {
          return _gatherAllDeps(depSpec);
        }).catchError((e) {
          // Remote spec file doesn't exist: this is a leaf package with no
          // dependencies.
          return new Future.value();
        });

        futures.add(f);
      }
    });

    return Future.wait(futures);
  }

  Future _fetchAllDeps() {
    List<Future> futures = [];
    _allDeps.values.forEach((_Package package) =>
        futures.add(_fetchPackage(package))
    );
    return Future.wait(futures);
  }

  List<_Package> _parseDepsFromSpec(String spec) {
    Map<String, String> rawDeps;
    try {
      final Map<String, dynamic> specMap = JSON.decode(spec);
      rawDeps = specMap['dependencies'];
    } on Exception catch(e) {
      _logger.warning('Error parsing package spec: $e\n$spec');
    }
    if (rawDeps == null) rawDeps = {};

    List<_Package> deps = [];
    rawDeps.forEach((String name, String fullPath) =>
      deps.add(new _Package(name, fullPath))
    );

    return deps;
  }

  Future<String> _readRemoteSpecFile(_Package package) {
    final String url = package.getUrlForDownloading(_packageSpecFileName);
    return html.HttpRequest.getString(url)
        .catchError((e, s) =>
            _logger.info('Error reading spec file for ${package.name}: $e'));
  }

  Future _fetchPackage(_Package package) {
    return _packagesDir.createDirectory(package.name, exclusive: true)
        .then((dir) {
      return _git.clone(package.getUrlForCloning(), dir, branchName: package.branch)
          .catchError((e, s) =>
              _logger.severe('Error cloning package ${package.name}: $e'));
    }).catchError((e, s) =>
      _logger.severe('Error creating directory for ${package.name}: $e')
    );
  }
}

class _Package {
  /// E.g.: "Polymer/polymer-elements".
  static const _PACKAGE_SPEC_PATH = '''[-\\w./]+''';
  /// E.g.: "#master", "#1.2.3".
  static const _PACKAGE_SPEC_BRANCH = '''[-\\w.]+''';
  /// E.g.: "Polymer/polymer#master";
  static final RegExp _PACKAGE_SPEC_REGEXP =
      new RegExp('''^($_PACKAGE_SPEC_PATH)(?:#($_PACKAGE_SPEC_BRANCH))?\$''');

  static const _GITHUB_ROOT_URL = 'https://github.com';
  static const _GITHUB_USER_CONTENT_URL = 'https://raw.githubusercontent.com';

  String name;
  String fullPath;
  String path;
  String branch;

  _Package(this.name, this.fullPath) {
    final Match match = _PACKAGE_SPEC_REGEXP.matchAsPrefix(fullPath);
    if (match == null) throw "Malformed Bower dependency: '$fullPath'";
    path = match.group(1);
    branch = match.group(2);
    if (branch == null) {
      branch = 'master';
    }
  }

  bool operator==(_Package another) =>
      path == another.path && branch == another.branch;

  String getUrlForCloning() =>
      '$_GITHUB_ROOT_URL/$path' + (path.endsWith('.git') ? '' : '.git');

  String getUrlForDownloading(String remoteFilePath) =>
      '$_GITHUB_USER_CONTENT_URL/$path/$branch/$remoteFilePath';
}

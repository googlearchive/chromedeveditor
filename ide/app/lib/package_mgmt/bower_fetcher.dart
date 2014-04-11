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
    return _gatherAllDeps(_readLocalSpecFile(specFile)).then((_) {
      return _fetchAllDeps();
    });
  }

  Future _gatherAllDeps(Future<String> getSpec) {
    return getSpec.then((String spec) {
      List<_Package> deps = _parseDepsFromSpec(spec);

      List<Future> futures = [];

      deps.forEach((_Package package) {
        // TODO(ussuri): Handle conflicts: same name, but different paths.
        if (!_allDeps.containsKey(package.name)) {
          _allDeps[package.name] = package;

          // Recurse into sub-dependencies.
          futures.add(_gatherAllDeps(_readRemoteSpecFile(package)));
        }
      });

      return Future.wait(futures);
    }).catchError((e, s) {
      // Ignore errors for now.
      _logger.warning(e, s);
//      return new Future.error(e);
    });
  }

  Future _fetchAllDeps() {
    List<Future> futures = [];
    _allDeps.values.forEach((_Package package) {
        futures.add(
            _fetchPackage(package).catchError((e, s) {
              _logger.warning(e);
            })
        );
    });
    return Future.wait(futures);
  }

  List<_Package> _parseDepsFromSpec(String spec) {
    Map<String, dynamic> specMap;
    try {
      specMap = JSON.decode(spec);
    } on FormatException catch(e, s) {
      _logger.warning("Bad package spec: $e\n$spec");
      return [];
    }

    final Map<String, String> rawDeps = specMap['dependencies'];
    if (rawDeps == null) return [];

    List<_Package> deps = [];
    rawDeps.forEach((String name, String fullPath) =>
      deps.add(new _Package(name, fullPath))
    );

    return deps;
  }

  Future<String> _readLocalSpecFile(chrome.ChromeFileEntry file) {
    return file.readText().catchError((e, s) {
      return new Future.error("Failed to read ${file.fullPath}: $e");
    });
  }

  Future<String> _readRemoteSpecFile(_Package package) {
    final completer = new Completer();

    final request = new html.HttpRequest();
    request.open('GET', package.getUrlForDownloading(_packageSpecFileName));
    request.onLoad.listen((event) {
      if (request.status == 200) {
        completer.complete(request.responseText);
      } else if (request.status == 404) {
        // Remote bower.json doesn't exist: it's just a leaf package with no
        // dependencies. Emulate that by returning an empty JSON.
        completer.complete('{}');
      } else {
        completer.completeError(
            "Failed to load $_packageSpecFileName for ${package.name}: "
            "$request.statusText");
      }
    });
    request.send();

    return completer.future;
  }

  Future _fetchPackage(_Package package) {
    return _packagesDir.createDirectory(package.name, exclusive: true).catchError((e, s) {
      return new Future.error(
          "Target directory for package ${package.name} not created: $e");
    }).then((dir) {
      return _git.clone(
          package.getUrlForCloning(), dir, branchName: package.branch)
            .catchError((e, s) {
                return new Future.error(
                    "Package ${package.name} not cloned: $e");
              });
    });
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

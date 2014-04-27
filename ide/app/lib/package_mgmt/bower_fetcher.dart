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

import '../enum.dart';
import '../scm.dart';

Logger _logger = new Logger('spark.bower_fetcher');

class FetchMode extends Enum<int> {
  const FetchMode._(int val) : super(val);

  String get enumName => 'FetchMode';

  static const INSTALL = const FetchMode._(1);
  static const UPGRADE = const FetchMode._(2);
}

class _PrepareDirRes {
  chrome.DirectoryEntry entry;
  bool existed;
  _PrepareDirRes(this.entry, this.existed);
}

class BowerFetcher {
  static final ScmProvider _git = getProviderType('git');

  final chrome.DirectoryEntry _packagesDir;
  final String _packageSpecFileName;

  Map<String, _Package> _allDeps = {};

  BowerFetcher(this._packagesDir, this._packageSpecFileName);

  Future fetchDependencies(chrome.ChromeFileEntry specFile, FetchMode mode) {
    return _gatherAllDeps(
        _readLocalSpecFile(specFile), specFile.fullPath
    ).catchError((e) {
      return e;
    }).then((_) {
      return _fetchAllDeps(mode);
    });
  }

  Future _gatherAllDeps(Future<String> specGetter, String specDesc) {
    return specGetter.then((String spec) {
      List<_Package> deps;
      try {
        deps = _parseDepsFromSpec(spec);
      } catch (e) {
        // TODO(ussuri): Perhaps differentiate between the user's own bower.json
        // (a hard error with a modal popup) and dependency bower.json's (a soft
        // error with just a progress bar notification).
        return new Future.error('Error parsing Bower spec file ($specDesc): $e');
      }

      List<Future> futures = [];

      deps.forEach((_Package package) {
        // TODO(ussuri): Handle conflicts: same name, but different paths.
        if (!_allDeps.containsKey(package.name)) {
          _allDeps[package.name] = package;

          // Recurse into sub-dependencies.
          futures.add(
              _gatherAllDeps(
                  _readRemoteSpecFile(package), 'for package ${package.path}'));
        }
      });

      return Future.wait(futures);
    });
  }

  Future _fetchAllDeps(FetchMode mode) {
    List<Future> futures = [];
    _allDeps.values.forEach((_Package package) {
      futures.add(
          _fetchPackage(package, mode).catchError((e) => _logger.warning(e)));
    });
    return Future.wait(futures);
  }

  List<_Package> _parseDepsFromSpec(String spec) {
    Map<String, dynamic> specMap;
    try {
      specMap = JSON.decode(spec);
    } on FormatException catch (e, s) {
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
    return file.readText().catchError((e) {
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

  Future _fetchPackage(_Package package, FetchMode mode) {
    return _preparePackageDir(package, mode).catchError((e) {
      // TODO(ussuri): Is this needed?
      return new Future.error(e);
    }).then((_PrepareDirRes res) {
      if (!res.existed && mode == FetchMode.INSTALL) {
        // _preparePackageDir created the directory.
        return _clonePackage(package, res.entry);
      } else if (!res.existed && mode == FetchMode.UPGRADE) {
        // _preparePackageDir created the directory.
        // TODO(ussuri): Verify that installing missing packages is what
        // 'bower update' really does (maybe it just updates existing ones).
        return _clonePackage(package, res.entry);
      } else if (res.existed && mode == FetchMode.INSTALL) {
        // Skip fetching (don't even try to analyze the directory's contents).
        return new Future.value();
      } else if (res.existed && mode == FetchMode.UPGRADE) {
        // TODO(ussuri): #1694 - when fixed, switch to using 'git pull'.
        return _clonePackage(package, res.entry);
      } else {
        throw new StateError('Unhandled case');
      }
    });
  }

  /**
   * Prepares a destination directory for a package about to be fetched:
   * - when installing packages, skips the directory if already exists;
   * - when upgrading packages, cleans the directory if already exists;
   * - when the directory doesn't yet exists, creates it in both modes;
   * - in all cases, returns the [DirectoryEntry] of the existing or created
   *   directory in the [entry] field of the returned value, and sets the
   *   [existed] field accordingly.
   */
  Future<_PrepareDirRes> _preparePackageDir(_Package package, FetchMode mode) {
    final completer = new Completer();

    _packagesDir.getDirectory(package.name).then((chrome.DirectoryEntry dir) {
      // TODO(ussuri): #1694 - when fixed, leave just the 'true' branch.
      if (mode == FetchMode.INSTALL) {
        completer.complete(new _PrepareDirRes(dir, true));
      } else {
        dir.removeRecursively().then((_) {
          _createPackageDir(package).then((chrome.DirectoryEntry dir2) {
            completer.complete(new _PrepareDirRes(dir2, true));
          });
        });
      }
    }, onError: (_) {
      _createPackageDir(package).then((chrome.DirectoryEntry dir) {
        completer.complete(new _PrepareDirRes(dir, false));
      });
    });

    return completer.future;
  }

  Future<chrome.DirectoryEntry> _createPackageDir(_Package package) {
    return _packagesDir.createDirectory(package.name, exclusive: true)
        .catchError((e) {
      return new Future.error(
        "Couldn't create directory for package '${package.name}': $e");
    });
  }

  Future _clonePackage(_Package package, chrome.DirectoryEntry dir) {
    final String url = package.getUrlForCloning();
    return _git.clone(url, dir, branchName: package.branch).catchError((e) {
      return new Future.error(
        "Package ${package.name} not cloned: $e");
    });
  }
}

class _Package {
  // TODO(ussuri): The below handles only short-hand package names that assume
  // GitHub as the root location. In actuality, Bower supports a lot more
  // formats, including paths to local git repos and explicit GitHub URLs.
  // Handle at least those two.

  /// E.g.: "Polymer/polymer-elements".
  static const _PACKAGE_SPEC_PATH = r'[-\w./]+';
  /// E.g.: "#master", "#1.2.3".
  static const _PACKAGE_SPEC_BRANCH = r'[-\w.]+';
  /// E.g.: "Polymer/polymer#master";
  static final RegExp _PACKAGE_SPEC_REGEXP =
      new RegExp('^($_PACKAGE_SPEC_PATH)(?:#($_PACKAGE_SPEC_BRANCH))?\$');

  static const _GITHUB_ROOT_URL = 'https://github.com';
  static const _GITHUB_USER_CONTENT_URL = 'https://raw.githubusercontent.com';

  String name;
  String fullPath;
  String path;
  String branch;

  _Package(this.name, this.fullPath) {
    final Match match = _PACKAGE_SPEC_REGEXP.matchAsPrefix(fullPath);
    if (match == null) {
      throw "Malformed Bower dependency: '$fullPath'";
    }
    path = match.group(1);
    branch = match.group(2);
    if (branch == null) {
      branch = 'master';
    }
  }

  bool operator==(_Package another) =>
      path == another.path && branch == another.branch;

  String getUrlForCloning() =>
      '$_GITHUB_ROOT_URL/$path';

  String getUrlForDownloading(String remoteFilePath) =>
      '$_GITHUB_USER_CONTENT_URL/$path/$branch/$remoteFilePath';
}

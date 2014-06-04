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
import '../../spark_flags.dart';

final Logger _logger = new Logger('spark.bower_fetcher');

class FetchMode extends Enum<String> {
  const FetchMode._(String val) : super(val);

  String get enumName => 'FetchMode';

  static const INSTALL = const FetchMode._('INSTALL');
  static const UPGRADE = const FetchMode._('UPGRADE');
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

  List<String> _alteredDepsComments = [];
  List<String> _unresolvedDepsComments = [];
  List<String> _ignoredDepsComments = [];

  BowerFetcher(this._packagesDir, this._packageSpecFileName);

  Future fetchDependencies(chrome.ChromeFileEntry specFile, FetchMode mode) {
    return _gatherAllDeps(
        _readLocalSpecFile(specFile), specFile.fullPath
    ).then((_) {
      return _fetchAllDeps(mode);
    }).then((deps) {
      _maybePrintResolutionComments();
      return deps;
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
        throw "Error parsing Bower spec file ($specDesc): $e";
      }

      List<Future> futures = [];

      deps.forEach((_Package package) {
        // TODO(ussuri): Handle conflicts: same name, but different paths.
        if (!_allDeps.containsKey(package.name)) {
          _allDeps[package.name] = package;

          // Recurse into sub-dependencies.
          futures.add(
              _gatherAllDeps(
                  _readRemoteSpecFile(package), 'for package "${package.path}"'));
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
    rawDeps.forEach((String name, String fullPath) {
      final _Package package = new _Package(name, fullPath);
      final String comment = package.resolutionComment;
      if (package.isUnresolved) {
        _unresolvedDepsComments.add(comment);
      } else if (package.isIgnored) {
        _ignoredDepsComments.add(comment);
      } else if (package.isResolved) {
        deps.add(package);
        if (comment.isNotEmpty) {
          _alteredDepsComments.add(comment);
        }
      }
    });
    return deps;
  }

  Future<String> _readLocalSpecFile(chrome.ChromeFileEntry file) {
    return file.readText().catchError((e) =>
        throw "Failed to read '${file.fullPath}': $e");
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
            "Failed to load $_packageSpecFileName for '${package.name}': "
            "${request.statusText}");
      }
    });
    request.send();

    return completer.future;
  }

  Future _fetchPackage(_Package package, FetchMode mode) {
    return _preparePackageDir(package, mode).then((_PrepareDirRes res) {
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
      throw "Couldn't create directory for package '${package.name}': $e";
    });
  }

  Future _clonePackage(_Package package, chrome.DirectoryEntry dir) {
    final String url = package.getUrlForCloning();
    return _git.clone(url, dir, branchName: package.branch).catchError((e) {
      throw "Package ${package.name} not cloned: $e";
    });
  }

  void _maybePrintResolutionComments() {
    if (_alteredDepsComments.isNotEmpty) {
      _logger.info(
'''
Some dependencies have been altered from the original spec:

  ${_alteredDepsComments.join('\n  ')}

'''
      );
    }

    if (_ignoredDepsComments.isNotEmpty) {
      _logger.info(
'''
Some dependencies have been ignored:

  ${_ignoredDepsComments.join('\n  ')}

'''
      );
    }

    if (_unresolvedDepsComments.isNotEmpty) {
      _logger.warning(
'''
Some dependencies could not be resolved and have been skipped. 
To fix, add or modify the following entry in .spark.json under your workspace 
directory: 

  "bower-mapped-dependencies": {
    ${_unresolvedDepsComments.join('\n    ')}
  }

Alternatively, you can have any dependency ignored by adding its name to 
the following list in .spark.json:

  "bower-ignored-dependencies": [
  ]

Finally, you can also map unsupported complex versions to latest stable 
by adding the following to .spark.json:

  "bower-map-complex-ver-to-latest-stable": true
'''
      );
    }
  }
}

abstract class _Resolution extends Enum<String> {
  const _Resolution._(String val) : super(val);
  String get comment => value;
}

class _Resolved extends _Resolution {
  const _Resolved._(String val) : super._(val);
  String get enumName => '_Resolved';

  static const USED_AS_IS = const _Resolved._('');
  static const STAR_PATH_MAPPED = const _Resolved._(
      '"*" path resolved using mappings from config files');
  static const NORMAL_PATH_OVERRIDDEN = const _Resolved._(
      'regular path overridden using mappings from config files');
  static const COMPLEX_VERSION_DEFAULTED = const _Resolved._(
      'unsupported complex version defaulted to latest stable');
}

class _Unresolved extends _Resolution {
  const _Unresolved._(String val) : super._(val);
  String get enumName => '_Unresolved';

  static const MALFORMED_SPEC = const _Unresolved._(
      'unrecognized dependency specification; replace with a supported one');
  static const STAR_PATH = const _Unresolved._(
      'replace "*" path with an explicit one');
  static const COMPLEX_VERSION = const _Unresolved._(
      'replace complex version with a simple one');
}

class _Ignored extends _Resolution {
  const _Ignored._(String val) : super._(val);
  String get enumName => '_Ignored';

  static const PER_CONFIG_DIRECTIVE = const _Ignored._(
      'ignored per directive in config file(s)');
}

class _Package {
  // TODO(ussuri): The below handles only short-hand package names that assume
  // GitHub as the root location. In actuality, Bower supports a lot more
  // formats, including paths to local git repos and explicit GitHub URLs.
  // Handle at least those two.

  /// E.g.: "Polymer", "Polymer/core-elements".
  static const _PACKAGE_PATH = r"[-\w./]+";
  /// Direct branch, e.g. "master", "1.2.3", "1.2.3-pre.4".
  static const _PACKAGE_BRANCH_SIMPLE = r"[-\w.]+";
  /// Direct branch or a branch range in semver format, a superset of the above,
  /// adds e.g. "'>=1.2.3 <2.0.0'", "^1.2.3", "1.2.*", "'1.2.3 - 1.3.5'", "~1.2.3".
  /// See http://semver.org.
  // TODO(ussuri): More precise regexp; some preliminary input from semver.org:
  // r'(\d+)\.(\d+)\.(\d+)(?:-([\dA-Za-z-]+(?:\.[\dA-Za-z-]+)*))?(?:\+[\dA-Za-z-]+)?';
  static const _PACKAGE_BRANCH_FULL = r"'?[-\w.^=><~* ]+'?";
  /// Accept the full branch spec in the input, e.g.: "Polymer/polymer#master",
  /// "Polymer/polymer#^1.2.3", "Polymer/polymer#'>=1.2.3 <1.4.5'".
  /// The actually supported branch specs are determined by the code below.
  static const _PACKAGE_SPEC = "^($_PACKAGE_PATH)(?:#($_PACKAGE_BRANCH_FULL))?\$";

  static final _PACKAGE_BRANCH_SIMPLE_REGEXP = new RegExp(_PACKAGE_BRANCH_SIMPLE);
  static final _PACKAGE_SPEC_REGEXP = new RegExp(_PACKAGE_SPEC);

  static const _GITHUB_ROOT_URL = 'https://github.com';
  static const _GITHUB_USER_CONTENT_URL = 'https://raw.githubusercontent.com';

  String name;
  String fullPath;
  String path;
  String branch;

  _Resolution resolution;

  bool get isResolved => resolution is _Resolved;
  bool get isUnresolved => resolution is _Unresolved;
  bool get isIgnored => resolution is _Ignored;

  _Package(this.name, this.fullPath) {
    if (SparkFlags.bowerIgnoredDeps != null &&
        SparkFlags.bowerIgnoredDeps.contains(name)) {
      resolution = _Ignored.PER_CONFIG_DIRECTIVE;
      return;
    }

    if (fullPath == '*') {
      // Handle "*" in the dependency path (== "retrieve from Bower registry").
      // TODO(ussuri): At a minumum, implement extracting package info from Bower.
      if (SparkFlags.bowerOverriddenDeps == null) {
        resolution = _Unresolved.STAR_PATH;
        return;
      }
      final String mappedPath = SparkFlags.bowerOverriddenDeps[name];
      if (mappedPath == null) {
        resolution = _Unresolved.STAR_PATH;
        return;
      }
      resolution = _Resolved.STAR_PATH_MAPPED;
      fullPath = mappedPath;
    } else {
      // If the path is not "*", still look if the dependency is overridden.
      if (SparkFlags.bowerOverriddenDeps != null) {
        final String mappedPath = SparkFlags.bowerOverriddenDeps[name];
        if (mappedPath != null) {
          fullPath = mappedPath;
          resolution = _Resolved.NORMAL_PATH_OVERRIDDEN;
        }
      }
    }

    // Extract path and branch/version from fullPath.
    final Match match = _PACKAGE_SPEC_REGEXP.matchAsPrefix(fullPath);
    if (match == null) {
      resolution = _Unresolved.MALFORMED_SPEC;
      return;
    }

    path = match.group(1);
    branch = match.group(2);

    // Resolve the branch.
    if (branch == null) {
      // Default to the latest stable.
      branch = null;
    } else {
      if (_PACKAGE_BRANCH_SIMPLE_REGEXP.matchAsPrefix(branch) == null) {
        // This is an extended semver version or version range.
        if (SparkFlags.bowerMapComplexVerToLatestStable) {
          resolution = _Resolved.COMPLEX_VERSION_DEFAULTED;
          branch = null;
        } else {
          // TODO(ussuri): Add full support for semver versions and ranges.
          resolution = _Unresolved.COMPLEX_VERSION;
          return;
        }
      }
    }

    if (resolution == null) {
      resolution = _Resolved.USED_AS_IS;
    }
  }

  bool operator==(_Package another) =>
      path == another.path && branch == another.branch;

  String getUrlForCloning() =>
      '$_GITHUB_ROOT_URL/$path';

  String getUrlForDownloading(String remoteFilePath) =>
      '$_GITHUB_USER_CONTENT_URL/$path/$branch/$remoteFilePath';

  String get spec => '"$name": "$fullPath"';

  String get resolutionComment {
    return resolution == _Resolved.USED_AS_IS ?
        '' : '$spec, <== ${resolution.comment}';
  }
}

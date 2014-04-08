// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Bower services.
 */
library spark.bower;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html';


import 'package:chrome/chrome_app.dart' as chrome;
import 'package:logging/logging.dart';

import '../scm.dart';
import '../workspace.dart' as ws;

const PACKAGES_DIR_NAME = 'bower_packages';
const PACKAGE_SPEC_FILE_NAME = 'bower.json';

bool isInPackagesFolder(ws.Resource resource) {
  String path = resource.path;
  return path.contains('/$PACKAGES_DIR_NAME/') ||
         path.endsWith('/$PACKAGES_DIR_NAME');
}

Logger _logger = new Logger('spark.bower');

class BowerManager {
  static const GITHUB_ROOT_URL = 'https://github.com';

  /// E.g.: "Polymer/polymer-elements".
  static const PKG_SPEC_PATH = '''[-\\w./]+''';
  /// E.g.: "#master", "#1.2.3" (however branches in general are not yet
  /// supported, only "#master" is accepted - see below).
  static const PKG_SPEC_BRANCH = '''[-\\w.]+''';
  /// E.g.: "Polymer/polymer#master";
  static final RegExp PKG_SPEC_REGEXP =
      new RegExp('''^($PKG_SPEC_PATH)(?:#($PKG_SPEC_BRANCH))?\$''');

  ScmProvider _scmProvider;

  BowerManager() :
    _scmProvider = getProviderType('git');

  static bool isBowerProject(ws.Project project) =>
      project.getChild(PACKAGE_SPEC_FILE_NAME) != null;

  static bool isBowerResource(ws.Resource resource) {
    return (resource is ws.File && resource.name == PACKAGE_SPEC_FILE_NAME) ||
           (resource is ws.Project && isBowerProject(resource));
  }

  Future runBowerInstall(ws.Project project) {
    final ws.File specFile = project.getChild(PACKAGE_SPEC_FILE_NAME);
    final ws.Folder packagesDir = project.getChild(PACKAGES_DIR_NAME);

    return _fetchDependencies(specFile.entry, packagesDir.entry).whenComplete(() {
      return project.refresh();
    }).catchError((e, st) {
      _logger.severe('Error getting Bower packages', e, st);
      return new Future.error(e, st);
    });
  }

  void _handleLog(String line, String level) {
    // TODO: Dial the logging back.
     _logger.info(line);
  }

  Future _fetchDependencies(chrome.ChromeFileEntry specFile,
                                  chrome.DirectoryEntry topDestDir) {
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
          topDestDir.getFile('$packageName/$PACKAGE_SPEC_FILE_NAME').then(
              (chrome.FileEntry subSpecFile) {
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
    });
  }

  Future _fetchPackage(String name,
                       String spec,
                       chrome.DirectoryEntry topDestDir) {
    final Match match = PKG_SPEC_REGEXP.matchAsPrefix(spec);

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

    return topDestDir.createDirectory(name).then(
        (chrome.DirectoryEntry destDir) {
      return _scmProvider.clone('$GITHUB_ROOT_URL/$path', destDir);
    });
  }
}

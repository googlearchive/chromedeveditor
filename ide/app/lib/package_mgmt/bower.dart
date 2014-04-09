// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Bower services.
 */
library spark.bower;

import 'dart:async';
import 'dart:convert' show JSON;


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
    return _fetchPackages(project).whenComplete(() {
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

  Future _fetchPackages(ws.Project project) {
    final chrome.Entry packagesDir = project.getChild(PACKAGES_DIR_NAME).entry;
    final ws.File specFile = project.getChild(PACKAGE_SPEC_FILE_NAME);

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

  Future _fetchPackage(String packageName,
                     String packageSpec,
                     chrome.DirectoryEntry packagesDir) {
    final Match m = PKG_SPEC_REGEXP.matchAsPrefix(packageSpec);
    String path = m.group(1);
    if (!path.endsWith('.git')) {
      path += '.git';
    }
    final String branch = m.group(2);

    if (m == null) {
      return new Future.error("Malformed Bower dependency: '$packageSpec'");
    } else if (branch != 'master') {
      return new Future.error(
          "Unsupported branch in Bower dependency: '$packageSpec'."
          " Only 'master' is supported.");
    }

    return packagesDir.createDirectory(packageName).then((destDir) {
      return _scmProvider.clone('$GITHUB_ROOT_URL/$path', destDir);
    });
  }
}

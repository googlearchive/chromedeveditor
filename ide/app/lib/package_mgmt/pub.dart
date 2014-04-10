// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Pub services.
 */
library spark.package_mgmt.pub;

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tavern/tavern.dart' as tavern;
import 'package:yaml/yaml.dart' as yaml;

import 'package_manager.dart';
import '../workspace.dart';

Logger _logger = new Logger('spark.pub');

class PubProps extends PackageManagerProps {
  static const _PACKAGE_SERVICE_NAME = 'pub';
  static const _PACKAGES_DIR_NAME = 'packages';
  static const _PACKAGE_SPEC_FILE_NAME = 'pubspec.yaml';
  static const _LIB_DIR_NAME = 'lib';
  static const _PACKAGE_REF_PREFIX = 'package:';
  // Matching prefixes:
  // package:foo/bar
  // package:/foo/bar
  // /packages/foo/bar
  static final _PACKAGE_REF_PREFIX_REGEXP = new RegExp(
      '^($_PACKAGE_REF_PREFIX|/${_PACKAGES_DIR_NAME}/)(.*)');

  String get packageSpecFileName => _PACKAGE_SPEC_FILE_NAME;
  String get packagesDirName => _PACKAGES_DIR_NAME;
  RegExp get packageRefPrefixRegexp => _PACKAGE_REF_PREFIX_REGEXP;
}

class PubManager extends PackageManager {
  static final _props = new PubProps();

  PubManager(Workspace workspace) : super(workspace);

  PackageManagerProps get props => _props;

  PackageBuilder getBuilder() => new _PubBuilder();

  PackageResolver getResolverFor(Project project) => new _PubResolver._(project);

  Future fetchPackages(Project project) {
    return tavern.getDependencies(project.entry, _handleLog).whenComplete(() {
      return project.refresh();
    }).catchError((e, st) {
      _logger.severe('Error Running Pub Get', e, st);
      return new Future.error(e, st);
    });
  }

  void _handleLog(String line, String level) {
    // TODO: Dial the logging back.
     _logger.info(line);
  }
}

/**
 * A class to help resolve pub `package:` references.
 */
class _PubResolver extends PackageResolver {
  static final _props = new PubProps();

  final Project project;

  _PubResolver._(this.project);

  String get packageServiceName => PubProps._PACKAGE_SERVICE_NAME;

  /**
   * Resolve a `package:` reference to a file in this project. This will
   * correctly handle self-references, and resolve them to the `lib/` directory.
   * Other references will resolve to the `packages/` directory. If a reference
   * does not resolve to an existing file, this method will return `null`.
   */
  File resolveRefToFile(String url) {
    Match match = _props.packageRefPrefixRegexp.matchAsPrefix(url);
    if (match == null) return null;

    String ref = match.group(2);
    String selfRefName = getSelfReference(project);
    Folder packageDir = project.getChild(PubProps._PACKAGES_DIR_NAME);

    if (selfRefName != null && ref.startsWith(selfRefName + '/')) {
      // `foo/bar.dart` becomes `bar.dart` in the lib/ directory.
      ref = ref.substring(selfRefName.length + 1);
      packageDir = project.getChild(PubProps._LIB_DIR_NAME);
    }

    if (packageDir == null) return null;

    Resource resource = packageDir.getChildPath(ref);
    return resource is File ? resource : null;
  }

  /**
   * Given a [File], return the best pub `package:` reference for it. This will
   * correctly return package self-references for files in the `lib/` folder. If
   * there is no valid `package:` reference to the file, then this methods will
   * return `null`.
   */
  String getReferenceFor(File file) {
    if (file.project != project) return null;

    List resources = [];
    resources.add(file);

    Container parent = file.parent;
    while (parent is! Project) {
      resources.insert(0, parent);
      parent = parent.parent;
    }

    if (resources[0].name == PubProps._PACKAGES_DIR_NAME) {
      resources.removeAt(0);
      return PubProps._PACKAGE_REF_PREFIX +
             resources.map((r) => r.name).join('/');
    } else if (resources[0].name == PubProps._LIB_DIR_NAME) {
      String selfRefName = getSelfReference(project);

      if (selfRefName != null) {
        resources.removeAt(0);
        return 'package:${selfRefName}/' +
               resources.map((r) => r.name).join('/');
      } else {
        return null;
      }
    } else {
      return null;
    }
  }
}

/**
 * A [Builder] implementation which watches for changes to `pubspec.yaml` files
 * and updates the project pub metadata. Specifically, it parses and stores
 * information about the project's self-reference name, for later use in
 * resolving `package:` references.
 */
class _PubBuilder extends PackageBuilder {
  _PubBuilder();

  String get packageSpecFileName => PubProps._PACKAGE_SPEC_FILE_NAME;

  String get packageServiceName => PubProps._PACKAGE_SERVICE_NAME;

  String getPackageNameFromSpec(String spec) {
    final doc = yaml.loadYaml(spec);
    return doc == null ? null : doc['name'];
  }
}

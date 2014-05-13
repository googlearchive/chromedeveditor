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
import 'pub_properties.dart';
import '../jobs.dart';
import '../workspace.dart';

Logger _logger = new Logger('spark.pub');

class PubManager extends PackageManager {
  PubManager(Workspace workspace) : super(workspace);

  //
  // PackageManager abstract interface:
  //

  PackageServiceProperties get properties => pubProperties;

  PackageBuilder getBuilder() => new _PubBuilder();

  PackageResolver getResolverFor(Project project) => new _PubResolver._(project);

  Future installPackages(Container container) =>
      _installUpgradePackages(container, 'get', false);

  Future upgradePackages(Container container) =>
      _installUpgradePackages(container, 'upgrade', true);

  //
  // - end PackageManager abstract interface.
  //

  Future _installUpgradePackages(
      Container container, String commandName, bool isUpgrade) {
    return tavern.getDependencies(container.entry, _handleLog, isUpgrade).
        whenComplete(() {
      return container.project.refresh();
    }).catchError((e, st) {
      _logger.severe('Error running pub $commandName', e, st);
      return new Future.error(e, st);
    });
  }

  void _handleLog(String line, String level) {
    _logger.info(line.trim());
  }
}

/**
 * A class to help resolve pub `package:` references.
 */
class _PubResolver extends PackageResolver {
  final Project project;

  _PubResolver._(this.project);

  //
  // PackageResolver virtual interface:
  //

  PackageServiceProperties get properties => pubProperties;

  /**
   * Resolve a `package:` reference to a file in this project. This will
   * correctly handle self-references, and resolve them to the `lib/` directory.
   * Other references will resolve to the `packages/` directory. If a reference
   * does not resolve to an existing file, this method will return `null`.
   */
  File resolveRefToFile(String url) {
    Match match = properties.packageRefPrefixRegexp.matchAsPrefix(url);
    if (match == null) return null;

    String ref = match.group(2);
    String selfRefName = properties.getSelfReference(project);
    Folder packageDir = project.getChild(properties.packagesDirName);

    if (selfRefName != null && ref.startsWith(selfRefName + '/')) {
      // `foo/bar.dart` becomes `bar.dart` in the lib/ directory.
      ref = ref.substring(selfRefName.length + 1);
      packageDir = project.getChild(properties.libDirName);
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

    if (resources[0].name == properties.packagesDirName) {
      resources.removeAt(0);
      return properties.packageRefPrefix + resources.map((r) => r.name).join('/');
    } else if (resources[0].name == properties.libDirName) {
      String selfRefName = properties.getSelfReference(project);

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

  //
  // PackageBuilder virtual interface:
  //

  PackageServiceProperties get properties => pubProperties;

  Future build(ResourceChangeEvent event, ProgressMonitor monitor) {
    Project project = event.changes.first.resource.project;

    // If we're building a top-level file, return.
    if (project == null) return new Future.value();

    File pubspecFile = project.getChild(properties.packageSpecFileName);

    if (pubspecFile is! File) {
      if (properties.getSelfReference(project) != null) {
        properties.setSelfReference(project, null);
      }
    } else {
      bool analyzePubspec = false;

      for (ChangeDelta delta in event.changes) {
        Resource r = delta.resource;

        if (r == pubspecFile) {
          if (delta.isDelete) {
            analyzePubspec = false;
            break;
          } else {
            analyzePubspec = true;
          }
        } else if (properties.isInPackagesFolder(r)) {
          analyzePubspec = true;
        }
      }

      if (analyzePubspec) {
        return _analyzePubspec(pubspecFile);
      }
    }

    return new Future.value();
  }

  //
  // - PackageBuilder virtual interface.
  //

  Future _analyzePubspec(File file) {
    file.clearMarkers(_packageServiceName);

    return file.getContents().then((String str) {
      try {
        _PubSpecInfo info = new _PubSpecInfo.parse(str);
        properties.setSelfReference(file.project, info.name);
        for (String dep in info.getDependencies()) {
          Resource dependency =
              file.project.getChildPath('${_packagesDirName}/${dep}');
          if (dependency is! Folder) {
            // TODO(devoncarew): We should place these markers on the correct line.
            file.createMarker(_packageServiceName,
                Marker.SEVERITY_WARNING,
                "'${dep}' does not exist in the packages directory. "
                "Do you need to run 'pub get'?",
                1);
          }
        }
      } on Exception catch (e) {
        file.createMarker(
            _packageServiceName, Marker.SEVERITY_ERROR, '${e}', 1);
      }
    });
  }

  String get _packagesDirName => properties.packagesDirName;
  String get _packageServiceName => properties.packageServiceName;
}

class _PubSpecInfo {
  Map _map;

  /**
   * This method can throw exceptions on parse errors.
   */
  _PubSpecInfo.parse(String str) {
    _map = yaml.loadYaml(str);
  }

  String get name => _map['name'];

  List<String> getDependencies() => _getDeps('dependencies');

  List<String> getDevDependencies() => _getDeps('dev_dependencies');

  List<String> _getDeps(String name) {
    var deps = _map[name];
    if (deps is Map) {
      return _map.containsKey(name) ? _map[name].keys.toList() : [];
    } else {
      return [];
    }
  }
}

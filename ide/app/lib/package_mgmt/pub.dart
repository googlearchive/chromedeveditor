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
import 'package:yaml/src/parser.dart' show SyntaxError;

import 'package_manager.dart';
import '../builder.dart';
import '../jobs.dart';
import '../workspace.dart';

Logger _logger = new Logger('spark.pub');

class PubManager extends PackageManager {
  static const PACKAGES_DIR_NAME = 'packages';
  static const PACKAGE_SPEC_FILE_NAME = 'pubspec.yaml';
  static const PACKAGE_REF_PREFIX = 'package:';

  static const _LIB_DIR_NAME = 'lib';

  PubManager(Workspace workspace) {
    workspace.builderManager.builders.add(new _PubBuilder());
  }

  static bool isProjectWithPackages(Project project) =>
      project.getChild(PACKAGE_SPEC_FILE_NAME) != null;

  static bool isPackageResource(Resource resource) {
    return (resource is File && resource.name == PACKAGE_SPEC_FILE_NAME) ||
           (resource is Project && isProjectWithPackages(resource));
  }

  static bool isPackageRef(String url) => url.startsWith(PACKAGE_REF_PREFIX);

  static bool isInPackagesFolder(Resource resource) {
    while (resource.parent != null) {
      if (resource.parent is Project) {
        return resource.name == PACKAGES_DIR_NAME && resource is Folder;
      }
      resource = resource.parent;
    }

    return false;
  }

  Future fetchPackages(Project project) {
    return tavern.getDependencies(project.entry, _handleLog).whenComplete(() {
      return project.refresh();
    }).catchError((e, st) {
      _logger.severe('Error Running Pub Get', e, st);
      return new Future.error(e, st);
    });
  }

  PubResolver getResolverFor(Project project) {
    return new PubResolver._(project);
  }

  void _handleLog(String line, String level) {
    // TODO: Dial the logging back.
     _logger.info(line);
  }
}

/**
 * A class to help resolve pub `package:` references.
 */
class PubResolver {
  final Project project;

  PubResolver._(this.project);

  /**
   * Resolve a `package:` reference to a file in this project. This will
   * correctly handle self-references, and resolve them to the `lib/` directory.
   * Other references will resolve to the `packages/` directory. If a reference
   * does not resolve to an existing file, this method will return `null`.
   */
  File resolveRefToFile(String url) {
    if (!PubManager.isPackageRef(url)) return null;

    String ref = url.substring(PubManager.PACKAGE_REF_PREFIX.length);
    String selfRefName = _getSelfReference(project);

    Folder packageDir = project.getChild(PubManager.PACKAGES_DIR_NAME);

    if (selfRefName != null && ref.startsWith(selfRefName + '/')) {
      // `foo/bar.dart` becomes `bar.dart` in the lib/ directory.
      ref = ref.substring(selfRefName.length + 1);
      packageDir = project.getChild(PubManager._LIB_DIR_NAME);
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

    if (resources[0].name == PubManager.PACKAGES_DIR_NAME) {
      resources.removeAt(0);
      return PubManager.PACKAGE_REF_PREFIX + resources.map((r) => r.name).join('/');
    } else if (resources[0].name == PubManager._LIB_DIR_NAME) {
      String selfRefName = _getSelfReference(project);

      if (selfRefName != null) {
        resources.removeAt(0);
        return 'package:${selfRefName}/' + resources.map((r) => r.name).join('/');
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
class _PubBuilder extends Builder {
  _PubBuilder();

  Future build(ResourceChangeEvent event, ProgressMonitor monitor) {
    List futures = [];

    for (ChangeDelta delta in event.changes) {
      Resource r = delta.resource;

      if (!r.isDerived()) {
        if (r.name == PubManager.PACKAGE_SPEC_FILE_NAME && r.parent is Project) {
          futures.add(_handlePackageSpecChange(delta));
        }
      }
    }

    return Future.wait(futures);
  }

  Future _handlePackageSpecChange(ChangeDelta delta) {
    File file = delta.resource;

    if (delta.isDelete) {
      _setSelfReference(file.project, null);
      return new Future.value();
    } else {
      return file.getContents().then((String str) {
        file.clearMarkers('pub');

        try {
          var doc = yaml.loadYaml(str);
          String packageName = doc == null ? null : doc['name'];
          _setSelfReference(file.project, packageName);
        } on SyntaxError catch (e) {
          // Use some better method for determining where to place the marker.
          file.createMarker('pub', Marker.SEVERITY_ERROR, '${e}', 1);
        }
      });
    }
  }
}

void _setSelfReference(Project project, String selfReference) {
  project.setMetadata('pubSelfReference', selfReference);
}

String _getSelfReference(Project project) {
  return project.getMetadata('pubSelfReference');
}

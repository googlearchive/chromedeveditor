// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.package_mgmt;

import 'dart:async';

import '../builder.dart';
import '../jobs.dart';
import '../workspace.dart';

// TODO(ussuri): Add comments.

abstract class PackageServiceProperties {
  bool isProjectWithPackages(Project project) =>
      project.getChild(packageSpecFileName) != null;

  bool isPackageResource(Resource resource) {
    return (resource is File && resource.name == packageSpecFileName) ||
           (resource is Project && isProjectWithPackages(resource));
  }

  bool isInPackagesFolder(Resource resource) {
    while (resource.parent != null) {
      if (resource.parent is Project) {
        return resource.name == packagesDirName && resource is Folder;
      }
      resource = resource.parent;
    }
    return false;
  }

  bool isPackageRef(String url) =>
      packageRefPrefixRegexp.matchAsPrefix(url) != null;

  bool isSecondaryPackage(Resource resource) {
    return resource.path.contains('/$packagesDirName/') &&
           !isInPackagesFolder(resource);
  }

  /**
   * Pure virtual interface.
   */

  String get packageServiceName;
  String get packageSpecFileName;
  String get packagesDirName;
  String get libDirName;
  String get packageRefPrefix;
  RegExp get packageRefPrefixRegexp;

  void setSelfReference(Project project, String selfReference);

  String getSelfReference(Project project);
}

abstract class PackageManager {
  PackageManager(Workspace workspace) {
    workspace.builderManager.builders.add(getBuilder());
  }

  /**
   * Pure virtual interface.
   */
  PackageServiceProperties get properties;

  PackageBuilder getBuilder();
  PackageResolver getResolverFor(Project project);

  Future installPackages(Project project);
  Future upgradePackages(Project project);
}

abstract class PackageResolver {
  /**
   * Pure virtual interface.
   */
  PackageServiceProperties get properties;
  File resolveRefToFile(String url);
  String getReferenceFor(File file);
}

abstract class PackageBuilder extends Builder {
  Future build(ResourceChangeEvent event, ProgressMonitor monitor) {
    List futures = [];

    for (ChangeDelta delta in event.changes) {
      Resource r = delta.resource;

      if (!r.isDerived()) {
        if (r.name == properties.packageSpecFileName && r.parent is Project) {
          futures.add(_handlePackageSpecChange(delta));
        }
      }
    }

    return Future.wait(futures);
  }

  Future _handlePackageSpecChange(ChangeDelta delta) {
    File file = delta.resource;

    if (delta.isDelete) {
      properties.setSelfReference(file.project, null);
      return new Future.value();
    } else {
      return file.getContents().then((String spec) {
        file.clearMarkers(properties.packageServiceName);

        try {
          properties.setSelfReference(
              file.project, getPackageNameFromSpec(spec));
        } on Exception catch (e) {
          // TODO: Use some better method for determining where to place the marker.
          file.createMarker(
              properties.packageServiceName, Marker.SEVERITY_ERROR, '${e}', 1);
        }
      });
    }
  }

  /**
   * Pure virtual interface.
   */
  PackageServiceProperties get properties;

  String getPackageNameFromSpec(String spec);
}

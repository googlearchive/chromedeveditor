// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.package_mgmt;

import 'dart:async';

import '../builder.dart';
import '../jobs.dart';
import '../workspace.dart';

abstract class PackageManagerProps {
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
  String get packageSpecFileName;
  String get packagesDirName;
  RegExp packageRefPrefixRegexp;
}

abstract class PackageManager {
  PackageManager(Workspace workspace) {
    workspace.builderManager.builders.add(getBuilder());
  }

  /**
   * Pure virtual interface.
   */
  PackageManagerProps get props;
  PackageBuilder getBuilder();
  PackageResolver getResolverFor(Project project);
  Future fetchPackages(Project project);
}

abstract class PackageResolver {
  String getSelfReference(Project project) =>
      project.getMetadata('${packageServiceName}SelfReference');

  /**
   * Pure virtual interface.
   */
  String get packageServiceName;
  File resolveRefToFile(String url);
  String getReferenceFor(File file);
}

abstract class PackageBuilder extends Builder {
  Future build(ResourceChangeEvent event, ProgressMonitor monitor) {
    List futures = [];

    for (ChangeDelta delta in event.changes) {
      Resource r = delta.resource;

      if (!r.isDerived()) {
        if (r.name == packageSpecFileName && r.parent is Project) {
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
      return file.getContents().then((String spec) {
        file.clearMarkers(packageServiceName);

        try {
          _setSelfReference(file.project, getPackageNameFromSpec(spec));
        } on Exception catch (e) {
          // Use some better method for determining where to place the marker.
          file.createMarker(packageServiceName, Marker.SEVERITY_ERROR, '${e}', 1);
        }
      });
    }
  }

  void _setSelfReference(Project project, String selfReference) =>
      project.setMetadata('${packageServiceName}SelfReference', selfReference);

  /**
   * Pure virtual interface.
   */
  String get packageSpecFileName;
  String get packageServiceName;
  String getPackageNameFromSpec(String spec);
}

// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.package_mgmt;

import 'dart:async';

import '../builder.dart';
import '../jobs.dart';
import '../workspace.dart';

abstract class PackageManagerProps {
  static bool isProjectWithPackages(Project project, String specFileName) =>
      project.getChild(specFileName) != null;

  static bool isPackageResource(Resource resource, String specFileName) {
    return
        (resource is File && resource.name == specFileName) ||
        (resource is Project && isProjectWithPackages(resource, specFileName));
  }

  static bool isInPackagesFolder(Resource resource, String packagesDirName) {
    while (resource.parent != null) {
      if (resource.parent is Project) {
        return resource.name == packagesDirName && resource is Folder;
      }
      resource = resource.parent;
    }
    return false;
  }
}

abstract class PackageManager {
  PackageManager(Workspace workspace) {
    workspace.builderManager.builders.add(getBuilder());
  }

  /**
   * Pure virtual interface.
   */
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

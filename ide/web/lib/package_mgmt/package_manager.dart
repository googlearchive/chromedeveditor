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
  bool isFolderWithPackages(Folder container) =>
      container.getChild(packageSpecFileName) != null;

  // TODO(ussuri): Instead of the below 2 methods, an easier-to-understand
  // approach cpuld be a single `File getAssociatedPackageSpecFile(Resource)`.
  bool isPackageResource(Resource resource) {
    return (resource is File && resource.name == packageSpecFileName) ||
           (resource is Folder && isFolderWithPackages(resource)) ||
           isPackagesFolder(resource);
  }

  /**
   * If [isPackageResource] returns true for [resource], this function will
   * return the matching folder with packages.
   */
  Folder getMatchingFolderWithPackages(Resource resource) {
    if (resource is File && resource.name == packageSpecFileName) {
      return resource.parent;
    } else if (resource is Folder && isFolderWithPackages(resource)) {
      return resource;
    } else if (isPackagesFolder(resource)) {
      return resource.parent;
    }
    return null;
  }

  bool isPackagesFolder(Resource resource) {
    return resource is Folder &&
           resource.name == getPackagesDirName(resource) &&
           isFolderWithPackages(resource.parent);
  }

  bool isInPackagesFolder(Resource resource) {
    while (resource.parent != null) {
      if (resource is Folder &&
          resource.name == getPackagesDirName(resource)) {
        return true;
      }
      resource = resource.parent;
    }
    return false;
  }

  bool isPackageRef(String url) =>
      packageRefPrefixRegexp.matchAsPrefix(url) != null;

  bool isSecondaryPackage(Resource resource) {
    return resource.path.contains('/' + getPackagesDirName(resource) + '/') &&
           !isInPackagesFolder(resource);
  }

  //
  // Pure virtual interface.
  //

  String get packageServiceName;
  String get configFileName;
  String get packageSpecFileName;
  String getPackagesDirName(Resource resource);
  String get libDirName;
  String get packageRefPrefix;
  RegExp get packageRefPrefixRegexp;

  void setSelfReference(Project project, String selfReference);

  String getSelfReference(Project project);
}

abstract class PackageManager {
  PackageManager(Workspace workspace) {
    workspace.builderManager.builders.add(getBuilderFor(workspace));
  }

  //
  // Pure virtual interface.
  //

  PackageServiceProperties get properties;

  PackageBuilder getBuilderFor(Workspace workspace);
  PackageResolver getResolverFor(Project project);

  Future installPackages(Folder container, ProgressMonitor monitor);
  Future upgradePackages(Folder container, ProgressMonitor monitor);

  /**
   * Return `true` or `null` if all packages are installed. Otherwise, return a
   * `String` with the name of an uninstalled package.
   */
  Future<dynamic> arePackagesInstalled(Folder container);
}

abstract class PackageResolver {
  //
  // Pure virtual interface.
  //

  PackageServiceProperties get properties;

  File resolveRefToFile(String url);
  String getReferenceFor(File file);
}

abstract class PackageBuilder extends Builder {
  //
  // Pure virtual interface.
  //

  PackageServiceProperties get properties;

  Future build(ResourceChangeEvent event, ProgressMonitor monitor);
}

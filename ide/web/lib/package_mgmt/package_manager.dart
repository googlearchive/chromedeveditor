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
  bool isFolderWithPackages(Folder project) =>
      project.getChild(packageSpecFileName) != null;

  bool isPackageResource(Resource resource) {
    return (resource is File && resource.name == packageSpecFileName) ||
           (resource is Folder && isFolderWithPackages(resource)) ||
           _isPackagesFolder(resource) ||
           _isPackagesFolder(resource.parent);
  }

  bool _isPackagesFolder(Resource resource) {
    return resource is Folder &&
           resource.name == packagesDirName &&
           isFolderWithPackages(resource.parent);
  }

  bool isInPackagesFolder(Resource resource) {
    while (resource.parent != null) {
      if (resource.name == packagesDirName && resource is Folder) {
        return true;
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

  //
  // Pure virtual interface.
  //

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

  //
  // Pure virtual interface.
  //

  PackageServiceProperties get properties;

  PackageBuilder getBuilder();
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

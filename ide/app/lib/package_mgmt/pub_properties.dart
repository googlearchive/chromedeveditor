// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.package_mgmt.pub_properties;

import 'package_manager.dart';
import '../workspace.dart';

// TODO(ussuri): Make package-private once no longer used outside.
final PubProperties pubProperties = new PubProperties();

class PubProperties extends PackageServiceProperties {
//
// PackageServiceProperties virtual interface:
//

String get packageServiceName => 'pub';
String get packageSpecFileName => 'pubspec.yaml';
String get packagesDirName => 'packages';
String get libDirName => 'lib';
String get packageRefPrefix => 'package:';
// This will get both the "package:foo/bar.dart" variant when used directly
// in Dart and the "baz/packages/foo/bar.dart" variant when served over HTTP.
RegExp get packageRefPrefixRegexp =>
   new RegExp(r'^(package:|.*/packages/)(.*)$');

void setSelfReference(Project project, String selfReference) =>
   project.setMetadata('${packageServiceName}SelfReference', selfReference);

String getSelfReference(Project project) =>
   project.getMetadata('${packageServiceName}SelfReference');
}

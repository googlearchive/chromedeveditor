// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.package_mgmt.bower_properties;

import 'package_manager.dart';
import '../workspace.dart';

// TODO(ussuri): Make package-private once no longer used outside.
final BowerProperties bowerProperties = new BowerProperties();

class BowerProperties extends PackageServiceProperties {
  //
  // PackageServiceProperties virtual interface:
  //

  String get packageServiceName => 'bower';
  String get packageSpecFileName => 'bower.json';
  // TODO(ussuri): Package name can be overridden in .bowerrc: handle that.
  String get packagesDirName => 'bower_components';

  // Bower doesn't use any of the below nullified properties/methods.

  String get libDirName => null;
  String get packageRefPrefix => null;
  RegExp get packageRefPrefixRegexp => null;

  void setSelfReference(Project project, String selfReference) {}
  String getSelfReference(Project project) => null;
}

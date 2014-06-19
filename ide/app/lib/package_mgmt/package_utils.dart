// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.package_utils;

import 'bower_properties.dart';
import 'pub_properties.dart';
import '../workspace.dart';

/**
 * Returns whether the given resource is a packages folder (`packages`,
 * `bower_components`), or is contained in a packages folder.
 */
bool isInPackagesFolder(Resource resource) {
  return pubProperties.isInPackagesFolder(resource) ||
      bowerProperties.isInPackagesFolder(resource);
}

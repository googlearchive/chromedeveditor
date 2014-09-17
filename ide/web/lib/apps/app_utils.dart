// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.app_utils;

import '../workspace.dart';

/**
 * Given a [Resource], return the [Container] containing the `manifest.json`
 * file for a Chrome app. Returns `null` if no Chrome app can be found.
 */
Container getAppContainerFor(Resource resource) {
  if (resource == null || resource.project == null) return null;

  // Look in the current container(s).
  Container container = resource is Container ? resource : resource.parent;

  while (container != null && container is! Workspace) {
    if (_hasManifest(container)) {
      return container;
    }
    container = container.parent;
  }

  // Look in the project root.
  if (_hasManifest(resource.project)) {
    return resource.project;
  }

  // Check potential subdirectories in the order of probability.
  for (String subdir in ['web', 'www', 'app']) {
    container = resource.project.getChild(subdir);
    if (container is Container && _hasManifest(container)) {
      return container;
    }
  }

  return null;
}

bool _hasManifest(Container container) {
  return container.getChild('manifest.json') is File;
}

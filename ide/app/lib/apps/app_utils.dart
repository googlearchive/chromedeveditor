// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.app_utils;

import '../workspace.dart';

/**
 * Given a [Resource], return the [Container] containing the `manifest.mf` file
 * for the Chrome app. Returns `null` if no Chrome app can be found.
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

  // Look in app/
  if (resource.project.getChild('app') is Container) {
    Container app = resource.project.getChild('app');
    if (_hasManifest(app)) return app;
  }

  return null;
}

bool _hasManifest(Container container) {
  return container.getChild('manifest.json') is File;
}

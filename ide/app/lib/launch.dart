// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Launch services
 */

library spark.launch;

import 'workspace.dart';

/**
 *  Manages all the launches and calls the appropriate delegate
 */
class LaunchManager {

  List<LaunchDelegate> _delegates = [ new DartWebAppLaunchDelegate(),
                                      new ChromeAppLaunchDelegate()
                                     ];

  LaunchManager();

  /**
   * Indicates whether a particular [Resource] can be run.
   */
  bool canRun(Resource resource) => _delegates.any((delegate) => delegate.canRun(resource));

  /**
   * Launches the given [Resouce].
   */
  void run(Resource resource) {
    _delegates.firstWhere((delegate) => delegate.canRun(resource)).run(resource);
  }

}

/**
 * Provides convenience methods for launching. Clients can customize the launch
 * delegate.
 */
abstract class LaunchDelegate {

  bool canRun(Resource resource);

  void run(Resource resource);
}

/**
 * Launcher for running Dart web apps
 */
class DartWebAppLaunchDelegate extends LaunchDelegate {

  DartWebAppLaunchDelegate();

  // for now launching only web/index.html
  bool canRun(Resource resource) {
    return resource.project != null && resource.project.getChildPath('web/index.html') is File;
  }

  void run(Resource resource) {
    //TODO: implement this
    print('TODO: run project ${resource.project}');
  }

}

/**
 * Launcher for Chrome Apps
 */
class ChromeAppLaunchDelegate extends LaunchDelegate {

  bool canRun(Resource resource) {
    return resource.project != null &&
        ( resource.project.getChildPath('manifest.json') is File
          || resource.project.getChildPath('app/manifest.json') is File);
  }

  void run(Resource resource) {
    //TODO: implement this
    print('TODO: run project ${resource.project}');
  }
}



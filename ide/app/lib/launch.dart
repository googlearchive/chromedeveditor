// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Launch services
 */

library spark.launch;

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data' as typed_data;

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:logging/logging.dart';

import 'server.dart';
import 'workspace.dart';


const int SERVER_PORT = 4040;

final Logger _logger = new Logger('spark.launch');

/**
 *  Manages all the launches and calls the appropriate delegate
 */
class LaunchManager {

  List<LaunchDelegate> _delegates = [];

  PicoServer _server;
  /**
   * The last project that was launched
   */
  Project _currentProject;
  Project get currentProject => _currentProject;

  Workspace _workspace;
  Workspace get workspace => _workspace;

  LaunchManager(this._workspace) {

    _delegates.add(new DartWebAppLaunchDelegate(this));
    _delegates.add(new ChromeAppLaunchDelegate());

    PicoServer.createServer(SERVER_PORT).then((server) {
      _server = server;
      _server.addServlet(new ProjectRedirectServlet(this));
      _server.addServlet(new StaticResourcesServlet());
      _server.addServlet(new WorkspaceServlet(this));
    });
  }

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

  void dispose() {
    _server.dispose();
  }

}

/**
 * Provides convenience methods for launching. Clients can customize the launch
 * delegate.
 */
abstract class LaunchDelegate {

  /**
   * The delegate can launch the given resource
   */
  bool canRun(Resource resource);

  void run(Resource resource);
}

/**
 * Launcher for running Dart web apps
 */
class DartWebAppLaunchDelegate extends LaunchDelegate {

  LaunchManager _launchManager;

  DartWebAppLaunchDelegate(this._launchManager);

  // for now launching only web/index.html
  bool canRun(Resource resource) {
    return resource.project != null && resource.project.getChildPath('web/index.html') is File;
  }

  void run(Resource resource) {
    _launchManager._currentProject = resource.project;
    // use htm extension for launch page, otherwise polymer build tries to pick it up.
    chrome.app.window.create('launch_page.htm',
        new chrome.CreateWindowOptions(id: 'runWindow', width: 600, height: 800))
      .then((_) {},
          onError: (e) => _logger.log(Level.INFO, 'Error launching Dart web app', e));
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

/**
 * A servlet that can serve files from any of the [Project]s in the [Workspace]
 */
class WorkspaceServlet extends PicoServlet {

  LaunchManager _launchManager;

  WorkspaceServlet(this._launchManager);

  bool canServe(HttpRequest request) {
    if (request.uri.pathSegments.length <= 1) return false;
    var projectNamesList = _launchManager.workspace.getProjects()
                              .map((project) => project.name).toList();
    return projectNamesList.contains(request.uri.pathSegments[0]);
  }

  Future<HttpResponse> serve(HttpRequest request) {
    HttpResponse response = new HttpResponse.ok();
    String path = request.uri.path;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    Resource resource = _launchManager.workspace.getChildPath(path);

    return (resource as File).getContents().then((String string) {
      response.setContent(string);
      response.setContentTypeFrom(resource.name);
      return new Future.value(response);
    });
  }
}

/**
 * Serves up resources like favicon.ico
 */
class StaticResourcesServlet extends PicoServlet {
  bool canServe(HttpRequest request) {
    return request.uri.path == '/favicon.ico';
  }

  Future<HttpResponse> serve(HttpRequest request) {
    HttpResponse response = new HttpResponse.ok();
    return _getContentsBinary('images/favicon.ico').then((List<int> bytes) {
      response.setContentStream(
          new Stream.fromIterable(bytes));
      response.setContentTypeFrom('favicon.ico');
      return new Future.value(response);
    });
  }
}

/**
 * Servlet that redirects to the landing page for the project that was run.
 */
class ProjectRedirectServlet extends PicoServlet {

  String HTML_REDIRECT =
      '<meta http-equiv="refresh" content="0; url=http://127.0.0.1:$SERVER_PORT/';

  LaunchManager _launchManager;

  ProjectRedirectServlet(this._launchManager);

  bool canServe(HttpRequest request) {
    return request.uri.path == '/';
  }

  Future<HttpResponse> serve(HttpRequest request) {
    HttpResponse response = new HttpResponse.ok();
    // TODO: for now landing page is hardcoded to project/web/index.html
    String string ='$HTML_REDIRECT${_launchManager.currentProject.name}/web/index.html">';
    response.setContent(string);
    response.setContentTypeFrom('redirect.html');
    return new Future.value(response);
  }
}


/**
 * Return the contents of the file at the given path. The path is relative to
 * the Chrome app's directory.
 */
//TODO: move to utils
Future<List<int>> _getContentsBinary(String path) {
  String url = chrome.runtime.getURL(path);

  return html.HttpRequest.request(url, responseType: 'arraybuffer').then((request) {
    typed_data.ByteBuffer buffer = request.response;
    return new typed_data.Uint8List.view(buffer);
  });
}


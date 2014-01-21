// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Launch services.
 */
library spark.launch;

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data' as typed_data;

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import 'compiler.dart';
import 'server.dart';
import 'workspace.dart';

const int SERVER_PORT = 4040;

final Logger _logger = new Logger('spark.launch');

final NumberFormat _NF = new NumberFormat.decimalPattern();

/**
 * Manages all the launches and calls the appropriate delegate.
 */
class LaunchManager {

  List<LaunchDelegate> _delegates = [];

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
    _delegates.forEach((delegate) => delegate.dispose());
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

  void dispose();
}

/**
 * Launcher for running Dart web apps.
 */
class DartWebAppLaunchDelegate extends LaunchDelegate {

  PicoServer _server;
  LaunchManager _launchManager;
  Dart2JsServlet _dart2jsServlet;

  DartWebAppLaunchDelegate(this._launchManager) {
    _dart2jsServlet = new Dart2JsServlet(_launchManager);

    PicoServer.createServer(SERVER_PORT).then((server) {
      _server = server;
      _server.addServlet(new ProjectRedirectServlet(_launchManager));
      _server.addServlet(new StaticResourcesServlet());
      _server.addServlet(_dart2jsServlet);
      _server.addServlet(new WorkspaceServlet(_launchManager));
    });
  }

  // For now launching only web/index.html.
  bool canRun(Resource resource) {
    return resource.project != null && resource.project.getChildPath('web/index.html') is File;
  }

  void run(Resource resource) {
    _launchManager._currentProject = resource.project;
    // Use htm extension for launch page, otherwise polymer build tries to pick it up.
    var options = new chrome.CreateWindowOptions(
        id: 'runWindow',
        width: 800, height: 540,
        minWidth: 800, minHeight: 540);
    chrome.app.window.create('launch_page.htm', options).catchError((e) {
      _logger.log(Level.INFO, 'Error launching Dart web app', e);
    });
  }

  void dispose() {
    _server.dispose();
    _dart2jsServlet.dispose();
  }
}

/**
 * Launcher for Chrome Apps.
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

  void dispose() {

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
    var projectNamesList =
        _launchManager.workspace.getProjects().map((project) => project.name);
    return projectNamesList.contains(request.uri.pathSegments[0]);
  }

  Future<HttpResponse> serve(HttpRequest request) {
    HttpResponse response = new HttpResponse.ok();

    String path = request.uri.path;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    Resource resource = _launchManager.workspace.getChildPath(path);
    if (resource != null) {
      // TODO: Verify that the resource is a File.
      return (resource as File).getBytes().then((chrome.ArrayBuffer buffer) {
        response.setContentBytes(buffer.getBytes());
        response.setContentTypeFrom(resource.name);
        return new Future.value(response);
      }, onError: (_) => new Future.value(new HttpResponse.notFound()));
    } else {
      new Future.value(new HttpResponse.notFound());
    }
  }
}

/**
 * Serves up resources like `favicon.ico`.
 */
class StaticResourcesServlet extends PicoServlet {
  bool canServe(HttpRequest request) {
    return request.uri.path == '/favicon.ico';
  }

  Future<HttpResponse> serve(HttpRequest request) {
    HttpResponse response = new HttpResponse.ok();
    return _getContentsBinary('images/favicon.ico').then((List<int> bytes) {
      response.setContentStream(new Stream.fromIterable([bytes]));
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
    // TODO: For now the landing page is hardcoded to project/web/index.html.
    String url = 'http://127.0.0.1:$SERVER_PORT/${_projectName}/web/index.html';

    // Issue a 302 redirect.
    HttpResponse response = new HttpResponse(statusCode: HttpStatus.FOUND);
    response.headers.set(HttpHeaders.LOCATION, url);
    response.headers.set(HttpHeaders.CONTENT_LENGTH, 0);

    return new Future.value(response);
  }

  String get _projectName => _launchManager.currentProject.name;
}

// 3 successive launches; dart2js warms up quite a bit.
// [INFO] spark.launch: compiled /solar/web/solar.dart in 6,446 ms
// [INFO] spark.launch: compiled /solar/web/solar.dart in 2,928 ms
// [INFO] spark.launch: compiled /solar/web/solar.dart in 2,051 ms

/**
 * Servlet that compiles and serves up the JavaScript for Dart sources.
 */
class Dart2JsServlet extends PicoServlet {
  LaunchManager _launchManager;
  Compiler _compiler;

  Dart2JsServlet(this._launchManager){
    Compiler.createCompiler().then((c) {
      _compiler = c;
    });
  }

  bool canServe(HttpRequest request) {
    String path = request.uri.path;
    return (path.endsWith('.dart.js') && _getResource(path) != null);
  }

  Resource _getResource(String path) {
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    // check if there is a corresponding dart file
    var dartFileName = path.substring(0, path.length - 3);
    return _launchManager.workspace.getChildPath(dartFileName);
  }

  Future<HttpResponse> serve(HttpRequest request) {
    HttpResponse response = new HttpResponse.ok();

    Resource resource = _getResource(request.uri.path);

    Stopwatch stopwatch = new Stopwatch();
    stopwatch.start();

    return (resource as File).getContents().then((String string) {
      // TODO: compiler should also accept files
      return _compiler.compileString(string).then((CompilerResult result) {
        _logger.info('compiled ${resource.path} in '
            '${_NF.format(stopwatch.elapsedMilliseconds)} ms');
        response.setContent(result.output);
        response.setContentTypeFrom(request.uri.path);
        return new Future.value(response);
      });
    });
  }

  void dispose() {
    _compiler.dispose();
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

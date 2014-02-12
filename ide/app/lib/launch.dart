// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Launch services.
 */
library spark.launch;

import 'dart:async';
import 'dart:js' as js;

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import 'compiler.dart';
import 'utils.dart';
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

  Workspace _workspace;
  Workspace get workspace => _workspace;

  LaunchManager(this._workspace) {
    // The order of regristration here matters.
    _delegates.add(new ChromeAppLaunchDelegate());
    _delegates.add(new DartWebAppLaunchDelegate(this));
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
  ProjectRedirectServlet _redirectServlet;

  DartWebAppLaunchDelegate(this._launchManager) {
    _dart2jsServlet = new Dart2JsServlet(_launchManager);
    _redirectServlet = new ProjectRedirectServlet(_launchManager);

    PicoServer.createServer(SERVER_PORT).then((server) {
      _server = server;
      _server.addServlet(_redirectServlet);
      _server.addServlet(new StaticResourcesServlet());
      _server.addServlet(_dart2jsServlet);
      _server.addServlet(new WorkspaceServlet(_launchManager));
    }).catchError((error) {
      // TODO: We could fallback to binding to any port.
      _logger.severe('Error starting up embedded server', error);
    });
  }

  // For now launching only web/index.html.
  bool canRun(Resource resource) {
    return getLaunchResourceFor(resource) != null;
  }

  Resource getLaunchResourceFor(Resource resource) {
    if (resource.project == null) return null;

    // We can always launch .htm and .html files.
    if (resource is File) {
      if (resource.name.endsWith('.html') || resource.name.endsWith('.htm')) {
        return resource;
      }
    }

    // Check to see if there is a launchable file in the current folder.
    Container parent;
    if (resource is Container) {
      parent = resource;
    } else {
      parent = resource.parent;
    }

    if (getLaunchResourceIn(parent) != null) {
      return getLaunchResourceIn(parent);
    }

    // Check for a launchable file in web/.
    if (resource.project.getChild('web') is Container) {
      return getLaunchResourceIn(resource.project.getChild('web'));
    }

    return null;
  }

  Resource getLaunchResourceIn(Container container) {
    if (container.getChild('index.html') is File) {
      return container.getChild('index.html');
    }

    for (Resource resource in container.getChildren()) {
      if (resource is File) {
        if (resource.name.endsWith('.html') || resource.name.endsWith('.htm')) {
          return resource;
        }
      }
    }

    return null;
  }

  void run(Resource resource) {
    _redirectServlet._launchFile = getLaunchResourceFor(resource);

    // Use `.htm` extension for launch page, otherwise the polymer build tries
    // to pick it up.
    var options = new chrome.CreateWindowOptions(
        id: 'runWindow',
        width: 800, height: 570,
        minWidth: 800, minHeight: 570);
    chrome.app.window.create('launch_page/launch_page.htm', options).catchError((e) {
      _logger.log(Level.INFO, 'Error launching Dart web app', e);
    });
  }

  void dispose() {
    if (_server != null) {
      _server.dispose();
    }
    _dart2jsServlet.dispose();
  }
}

/**
 * Launcher for Chrome Apps.
 */
class ChromeAppLaunchDelegate extends LaunchDelegate {
  bool canRun(Resource resource) {
    return getLaunchResourceFor(resource) != null;
  }

  void run(Resource resource) {
    Container launchContainer = getLaunchResourceFor(resource);

    if (!isDart2js()) {
      _logger.warning("Can't launch on Dartium currently...");
      return;
    }

    _loadApp(launchContainer).then((_) {
      _getAppId(launchContainer.project.name).then((String id) {
        _launchApp(id);
      });
    });
  }

  Resource getLaunchResourceFor(Resource resource) {
    if (resource.project == null) return null;

    // Look in the current container(s).
    Container container = resource.parent;
    if (resource is Container) {
      container = resource;
    }

    while (container != null && container is! Workspace) {
      if (hasManifest(container)) {
        return container;
      }
      container = container.parent;
    }

    // Look in the project root.
    if (hasManifest(resource.project)) {
      return resource.project;
    }

    // Look in app/.
    if (resource.project.getChild('app') is Container) {
      Container app = resource.project.getChild('app');
      if (hasManifest(app)) return app;
    }

    return null;
  }

  bool hasManifest(Container container) {
    return container.getChild('manifest.json') is File;
  }

  Future<String> _loadApp(Container container) {
    Completer completer = new Completer();
    callback(String id) {
      completer.complete(id);
    }

    js.JsObject obj = js.context['chrome']['developerPrivate'];
    obj.callMethod('loadDirectory', [(container.entry as
        chrome.ChromeObject).jsProxy, callback]);
    return completer.future;
  }

  void _launchApp(String id) {
    js.JsObject obj = js.context['chrome']['management'];
    obj.callMethod('launchApp', [id]);
  }

  /**
   * TODO(grv): This is a temporary function until loadDirectory returns the
   * app_id.
   */
  Future<String> _getAppId(String name) {
    Completer completer = new Completer();
    callback(List result) {
      for (int i = 0; i < result.length; ++i) {
        if (result[i]['is_unpacked'] && (result[i]['path'] as String).endsWith(
            name)) {
          completer.complete(result[i]['id']);
          return;
        }
      };
      completer.complete(null);
    }
    js.JsObject obj = js.context['chrome']['developerPrivate'];
    obj.callMethod('getItemsInfo', [false, false, callback]);
    return completer.future;
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
      return new Future.value(new HttpResponse.notFound());
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
    return getAppContentsBinary('images/favicon.ico').then((List<int> bytes) {
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
  Resource _launchFile;

  ProjectRedirectServlet(this._launchManager);

  bool canServe(HttpRequest request) {
    return request.uri.path == '/';
  }

  Future<HttpResponse> serve(HttpRequest request) {
    String url = 'http://127.0.0.1:$SERVER_PORT${launchPath}';

    // Issue a 302 redirect.
    HttpResponse response = new HttpResponse(statusCode: HttpStatus.FOUND);
    response.headers.set(HttpHeaders.LOCATION, url);
    response.headers.set(HttpHeaders.CONTENT_LENGTH, 0);

    return new Future.value(response);
  }

  String get launchPath => _launchFile.path;
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

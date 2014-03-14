// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Launch services.
 */
library spark.launch;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:chrome/gen/management.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import 'apps/app_utils.dart';
import 'services/compiler.dart';
import 'developer_private.dart';
import 'jobs.dart';
import 'pub.dart';
import 'server.dart';
import 'services.dart';
import 'utils.dart';
import 'workspace.dart';

const int SERVER_PORT = 4040;

final Logger _logger = new Logger('spark.launch');

final NumberFormat _nf = new NumberFormat.decimalPattern();

/**
 * Manages all the launches and calls the appropriate delegate.
 */
class LaunchManager {
  List<LaunchDelegate> _delegates = [];
  Services _services;
  PubManager _pubManager;
  CompilerService _compiler;

  Workspace _workspace;
  Workspace get workspace => _workspace;

  LaunchManager(this._workspace, this._services, this._pubManager) {
    _compiler = _services.getService("compiler");

    // The order of registration here matters.
    _delegates.add(new ChromeAppLaunchDelegate(this));
    _delegates.add(new DartWebAppLaunchDelegate(this));
  }

  /**
   * Indicates whether a particular [Resource] can be run.
   */
  bool canRun(Resource resource) => _delegates.any((delegate) => delegate.canRun(resource));

  /**
   * Launches the given [Resouce].
   */
  Future run(Resource resource) {
    for (LaunchDelegate delegate in _delegates) {
      if (delegate.canRun(resource)) {
        return delegate.run(resource);
      }
    }

    return new Future.value();
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
  final LaunchManager launchManager;

  LaunchDelegate(this.launchManager);

  /**
   * The delegate can launch the given resource
   */
  bool canRun(Resource resource);

  Future run(Resource resource);

  void dispose();
}

/**
 * Launcher for running Dart web apps.
 */
class DartWebAppLaunchDelegate extends LaunchDelegate {
  PicoServer _server;
  Dart2JsServlet _dart2jsServlet;
  ProjectRedirectServlet _redirectServlet;

  DartWebAppLaunchDelegate(LaunchManager launchManager) : super(launchManager) {
    _dart2jsServlet = new Dart2JsServlet(launchManager);
    _redirectServlet = new ProjectRedirectServlet(launchManager);

    PicoServer.createServer(SERVER_PORT).then((server) {
      _server = server;
      _server.addServlet(_redirectServlet);
      _server.addServlet(new StaticResourcesServlet());
      _server.addServlet(_dart2jsServlet);
      _server.addServlet(new PackagesServlet(launchManager));
      _server.addServlet(new WorkspaceServlet(launchManager));
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

  Future run(Resource resource) {
    _redirectServlet._launchFile = getLaunchResourceFor(resource);

    // Use `.htm` extension for launch page, otherwise the polymer build tries
    // to pick it up.
    var options = new chrome.CreateWindowOptions(
        id: 'runWindow',
        width: 800, height: 570,
        minWidth: 800, minHeight: 570);

    return chrome.app.window.create('launch_page/launch_page.htm', options);
  }

  void dispose() {
    if (_server != null) {
      _server.dispose();
    }
  }
}

/**
 * Launcher for Chrome Apps.
 */
class ChromeAppLaunchDelegate extends LaunchDelegate {
  ChromeAppLaunchDelegate(LaunchManager launchManager) : super(launchManager);

  bool canRun(Resource resource) {
    return getAppContainerFor(resource) != null;
  }

  Future run(Resource resource) {
    Container launchContainer = getAppContainerFor(resource);

    if (!isDart2js()) {
      return new Future.error("Can't launch on Dartium currently...");
    } else {
      return developerPrivate.loadDirectory(launchContainer.entry).then((String appId) {
        // TODO: Use the returned appId once it has the correct results.
        return _getAppId(launchContainer.name).then((String id) {
          if (id == null) {
            throw 'Unable to locate an application id.';
          } else if (!management.available) {
            throw 'The chrome.management API is not available.';
          } else {
            return management.launchApp(id);
          }
        });
      });
    }
  }

  /**
   * TODO(grv): This is a temporary function until loadDirectory returns the
   * app_id.
   */
  Future<String> _getAppId(String name) {
    return developerPrivate.getItemsInfo(false, false).then((List<ItemInfo> items) {
      for (ItemInfo item in items) {
        if (item.is_unpacked && item.path.endsWith(name)) {
          return item.id;
        }
      };
      return null;
    });
  }

  void dispose() { }
}

/**
 * A servlet that can serve `package:` urls (`/packages/`).
 */
class PackagesServlet extends PicoServlet {
  static const PACKAGE_SEGMENT = '/packages/';

  LaunchManager _launchManager;

  PackagesServlet(this._launchManager);

  bool canServe(HttpRequest request) {
    String path = request.uri.path;
    return path.contains(PACKAGE_SEGMENT);
  }

  Future<HttpResponse> serve(HttpRequest request) {
    String projectName = request.uri.pathSegments[0];
    Container project = _launchManager.workspace.getChild(projectName);

    if (project is Project) {
      String path = request.uri.path;
      path = PACKAGE_REF_PREFIX +
          path.substring(path.indexOf(PACKAGE_SEGMENT) + PACKAGE_SEGMENT.length);
      PubResolver resolver = _launchManager._pubManager.getResolverFor(project);
      File file = resolver.resolveRefToFile(path);
      if (file != null) {
        return _serveFileResponse(file);
      }
    }

    return new Future.value(new HttpResponse.notFound());
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
    String path = request.uri.path;

    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    Resource resource = _launchManager.workspace.getChildPath(path);

    if (resource is File) {
      return _serveFileResponse(resource);
    }

    if (resource is Container) {
      if (resource.getChild('index.html') != null) {
        // Issue a 302 redirect.
        HttpResponse response = new HttpResponse(statusCode: HttpStatus.FOUND);
        response.headers.set(HttpHeaders.LOCATION, request.uri.resolve('index.html'));
        response.headers.set(HttpHeaders.CONTENT_LENGTH, 0);
        return new Future.value(response);
      }
    }

    return new Future.value(new HttpResponse.notFound());
  }
}

Future<HttpResponse> _serveFileResponse(File file) {
  return file.getBytes().then((chrome.ArrayBuffer buffer) {
    HttpResponse response = new HttpResponse.ok();
    response.setContentBytes(buffer.getBytes());
    response.setContentTypeFrom(file.name);
    return new Future.value(response);
  }, onError: (_) {
    return new Future.value(new HttpResponse.notFound());
  });
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
  CompilerService _compiler;

  Dart2JsServlet(this._launchManager){
    _compiler = _launchManager._compiler;
  }

  bool canServe(HttpRequest request) {
    String path = request.uri.path;
    return path.endsWith('.dart.js') && _getResource(path) is File;
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
    File file = _getResource(request.uri.path);
    Stopwatch stopwatch = new Stopwatch()..start();
    Completer completer = new Completer();

    file.workspace.builderManager.jobManager.schedule(
        new ProgressJob('Compiling ${file.name}…', completer));

    return _compiler.compileFile(file).then((CompilerResult result) {
      if (!result.hasOutput) {
        // TODO: Log this to something like a console window.
        _logger.warning('Error compiling ${file.path} with dart2js.');
        for (CompilerProblem problem in result.problems) {
          _logger.warning('${problem}');
        }
        return new HttpResponse(statusCode: HttpStatus.INTERNAL_SERVER_ERROR);
      } else {
        _logger.info('compiled ${file.path} in '
            '${_nf.format(stopwatch.elapsedMilliseconds)} ms, '
            '${result.output.length ~/ 1024} kb');
        HttpResponse response = new HttpResponse.ok();
        response.setContent(result.output);
        response.setContentTypeFrom(request.uri.path);
        return response;
      }
    }).whenComplete(() => completer.complete());
  }
}

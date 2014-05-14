// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Launch services.
 */
library spark.launch;

import 'dart:async';
import 'dart:html' show window;

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:chrome/gen/management.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import 'apps/app_utils.dart';
import 'services/compiler.dart';
import 'developer_private.dart';
import 'jobs.dart';
import 'package_mgmt/package_manager.dart';
import 'server.dart';
import 'services.dart';
import 'utils.dart';
import 'workspace.dart';

final Logger _logger = new Logger('spark.launch');

final NumberFormat _nf = new NumberFormat.decimalPattern();

/**
 * Manages all the launches and calls the appropriate delegate.
 */
class LaunchManager {
  List<LaunchDelegate> _delegates = [];
  Services _services;
  PackageManager _packageManager;
  CompilerService _compiler;

  Workspace _workspace;
  Workspace get workspace => _workspace;

  LaunchManager(this._workspace, this._services, this._packageManager) {
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

  DartWebAppLaunchDelegate(LaunchManager launchManager) : super(launchManager) {
    PicoServer.createServer().then((server) {
      _server = server;
      _server.addServlet(new StaticResourcesServlet());
      _server.addServlet(new Dart2JsServlet(launchManager));
      _server.addServlet(new PackagesServlet(launchManager));
      _server.addServlet(new WorkspaceServlet(launchManager));

      _logger.info('embedded web server listening on port ${_server.port}');
    }).catchError((error) {
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
    window.open(_getUrlFor(getLaunchResourceFor(resource)), '_blank');
    return new Future.value();
  }

  void dispose() {
    if (_server != null) {
      _server.dispose();
    }
  }

  String _getUrlFor(Resource resource) {
    return 'http://127.0.0.1:${_server.port}${resource.path}';
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

    return developerPrivate.loadDirectory(launchContainer.entry).then((String appId) {
      // TODO: Use the returned appId once it has the correct results.

      // TODO: Delay a bit - there's a race condition.
      return new Future.delayed(new Duration(milliseconds: 100));
    }).then((_) {
      return _getAppId(launchContainer.name);
    }).then((String id) {
      if (id == null) {
        throw 'Unable to locate an application id.';
      } else if (!management.available) {
        throw 'The chrome.management API is not available.';
      } else {
        return management.launchApp(id);
      }
    });
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
  LaunchManager _launchManager;

  PackagesServlet(this._launchManager);

  bool canServe(HttpRequest request) {
    return request.uri.pathSegments.contains('packages');
  }

  Future<HttpResponse> serve(HttpRequest request) {
    String projectName = request.uri.pathSegments[0];
    Container project = _launchManager.workspace.getChild(projectName);

    if (project is Project) {
      PackageResolver resolver =
          _launchManager._packageManager.getResolverFor(project);
      File file = resolver.resolveRefToFile(_getPath(request));
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
    String path = _getPath(request);

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
  final LaunchManager _launchManager;
  final PicoServer _server;
  Resource _launchFile;

  ProjectRedirectServlet(this._launchManager, this._server);

  bool canServe(HttpRequest request) {
    return request.uri.path == '/';
  }

  Future<HttpResponse> serve(HttpRequest request) {
    String url = 'http://127.0.0.1:${_server.port}${launchPath}';

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
    String path = _getPath(request);
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
    File file = _getResource(_getPath(request));
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

String _getPath(HttpRequest request) => request.uri.pathSegments.join('/');

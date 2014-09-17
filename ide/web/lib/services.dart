// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services;

import 'dart:async';

import 'package:logging/logging.dart';

import 'package_mgmt/package_manager.dart';
import 'services/services_common.dart';
import 'services/services_bootstrap.dart' as bootstrap;
import 'utils.dart';
import 'workspace.dart';

export 'services/services_common.dart';

final Logger _logger = new Logger('spark.services');

/**
 * Defines a class which contains services and manages their communication.
 */
class Services {
  HostToWorkerHandler _workerHandler;
  Map<String, Service> _services = {};
  ChromeServiceImpl _chromeService;
  final Workspace _workspace;
  final PackageManager _packageManager;

  Services(this._workspace, this._packageManager) {
    _workerHandler = bootstrap.createHostToWorkerHandler();
    registerService(new CompilerService(this, _workerHandler));
    registerService(new AnalyzerService(this, _workerHandler));
    registerService(new TestService(this, _workerHandler));
    _chromeService = new ChromeServiceImpl(this, _workerHandler);

    _workerHandler.onWorkerMessage.listen((ServiceActionEvent event) {
      if (event.serviceId == "chrome") {
        _chromeService.handleEvent(event);
      }
    });
  }

  Future<String> ping() => _workerHandler.ping();

  Service getService(String serviceId) => _services[serviceId];

  void registerService(Service service) {
    _services[service.serviceId] = service;
  }

  void dispose() => _workerHandler.dispose();
}

/**
 * Abstract service with unique serviceId.  Hides communication with the
 * isolate from the actual Service.
 */
abstract class Service {
  final String serviceId;

  Services services;
  HostToWorkerHandler _workerHandler;

  Service(this.services, this.serviceId, this._workerHandler);

  ServiceActionEvent _createNewEvent(String actionId, [Map data]) {
    return new ServiceActionEvent(serviceId, actionId, data);
  }

  // Wraps up actionId and data into an ActionEvent and sends it to the isolate
  // and invokes the Future once response has been received.
  Future<ServiceActionEvent> _sendAction(String actionId, [Map data]) {
    return _workerHandler.onceWorkerReady
        .then((_) => _workerHandler.sendAction(
            _createNewEvent(actionId, data)));
  }

  void _sendResponse(ServiceActionEvent event, [Map data]) {
    ServiceActionEvent responseEvent = event.createReponse(data);
    _workerHandler.onceWorkerReady
        .then((_) => _workerHandler.sendResponse(responseEvent));
  }
}

class TestService extends Service {
  TestService(Services services, HostToWorkerHandler handler)
      : super(services, 'test', handler);

  Future<String> shortTest(String name) {
    return _sendAction("shortTest", {"name": name})
        .then((ServiceActionEvent event) {
      return event.data['response'];
    });
  }

  Future<String> longTest(String name) {
    return _sendAction("longTest", {"name": name})
        .then((ServiceActionEvent event) {
      return event.data['response'];
    });
  }

  /**
   * For testing ChromeService.getFileContents on the isolate side.
   *
   * Sends a [File] reference (via uuid) to the isolate which then then makes
   * [ChromeService].[getFileContents()] call with that uuid which should send
   * back the contents of the file to the isolate, which will return the
   * contents to us for verification.
   */
  Future<String> readText(File file) {
    return _sendAction("readText", {"fileUuid": file.uuid})
        .then((ServiceActionEvent event) => event.data['contents']);
  }

  // TODO(ericarnold): Include analyzer_tests.
}

class CompilerService extends Service {
  CompilerService(Services services, HostToWorkerHandler handler)
      : super(services, 'compiler', handler);

  Future<CompileResult> compileString(String string) {
    Map args = {"string": string};

    return _sendAction("compileString", args).then((ServiceActionEvent event) {
      CompileResult result = new CompileResult.fromMap(event.data);
      UuidResolver resolver = new _ServicesUuidResolver(services._packageManager);
      return result.resolve(resolver).then((_) => result);
    });
  }

  /**
   * Compile the given file and return the results from Dart2js. This includes
   * any errors and the generated JavaScript output. You can optionally pass in
   * [csp] `true` to select the content security policy output from dart2js.
   */
  Future<CompileResult> compileFile(File file, {bool csp: false}) {
    Map args = {
        "fileUuid" : file.uuid,
        "project" : file.project.name,
        "csp" : csp
    };

    return _sendAction("compileFile", args).then((ServiceActionEvent event) {
      CompileResult result = new CompileResult.fromMap(event.data);
      UuidResolver resolver = new _ServicesUuidResolver(
          services._packageManager, file.project);
      return result.resolve(resolver).then((_) => result);
    });
  }
}

class _ServicesUuidResolver extends UuidResolver {
  final PackageManager packageManager;
  final Project project;

  _ServicesUuidResolver(this.packageManager, [this.project]);

  File getResource(String uri) {
    if (uri.isEmpty) return null;

    if (uri.startsWith('/')) uri = uri.substring(1);

    if (uri.startsWith('package:')) {
      return packageManager.getResolverFor(project).resolveRefToFile(uri);
    } else if (project != null) {
      return project.workspace.restoreResource(uri);
    } else {
      return null;
    }
  }
}

class AnalyzerService extends Service {
  // We limit the number of active analysis contexts in order to better manage
  // our memory consumption.
  static final int MAX_CONTEXTS = 5;

  Map<Project, Completer> _contextCompleters = {};

  List<ProjectAnalyzer> _recentContexts = [];

  AnalyzerService(Services services, HostToWorkerHandler handler) :
      super(services, 'analyzer', handler);

  Workspace get workspace => services._workspace;

  // TODO(devoncarew): We'll want to move away from this method, in favor of the
  // [ProjectAnalyzer] interface.
  Future<Map<File, List<AnalysisError>>> buildFiles(List<File> dartFiles) {
    PackageResolver resolver = null;

    if (dartFiles.isNotEmpty) {
      resolver = services._packageManager.getResolverFor(dartFiles.first.project);
    }

    Map args = {
        "dartFileUuids": _filesToUuid(services._packageManager, resolver, dartFiles)
    };

    return _sendAction("buildFiles", args).then((ServiceActionEvent event) {
      Map<String, List<Map>> responseErrors = event.data['errors'];
      Map<File, List<AnalysisError>> errorsPerFile = {};

      for (String uuid in responseErrors.keys) {
        List<AnalysisError> errors = responseErrors[uuid].map((Map errorData) =>
            new AnalysisError.fromMap(errorData)).toList();
        errorsPerFile[_uuidToFile(uuid)] = errors;
      }

      return errorsPerFile;
    });
  }

  File _uuidToFile(String uuid) => services._workspace.restoreResource(uuid);

  Future<Outline> getOutlineFor(String codeString, [String name]) {
    var args = {"string": codeString};
    Stopwatch timer = new Stopwatch()..start();
    return _sendAction("getOutlineFor", args).then((ServiceActionEvent result) {
      String title = name == null ? '' : ' for $name';
      timer.stop();
      _logger.info('built outline${title} in ${timer.elapsedMilliseconds}ms');
      return new Outline.fromMap(result.data);
    });
  }

  bool hasProjectAnalyzer(Project project) =>
      _contextCompleters.containsKey(project);

  Future<ProjectAnalyzer> getCreateProjectAnalyzer(Project project) {
    Completer completer = _contextCompleters[project];

    if (completer == null) {
      completer = new Completer();
      _contextCompleters[project] = completer;
      return _createProjectAnalyzer(project).then((result) {
        completer.complete(result);
        return result;
      }).catchError((e) {
        completer.completeError(e);
        throw e;
      });
    } else {
      return completer.future;
    }
  }

  Future<Declaration> getDeclarationFor(File file, int offset) {
    return getCreateProjectAnalyzer(file.project).then((ProjectAnalyzer context){
      return context.getDeclarationFor(file, offset);
    });
  }

  Future<ProjectAnalyzer> _createProjectAnalyzer(Project project) {
    _logger.info('creating analysis context [${project.name}]');
    Stopwatch timer = new Stopwatch()..start();

    ProjectAnalyzer context = new ProjectAnalyzer._(this, project);
    _recentContexts.insert(0, context);

    if (_recentContexts.length > MAX_CONTEXTS) {
      // Dispose of the oldest context.
      disposeProjectAnalyzer(_recentContexts.last.project);
    }

    return _sendAction('createContext', {'contextId': project.uuid}).then((_) {
      // Add existing files to the context.
      List<File> files = project.traverse(includeDerived: false).where(
          (r) => r.isFile && r.name.endsWith('.dart')).toList();
      files.removeWhere(
          (file) => getPackageManager().properties.isSecondaryPackage(file));

      return context.processChanges(files, [], []).then((_) {
        _logger.info('context created in ${timer.elapsedMilliseconds}ms');
        return context;
      });
    });
  }

  Future disposeProjectAnalyzer(Project project) {
    Completer completer = _contextCompleters[project];

    return completer.future.then((ProjectAnalyzer context) {
      _logger.info('disposed analysis context [${project.name}]');

      _recentContexts.remove(context);
      _contextCompleters.remove(project);

      return _sendAction('disposeContext', {'contextId': project.uuid});
    });
  }

  PackageManager getPackageManager() => services._packageManager;

  PackageResolver getPackageResolverFor(Project project) =>
      services._packageManager.getResolverFor(project);

  void _touch(ProjectAnalyzer context) {
    _recentContexts.remove(context);
    _recentContexts.insert(0, context);
  }
}

/**
 * Used to associate a [Project] and an analysis context.
 */
class ProjectAnalyzer {
  final AnalyzerService analyzerService;
  final Project project;

  ProjectAnalyzer._(this.analyzerService, this.project);

  Future<Declaration> getDeclarationFor(File file, int offset) {
    analyzerService._touch(this);

    PackageManager manager = analyzerService.getPackageManager();
    PackageResolver resolver = analyzerService.getPackageResolverFor(project);

    var args = {'contextId': project.uuid};
    args['fileUuid'] = _filesToUuid(manager, resolver, [file])[0];
    args['offset'] = offset;

    return analyzerService._sendAction('getDeclarationFor', args)
        .then((ServiceActionEvent event) {
      if (event.error) throw event.getErrorMessage();

      return new Declaration.fromMap(event.data);
    });
  }

  Future<AnalysisResult> processChanges(
      List<File> addedFiles, List<File> changedFiles, List<File> deletedFiles) {
    analyzerService._touch(this);

    PackageManager manager = analyzerService.getPackageManager();
    PackageResolver resolver = analyzerService.getPackageResolverFor(project);

    var args = {'contextId': project.uuid};
    args['added'] = _filesToUuid(manager, resolver, addedFiles);
    args['changed'] = _filesToUuid(manager, resolver, changedFiles);
    args['deleted'] = _filesToUuid(manager, resolver, deletedFiles);

    return analyzerService._sendAction('processContextChanges', args)
        .then((ServiceActionEvent event) {
      if (event.error) {
        throw event.getErrorMessage();
      } else {
        AnalysisResult result =
            new AnalysisResult.fromMap(analyzerService.workspace, event.data);
        _handleAnalysisResult(project, result);
        return result;
      }
    });
  }

  Future dispose() => analyzerService.disposeProjectAnalyzer(project);

  void _handleAnalysisResult(Project project, AnalysisResult result) {
    project.workspace.pauseMarkerStream();

    try {
      for (File file in result.getFiles()) {
        if (file == null) continue;

        file.clearMarkers('dart');

        for (AnalysisError error in result.getErrorsFor(file)) {
          file.createMarker('dart',
              _convertErrorSeverity(error.errorSeverity),
              error.message, error.lineNumber,
              error.offset, error.offset + error.length);
        }
      }
    } finally {
      project.workspace.resumeMarkerStream();
    }
  }

  int _convertErrorSeverity(int sev) {
    if (sev == ErrorSeverity.ERROR) {
      return Marker.SEVERITY_ERROR;
    } else  if (sev == ErrorSeverity.WARNING) {
      return Marker.SEVERITY_WARNING;
    } else  if (sev == ErrorSeverity.INFO) {
      return Marker.SEVERITY_INFO;
    } else {
      return Marker.SEVERITY_NONE;
    }
  }
}

/**
 * Special service for handling Chrome app calls that the isolate
 * cannot handle on its own.
 */
class ChromeServiceImpl extends Service {
  ChromeServiceImpl(Services services, HostToWorkerHandler handler)
      : super(services, 'chrome', handler);

  // For incoming (non-requested) actions.
  void handleEvent(ServiceActionEvent event) {
    new Future.value(null).then((_) {
      switch(event.actionId) {
        case "delay":
          var duration = new Duration(milliseconds: event.data['ms']);
          return new Future.delayed(duration).then((_) => _sendResponse(event));
        case "getAppContents":
          String path = event.data['path'];

          PrintProfiler timer = new PrintProfiler('getAppContents(${path})');
          return getAppContentsBinary(path).then((List<int> contents) {
            return _sendResponse(event, {"contents": contents});
          }).then((response) {
            _logger.info(timer.finishProfiler());
            return response;
          });
        case "getFileContents":
          String uuid = event.data['uuid'];
          File restoredFile = services._workspace.restoreResource(uuid);
          if (restoredFile == null) {
            throw "Could not restore file with uuid $uuid";
          }
          return restoredFile.getContents().then((String contents) {
            return _sendResponse(event, {"contents": contents});
          });
        case "getPackageContents":
          String relativeToUuid = event.data['relativeTo'];
          String packageRef = event.data['packageRef'];
          Resource resource = services._workspace.restoreResource(relativeToUuid);
          if (resource == null) {
            throw "Could not restore file with uuid $relativeToUuid";
          }
          PackageResolver resolver = services._packageManager.getResolverFor(resource.project);
          File packageFile = resolver.resolveRefToFile(packageRef);
          if (packageFile == null) {
            throw "Could not resolve reference: ${packageRef}";
          }
          return packageFile.getContents().then((String contents) {
            return _sendResponse(event, {"contents": contents});
          });
        default:
          throw "Unknown action '${event.actionId}' sent to Chrome service.";
      }
    }).catchError((error) => _sendErrorResponse(event, error));
  }

  void _sendErrorResponse(ServiceActionEvent event, e) {
    String stackTrace = '';

    try {
      if (e.stackTrace != null) {
        stackTrace = '${e.stackTrace}';
      }
    } catch(e) { }

    ServiceActionEvent responseEvent = event.createReponse({
        "error": '${e}',
        "stackTrace": stackTrace});

    responseEvent.error = true;
    _workerHandler.onceWorkerReady
        .then((_) => _workerHandler.sendResponse(responseEvent));
  }
}

List<String> _filesToUuid(
    PackageManager manager, PackageResolver resolver, List<File> files) {
  Iterable uuids = files.map((File file) {
    if (resolver != null && manager.properties.isInPackagesFolder(file)) {
      return resolver.getReferenceFor(file);
    } else {
      return file.uuid;
    }
  });
  return uuids.where((uuid) => uuid != null).toList();
}

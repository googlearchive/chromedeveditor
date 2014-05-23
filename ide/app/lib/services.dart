// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services;

import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';

import 'package_mgmt/package_manager.dart';
import 'services/compiler.dart';
import 'services/services_common.dart';
import 'utils.dart';
import 'workspace.dart';

export 'services/compiler.dart' show CompilerResult;
export 'services/services_common.dart';

Logger _logger = new Logger('spark.services');

/**
 * Defines a class which contains services and manages their communication.
 */
class Services {
  _IsolateHandler _isolateHandler;
  Map<String, Service> _services = {};
  ChromeServiceImpl _chromeService;
  final Workspace _workspace;
  final PackageManager _packageManager;

  Services(this._workspace, this._packageManager) {
    _isolateHandler = new _IsolateHandler();
    registerService(new CompilerService(this, _isolateHandler));
    registerService(new AnalyzerService(this, _isolateHandler));
    registerService(new TestService(this, _isolateHandler));
    _chromeService = new ChromeServiceImpl(this, _isolateHandler);

    _isolateHandler.onIsolateMessage.listen((ServiceActionEvent event) {
      if (event.serviceId == "chrome") {
        _chromeService.handleEvent(event);
      }
    });
  }

  Future<String> ping() => _isolateHandler.ping();

  Service getService(String serviceId) => _services[serviceId];

  void registerService(Service service) {
    _services[service.serviceId] = service;
  }

  void dispose() => _isolateHandler.dispose();
}

/**
 * Abstract service with unique serviceId.  Hides communication with the
 * isolate from the actual Service.
 */
abstract class Service {
  final String serviceId;

  Services services;
  _IsolateHandler _isolateHandler;

  Service(this.services, this.serviceId, this._isolateHandler);

  ServiceActionEvent _createNewEvent(String actionId, [Map data]) {
    return new ServiceActionEvent(serviceId, actionId, data);
  }

  // Wraps up actionId and data into an ActionEvent and sends it to the isolate
  // and invokes the Future once response has been received.
  Future<ServiceActionEvent> _sendAction(String actionId, [Map data]) {
    return _isolateHandler.onceIsolateReady
        .then((_) => _isolateHandler.sendAction(
            _createNewEvent(actionId, data)));
  }

  void _sendResponse(ServiceActionEvent event, [Map data]) {
    ServiceActionEvent responseEvent = event.createReponse(data);
    _isolateHandler.onceIsolateReady
        .then((_) => _isolateHandler.sendResponse(responseEvent));
  }
}

class TestService extends Service {
  TestService(Services services, _IsolateHandler handler)
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
  CompilerService(Services services, _IsolateHandler handler)
      : super(services, 'compiler', handler);

  Future<CompilerResult> compileString(String string) {
    Map args = {"string": string};
    return _sendAction("compileString", args).then((ServiceActionEvent result) {
      return new CompilerResult.fromMap(result.data);
    });
  }

  /**
   * Compile the given file and return the results from Dart2js. This includes
   * any errors and the generated JavaScript output. You can optionally pass in
   * [csp] `true` to select the content security policy output from dart2js.
   */
  Future<CompilerResult> compileFile(File file, {bool csp: false}) {
    Map args = {
        "fileUuid" : file.uuid,
        "project" : file.project.name,
        "csp" : csp
    };
    return _sendAction("compileFile", args).then((ServiceActionEvent result) {
      return new CompilerResult.fromMap(result.data);
    });
  }
}

class AnalyzerService extends Service {
  // We limit the number of active analysis contexts in order to better manage
  // our memory consumption.
  static final int MAX_CONTEXTS = 5;

  Map<Project, ProjectAnalyzer> _contextMap = {};
  List<ProjectAnalyzer> _recentContexts = [];

  AnalyzerService(Services services, _IsolateHandler handler) :
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

  Future<Declaration> getDeclarationFor(File file, int offset) {
    ProjectAnalyzer context = getProjectAnalyzer(file.project);

    if (context == null) {
      return createProjectAnalyzer(file.project).then((context) {
        return context.getDeclarationFor(file, offset);
      });
    } else {
      return new Future.value(context.getDeclarationFor(file, offset));
    }
  }

  Future<ProjectAnalyzer> createProjectAnalyzer(Project project) {
    if (_contextMap[project] != null) {
      return new Future.value(_contextMap[project]);
    }

    _logger.info('creating analysis context [${project.name}]');

    ProjectAnalyzer context = new ProjectAnalyzer._(this, project);
    _contextMap[project] = context;
    _recentContexts.insert(0, context);

    if (_recentContexts.length > MAX_CONTEXTS) {
      // Dispose of the oldest context.
      disposeProjectAnalyzer(_recentContexts.last);
    }

    return _sendAction('createContext', {'contextId': project.uuid}).then((_) {
      // Add existing files to the context.
      List<File> files = project.traverse(includeDerived: false).where(
          (r) => r.isFile && r.name.endsWith('.dart')).toList();
      files.removeWhere(
          (file) => getPackageManager().properties.isSecondaryPackage(file));

      return context.processChanges(files, [], []).then((_) => context);
    });
  }

  ProjectAnalyzer getProjectAnalyzer(Project project) => _contextMap[project];

  Future disposeProjectAnalyzer(ProjectAnalyzer projectAnalyzer) {
    Project project = projectAnalyzer.project;
    ProjectAnalyzer context = _contextMap.remove(project);

    if (context != null) {
      _logger.info('disposed analysis context [${projectAnalyzer.project.name}]');

      _recentContexts.remove(context);
      return _sendAction('disposeContext', {'contextId': project.uuid});
    } else {
      return new Future.value();
    }
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

  Future dispose() => analyzerService.disposeProjectAnalyzer(this);

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
  ChromeServiceImpl(Services services, _IsolateHandler handler)
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
          return getAppContentsBinary(path).then((List<int> contents) {
            return _sendResponse(event, {"contents": contents});
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
    _isolateHandler.onceIsolateReady
        .then((_) => _isolateHandler.sendResponse(responseEvent));
  }
}

/**
 * Defines a class which handles all isolate setup and communication
 */
class _IsolateHandler {
  int _topCallId = 0;
  Isolate _isolate;
  Map<String, Completer> _serviceCallCompleters = {};

  final String _workerPath = 'services_entry.dart';

  SendPort _sendPort;
  final ReceivePort _receivePort = new ReceivePort();

  // Fired when isolate originates a message
  Stream<ServiceActionEvent> onIsolateMessage;

  // Future to fire once, when isolate is started and ready to receive messages.
  // Usage: onceIsolateReady.then() => // do stuff
  Future onceIsolateReady;
  StreamController _readyController = new StreamController.broadcast();

  _IsolateHandler() {
    onceIsolateReady = _readyController.stream.first;
    _startIsolate().then((result) => _isolate = result);
  }

  String _getNewCallId() => "host_${_topCallId++}";

  Future<Isolate> _startIsolate() {
    StreamController<ServiceActionEvent> _messageController =
        new StreamController<ServiceActionEvent>.broadcast();

    onIsolateMessage = _messageController.stream;

    _receivePort.listen((arg) {
      if (arg is String) {
        // String: handle as print
        print(arg);
      } else if (_sendPort == null) {
        _sendPort = arg;
        _readyController..add(null)..close();
      } else if (arg is int) {
        // int: handle as ping
        _pong(arg);
      } else {
        ServiceActionEvent event = new ServiceActionEvent.fromMap(arg);

        if (event.response == true) {
          Completer<ServiceActionEvent> completer =
              _serviceCallCompleters.remove(event.callId);
          if (event.error) {
            completer.completeError(event.getErrorMessage());
          } else {
            completer.complete(event);
          }
        } else {
          _messageController.add(event);
        }
      }
    });

    return Isolate.spawnUri(Uri.parse(_workerPath), [], _receivePort.sendPort);
  }

  Future<String> ping() {
    Completer<String> completer = new Completer();

    int callId = _topCallId;
    _serviceCallCompleters["ping_$callId"] = completer;

    onceIsolateReady.then((_) {
      _sendPort.send(callId);
    });

    _topCallId += 1;
    return completer.future;
  }

  Future _pong(int id) {
    Completer completer = _serviceCallCompleters.remove("ping_$id");
    completer.complete("pong");
    return completer.future;
  }

  Future<ServiceActionEvent> sendAction(ServiceActionEvent event) {
    Completer<ServiceActionEvent> completer =
        new Completer<ServiceActionEvent>();

    event.makeRespondable(_getNewCallId());
    _serviceCallCompleters[event.callId] = completer;
    _sendPort.send(event.toMap());

    return completer.future;
  }

  void sendResponse(ServiceActionEvent event) {
    _sendPort.send(event.toMap());
  }

  // TODO: I'm not entirely sure how to terminate an isolate...
  void dispose() { }
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

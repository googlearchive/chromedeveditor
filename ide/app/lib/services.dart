// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services;

import 'dart:async';
import 'dart:isolate';

import 'pub.dart';
import 'services/compiler.dart';
import 'services/services_common.dart';
import 'utils.dart';
import 'workspace.dart';

export 'services/compiler.dart' show CompilerResult;
export 'services/services_common.dart';

/**
 * Defines a class which contains services and manages their communication.
 */
class Services {
  _IsolateHandler _isolateHandler;
  Map<String, Service> _services = {};
  ChromeServiceImpl _chromeService;
  final Workspace _workspace;
  final PubManager _pubManager;

  Services(this._workspace, this._pubManager) {
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

  Future<CompilerResult> compileFile(File file) {
    Map args = { "fileUuid" : file.uuid, "project" : file.project.name };
    return _sendAction("compileFile", args).then((ServiceActionEvent result) {
      return new CompilerResult.fromMap(result.data);
    });
  }
}

class AnalyzerService extends Service {
  AnalyzerService(Services services, _IsolateHandler handler) :
    super(services, 'analyzer', handler);

  Future<Map<File, List<AnalysisError>>> buildFiles(Iterable<File> dartFiles) {
    return _sendAction("buildFiles", {"dartFileUuids": _filesToUuid(dartFiles)})
        .then((ServiceActionEvent event) {
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

  List<String> _filesToUuid(Iterable<File> files) =>
      files.map((f) => f.uuid).toList();

  Future<Outline> getOutlineFor(String codeString) {
    return _sendAction("getOutlineFor", {"string": codeString})
        .then((ServiceActionEvent result) {
      return new Outline.fromMap(result.data);
    });
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
          return new Future.delayed(
              new Duration(milliseconds: event.data['ms'])).then((_) {
            _sendResponse(event);
          });
        case "getAppContents":
          String path = event.data['path'];
          return getAppContentsBinary(path).then((List<int> contents) {
            return _sendResponse(event, {"contents": contents.toList()});
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
          String relativeToUUid = event.data['relativeTo'];
          String packageRef = event.data['packageRef'];
          File file = services._workspace.restoreResource(relativeToUUid);
          if (file == null) {
            throw "Could not restore file with uuid $relativeToUUid";
          }
          PubResolver resolver = services._pubManager.getResolverFor(file.project);
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
    String stackTrace;
    try {
      stackTrace = e.stackTrace.toString();
    } catch(e) {
      stackTrace = "";
    }

    ServiceActionEvent responseEvent = event.createReponse({
        "error": e.toString(),
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
        // TODO: convert this to a logger call?
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
          completer.complete(event);
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

  void dispose() {
    // TODO: I'm not entirely sure how to terminate an isolate...
    //_isolate.
  }
}

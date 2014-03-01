// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services;

import 'dart:async';
import 'dart:isolate';

import 'analyzer_common.dart';
import 'workspace.dart' as ws;
import 'services/compiler.dart';
import 'utils.dart';

export 'services/compiler.dart' show CompilerResult;

/**
 * Defines a class which contains services and manages their communication.
 */
class Services {
  _IsolateHandler _isolateHandler;
  Map<String, Service> _services = {};
  ChromeServiceImpl _chromeService;
  ws.Workspace _workspace;

  Services(this._workspace) {
    _isolateHandler = new _IsolateHandler();
    registerService(new CompilerService(this, _isolateHandler));
    registerService(new AnalyzerService(this, _isolateHandler));
    registerService(new TestService(this, _isolateHandler));
    _chromeService = new ChromeServiceImpl(this, _isolateHandler);

    _isolateHandler.onIsolateMessage.listen((ServiceActionEvent event){
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
}

/**
 * Abstract service with unique serviceId.  Hides communication with the
 * isolate from the actual Service.
 */
abstract class Service {
  Services _services;
  _IsolateHandler _isolateHandler;

  String get serviceId;

  Service(this._services, this._isolateHandler);

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
  String serviceId = "test";

  TestService(Services services, _IsolateHandler handler)
      : super(services, handler);

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
  Future<String> readText(ws.File file) {
    return _sendAction("readText", {"fileUuid": file.uuid})
        .then((ServiceActionEvent event) => event.data['contents']);
  }

  Future<String> analyzerSdkTest() => _sendAction("analyzerSdkTest")
      .then((ServiceActionEvent event) => event.data['success']);

//  Future buildTest() {
//    AnalyzerService analyzer = _services.getService("analysisService");
//    analyzer.start().then((_) {
//      analyzer.buildFiles(dartFiles)
//    });
//  }
}

class CompilerService extends Service {
  Completer _readyCompleter = new Completer();

  String serviceId = "compiler";
  Future onceReady;

  CompilerService(Services services, _IsolateHandler handler)
      : super(services, handler) {
    onceReady = _readyCompleter.future;
  }

  Future start() {
    return _isolateHandler.onceIsolateReady
        .then((_) => _sendAction("start"))
        .then((_) => _readyCompleter.complete());
  }

  Future<CompilerResult> compileString(String string) {
    return onceReady.then((_) =>
        _sendAction("compileString", {"string": string}))
        .then((ServiceActionEvent result) {
      CompilerResult response = new CompilerResult.fromMap(result.data);
      return response;
    });
  }

  Future dispose() {
    return onceReady.then((_) => _sendAction("dispose"))
        .then((_) => null);
  }
}

class AnalyzerService extends Service {
  String serviceId = "analyzer";

  AnalyzerService(Services services, _IsolateHandler handler)
  : super(services, handler);

  // TODO(ericarnold): Implement
//  List<AnalyzerResult> build(Iterable<File> dartFiles) {
//    return onceReady.then((_) =>
//        _sendAction("analyzeString", {"string": string}))
//        .then((ServiceActionEvent result) {
////          CompilerResult response = new AnalysisResult.fromMap(result.data);
//          return response;
//        });
//  }

  Future<AnalysisResult> analyzeString(String string,
      {bool performResolution}) {
    return _sendAction("analyzeString", {"string": string})
        .then((ServiceActionEvent result) {
          AnalysisResult response = new AnalysisResult.fromMap(result.data);
          return response;
        });
  }

  Future dispose() {
    return _sendAction("dispose")
        .then((_) => null);
  }

  Future<Map<ws.File, List<AnalysisError>>>
      buildFiles(Iterable<ws.File> dartFiles) {
    return _sendAction("buildFiles", {"dartFileUuids": _filesToUuid(dartFiles)})
    .then((ServiceActionEvent event) {
      Map<String, List<Map>> responseErrors =
          event.data['errors'];

      Map<ws.File, List<AnalysisError>> errorsPerFile = {};

      for (String uuid in responseErrors.keys) {
        List<AnalysisError> errors =
            responseErrors[uuid].map((Map errorData) =>
            new AnalysisError.fromMap(errorData)).toList();
        errorsPerFile[_uuidToFile(uuid)] = errors;
      }

      return errorsPerFile;
    });
  }

  ws.File _uuidToFile(String uuid) =>
      _services._workspace.restoreResource(uuid);

  List<String> _filesToUuid(Iterable<ws.File> files) =>
      files.map((f) => f.uuid).toList();
}

/**
 * Special service for handling Chrome app calls that the isolate
 * cannot handle on its own.
 */
class ChromeServiceImpl extends Service {
  String serviceId = "chrome";

  ChromeServiceImpl(Services services, _IsolateHandler handler)
      : super(services, handler);

  // For incoming (non-requested) actions.
  void handleEvent(ServiceActionEvent event) {
    Completer<ServiceActionEvent> completer =
        new Completer<ServiceActionEvent>();

    new Future.value(null).then((_){
      switch(event.actionId) {
        case "delay":
          new Future.delayed(new Duration(milliseconds: event.data['ms'])).then(
              (_) => _sendResponse(event));
          break;
        case "getAppContents":
          String path = event.data['path'];
          getAppContentsBinary(path)
              .then((List<int> contents) {
                return _sendResponse(event, {"contents": contents.toList()});
              });
          break;
        case "getFileContents":
          String uuid = event.data['uuid'];
          ws.File restoredFile = _services._workspace.restoreResource(uuid);
          if (restoredFile == null) {
            // TODO(ericarnold): Turn into an Exception subclass.
            throw new Exception("Could not restore file with uuid $uuid");
          }

          restoredFile.getContents()
              .then((String contents) =>
                  _sendResponse(event, {"contents": contents}));
          break;
        default:
          throw "Unknown action '${event.actionId}' sent to Chrome service.";
      }
    })
    .catchError((error) => _sendErrorResponse(event, error));
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
    _startIsolate();
  }

  String _getNewCallId() => "host_${_topCallId++}";

  Future _startIsolate() {
    StreamController<ServiceActionEvent> _messageController =
        new StreamController<ServiceActionEvent>.broadcast();

    onIsolateMessage = _messageController.stream;

    _receivePort.listen((arg) {
      if (arg is String) {
        // TODO: convert this to a logger call?
        // String: handle as print
        print(arg.replaceAll(new RegExp("chrome-extension://[a-z]*"),
            "file:///Users/ericarnold/src/spark/ide/app"));
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

    onceIsolateReady.then((_){
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
}

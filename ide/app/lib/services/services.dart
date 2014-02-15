// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services;

import 'dart:async';
import 'dart:isolate';

import 'package:chrome/chrome_app.dart' as chrome;

import '../utils.dart';
import '../compiler.dart';


/**
 * Defines a class which contains services and manages their communication.
 */
class Services {
  _IsolateHandler _isolateHandler;
  Map<String, Service> _services = {};
  ChromeServiceImpl _chromeService;

  Services() {
    _isolateHandler = new _IsolateHandler();
    registerService(new CompilerService(this, _isolateHandler));
    registerService(new ExampleService(this, _isolateHandler));
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

class CompilerService extends Service {
  String serviceId = "compiler";

  CompilerService(Services services, _IsolateHandler handler)
      : super(services, handler);

  Future start() {
    return _sendAction("start").then((_) => null);
  }

  Future<CompilerResult> compileString(String string) {
    return _sendAction("compileString")
        .then((ServiceActionEvent result) {
      CompilerResult response = new CompilerResult.fromMap(result.data);
      return response;
    });
  }

  Future dispose() {
    return _sendAction("dispose").then((_) => null);
  }
}

class ExampleService extends Service {
  String serviceId = "example";

  ExampleService(Services services, _IsolateHandler handler)
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

    switch(event.actionId) {
      case "delay":
        new Future.delayed(new Duration(milliseconds: event.data['ms']))
            .then((_) => _sendResponse(event.createReponse(null)));
        break;
      case "getURL":
        _sendResponse(event.createReponse({"url": chrome.runtime.getURL(
            event.data['path'])}));
        break;
      default:
        throw "Unknown action '${event.actionId}' sent to Chrome service.";
    }
  }
}

/**
 * Defines a class which handles all isolate setup and communication
 */
class _IsolateHandler {
  int _topCallId = 0;
  Map<String, Completer> _serviceCallCompleters = {};

  final String _workerPath = 'services_impl.dart';

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
      if (_sendPort == null) {
        _sendPort = arg;
        _readyController..add(null)..close();
      } else {
        if (arg is int) {
          // int: handle as ping
          _pong(arg);
        } else if (arg is String) {
          // String: handle as print
          print ("Worker: $arg");
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


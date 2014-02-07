// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services;

import 'dart:async';
import 'dart:isolate';

import '../utils.dart';

/**
 * Defines a class which contains services and manages their communication.
 */
class Services {
  // TODO(ericarnold): instantiate each Service
  // TODO(ericarnold): send messages for workers to be instantiated (either
  //         immediately, on-demand, or manually).

  _IsolateHandler _isolateHandler;

  // Fires when the isolate communication has been established.
  Stream onReady;
  Map<String, Service> _services = {};

  Services() {
    _isolateHandler = new _IsolateHandler();
    registerService(new ExampleService(this, _isolateHandler));
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
  static int _topCallId = 0;

  Services _services;
  _IsolateHandler _isolateHandler;

  String get serviceId;

  Service(this._services, this._isolateHandler);

  String _getNewCallId() => "host_${_topCallId++}";

  // Wraps up actionId and data into an ActionEvent and sends it to the isolate
  // and invokes the Future once response has been received.
  Future<ServiceActionEvent> _sendAction(String actionId, [Map data]) {
    // TODO(ericarnold): Implement
  }
}

/**
 * Special service for handling Chrome app calls that the isolate
 * cannot handle on its own.
 */
class ExampleService extends Service {
  String serviceId = "example";

  ExampleService(Services services, _IsolateHandler handler)
      : super(services, handler);
}

/**
 * Special service for handling Chrome app calls that the isolate
 * cannot handle on its own.
 */
class ChromeService extends Service {
  String serviceId = "chrome";
  ChromeService(Services services, _IsolateHandler handler)
      : super(services, handler);

  // For incoming (non-requested) actions.
  void _receiveAction(ServiceActionEvent event) {
    // TODO(ericarnold): Implement
  }

  void _sendResponse(ServiceActionEvent event) {
    // TODO(ericarnold): Implement
  }
}

/**
 * Defines a class which handles all isolate setup and communication
 */
class _IsolateHandler {
  int _topCallId = 0;
  Map<int, Completer> _serviceCallCompleters = {};

  final String _workerPath = 'services_impl.dart';
  SendPort _sendPort;
  final ReceivePort _receivePort = new ReceivePort();

  // Fired when isolate responds to message
  Stream<ServiceActionEvent> onIsolateResponse(String callId) {
    onIsolateMessage = _messageController.stream;
    onceIsolateReady = _readyController.stream.first;
    // TODO(ericarnold): Implement
  }

  StreamController<ServiceActionEvent> _messageController =
      new StreamController<ServiceActionEvent>.broadcast();

  StreamController _readyController = new StreamController.broadcast();

  // Fired when isolate originates a message
  Stream onIsolateMessage;

  // Future to fire once, when isolate is started and ready to receive messages.
  // Usage: onceIsolateReady.then() => // do stuff
  Future onceIsolateReady;

  _IsolateHandler() {
    // TODO(ericarnold): Implement
  }

  Future _startIsolate() {
    _receivePort.listen((arg) {
      if (_sendPort == null) {
        _sendPort = arg;
        _readyController..add(null)..close();
      } else {
        pong(arg);
      }
    });

    return Isolate.spawnUri(Uri.parse(_workerPath), [], _receivePort.sendPort);
  }

  Future<String> ping() {
    Completer<String> completer = new Completer();
    int callId = _topCallId;
    _serviceCallCompleters[callId] = completer;

    onceIsolateReady.then((_){
      _sendPort.send(callId);
    });

    _topCallId += 1;
    return completer.future;
  }

  Future pong(int id) {
    Completer completer = _serviceCallCompleters[id];
    _serviceCallCompleters.remove(id);
    completer.complete("pong");
    return completer.future;
  }


  Future<ServiceActionEvent> sendAction(String serviceId, String actionId,
      String callId, [String data = ""]) {
    // TODO(ericarnold): Implement
    // TODO(ericarnold): implement callId response
  }

  void sendResponse(ServiceActionEvent event, String data) {
    // TODO(ericarnold): Implement
  }
}


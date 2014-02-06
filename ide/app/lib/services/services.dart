// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services;

import 'dart:async';
import 'dart:isolate';

import 'action_event.dart';

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
  Future<ActionEvent> _sendAction(String actionId, [Map data]) {
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
  void _receiveAction(ActionEvent event) {
    // TODO(ericarnold): Implement
  }

  void _sendResponse(ActionEvent event) {
    // TODO(ericarnold): Implement
  }
}

/**
 * Defines a class which handles all isolate setup and communication
 */
class _IsolateHandler {
  final String _workerPath = 'services_impl.dart';
  SendPort _sendPort;
  final ReceivePort _receivePort = new ReceivePort();

  // Fired when isolate responds to message
  Stream<ActionEvent> onIsolateResponse(String callId) {
    // TODO(ericarnold): Implement
  }

  // Fired when isolate originates a message
  Stream onIsolateMessage;

  // Future to fire once, when isolate is started and ready to receive messages.
  // Usage: onceIsolateReady.then() => // do stuff
  Future onceIsolateReady;

  _IsolateHandler() {
    // TODO(ericarnold): Implement
  }

  Future _startIsolate() {
    StreamController<ActionEvent> messageController =
        new StreamController<ActionEvent>.broadcast();
  }

  Future<ActionEvent> sendAction(String serviceId, String actionId,
      String callId, [String data = ""]) {
    // TODO(ericarnold): Implement
    // TODO(ericarnold): implement callId response
  }

  void sendResponse(ActionEvent event, String data) {
    // TODO(ericarnold): Implement
  }
}


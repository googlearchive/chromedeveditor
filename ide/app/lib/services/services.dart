// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
library spark.services;

import 'dart:async';
import 'dart:isolate';

/**
 * Defines a class which contains services and manages their communication.
 */
class Services {
  IsolateHandler _isolateHandler;

  // Services
  PingService pingService;

  Services() {
    _isolateHandler = new IsolateHandler();
    _isolateHandler.onWorkerReady.listen((_){
      // Initialize each service
      pingService = new PingService(_isolateHandler);
    });
  }

  Stream get onReady => _isolateHandler.onWorkerReady;
}

/*
 * A simple service for pinging the worker
 */
class PingService extends Service{
  PingService(IsolateHandler handler) : super(handler);

  String get serviceId => "ping";

  Future ping(String message) {
    sendAction(message);
  }
}

/*
 * Defines an abstract service with a unique service id.  This class hides the
 * isolate communication.
 */
abstract class Service {
  String get serviceId;
  IsolateHandler _isolateHandler;
  Service(this._isolateHandler);

  // TODO(ericarnold): This will need to return a future to complete when action
  // is done.
  Future sendAction(String message) {
    _isolateHandler.sendAction(serviceId, message);
  }
}

/**
 * Defines a class which handles all isolate setup and communication
 */
class IsolateHandler {
  final String _workerPath = 'lib/services/services_impl.dart';

  SendPort _sendPort;
  final ReceivePort _receivePort = new ReceivePort();
  StreamController _readyController = new StreamController.broadcast();

  IsolateHandler() {
    _startIsolate().then((_)=>_isolateReady());
  }

  Future _startIsolate() {
    Completer completer = new Completer();
    _receivePort.listen((arg) {
      if (_sendPort == null) {
        _sendPort = arg;
        completer.complete();
      } else {
        print('Received from isolate: $arg\n');
      }
    });

    Isolate.spawnUri(Uri.parse(_workerPath), [], _receivePort.sendPort);

    return completer.future;
  }

  void _isolateReady() {
    _readyController.add(null);
    _readyController.close();
  }

  Stream get onWorkerReady => _readyController.stream;

  // TODO(ericarnold): Complete a future / stream.
  Future sendAction(String id, [String data = ""]) {
    _sendPort.send({"id": id, "data": data});
  }

  void sendResponse(String id, String data) {
    // TODO(ericarnold): Implement
  }
}


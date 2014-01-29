// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
library spark.services;

import 'dart:isolate';
import 'dart:async';

/**
 * This is a separate application spawned by Spark (via Services) as an isolate
 * for use in running long-running / heaving tasks.
 */
void main(List<String> args, SendPort sendPort) {
  final ServicesIsolate servicesIsolate = new ServicesIsolate(sendPort);
}

/**
 * Defines a handler for all worker-side service implementations.
 */
class ServicesIsolate {
  WorkerHandler _handler;

  ServicesIsolate(SendPort sendPort) {
    _handler = new WorkerHandler(sendPort)
        ..onMessage.listen(handleMessage);
  }

  handleMessage(ActionEvent event) {
    // Service implementations:
    switch(event.id) {
      case "ping":
        _handler.sendResponse(event.id, 'pong: ${event.data}');
        break;
    }
  }
}

/**
 * Defines a received action event.
 */
// TODO(ericarnold): Extend Event?
// TODO(ericarnold): This should be shared between ServiceIsolate and Service.
class ActionEvent {
  String id;
  Map data;
  ActionEvent(this.id, this.data);
}

/**
 * Defines a class which handles all isolate communcation
 */
class WorkerHandler {
  final SendPort _sendPort;
  StreamController<ActionEvent> _messageStreamController =
      new StreamController<ActionEvent>.broadcast();

  WorkerHandler(this._sendPort) {
    ReceivePort receivePort = new ReceivePort();
    _sendPort.send(receivePort.sendPort);

    receivePort.listen((arg) {
      _messageStreamController.add(new ActionEvent(arg["id"], arg["data"]));
    });
  }

  Stream<ActionEvent> get onMessage => _messageStreamController.stream;

  void sendResponse(String id, String data) {
    _sendPort.send({"id": id, "data": data});
  }

  void sendAction(String id, String data) {
    // TODO(ericarnold): Implement
  }
}



// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
library spark.services;

import 'dart:convert';
import 'dart:async';
import 'dart:isolate';

import 'lib/compiler.dart';


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
  CompilerServiceImpl compiler;

  ServicesIsolate(SendPort sendPort) {
    _handler = new WorkerHandler(sendPort)
        ..onMessage.listen(handleMessage);

    // For use with top level print() helper function.
    _globalHandler = _handler;
  }

  handleMessage(ActionEvent event) {
    print("handleMessage");
    // Service implementations:
    switch(event.serviceId) {
      case "ping":
        switch(event.actionId) {
          case "ping":
            _handler.sendResponse(
                event.serviceId, "pong", event.data["message"]);
            break;
        }
        break;

      case "compiler":
        switch(event.actionId) {
          case "instantiate":
            compiler = new CompilerServiceImpl()..onReady.listen((String state){
              _handler.sendResponse(
                  event.serviceId, event.actionId, {"state": state});
            });
            break;
        }
        break;
    }
  }
}

class CompilerServiceImpl {
  Compiler _compiler;

  StreamController<String> _readyController =
      new StreamController<String>.broadcast();

  CompilerServiceImpl() {
    Compiler.createCompiler().then((c) {
      _compiler = c;
      _readyController.add("ready");
      _readyController.close();
    });
  }
  Stream<String> get onReady => _readyController.stream;
}

/**
 * Defines a received action event.
 */
// TODO(ericarnold): Extend Event?
// TODO(ericarnold): This should be shared between ServiceIsolate and Service.
class ActionEvent {
  String serviceId;
  String actionId;
  Map data;
  ActionEvent(this.serviceId, this.actionId, this.data);
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

      String data = arg["data"];
      _messageStreamController.add(new ActionEvent(
          arg["serviceId"], arg["actionId"], JSON.decode(data)));
    });
  }

  Stream<ActionEvent> get onMessage => _messageStreamController.stream;

  void sendResponse(String serviceId, String actionId, Map data) {
    _sendPort.send({
        "serviceId": serviceId,
        "actionId": actionId,
        "data": JSON.encode(data)});
  }

  void sendAction(String serviceId, String actionId, Map data) {
    // TODO(ericarnold): Implement
  }
}

// Prints are crashing isolate, so this will take over for the time being.
WorkerHandler _globalHandler;
void print(String message) {
  _globalHandler.sendResponse("ping", "pong", {"message": message});
}

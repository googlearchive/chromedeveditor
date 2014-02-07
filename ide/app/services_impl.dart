// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
library spark.services_impl;

import 'dart:async';
import 'dart:isolate';

import 'lib/utils.dart';

/**
 * This is a separate application spawned by Spark (via Services) as an isolate
 * for use in running long-running / heaving tasks.
 */
void main(List<String> args, SendPort sendPort) {
  // For use with top level print() helper function.
  _printSendPort = sendPort;

  final ServicesIsolate servicesIsolate = new ServicesIsolate(sendPort);
}

/**
 * Defines a handler for all worker-side service implementations.
 */
class ServicesIsolate {
  final SendPort _sendPort;

  // Fired when host responds to message
  Stream<ServiceActionEvent> _onResponseMessage;

  // Fired when host originates a message
  Stream<ServiceActionEvent> _onHostMessage ;

  // Services:
  // ExampleServiceImpl example;

  ServicesIsolate(this._sendPort) {
    StreamController<ServiceActionEvent> hostMessageController =
        new StreamController<ServiceActionEvent>.broadcast();
    StreamController<ServiceActionEvent> responseMessageController =
        new StreamController<ServiceActionEvent>.broadcast();

    _onHostMessage = hostMessageController.stream;
    _onResponseMessage = responseMessageController.stream;

    ReceivePort receivePort = new ReceivePort();
    _sendPort.send(receivePort.sendPort);

    receivePort.listen((arg) {
      if (arg is int) {
        _sendPort.send(arg);
      } else {
        ServiceActionEvent event = new ServiceActionEvent.fromMap(arg);
        ServiceImpl service = getService(event.serviceId);
        service.handleEvent(event);
      }
//      _sendPort.send(arg);

      //String data = arg["data"];
      // TODO(ericarnold): differntiate between host and response messages ...
      //hostMessageController.add(new ActionEvent(
      //    arg["serviceId"], arg["actionId"], arg["callId"], JSON.decode(data)));
      //responseMessageController.add(new ActionEvent(
      //    arg["serviceId"], arg["actionId"], arg["callId"], JSON.decode(data)));
    });
  }

  ServiceImpl getService(String serviceId) {
    // TODO(ericarnold): Implement
    return new ExampleServiceImpl(this);
  }

  _handleMessage(ServiceActionEvent event) {
    // TODO(ericarnold): Initialize each requested ServiceImpl subclass as
    //    requested by the sender and add listeners to them to facilitate
    //    two-way communication.
    // TODO(ericarnold): Route ActionEvent by serviceId to the appropriate
    //    ServiceImpl instance.
  }


  // Sends a response message.
  Future<ServiceActionEvent> _sendResponse(ServiceActionEvent event, Map data,
      [bool expectResponse = false]) {
    event.response = true;
    var eventMap = event.toMap();
    _sendPort.send(eventMap);
  }

  // Sends action to host.  Returns a future if expectResponse is true.
  Future<ServiceActionEvent> _sendAction(String serviceId, String actionId, Map data,
      [bool expectResponse = false]) {
    // TODO(ericarnold):
    // - Create call id
    // - send message
    // - implement on other end
  }
}

class ExampleServiceImpl extends ServiceImpl {
  String get serviceId => "example";
  ExampleServiceImpl(ServicesIsolate isolate) : super(isolate);

  Future<ServiceActionEvent> handleEvent(ServiceActionEvent event) {
    switch (event.actionId) {
      case "test":
        _sendResponse(event, {"a":"b"});
        break;
    }
    // TODO(ericarnold): Implement
  }
}


// Provides an abstract class and helper code for service implementations.
abstract class ServiceImpl {
  ServicesIsolate _isolate;
  String get serviceId => null;
  // TODO(ericarnold): Handle Instantiation messages
  // TODO(ericarnold): Handles each ActionEvent sent to it and provides
  // a uniform way for subclasses to route messages by actionId.
  ServiceImpl(this._isolate);

  Future<ServiceActionEvent> handleEvent(ServiceActionEvent event);

  _sendResponse(ServiceActionEvent event, Map data,
      [bool expectResponse = false]) {
    _isolate._sendResponse(event, data, expectResponse);
  }
}

// Prints are crashing isolate, so this will take over for the time being.
SendPort _printSendPort;
void print(var message) {
  // Host will know it's a print because it's a simple string instead of a map
  _printSendPort.send("$message");
}

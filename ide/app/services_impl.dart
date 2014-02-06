// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services_impl;

import 'dart:convert';
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
      _sendPort.send(arg);

      //String data = arg["data"];
      // TODO(ericarnold): differntiate between host and response messages ...
      //hostMessageController.add(new ActionEvent(
      //    arg["serviceId"], arg["actionId"], arg["callId"], JSON.decode(data)));
      //responseMessageController.add(new ActionEvent(
      //    arg["serviceId"], arg["actionId"], arg["callId"], JSON.decode(data)));
    });
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
    _sendPort.send({
      "serviceId": event.serviceId,
      "actionId": event.actionId,
      "callId": event.callId,
      "data": JSON.encode(data)});
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

// Provides an abstract class and helper code for service implementations.
class ServiceImpl {
  // TODO(ericarnold): Handle Instantiation messages
  // TODO(ericarnold): Handles each ActionEvent sent to it and provides
  // a uniform way for subclasses to route messages by actionId.
}

class PingServiceImpl extends ServiceImpl {

}

// Prints are crashing isolate, so this will take over for the time being.
SendPort _printSendPort;
void print(String message) {
  // Host will know it's a print because it's a simple string instead of a map
  _printSendPort.send("print $message");
}

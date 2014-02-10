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

  // Fired when host originates a message
  Stream<ServiceActionEvent> onHostMessage ;

  // Fired when host responds to message
  Stream<ServiceActionEvent> onResponseMessage;

  ChromeService chromeService;

  Future<ServiceActionEvent> _onResponseByCallId(String callId) {
    Completer<ServiceActionEvent> completer =
        new Completer<ServiceActionEvent>();
    onResponseMessage.listen((ServiceActionEvent event) {
      try {
        if (event.callId == callId) {
          completer.complete(event);
        }
      } catch(e) {
        print("exception: $e ${e.stackTrace}");
      }
    });
    return completer.future;
  }


  ServicesIsolate(this._sendPort) {
    chromeService = new ChromeService(this);

    StreamController<ServiceActionEvent> hostMessageController =
        new StreamController<ServiceActionEvent>.broadcast();
    StreamController<ServiceActionEvent> responseMessageController =
        new StreamController<ServiceActionEvent>.broadcast();

    onResponseMessage = responseMessageController.stream;
    onHostMessage = hostMessageController.stream;

    ReceivePort receivePort = new ReceivePort();
    _sendPort.send(receivePort.sendPort);

    receivePort.listen((arg) {
      try {
        if (arg is int) {
          _sendPort.send(arg);
        } else {
          ServiceActionEvent event = new ServiceActionEvent.fromMap(arg);
          if (event.response) {
            responseMessageController.add(event);
          } else {
            hostMessageController.add(event);
          }
        }
      } catch(e) {
        print("exception: $e ${e.stackTrace}");
      }
    });

    onHostMessage.listen((ServiceActionEvent event) {
      try {
        _handleMessage(event);
      } catch(e) {
        print("exception: $e ${e.stackTrace}");
      }
    });
  }

  ServiceImpl getService(String serviceId) {
    return new ExampleServiceImpl(this);
  }

  _handleMessage(ServiceActionEvent event) {
    ServiceImpl service = getService(event.serviceId);
    service.handleEvent(event).then((ServiceActionEvent responseEvent){
      if (responseEvent != null) {
        _sendResponse(responseEvent);
      }
    });
  }


  // Sends a response message.
  Future<ServiceActionEvent> _sendResponse(ServiceActionEvent event, [Map data,
      bool expectResponse = false]) {
    // TODO(ericarnold): implement expectResponse
    event.response = true;
    var eventMap = event.toMap();
    if (data != null) {
      eventMap['data'] = data;
    }
    _sendPort.send(eventMap);
  }

  // Sends action to host.  Returns a future if expectResponse is true.
  Future<ServiceActionEvent> _sendAction(ServiceActionEvent event,
      [bool expectResponse = false]) {
    var eventMap = event.toMap();
    _sendPort.send(eventMap);
    return _onResponseByCallId(event.callId);
  }
}

class ExampleServiceImpl extends ServiceImpl {
  String get serviceId => "example";
  ExampleServiceImpl(ServicesIsolate isolate) : super(isolate);

  Future<ServiceActionEvent> handleEvent(ServiceActionEvent event) {
    switch (event.actionId) {
      case "shortTest":
        return new Future.value(event.createReponse(
            {"response": "short${event.data['name']}"}));
        break;
      case "longTest":
        return _isolate.chromeService.delay(1000).then((_){
          return new Future.value(event.createReponse(
              {"response": "long${event.data['name']}"}));
        });
    }
  }
}

/**
 * Special service for calling back to chrome.
 */
class ChromeService {
  static int _topCallId = 0;
  ServicesIsolate _isolate;

  ChromeService(this._isolate);

  String _getNewCallId() => "iso_${_topCallId++}";
  ServiceActionEvent _createNewEvent(String actionId, [Map data]) {
    String callId = _getNewCallId();
    return new ServiceActionEvent("chrome", actionId, callId, data);
  }


  Future<ServiceActionEvent> delay(int milliseconds) {
    ServiceActionEvent delayEvent =
        _createNewEvent("delay", {"ms": milliseconds});
    delayEvent.serviceId = "chrome";
    return _isolate._sendAction(delayEvent);
  }
}

// Provides an abstract class and helper code for service implementations.
abstract class ServiceImpl {
  static int _topCallId = 0;

  ServicesIsolate _isolate;

  ServiceImpl(this._isolate);

  String get serviceId => null;

  String _getNewCallId() => "iso_${_topCallId++}";

  ServiceActionEvent _createNewEvent(String actionId, [Map data]) {
    String callId = _getNewCallId();
    return new ServiceActionEvent(serviceId, actionId, callId, data);
  }

  Future<ServiceActionEvent> handleEvent(ServiceActionEvent event);
}

// Prints are crashing isolate, so this will take over for the time being.
SendPort _printSendPort;
void print(var message) {
  // Host will know it's a print because it's a simple string instead of a map
  _printSendPort.send("$message");
}

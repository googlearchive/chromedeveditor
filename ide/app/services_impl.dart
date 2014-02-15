// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services_impl;

import 'dart:async';
import 'dart:html' as html;
import 'dart:isolate';
import 'dart:typed_data' as typed_data;

import 'lib/utils.dart';
import 'lib/compiler.dart';

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
  int _topCallId = 0;
  final SendPort _sendPort;

  // Fired when host originates a message
  Stream<ServiceActionEvent> onHostMessage ;

  // Fired when host responds to message
  Stream<ServiceActionEvent> onResponseMessage;

  ChromeService chromeService;
  Map<String, ServiceImpl> _serviceImplsById = {};
  static ServicesIsolate _instance;
  static ServicesIsolate get instance => _instance;

  Future<ServiceActionEvent> _onResponseByCallId(String callId) {
    Completer<ServiceActionEvent> completer =
        new Completer<ServiceActionEvent>();
    onResponseMessage.listen((ServiceActionEvent event) {
      try {
        if (event.callId == callId) {
          completer.complete(event);
        }
      } catch(e) {
        print("Service error: $e ${e.stackTrace}");
      }
    });
    return completer.future;
  }


  ServicesIsolate(this._sendPort) {
    _instance = this;
    chromeService = new ChromeService(this);

    StreamController<ServiceActionEvent> hostMessageController =
        new StreamController<ServiceActionEvent>.broadcast();
    StreamController<ServiceActionEvent> responseMessageController =
        new StreamController<ServiceActionEvent>.broadcast();

    onResponseMessage = responseMessageController.stream;
    onHostMessage = hostMessageController.stream;

    // Register each ServiceImpl:
    _registerServiceImpl(new CompilerServiceImpl(this));
    _registerServiceImpl(new ExampleServiceImpl(this));

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
        print("service error: $e ${e.stackTrace}");
      }
    });

    onHostMessage.listen((ServiceActionEvent event) {
      try {
        _handleMessage(event);
      } catch(e) {
        print("service error: $e ${e.stackTrace}");
      }
    });
  }

  void _registerServiceImpl(ServiceImpl serviceImplementation) {
    _serviceImplsById[serviceImplementation.serviceId] =
        serviceImplementation;
  }

  ServiceImpl getServiceImpl(String serviceId) {
    return _serviceImplsById[serviceId];
  }

  Future<ServiceActionEvent> _handleMessage(ServiceActionEvent event) {
    Completer<ServiceActionEvent> completer =
        new Completer<ServiceActionEvent>();

    ServiceImpl service = getServiceImpl(event.serviceId);
    service.handleEvent(event).then((ServiceActionEvent responseEvent){
      if (responseEvent != null) {
        _sendResponse(responseEvent);
        completer.complete();
      }
    });
    return completer.future;
  }


  // Sends a response message.
  void _sendResponse(ServiceActionEvent event, [Map data,
      bool expectResponse = false]) {
    // TODO(ericarnold): implement expectResponse
    event.response = true;
    var eventMap = event.toMap();
    if (data != null) {
      eventMap['data'] = data;
    }
    _sendPort.send(eventMap);
  }

  String _getNewCallId() => "iso_${_topCallId++}";

  // Sends action to host.  Returns a future if expectResponse is true.
  Future<ServiceActionEvent> _sendAction(ServiceActionEvent event,
      [bool expectResponse = false]) {

    event.makeRespondable(_getNewCallId());

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
      default:
        throw "Unknown action '${event.actionId}' sent to $serviceId service.";
    }
  }
}


class CompilerServiceImpl extends ServiceImpl {
  String get serviceId => "compiler";

  Compiler _compiler;
  Completer<ServiceActionEvent> _readyCompleter =
      new Completer<ServiceActionEvent>();

  Future<ServiceActionEvent> get onceReady => _readyCompleter.future;

  CompilerServiceImpl(ServicesIsolate isolate) : super(isolate);

  Future<ServiceActionEvent> handleEvent(ServiceActionEvent event) {
    switch (event.actionId) {
      case "start":
        return _start().then((_) => new Future.value(event.createReponse(null)));
        break;
      case "dispose":
        try {
          _compiler.dispose();
        } catch(error) {
          // TODO(ericarnold): Return error which service will throw
          print("Chrome service error: $error ${error.stackTrace}");
        }

        return new Future.value(event.createReponse(null));
        break;
      case "compileString":
        return _compiler.compileString(event.data['string'])
            .then((CompilerResult result)  {
              return new Future.value(event.createReponse(result.toMap()));
            });
        break;
      default:
        throw "Unknown action '${event.actionId}' sent to $serviceId service.";
    }
  }

  Future _start() {
    return Compiler.createCompiler().then((Compiler newCompler) {
//      ServiceActionEvent responseEvent = event.createReponse(null);
      _compiler = newCompler;
      _readyCompleter.complete();
//      return responseEvent;
      return null;
    }).catchError((error){
      // TODO(ericarnold): Return error which service will throw
      print("Chrome service error: $error ${error.stackTrace}");
    });
  }
}

/**
 * Special service for calling back to chrome.
 */
class ChromeService {
  ServicesIsolate _isolate;

  /**
   * Return the contents of the file at the given path. The path is relative to
   * the Chrome app's directory.
   */
  static Future<List<int>> getAppContentsBinary(String path) {
    return ServicesIsolate.instance.chromeService.getURL(path)
        .then((String url) => html.HttpRequest.request(
        url, responseType: 'arraybuffer'))
    .then((request) {
      typed_data.ByteBuffer buffer = request.response;
      return new typed_data.Uint8List.view(buffer);
    });
  }


  ChromeService(this._isolate);

  ServiceActionEvent _createNewEvent(String actionId, [Map data]) {
    return new ServiceActionEvent("chrome", actionId, data);
  }

  Future<ServiceActionEvent> delay(int milliseconds) =>
      _isolate._sendAction(_createNewEvent("delay", {"ms": milliseconds}));

  Future<String> getURL(String path) =>
      _isolate._sendAction(_createNewEvent("getURL", {"path": path}))
      .then((ServiceActionEvent event) => event.data['url']);
}

// Provides an abstract class and helper code for service implementations.
abstract class ServiceImpl {
  ServicesIsolate _isolate;

  ServiceImpl(this._isolate);

  String get serviceId => null;

  Future<ServiceActionEvent> handleEvent(ServiceActionEvent event);
}

// Prints are crashing isolate, so this will take over for the time being.
SendPort _printSendPort;
void print(var message) {
  // Host will know it's a print because it's a simple string instead of a map
  if (_printSendPort != null) {
    _printSendPort.send("$message");
  }
}

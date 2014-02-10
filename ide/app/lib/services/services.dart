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
  _IsolateHandler _isolateHandler;
  Map<String, Service> _services = {};

  Services() {
    _isolateHandler = new _IsolateHandler();
    registerService(new ExampleService(this, _isolateHandler));
    registerService(new ChromeServiceImpl(this, _isolateHandler));
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


class ExampleService extends Service {
  String serviceId = "example";

  ExampleService(Services services, _IsolateHandler handler)
      : super(services, handler);

  Future<String> shortTest(String name) {
    return _sendAction("shortTest", {"name": name})
        .then((ServiceActionEvent event) {
      return new Future.value(event.data['response']);
    });
  }

  Future<String> longTest(String name) {
    return _sendAction("longTest", {"name": name})
        .then((ServiceActionEvent event) {
      return new Future.value(event.data['response']);
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
      : super(services, handler) {
    handler.onIsolateMessage.listen((ServiceActionEvent event){
      if (event.serviceId == serviceId) {
        _receiveAction(event);
      }
    });
  }

  // For incoming (non-requested) actions.
  Future<ServiceActionEvent> _receiveAction(ServiceActionEvent event) {
    switch(event.actionId) {
      case "delay":
        int milliseconds = event.data['ms'];
        new Future.delayed(new Duration(milliseconds: milliseconds))
            .then((_) {
              ServiceActionEvent response = event.createReponse(null);
              _sendResponse(response);
            });
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
  Stream onIsolateMessage;

  // Future to fire once, when isolate is started and ready to receive messages.
  // Usage: onceIsolateReady.then() => // do stuff
  Future onceIsolateReady;
  StreamController _readyController = new StreamController.broadcast();

  _IsolateHandler() {
    onceIsolateReady = _readyController.stream.first;
    _startIsolate();
  }

  String _getCallId(String callId) => "host_${callId}";
  String _getNewCallId() => "host_${_getCallId(_topCallId++)}";

  // Fired when isolate responds to message
  Future<ServiceActionEvent> onIsolateResponse(String callId) {
    Completer<ServiceActionEvent> completer =
        new Completer<ServiceActionEvent>();

    _serviceCallCompleters[callId] = completer;


    onIsolateMessage.listen((ServiceActionEvent event){
      if (event.response && event.callId == callId) {
        completer.complete(event);
      }
    });

    return completer.future;
  }

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
          _messageController.add(event);
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
    Completer completer = _serviceCallCompleters["ping_$id"];
    _serviceCallCompleters.remove(id);
    completer.complete("pong");
    return completer.future;
  }

  Future<ServiceActionEvent> sendAction(ServiceActionEvent event) {
    event.makeRespondable(_getNewCallId());
    _sendPort.send(event.toMap());
    return onIsolateResponse(event.callId);
  }

  Future<ServiceActionEvent> sendResponse(ServiceActionEvent event) {
    _sendPort.send(event.toMap());
    return onIsolateResponse(event.callId);
  }
}


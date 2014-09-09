// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services_bootstrap;

import 'dart:async';

import 'services_common.dart';
import 'services_impl.dart' as services_impl;

IsolateHandler createIsolateHandler() {
  return new _IsolateHandlerSingleThreadImpl();  
}

class StreamWorkerPort implements WorkerPort {
  final StreamController _hostStreamController = new StreamController();
  final StreamController _workerStreamController = new StreamController();

  @override
  void sendToHost(dynamic message) {
    _hostStreamController.add(message);
  }
  
  @override
  void listenFromHost(void onData(var message)) {
    _workerStreamController.stream.listen(onData);    
  }

  void sendToWorker(dynamic message) {
    _workerStreamController.add(message);
  }
  
  void listenFromWorker(void onData(var message)) {
    _hostStreamController.stream.listen(onData);    
  }
}

/**
 * Implements [IsolateHandler] where the worker runs on the same isolate
 * as the host. This is used for debuggin/testing only.
 */
class _IsolateHandlerSingleThreadImpl implements IsolateHandler {
  int _topCallId = 0;
  final Map<String, Completer> _serviceCallCompleters = {};
  final StreamController _readyController = new StreamController.broadcast();
  final StreamController<ServiceActionEvent> _messageController =
      new StreamController<ServiceActionEvent>.broadcast();
  final StreamWorkerPort _port = new StreamWorkerPort();

  Stream<ServiceActionEvent> onIsolateMessage;
  Future onceIsolateReady;
  
  _IsolateHandlerSingleThreadImpl() {
     _port.listenFromWorker(_onWorkerMessage);
    onIsolateMessage = _messageController.stream;
    onceIsolateReady = _readyController.stream.first;
    
    services_impl.init(_port);
    
    // The worker is immediately ready to process messages.
    // TODO(rpaquay): Is this correct?
    _readyController..add(null)..close();
  }

  /**
   * Called when a message from the worker process is received.
   * Dispatches [message] to appropriate host component.
   */
  void _onWorkerMessage(dynamic message) {
    if (message is String) {
      // String: handle as print
      print(message);
    } else if (message is int) {
      // int: handle as ping
      _pong(message);
    } else {
      ServiceActionEvent event = new ServiceActionEvent.fromMap(message);

      if (event.response == true) {
        Completer<ServiceActionEvent> completer =
            _serviceCallCompleters.remove(event.callId);
        assert(completer != null);
        if (event.error) {
          completer.completeError(event.getErrorMessage());
        } else {
          completer.complete(event);
        }
      } else {
        _messageController.add(event);
      }
    }
  }
  
  @override
  Future<String> ping() {
    Completer<String> completer = new Completer();
    
    int callId = _topCallId;
    _serviceCallCompleters["ping_$callId"] = completer;
    onceIsolateReady.then((_) {
      _port.sendToHost(callId);
    });
    _topCallId += 1;
    
    return completer.future;
  }

  void _pong(int id) {
    Completer completer = _serviceCallCompleters.remove("ping_$id");
    completer.complete("pong");
  }

  String _getNewCallId() => "host_${_topCallId++}";
  
  @override
  Future<ServiceActionEvent> sendAction(ServiceActionEvent event) {
    Completer<ServiceActionEvent> completer =
        new Completer<ServiceActionEvent>();

    event.makeRespondable(_getNewCallId());
    _serviceCallCompleters[event.callId] = completer;
    _port.sendToWorker(event.toMap());

    return completer.future;
  }

  @override
  void sendResponse(ServiceActionEvent event) {
    _port.sendToWorker(event.toMap());
  }

  @override
  void dispose() {
    // TODO(rpaquay)
  }
}

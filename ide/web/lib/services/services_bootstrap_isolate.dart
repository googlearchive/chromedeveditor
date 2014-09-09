// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services_bootstrap;

import 'dart:async';
import 'dart:isolate';

import 'services_common.dart';

HostToWorkerHandler createHostToWorkerHandler() {
  return new _IsolateHostToWorkerHandler();  
}

/**
 * Implements [HostToWorkerHandler] as the regular IPC from the host to the [Isolate]
 * worker implementing the services..
 */
class _IsolateHostToWorkerHandler implements HostToWorkerHandler {
  final String _workerPath = 'services_entry.dart';
  final Map<String, Completer> _serviceCallCompleters = {};
  final StreamController _readyController = new StreamController.broadcast();
  final ReceivePort _receivePort = new ReceivePort();

  int _topCallId = 0;
  Isolate _isolate;
  SendPort _sendPort;
  
  @override
  Stream<ServiceActionEvent> onWorkerMessage;

  @override
  Future onceWorkerReady;
  
  _IsolateHostToWorkerHandler() {
    onceWorkerReady = _readyController.stream.first;
    _startIsolate().then((result) => _isolate = result);
  }

  String _getNewCallId() => "host_${_topCallId++}";

  Future<Isolate> _startIsolate() {
    StreamController<ServiceActionEvent> _messageController =
        new StreamController<ServiceActionEvent>.broadcast();

    onWorkerMessage = _messageController.stream;

    _receivePort.listen((arg) {
      if (arg is String) {
        // String: handle as print
        print(arg);
      } else if (_sendPort == null) {
        _sendPort = arg;
        _readyController..add(null)..close();
      } else if (arg is int) {
        // int: handle as ping
        _pong(arg);
      } else {
        ServiceActionEvent event = new ServiceActionEvent.fromMap(arg);

        if (event.response == true) {
          Completer<ServiceActionEvent> completer =
              _serviceCallCompleters.remove(event.callId);
          if (event.error) {
            completer.completeError(event.getErrorMessage());
          } else {
            completer.complete(event);
          }
        } else {
          _messageController.add(event);
        }
      }
    });

    return Isolate.spawnUri(Uri.parse(_workerPath), [], _receivePort.sendPort);
  }

  @override
  Future<String> ping() {
    Completer<String> completer = new Completer();

    int callId = _topCallId;
    _serviceCallCompleters["ping_$callId"] = completer;

    onceWorkerReady.then((_) {
      _sendPort.send(callId);
    });

    _topCallId += 1;
    return completer.future;
  }

  Future _pong(int id) {
    Completer completer = _serviceCallCompleters.remove("ping_$id");
    completer.complete("pong");
    return completer.future;
  }

  @override
  Future<ServiceActionEvent> sendAction(ServiceActionEvent event) {
    Completer<ServiceActionEvent> completer =
        new Completer<ServiceActionEvent>();

    event.makeRespondable(_getNewCallId());
    _serviceCallCompleters[event.callId] = completer;
    _sendPort.send(event.toMap());

    return completer.future;
  }

  @override
  void sendResponse(ServiceActionEvent event) {
    _sendPort.send(event.toMap());
  }

  // TODO: I'm not entirely sure how to terminate an isolate...
  @override
  void dispose() { }
}

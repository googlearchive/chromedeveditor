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
  int _serviceCallId = 0;
  Map<int, Completer> _serviceCallCompleters = {};
  final String _workerPath = 'lib/services/services_impl.dart';
  SendPort _sendPort;
  final ReceivePort _receivePort = new ReceivePort();
  StreamController _readyController = new StreamController.broadcast();
  bool _ready = false;

  Services() {
    _startIsolate();
  }

  Stream get _onWorkerReady => _readyController.stream;

  Future _startIsolate() {
    Completer completer = new Completer();
    _receivePort.listen((arg) {
      if (_sendPort == null) {
        _sendPort = arg;
        _readyController.add(null);
        _readyController.close();
      } else {
        pong(arg);
      }
    });

    Isolate.spawnUri(Uri.parse(_workerPath), [], _receivePort.sendPort);

    return completer.future;
  }

  Future pong(int id) {
    Completer completer = _serviceCallCompleters[id];
    _serviceCallCompleters.remove(id);
    completer.complete("pong");
  }

  Future<String> ping() {
    Completer<String> completer = new Completer();
    if (_ready) {
      return _ping(completer);
    } else {
      _onWorkerReady.listen((_)=>_ping(completer));
    }
    _serviceCallCompleters[_serviceCallId] = completer;
    return completer.future;
  }

  _ping(Completer completer) {
    _sendPort.send(_serviceCallId++);
  }
}


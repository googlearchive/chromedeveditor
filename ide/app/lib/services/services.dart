// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
library spark.services;

import 'dart:async';
import 'dart:isolate';

/**
 * Defines a class which contains services and handles their communication.
 */
class Services {
  final String _workerPath = 'lib/services/services_impl.dart';

  SendPort _sendPort;
  final ReceivePort _receivePort = new ReceivePort();
  ServiceHandler _handler;

  Services() {
    _startIsolate().then((_)=>_handler = new ServiceHandler(_sendPort));
  }

  Future _startIsolate() {
    Completer completer = new Completer();
    _receivePort.listen((arg) {
      if (_sendPort == null) {
        _sendPort = arg;
        completer.complete();
      } else {
        print('Received from isolate: $arg\n');
      }
    });

    Isolate.spawnUri(Uri.parse(_workerPath), [], _receivePort.sendPort);

    return completer.future;
  }
}

class ServiceHandler {
  SendPort _sendPort;

  ServiceHandler(this._sendPort) {
    sendAction("ping", "Foo");
  }

  // TODO(ericarnold): Complete a future / stream.
  void sendAction(String id, [String data = ""]) {
    _sendPort.send({"id": id, "data": data});
  }
}


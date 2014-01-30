// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services;

import 'dart:isolate';

/**
 * This is a separate application spawned by Spark (via Services) as an isolate
 * for use in running long-running / heaving tasks.
 */
void main(List<String> args, SendPort sendPort) {
  final ServicesIsolate servicesIsolate = new ServicesIsolate(sendPort);
}

class ServicesIsolate {
  final SendPort _sendPort;
  ReceivePort _receivePort = new ReceivePort();
  ServicesIsolate(this._sendPort) {
    _sendPort.send(_receivePort.sendPort);
    _receivePort.listen((int arg) {
      _sendPort.send(arg);
    });
  }
}



// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
library spark.services;

import 'dart:isolate';

import 'services.dart';

void main(List<String> args, SendPort sendPort) {
  final ServicesIsolate servicesIsolate = new ServicesIsolate(sendPort);
}

/**
 * This is a separate application spawned by Spark (via Services) as an isolate
 * for use in running long-running / heaving tasks.
 */
class ServicesIsolate {
  final SendPort sendPort;
  ServiceHandler handler;

  ServicesIsolate(this.sendPort) {
    print("This statement makes me crash"); // Remove this and isolate runs.
    ReceivePort receivePort = new ReceivePort();
    sendPort.send(receivePort.sendPort);
    handler = new ServiceHandler.worker(receivePort, sendPort);
  }
}



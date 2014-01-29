import 'dart:isolate';

import 'services.dart';

main(List<String> args, SendPort sendPort) {
  final servicesIsolate = new ServicesIsolate(sendPort);
}

class ServicesIsolate {
  SendPort sendPort;
  ServiceHandler handler;

  ServicesIsolate(this.sendPort) {
    ReceivePort receivePort = new ReceivePort();
    sendPort.send(receivePort.sendPort);
    handler = new ServiceHandler.worker(receivePort, sendPort);
  }
}



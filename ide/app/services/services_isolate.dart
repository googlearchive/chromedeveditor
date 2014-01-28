import 'dart:isolate';

import 'package:serialization/serialization.dart';

import 'services.dart';

main(List<String> args, SendPort sendPort) {
  final servicesIsolate = new ServicesIsolate();

  ReceivePort receivePort = new ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    message.
//    switch (message) {
//      // TODO(ericarnold): Testing.  Remove.
//      case "say":
//        servicesIsolate.say(mesage);
//    }
    sendPort.send('$message - From isolate: "Polo!"');
  });
}

class ServicesIsolate {
  ServicesIsolate();

  // TODO(ericarnold): Testing.  Remove.
  say(String message) {
    return "Polo!";
  }
}
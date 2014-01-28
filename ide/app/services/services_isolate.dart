import 'dart:isolate';

import 'services.dart';

main(List<String> args, SendPort sendPort) {
  final servicesIsolate = new ServicesIsolate(sendPort);


}

class ServicesIsolate {
  SendPort sendPort;

  ServicesIsolate(this.sendPort) {
    ReceivePort receivePort = new ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((command) {
      performCommand(command);
    });
  }

  sendCommand(Command command) {
    sendPort.send({"id": command.commandId, "data": command.serialize()});
  }


  void performCommand(command) {
    String commandId = command.commandId;
    String serializedData = command.data;

    switch (commandId) {
      // TODO(ericarnold): Testing.  Remove.
      case "message":
        TestMessage message = new TestMessage.serialized(serializedData);
        if (message.toString() == 'Marco!') {
          sendCommand(new TestMessage('Polo')..volume = 11);
        }
        break;
    }
  }
  // TODO(ericarnold): Testing.  Remove.
  say(String message) {
    return "Polo!";
  }
}
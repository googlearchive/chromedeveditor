import 'dart:isolate';
import 'dart:async';
import 'dart:convert';


class Services {
  final String workerPath = 'services/services_isolate.dart';
  ServiceHandler handler;
  SendPort sendPort;
  final ReceivePort receivePort = new ReceivePort();

  Services() {
    handler = new ServiceHandler(receivePort);
    handler.listenForSendPort(workerPath).then((_){
      new Timer.periodic(const Duration(seconds: 1), (t) {
        print("Sending Message!");
        TestMessage command = new TestMessage.yell('Marco');

        handler.sendCommand(command);
      });
    });
  }
}


class ServiceHandler {
  SendPort sendPort;
  ReceivePort receivePort;

  Future listenForSendPort(String workerPath) {
    Completer completer = new Completer();
    receivePort.listen((msg) {
      /*%TRACE3*/ print("(4> 1/28/14): listen!"); // TRACE%
      if (sendPort == null) {
        sendPort = msg;
        completer.complete();
      } else {
        performCommand(msg);
      }
    });

    Uri workerUri = Uri.parse(workerPath);

    Isolate.spawnUri(workerUri, [], receivePort.sendPort);
    return completer.future;
  }

  ServiceHandler(this.receivePort, [this.sendPort]) {
    if (sendPort != null) {
      receivePort.listen((command) {
        performCommand(command);
      });
    }
  }

  sendCommand(Command command) {
    sendPort.send({"id": command.commandId, "data": command.serialize()});
  }

  void performCommand(command) {
    String commandId = command["id"];
    String serializedData = command["data"];

    switch (commandId) {
      // TODO(ericarnold): Testing.  Remove.
      case "message":
        sendCommand(new TestMessage.serialized(serializedData).respond());
        break;
    }
  }
}

abstract class Command {
  Command();
  Command.serialized(String serializedData);
  String get commandId;
  String serialize();
  Command respond();
}

// TODO(ericarnold): Testing.  Remove.
class TestMessage extends Command{
  String message;
  int volume;

  TestMessage();
  TestMessage.yell(this.message);

  TestMessage.serialized(String serializedData) {
    var data = JSON.decode(serializedData);
    this.message = data['message'];
    this.volume = data['volume'];
  }

  TestMessage respond() {
    if (message == 'Marco!') {
      return new TestMessage.yell('Polo');
    }
  }

  String get commandId => "message";

  String toString() {
    return message + ((volume > 10) ? "!" : "");
  }

  String serialize() {
    return JSON.encode({
      "message": message,
      "volume": volume
    });
  }
}

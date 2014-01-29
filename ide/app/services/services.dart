import 'dart:isolate';
import 'dart:async';
import 'dart:convert';


class Services {
  final String workerPath = 'services/services_isolate.dart';
  ServiceHandler handler;
  SendPort sendPort;
  final ReceivePort receivePort = new ReceivePort();

  Services() {
    handler = new ServiceHandler.owner(receivePort);
    handler.listenForSendPort(workerPath).then((_){
      new Timer.periodic(const Duration(seconds: 1), (t) {
        print("Sending 'Marco!'");
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
    receivePort.listen((parameter) {
      if (sendPort == null) {
        sendPort = parameter;
        completer.complete();
      } else {
        performCommand(parameter);
      }
    });

    Uri workerUri = Uri.parse(workerPath);

    Isolate.spawnUri(workerUri, [], receivePort.sendPort);
    return completer.future;
  }

  bool isWorker = false;
  ServiceHandler.worker(this.receivePort, this.sendPort) {
    isWorker = true;
    receivePort.listen((command) {
      performCommand(command);
    });
  }

  ServiceHandler.owner(this.receivePort);

  sendCommand(Command command) {
    sendPort.send({
        "response": false,
        "id": command.commandId,
        "data": command.serialize()});
  }

  void performCommand(command) {
    bool isResponse = command["response"];
    String commandId = command["id"];
    String serializedData = command["data"];

    switch (commandId) {
      // TODO(ericarnold): Testing.  Remove.
      case "message":
        handleCommand(new TestMessage.serialized(serializedData), isResponse);
        break;
    }
  }

  handleCommand(Command command, bool isResponse) {
    if (isResponse) {
      // TODO(ericarnold): Complete a future
      print("response: " + command.toString());
    } else {
      sendResponse(command);
    }
  }

  sendResponse(Command command) {
    Command responseObject = command.respond();
    sendPort.send({
        "response": true,
        "id": responseObject.commandId,
        "data": responseObject.serialize()});
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
  TestMessage.yell(this.message) {
    this.volume = 11;
  }

  TestMessage.serialized(String serializedData) {
    var data = JSON.decode(serializedData);
    this.message = data['message'];
    this.volume = data['volume'];
  }

  TestMessage respond() {
    if (toString() == 'Marco!') {
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

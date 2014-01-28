import 'dart:isolate';
import 'dart:async';
import 'dart:convert';


class Services {
  final String workerPath = 'services/services_isolate.dart';
  SendPort sendPort;

  Services() {
    final ReceivePort receivePort = new ReceivePort();

    receivePort.listen((parameter) {
      if (sendPort == null) {
        sendPort = parameter;
      } else {
        String message = parameter;
        print('$message\n');
      }
    });

    Uri workerUri = Uri.parse(workerPath);

    Isolate.spawnUri(workerUri, [], receivePort.sendPort).then((isolate) {
      TestMessage command = new TestMessage('Marco')
        ..volume = 11;

      Timer.run(() => sendCommand(command));
    });
  }

  sendCommand(Command command) {
    sendPort.send({"id": command.commandId, "data": command.serialize()});
  }
}

abstract class Command {
  String get commandId;
  String serialize();
  Command();
  Command.serialized(String serializedData);
}

// TODO(ericarnold): Testing.  Remove.
class TestMessage extends Command{
  String message;
  int volume;

  TestMessage(this.message);

  TestMessage.serialized(String serializedData) {
    var data = JSON.decode(serializedData);
    this.message = data.message;
    this.volume = data.volume;
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

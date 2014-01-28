import 'package:serialization/serialization.dart';

import 'dart:isolate';
import 'dart:async';

class Services {
  final String workerPath = 'services/services_isolate.dart';

  Services() {
    final ReceivePort receivePort = new ReceivePort();
    SendPort sendPort;

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
      Say command = new Say();
      command.message = 'Marco';
      // TODO(ericarnold): Sending shared-code object instances is supported
      //    only by dartvm not by dart2js.  If / when that changes, we can
      //    remove Serialization dependency.
      //    See https://api.dartlang.org/docs/channels/stable/latest/dart_isolate/SendPort.html#send
      var serialization = new Serialization()
          ..addRule(new SayRule());
      Map output = serialization.write(command);

      Timer.run(() => sendPort.send(output));
    });
  }
}

abstract class Command {
}

class Say extends Command{
  String message;
  int volume;
  String toString() {
    return message + ((volume >= 11) ? "!" : "");
  }
}

class SayRule extends CustomRule {
  bool appliesTo(instance, Writer w) => instance.runtimeType == Say;
  getState(Say instance) => [instance.message, instance.volume];
  create(state) => new Say();
  setState(Say a, List state) {
    a.message = state[0];
    a.volume = state[1];
  }
}

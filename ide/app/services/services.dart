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
        print('message\n');
      }
    });

    Uri workerUri = Uri.parse(workerPath);

    Isolate.spawnUri(workerUri, [], receivePort.sendPort).then((isolate) {
      Timer.run(() => sendPort.send('From app: "Marco!"'));
    });
  }
}
import 'dart:isolate';
import 'dart:async';

main() {
  var s = new Services('services_isolate.dart');
}

class Services {
  int counter = 0;

  Services([String workerPath = 'services/services_isolate.dart']) {
    print("Services instantiated!");
    SendPort sendPort;

    ReceivePort receivePort = new ReceivePort();
    receivePort.listen((msg) {
      print("Spark never gets here!");
      if (sendPort == null) {
        sendPort = msg;
        new Timer.periodic(const Duration(seconds: 1), (t) {
          print("Sending Message!");
          sendPort.send('From app: ${counter++}');
        });
      } else {
        print('Received from isolate: $msg\n');
      }
    });


    Isolate.spawnUri(Uri.parse(workerPath), [], receivePort.sendPort).then((isolate) {
      print('Isolate spawned');
    });
  }
}
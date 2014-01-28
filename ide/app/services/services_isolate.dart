import 'dart:isolate';

main(List<String> args, SendPort sendPort) {
  ReceivePort receivePort = new ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    sendPort.send('$message - From isolate: "Polo!"');
  });
}

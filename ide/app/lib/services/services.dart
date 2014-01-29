// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
library spark.services;

import 'dart:isolate';
import 'dart:async';
import 'dart:convert';

/**
 * Defines a class which contains services and handles their communication.
 */
class Services {
  final String _workerPath = 'lib/services/services_isolate.dart';
  ServiceHandler _handler;
  SendPort _sendPort;
  final ReceivePort _receivePort = new ReceivePort();

  void ping() {
    TestMessage command = new TestMessage.yell('Marco');
    print("Sending '$command'");
    _handler.sendCommand(command);
  }

  Services() {
    _handler = new ServiceHandler.owner(_receivePort);

    // TODO(ericarnold): Provide an onReady handler
    _handler.listenForSendPort(_workerPath).then((_){
      ping();
    });
  }
}

/**
 * Defines a handler for isolates which is unified between worker and origin.
 */
class ServiceHandler {
  SendPort _sendPort;
  ReceivePort _receivePort;
  bool _isWorker = false;

  ServiceHandler.worker(this._receivePort, this._sendPort) {
    _isWorker = true;
    _receivePort.listen((command) {
      performCommand(command);
    });
  }

  ServiceHandler.owner(this._receivePort);

  Future listenForSendPort(String workerPath) {
    Completer completer = new Completer();
    _receivePort.listen((parameter) {
      if (_sendPort == null) {
        _sendPort = parameter;
        completer.complete();
      } else {
        performCommand(parameter);
      }
    });

    Uri workerUri = Uri.parse(workerPath);

    Isolate.spawnUri(workerUri, [], _receivePort.sendPort);
    return completer.future;
  }

  Future sendCommand(Command command) {
    _sendPort.send({
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

  void handleCommand(Command command, bool isResponse) {
    if (isResponse) {
      // TODO(ericarnold): Complete a future (returned by sendCommand)/
      print("response: " + command.toString());
    } else {
      sendResponse(command);
    }
  }

  void sendResponse(Command command) {
    Command responseObject = command.respond();
    _sendPort.send({
        "response": true,
        "id": responseObject.commandId,
        "data": responseObject.serialize()});
  }
}

/**
 * Defines an abstract class whose interface is identical at the origin and the
 * worker, but which provides functionality only on the responder and acts as a
 * simple proxy on the other end.
 */
abstract class Command {
  Command();
  Command.serialized(String serializedData);
  String get commandId;
  String serialize();
  Command respond();
}

/**
 * Sample Command usage
 */
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

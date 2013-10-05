// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * TODO:
 */
library spark.tcp;

import 'dart:async';

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;
export 'package:chrome_gen/chrome_app.dart' show SocketInfo;

const LOCAL_HOST = '127.0.0.1';

// TODO(devoncarew): these classes are fairly generic; explore contributing them
// to package:chrome_gen, or to a new utility library for chrome functionalty,
// build on chrome_gen? chrome_util?

/**
 * TODO:
 */
class SocketException implements Exception {
  final String message;

  const SocketException([this.message = ""]);

  String toString() => "SocketException: $message";
}

// StreamController

/**
 * TODO:
 */
class TcpClient {
  String host;
  int port;

  int _socketId;

  static Future<TcpClient> createClient(String host, int port) {
    return chrome_gen.socket.create(chrome_gen.SocketType.TCP).then((chrome_gen.CreateInfo createInfo) {
      int socketId = createInfo.socketId;

      return chrome_gen.socket.connect(socketId, host, port).then((int result) {
        if (result < 0) {
          chrome_gen.socket.destroy(socketId);
          throw new SocketException('unable to connect to ${host} ${port}: ${result}');
        } else {
          return new TcpClient._fromSocketId(socketId);
        }
      });
    });
  }

  TcpClient._fromSocketId(this._socketId) {
    chrome_gen.socket.getInfo(_socketId).then((chrome_gen.SocketInfo socketInfo) {
      // TODO: the host and port info won't be immediately available
      host = socketInfo.peerAddress;
      port = socketInfo.peerPort;
    });
  }

  void dispose() {
    chrome_gen.socket.disconnect(_socketId);
  }

  Future<chrome_gen.SocketWriteInfo> send(String message) {
    return chrome_gen.socket.write(
        _socketId, new chrome_gen.ArrayBuffer.fromString(message));
  }

//  void _setupDataPoll() {
//    _intervalHandle =
//        new Timer.periodic(const Duration(milliseconds: 500), _read);
//  }

//  OnReceived receive; // passed a String
//  OnReadTcpSocket onRead; // passed a SocketReadInfo
//
//  void _read(Timer timer) {
//    _logger.fine("enter: read()");
//    Socket.read(_createInfo.socketId).then((SocketReadInfo readInfo) {
//      if (readInfo == null) {
//        return;
//      }
//
//      _logger.fine("then: read()");
//      if (onRead != null) {
//        onRead(readInfo);
//      }
//
//      if (receive != null) {
//        // Convert back to string and invoke receive
//        // Might want to add this kind of method
//        // onto SocketReadInfo
//        /*
//        var blob =
//            new html.Blob([new html.Uint8Array.fromBuffer(readInfo.data)]);
//        var fileReader = new html.FileReader();
//        fileReader.on.load.add((html.Event event) {
//          _logger.fine("fileReader.result = ${fileReader.result}");
//          receive(fileReader.result);
//        });
//        fileReader.readAsText(blob);
//        */
//        _logger.fine(readInfo.data.toString());
//        var str = new String.fromCharCodes(
//            new typed_data.Uint8List.view(readInfo.data));
//        //_logger.fine("receive(str) = ${str}");
//        receive(str, this);
//      }
//    });
//  }

}

/**
 * TODO:
 */
class TcpServer {
  int _socketId;
  StreamController<TcpClient> _controller;

  static Future<TcpServer> createServerSocket([int port = 0]) {
    return chrome_gen.socket.create(chrome_gen.SocketType.TCP).then((chrome_gen.CreateInfo info) {
      int socketId = info.socketId;

      return chrome_gen.socket.listen(socketId, LOCAL_HOST, port, 5).then((int result) {
        if (result < 0) {
          chrome_gen.socket.destroy(socketId);
          throw new SocketException('unable to listen on port ${port}: ${result}');
        } else {
          return new TcpServer._(socketId);
        }
      });
    });
  }

  TcpServer._(this._socketId) {
    _controller = new StreamController(onListen: _accept);
  }

  Stream<TcpClient> get onAccept => _controller.stream;

  Future<chrome_gen.SocketInfo> getInfo() => chrome_gen.socket.getInfo(_socketId);

  void dispose() {
    chrome_gen.socket.destroy(_socketId);
  }

  void _accept() {
    chrome_gen.socket.accept(_socketId).then((chrome_gen.AcceptInfo info) {
      if (info.resultCode == 0) {
        _controller.add(new TcpClient._fromSocketId(info.socketId));
        _accept();
      } else {
        _controller.addError(info.resultCode);
        _controller.close();
      }
    });
  }
}

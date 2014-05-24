// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Lightweight implementations of a tcp clients and servers. This library serves
 * as a higher level abstraction over the `chrome.socket` APIs.
 *
 * See also:
 *
 * * [developer.chrome.com/apps/socket.html](http://developer.chrome.com/apps/socket.html)
 * * [dart-gde.github.io/chrome.dart/app/chrome.socket.html](http://dart-gde.github.io/chrome.dart/app/chrome.socket.html)
 */
library spark.tcp;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;
export 'package:chrome/chrome_app.dart' show SocketInfo;

const LOCAL_HOST = '127.0.0.1';

/**
 * An [Exception] implementation for socket errors.
 */
class SocketException implements Exception {
  final String message;
  final int code;

  const SocketException([this.message = "", this.code = 0]);

  String toString() => "SocketException: $message";
}

/**
 * A wrapper around the `chrome.socket` APIs used to read and write data to a
 * socket.
 *
 * ## Usage:
 *
 *     TcpCLient.createClient();
 *     stream.listen();
 *     sink.add(data);
 *     dispose();
 */
class TcpClient {
  /**
   * A map from client socketIds to StreamControllers. We're notified about
   * incoming data based on the socketId. We want to use that information to
   * notify the correct StreamController.
   */
  static Map<int, StreamController> _clientMap;

  Future _lastWrite = new Future.value();
  final int _socketId;

  static Future<TcpClient> createClient(String host, int port,
      {bool throwOnError: true}) {
    return chrome.sockets.tcp.create().then((chrome.CreateInfo createInfo) {
      int socketId = createInfo.socketId;

      return chrome.sockets.tcp.connect(socketId, host, port).then((int result) {
        if (result < 0) {
          chrome.sockets.tcp.close(socketId);
          if (!throwOnError) return null;
          throw new SocketException(
              'unable to connect to ${host} ${port}: ${result}');
        } else {
          return new TcpClient._fromSocketId(socketId);
        }
      }).catchError((e) {
        if (!throwOnError) return null;
        throw new SocketException(
            'unable to connect to ${host} ${port}: ${e.toString()}');
      });
    });
  }

  static void _initListeners() {
    _clientMap = {};

    chrome.sockets.tcp.onReceive.listen((chrome.ReceiveInfo info) {
      StreamController controller = _clientMap[info.socketId];
      if (controller != null) {
        controller.add(info.data.getBytes());
      }
    });

    chrome.sockets.tcp.onReceiveError.listen((chrome.ReceiveErrorInfo info) {
      int socket = info.socketId;
      StreamController controller = _clientMap[socket];

      if (controller != null) {
        if (info.resultCode == -15) {
          // An error code of -15 indicates the port is closed.
          controller.close();
          _clientMap.remove(socket);
        } else {
          controller.addError(new SocketException(
              "error reading stream: ${info.resultCode}", info.resultCode));
          controller.close();
          _clientMap.remove(socket);
        }
      }
    });
  }

  TcpClient._fromSocketId(this._socketId, [bool unpause = false]) {
    if (_clientMap == null) _initListeners();

    _clientMap[_socketId] = new StreamController();

    if (unpause) {
      chrome.sockets.tcp.setPaused(_socketId, false);
    }
  }

  Future<chrome.SocketInfo> getInfo() => chrome.sockets.tcp.getInfo(_socketId);

  /**
   * The read [Stream] for incoming data.
   */
  Stream<List<int>> get stream => _clientMap[_socketId].stream;

  void write(List<int> event) {
    _lastWrite = chrome.sockets.tcp.send(
        _socketId, new chrome.ArrayBuffer.fromBytes(event));
  }

  /**
   * This is a convenience method, fully equivalent to:
   *
   *     write(str.codeUnits);
   *
   * Note that it does not do UTF8 encoding of the given string. It will
   * truncate any character that does not fit in 8 bits.
   */
  void writeString(String str) => write(str.codeUnits);

  Future dispose() {
    return _lastWrite.then((_) {
      _clientMap.remove(_socketId);
      return chrome.sockets.tcp.close(_socketId);
    });
  }
}

/**
 * A lightweight implementation of a tcp server socket.
 *
 * ## Usage:
 *
 *     TcpServer.createServerSocket();
 *     onAccept;
 *     dispose();
 */
class TcpServer {
  /**
   * A map from server socketIds to StreamControllers. We're notified about
   * incoming `accept` connections based on the socketId. We want to use that
   * information to notify the correct StreamController.
   */
  static Map<int, StreamController> _serverMap;

  final int _socketId;
  final int port;

  static Future<TcpServer> createServerSocket([int port = 0]) {
    return chrome.sockets.tcpServer.create().then((chrome.CreateInfo info) {
      int socketId = info.socketId;
      return chrome.sockets.tcpServer.listen(socketId, LOCAL_HOST, port, 5).then((int result) {
        if (result < 0) {
          chrome.sockets.tcpServer.close(socketId);
          throw new SocketException('unable to listen on port ${port}: ${result}');
        } else {
          return chrome.sockets.tcpServer.getInfo(socketId).then((chrome.SocketInfo info) {
            return new TcpServer._(socketId, info.localPort);
          });
        }
      });
    });
  }

  static void _initListener() {
    _serverMap = {};

    chrome.sockets.tcpServer.onAccept.listen((chrome.AcceptInfo info) {
      StreamController controller = _serverMap[info.socketId];
      if (controller != null) {
        controller.add(new TcpClient._fromSocketId(info.clientSocketId, true));
      }
    });
  }

  TcpServer._(this._socketId, this.port) {
    if (_serverMap == null) _initListener();

    _serverMap[_socketId] = new StreamController();
  }

  Stream<TcpClient> get onAccept => _serverMap[_socketId].stream;

  Future<chrome.SocketInfo> getInfo() =>
      chrome.sockets.tcpServer.getInfo(_socketId);

  Future dispose() {
    _serverMap.remove(_socketId);
    return chrome.sockets.tcpServer.close(_socketId);
  }
}

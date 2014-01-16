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

// TODO(devoncarew): these classes are fairly generic; explore contributing them
// to package:chrome, or to a new utility library for chrome functionalty
// built on chrome? chrome_util?

/**
 * An [Exception] implementation for socket errors.
 */
class SocketException implements Exception {
  final String message;

  const SocketException([this.message = ""]);

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
  final int _socketId;

  StreamController<List<int>> _controller;
  _SocketEventSink _sink;
  bool _keepPolling = true;

  static Future<TcpClient> createClient(String host, int port,
      {bool throwOnError: true}) {
    return chrome.socket.create(chrome.SocketType.TCP).then((chrome.CreateInfo createInfo) {
      int socketId = createInfo.socketId;

      return chrome.socket.connect(socketId, host, port).then((int result) {
        if (result < 0) {
          chrome.socket.destroy(socketId);

          if (throwOnError) {
            throw new SocketException('unable to connect to ${host} ${port}: ${result}');
          } else {
            return null;
          }
        } else {
          return new TcpClient._fromSocketId(socketId);
        }
      });
    });
  }

  TcpClient._fromSocketId(this._socketId) {
    _controller = new StreamController(
        onListen: _pollIncoming, onCancel: _stopPolling);
    _sink = new _SocketEventSink(this);
  }

  Future<chrome.SocketInfo> getInfo() => chrome.socket.getInfo(_socketId);

  /**
   * The read [Stream] for incoming data.
   */
  Stream<List<int>> get stream => _controller.stream;

  /**
   * The write [EventSink] for outgoing data.
   */
  EventSink<List<int>> get sink => _sink;

  /**
   * This is a convenience method, fully equivalent to:
   *
   *     sink.add(str.codeUnits);
   *
   * Note that it does not do UTF8 encoding of the given string. It will
   * truncate any character that does not fit in 8 bits.
   */
  void writeString(String str) => sink.add(str.codeUnits);

  void dispose() {
    chrome.socket.disconnect(_socketId);
  }

  void _pollIncoming() {
    _keepPolling = true;

    chrome.socket.read(_socketId).then((chrome.SocketReadInfo info) {
      if (info.resultCode < 0) {
        // TODO: get the bsd socket codes
        if (info.resultCode != -15) {
          _controller.addError(
              new SocketException("error reading stream: ${info.resultCode}"));
        }
        _controller.close();
      } else {
        _controller.add(info.data.getBytes());

        if (_keepPolling) {
          _pollIncoming();
        }
      }
    }).catchError((error) {
      _controller.addError(
          new SocketException("error reading stream: ${error}"));
      _controller.close();
    });
  }

  void _stopPolling() {
    _keepPolling = false;
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
  final int _socketId;
  final int port;

  StreamController<TcpClient> _controller;

  static Future<TcpServer> createServerSocket([int port = 0]) {
    return chrome.socket.create(chrome.SocketType.TCP).then((chrome.CreateInfo info) {
      int socketId = info.socketId;

      return chrome.socket.listen(socketId, LOCAL_HOST, port, 5).then((int result) {
        if (result < 0) {
          chrome.socket.destroy(socketId);
          throw new SocketException('unable to listen on port ${port}: ${result}');
        } else {
          return chrome.socket.getInfo(socketId).then((chrome.SocketInfo info) {
            return new TcpServer._(socketId, info.localPort);
          });
        }
      });
    });
  }

  TcpServer._(this._socketId, this.port) {
    _controller = new StreamController(onListen: _accept);
  }

  Stream<TcpClient> get onAccept => _controller.stream;

  Future<chrome.SocketInfo> getInfo() => chrome.socket.getInfo(_socketId);

  void dispose() {
    chrome.socket.destroy(_socketId);
  }

  void _accept() {
    chrome.socket.accept(_socketId).then((chrome.AcceptInfo info) {
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

class _SocketEventSink implements EventSink<List<int>> {
  TcpClient tcpClient;

  _SocketEventSink(this.tcpClient);

  void add(List<int> event) {
    // TODO(devoncarew): do we need to do anything with the returned
    // Future<SocketWriteInfo>? Send it to the read stream controller?

    chrome.socket.write(
        tcpClient._socketId,
        new chrome.ArrayBuffer.fromBytes(event));
  }

  void addError(errorEvent, [StackTrace stackTrace]) {
    // TODO(devoncarew): implement this method

  }

  void close() {
    tcpClient.dispose();
  }
}

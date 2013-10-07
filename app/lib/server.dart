// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A tiny embedded http server. This is used when launching web apps from Spark.
 */
library spark.server;

import 'dart:async';

import 'tcp.dart' as tcp;

/**
 * A tiny embedded http server.
 *
 * Usage:
 *  * PicoServer.createServer()
 *  * TODO: add handlers
 *  * dispose()
 */
class PicoServer {
  tcp.TcpServer _server;

  /**
   * Create an instance of an http server, bound to the given port. If [port] is
   * `0`, this will bind to any available port.
   */
  static Future<PicoServer> createServer([int port = 0]) {
    return tcp.TcpServer.createServerSocket(port).then((tcp.TcpServer server) {
      return new PicoServer._(server);
    });
  }

  PicoServer._(this._server) {
    _server.onAccept.listen(_serveClient);
  }

  int get port => _server.port;

  Future<tcp.SocketInfo> getInfo() => _server.getInfo();

  void dispose() {
    _server.dispose();
  }

  void _serveClient(tcp.TcpClient client) {
    // TODO: parse and create a HttpRequest object

    // TODO: ask each handler in turn if it wants to handle this request

    // serve back a default 404 response
    client.writeString('HTTP/1.1 404 Not Found\r\n');
    client.dispose();
  }
}

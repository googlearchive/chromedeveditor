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
 * TODO:
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
    // TODO: use onAccept

  }

  Future<tcp.SocketInfo> getInfo() => _server.getInfo();

  void dispose() {
    _server.dispose();
  }
}

/**
 * A tiny embedded http server. This is used when launching web apps from Spark.
 */
library spark.server;

import 'dart:async';

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;

/**
 * TODO:
 */
class PicoServer {
  static const int DEFAULT_PORT = 3030;

  static Future<PicoServer> connect([int port = DEFAULT_PORT]) {
    chrome_gen.TcpServer server = new chrome_gen.TcpServer('127.0.0.1', port);

    return server.connect().then((bool success) {
      if (success) {
        return new PicoServer._(server);
      } else {
        throw new Exception('no listener available on port ${port}');
      }
    });
  }

  chrome_gen.TcpServer _tcpServer;

  PicoServer._(this._tcpServer);

  int get port => _tcpServer.port;

  // TODO:

}

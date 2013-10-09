// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A tiny embedded http server. This is used when launching web apps from Spark.
 */
library spark.server;

import 'dart:async';

//import 'http.dart';
import 'tcp.dart' as tcp;

/**
 * A tiny embedded http server.
 *
 * Usage:
 *  * `PicoServer.createServer()`
 *  * `addServlet(fooServlet)`
 *  * `addServlet(barServlet)`
 *  * `dispose()`
 */
class PicoServer {
  tcp.TcpServer _server;
  List<PicoServlet> _servlets = [];

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

  void addServlet(PicoServlet servlet) => _servlets.add(servlet);

  Future<tcp.SocketInfo> getInfo() => _server.getInfo();

  void dispose() {
    _server.dispose();
  }

  void _serveClient(tcp.TcpClient client) {
    HttpRequest._parse(client).then((HttpRequest request) {
      for (PicoServlet servlet in _servlets) {
        if (servlet.canServe(request)) {
          _serve(servlet, client, request);
          return;
        }
      }

      client.writeString('HTTP/1.1 404 Not Found\r\n');
      client.dispose();
    }).catchError((e) {
      // TODO: bad request error code
      client.writeString('HTTP/1.1 404 Not Found\r\n');
      client.dispose();
    });
  }

  void _serve(PicoServlet servlet, tcp.TcpClient client, HttpRequest request) {
    servlet.serve(request).then((HttpResponse response) {
      response._send(client).then((_) {
        client.dispose();
      });
    });
  }
}

/**
 * TODO:
 */
abstract class PicoServlet {

  /**
   * TODO:
   */
  bool canServe(HttpRequest request) => true;

  /**
   * TODO:
   */
  Future<HttpResponse> serve(HttpRequest request);

}

/**
 * TODO:
 */
class HttpRequest {

  static Future<HttpRequest> _parse(tcp.TcpClient client) {
    // TODO:
    return new Future.value(new HttpRequest._());
  }

  HttpRequest._() {
    // TODO:

  }

}

/**
 * TODO:
 */
class HttpResponse {

  Future _send(tcp.TcpClient client) {
    // TODO:
    client.writeString('HTTP/1.1 404 Not Found\r\n');
  }

}

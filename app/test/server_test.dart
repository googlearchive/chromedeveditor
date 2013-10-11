// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.server_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../lib/server.dart';
import '../lib/tcp.dart' as tcp;

// TODO(devoncarew): move some tests from dart:io

// TODO(devoncarew): write mime tests

// TODO(devoncarew): test header decode

// TODO(devoncarew): test header encode

// TODO(devoncarew): test serving a stream response (contentLength == -1)


main() {
  group('PicoServer', () {
    PicoServer server;

    setUp(() {
      return PicoServer.createServer().then((s) {
        server = s;
        server.addServlet(new HelloServlet());
        server.addServlet(new HelloStreamServlet());
      });
    });

    tearDown(() {
      server.dispose();
    });

    test('bind and dispose', () {
      expect(server, isNotNull);
    });

    test('serve request', () {
      tcp.TcpClient client;

      return tcp.TcpClient.createClient(tcp.LOCAL_HOST, server.port).then((c) {
        client = c;
        client.writeString("HEAD /hello.txt HTTP/1.0\r\n\r\n");
        return client.stream.toList();
      }).then((List<List<int>> inData) {
        List<int> data = [];
        inData.forEach((l) => data.addAll(l));
        String str = new String.fromCharCodes(data);
        expect(str, startsWith('HTTP/1.1 200 OK\r\n'));
        expect(str, endsWith('Hello world!'));
        client.dispose();
      });
    });

    test('serve request 404', () {
      tcp.TcpClient client;

      return tcp.TcpClient.createClient(tcp.LOCAL_HOST, server.port).then((c) {
        client = c;
        client.writeString("HEAD /robots.txt HTTP/1.0\r\n\r\n");
        return client.stream.first;
      }).then((List<int> data) {
        String str = new String.fromCharCodes(data);
        expect(str, startsWith('HTTP/1.1 404 Not Found\r\n'));
        client.dispose();
      });
    });
  });
}

/**
 * A servlet to serve up /hello.txt.
 */
class HelloServlet extends PicoServlet {
  bool canServe(HttpRequest request) => request.uri.path == '/hello.txt';

  Future<HttpResponse> serve(HttpRequest request) {
    HttpResponse response = new HttpResponse.ok();
    response.setContent('Hello world!');
    response.setContentTypeFrom(request.uri.path);
    return new Future.value(response);
  }
}

/**
 * A servlet to serve up /hello.html.
 */
class HelloStreamServlet extends PicoServlet {
  bool canServe(HttpRequest request) => request.uri.path == '/hello.html';

  Future<HttpResponse> serve(HttpRequest request) {
    HttpResponse response = new HttpResponse.ok();
    response.setContentStream(
        new Stream.fromIterable(['<p>Hello <b>world</b>!</p>'.codeUnits]));
    response.setContentTypeFrom(request.uri.path);
    return new Future.value(response);
  }
}

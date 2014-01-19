// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.tcp_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../lib/tcp.dart' as tcp;

/** A matcher for SocketExceptions. */
const isSocketException = const _SocketException();

class _SocketException extends TypeMatcher {
  const _SocketException() : super("SocketException");
  bool matches(item, Map matchState) => item is tcp.SocketException;
}

defineTests() {
  EchoServer echoServer = new EchoServer();

  group('tcp.TcpClient', () {
    test('connect', () {
      return tcp.TcpClient.createClient('www.google.com', 80).then((tcp.TcpClient client) {
        expect(client, isNotNull);
        client.dispose();
      });
    });
    test('connect with error', () {
      Future future = tcp.TcpClient.createClient(tcp.LOCAL_HOST, 7171);
      expect(future, throwsA(isSocketException));
    });
    test('send and receive', () {
      tcp.TcpClient client;

      return tcp.TcpClient.createClient('www.google.com', 80).then((tcp.TcpClient _client) {
        expect(_client, isNotNull);
        client = _client;
        client.writeString("HEAD /robots.txt HTTP/1.0\r\n\r\n");
        return client.stream.first;
      }).then((List<int> data) {
        expect(data.length, greaterThan(0));
        String str = new String.fromCharCodes(data);
        expect(str, startsWith("HTTP/1.0 200 OK"));
        client.dispose();
      });
    });
    // TODO: fix this test
//    test('error on read', () {
//      tcp.TcpClient client;
//
//      Completer completer = new Completer();
//
//      tcp.TcpClient.createClient(tcp.LOCAL_HOST, echoServer.port).then((tcp.TcpClient _client) {
//        client = _client;
//        client.writeString('foo');
//        client.sink.close();
//
//        client.stream.listen((List<int> data) {
//          expect(data.length, 3);
//          expect(new String.fromCharCodes(data), 'foo');
//        }, onError: (e) {
//          completer.completeError('error from stream when expected close');
//        }, onDone: () {
//          expect(true, true);
//          completer.complete();
//        });
//      });
//
//      return completer.future;
//    });
    // TODO: fix this test
//    test('echo', () {
//      tcp.TcpClient client;
//
//      Completer completer = new Completer();
//
//      tcp.TcpClient.createClient(tcp.LOCAL_HOST, echoServer.port).then((tcp.TcpClient _client) {
//        client = _client;
//        client.writeString('foo');
//
//        client.stream.listen((List<int> data) {
//          expect(data.length, 3);
//          expect(new String.fromCharCodes(data), 'foo');
//          client.dispose();
//        }, onError: (e) {
//          completer.completeError('error from stream when expected close');
//        }, onDone: () {
//          expect(true, true);
//          completer.complete();
//        });
//      });
//
//      return completer.future;
//    });
//    test('read until close', () {
//      // TODO:
//
//    });
//    test('error on write', () {
//      // TODO:
//
//    });
  });

  group('tcp.TcpServer', () {
    test('connect dispose', () {
      return tcp.TcpServer.createServerSocket().then((tcp.TcpServer server) {
        expect(server, isNotNull);
        server.dispose();
      });
    });
    test('bind to any port', () {
      return tcp.TcpServer.createServerSocket().then((tcp.TcpServer server) {
        return server.getInfo().then((tcp.SocketInfo info) {
          //print("bound to port ${info.localPort}");
          //print("localAddress = ${info.localAddress}");
          expect(info.localAddress, isNotNull);
          expect(info.localPort, greaterThan(0));
          server.dispose();
        });
      });
    });
    test('bind to a specific port', () {
      return tcp.TcpServer.createServerSocket(37123).then((tcp.TcpServer server) {
        return server.getInfo().then((tcp.SocketInfo info) {
          expect(info.localAddress, isNotNull);
          expect(info.localPort, 37123);
          server.dispose();
        });
      });
    });
  });
}

/**
 * A simple class that listens on a fixed port for connections, and echos back
 * any data sent to that port.
 */
class EchoServer {
  tcp.TcpServer server;

  final int port = 7990;

  EchoServer() {
    tcp.TcpServer.createServerSocket(port).then((s) {
      server = s;
      server.onAccept.listen(_echo);
    });
  }

  void _echo(tcp.TcpClient client) {
    client.stream.listen((List<int> data) {
      client.sink.add(data);
      //client.dispose();
    });
  }

  void dispose() {
    if (server != null) {
      server.dispose();
    }
  }
}

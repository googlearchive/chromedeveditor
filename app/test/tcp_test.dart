// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.tcp_test;

import 'package:unittest/unittest.dart';

import '../lib/tcp.dart' as tcp;

main() {
  group('tcp.TcpClient', () {
    test('connect', () {
      // TODO:

    });
    test('connect with error', () {
      // TODO:

    });
    test('send', () {
      // TODO:

    });
    test('receive', () {
      // TODO:

    });
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
          print("bound to port ${info.localPort}");
          print("localAddress = ${info.localAddress}");
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

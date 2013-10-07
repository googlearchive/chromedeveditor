// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.server_test;

import 'package:unittest/unittest.dart';

import '../lib/server.dart';
import '../lib/tcp.dart' as tcp;

main() {
  group('PicoServer', () {
    PicoServer server;

    setUp(() {
      return PicoServer.createServer().then((s) => server = s);
    });

    tearDown(() {
      server.dispose();
    });

    test('bind and dispose', () {
      expect(server, isNotNull);
    });

    test('serve request', () {
      // TODO:

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

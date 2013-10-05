// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.server_test;

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;
import 'package:unittest/unittest.dart';

import '../lib/server.dart';

main() {
  group('PicoServer', () {
    test('bind and dispose', () {
      return PicoServer.createServer().then((PicoServer server) {
        expect(server, isNotNull);
        server.dispose();
      });
    });
    test('serve request', () {
      // TODO:

    });
    test('serve request 404', () {
      // TODO:

    });
  });

}

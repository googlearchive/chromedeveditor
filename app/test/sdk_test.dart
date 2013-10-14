// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library sdk_test;

import 'package:unittest/unittest.dart';

import '../lib/sdk.dart';

main() {
  group('sdk', () {
    DartSdk sdk;

    setUp(() {
      return DartSdk.createSdk().then((result) {
        sdk = result;
      });
    });

    test('exists', () {
      expect(sdk.available, true);
    });

    test('has version', () {
      expect(sdk.version.length, greaterThan(0));
    });

    test('sdk parent is null', () {
      expect(sdk.parent, isNull);
    });

    test('list directory entries', () {
      return sdk.getChildren().then((List children) {
        expect(children.length, 2);
      });
    });

    test('lib directory parent is sdk', () {
      expect(sdk.libDirectory.parent, sdk);
    });

    test('list lib directory entries', () {
      return sdk.libDirectory.getChildren().then((List children) {
        expect(children.length, greaterThan(10));
      });
    });
  });
}

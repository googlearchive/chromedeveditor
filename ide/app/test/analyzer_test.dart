// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.analyzer_test;

import 'package:unittest/unittest.dart';

import '../lib/analyzer.dart';

main() {
  group('analyzer.', () {
    test('ChromeDartSdk exists', () {
      return ChromeDartSdk.createSdk().then((sdk) {
        expect(sdk, isNotNull);
        expect(sdk.sdkVersion.length, greaterThan(0));

        // expect some libraries
        expect(sdk.sdkLibraries.length, greaterThan(10));

        // expect some uris
        expect(sdk.uris.length, greaterThan(10));

        expect(sdk.getSdkLibrary('dart:core'), isNotNull);
        expect(sdk.getSdkLibrary('dart:html'), isNotNull);

        // TODO: test fromEncoding

        // TODO: test mapDartUri

      });
    });
  });
}

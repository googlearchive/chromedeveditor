// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.utils_tests;

import 'package:unittest/unittest.dart';

import '../lib/utils.dart';

defineTests() {
  group('utils', () {
    test('i18n found', () {
      expect(i18n('app_name'), 'Spark');
    });

    test('i18n not found', () {
      expect(i18n('not_found'), '');
    });

    test('baseName', () {
      expect(baseName('foo'), 'foo');
      expect(baseName('foo/bar'), 'bar');
      expect(baseName('foo/bar/baz'), 'baz');
    });

    test('dirName', () {
      expect(dirName('foo'), null);
      expect(dirName('foo/bar'), 'foo');
      expect(dirName('foo/bar/baz'), 'foo/bar');
    });

    test('dartium stack trace', () {
      final line = '#0      main.foo (chrome-extension://ldgidbpjc/test/utils_test.dart:35:9)';
      Match match = DARTIUM_REGEX.firstMatch(line);
      expect(match.group(1), 'main.foo');
      expect(match.group(2), 'chrome-extension://ldgidbpjc/test/utils_test.dart:35:9');
    });

    test('dart2js stack trace', () {
      final line = 'at Object.wrapException (chrome-extension://aadcannocln/spark.dart.precompiled.js:2646:13)';
      Match match = DART2JS_REGEX_1.firstMatch(line);
      expect(match.group(1), 'Object.wrapException');
      expect(match.group(2), 'chrome-extension://aadcannocln/spark.dart.precompiled.js:2646:13');
    });

    test('dart2js stack trace alternative', () {
      final line = r'at Object.wrapException [as call$0] (chrome-extension://aadcannocln/spark.dart.precompiled.js:2646:13)';
      Match match = DART2JS_REGEX_2.firstMatch(line);
      expect(match.group(1), 'Object.wrapException');
      expect(match.group(3), 'chrome-extension://aadcannocln/spark.dart.precompiled.js:2646:13');
    });

    test('minimizeStackTrace', () {
      try {
        throw new ArgumentError('happy message');
      } catch (e, st) {
        String description = minimizeStackTrace(st);
        expect(description.contains('chrome-extension:'), false);
        expect(description.contains('('), false);
        expect(description.startsWith('#'), false);
      }
    });
  });
}

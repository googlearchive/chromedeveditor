// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.utils_test;

import 'dart:async';

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

    test('StreamReader, read 1', () {
      StreamReader reader = new StreamReader(new Stream.fromIterable([[1, 2, 3, 4]]));
      return reader.read(2).then((result) {
        expect(result.length, 2);
        reader.read(2).then((result) {
          expect(result.length, 2);
        });
      });
    });

    test('StreamReader, read 2', () {
      StreamReader reader = new StreamReader(new Stream.fromIterable([[1], [2, 3, 4]]));
      return reader.read(2).then((result) {
        expect(result.length, 2);
        reader.read(2).then((result) {
          expect(result.length, 2);
        });
      });
    });

    test('StreamReader, read until eos', () {
      StreamReader reader = new StreamReader(new Stream.fromIterable([[1, 2, 3, 4]]));
      return reader.read(1).then((result) {
        expect(result.length, 1);
        reader.readRemaining().then((result) {
          expect(result.length, 3);
        });
      });
    });
  });
}

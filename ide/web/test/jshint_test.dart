// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.jshint_test;

import 'package:unittest/unittest.dart';

import '../lib/javascript/jshint.dart';

defineTests() {
  group('jshint', () {
    test('available', () {
      expect(JsHint.available, true);
    });

    test('no issues', () {
      JsHint linter = new JsHint();
      List results = linter.lint('''
var foo = (function () {
});''');
      expect(results, isEmpty);
    });
    
    test('missing semi', () {
      JsHint linter = new JsHint();
      List results = linter.lint('''
var foo = (function () {
})''');
      expect(results.length, 1);
      JsResult issue = results.first;
      expect(issue.line, 2);
      expect(issue.message, 'Missing semicolon.');
    });
  });
}

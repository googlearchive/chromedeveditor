// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.cssbeautify_test;

import 'package:unittest/unittest.dart';

import '../lib/css/cssbeautify.dart';

defineTests() {
  group('cssbeautify', () {
    test('format', () {
      CssBeautify formatter = new CssBeautify();
      expect(formatter.format(
          'menu{color:red} navigation{background-color:#333}\n'),
          'menu {\n  color: red;\n}\n\nnavigation {\n  background-color: #333;\n}\n');
    });

    test('format tabs', () {
      CssBeautify formatter = new CssBeautify(useTabs: true);
      expect(formatter.format(
          'menu{color:red} navigation{background-color:#333}\n'),
          'menu {\n\tcolor: red;\n}\n\nnavigation {\n\tbackground-color: #333;\n}\n');
    });

    test('format ends with newline', () {
      CssBeautify formatter = new CssBeautify();
      expect(formatter.format(
          '\n\n\n\n\n\nmenu{color:red} navigation{background-color:#333}'),
          '\nmenu {\n  color: red;\n}\n\nnavigation {\n  background-color: #333;\n}\n');
    });

    test('format preserve one newline', () {
      CssBeautify formatter = new CssBeautify();
      expect(formatter.format(
          '\n\n\n\n\n\nmenu{color:red} navigation{background-color:#333}'),
          '\nmenu {\n  color: red;\n}\n\nnavigation {\n  background-color: #333;\n}\n');
    });
  });
}

// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.compiler_test;

import 'package:unittest/unittest.dart';

import '../lib/compiler.dart';

main() {
  group('compiler', () {
    test('is available', () {
      Compiler compiler = new Compiler();

      expect(compiler.available, false);
    });

    test('ping compiler isolate', () {
      Compiler compiler = new Compiler();

      return compiler.pingCompiler().then((CompilerResult r) {
        expect(r, isNotNull);
        expect(r.success, true);
      });
    });

    test('compile helloworld', () {
      Compiler compiler = new Compiler();

      return compiler.compileString('''
void main() {
  print('hello');
}
''').then((CompilerResult r) {
        expect(r, isNotNull);
        expect(r.success, true);
        expect(r.warnings.length, 0);
        expect(r.output.length, greaterThan(1000));
      });
    });
  });
}

// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.compiler_test;

import 'package:unittest/unittest.dart';

import '../compiler.dart';

defineTests() {
  group('compiler', () {
    Compiler compiler;

    setUp(() {
      return Compiler.createCompiler().then((c) {
        compiler = c;
      });
    });

    test('is available', () {
      expect(compiler, isNotNull);
    });

    test('compile helloworld', () {
      return compiler.compileString('''
void main() {
  print('hello');
}
''').then((CompilerResult r) {
        expect(r.problems, isEmpty);
        expect(r.getSuccess(), true);
        expect(r.output.length, greaterThan(1000));
      });
    });
  });
}

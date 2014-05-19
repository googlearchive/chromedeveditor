// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.compiler_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../compiler.dart';
import '../services_common.dart';

defineTests() {
  group('compiler', () {
    Compiler compiler;

    setUp(() {
      // TODO: Move over to calling createCompilerFrom().
//      return Compiler.createCompiler(new _MockContentsProvider()).then((c) {
//        compiler = c;
//      });
    });

    test('is available', () {
      expect(compiler, isNotNull);
    });

    test('compile helloworld', () {
      return compiler.compileString('''
void main() {
  print('hello');
}
''').then((CompilerResultHolder r) {
        expect(r.problems, isEmpty);
        expect(r.getSuccess(), true);
        expect(r.output.length, greaterThan(1000));
      });
    });
  });
}

class _MockContentsProvider implements ContentsProvider {
  Future<String> getFileContents(String uuid) {
    return new Future.error('not implemented');
  }

  Future<String> getPackageContents(String relativeToUuid, String packageRef) {
    return new Future.error('not implemented');
  }
}

// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.analyzer_test;

import 'package:unittest/unittest.dart';

import '../lib/analyzer.dart';

main() {
  group('analyzer.', () {
    test('ChromeDartSdk exists', () {
      return createSdk().then((ChromeDartSdk sdk) {
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

    test('analyze string, no resolution', () {
      return createSdk().then((ChromeDartSdk sdk) {
        return analyzeString(sdk, "void main() {\n print('hello world');\n}",
            performResolution: false).then((AnalyzerResult result) {
          expect(result, isNotNull);
          expect(result.ast, isNotNull);
          expect(result.ast.declarations.length, greaterThan(0));
          CompilationUnitMember decl = result.ast.declarations.first;
          expect(decl is FunctionDeclaration, true);
          expect((decl as FunctionDeclaration).name.toString(), 'main');
          expect(result.errors, isEmpty);
        });
      });
    });

    test('analyze string, no resolution, syntax errors', () {
      return createSdk().then((ChromeDartSdk sdk) {
        return analyzeString(sdk, "void main() {\n print('hello world') \n}",
            performResolution: false).then((AnalyzerResult result) {
          expect(result.ast.declarations.length, greaterThan(0));
          CompilationUnitMember decl = result.ast.declarations.first;
          expect(decl is FunctionDeclaration, true);
          expect((decl as FunctionDeclaration).name.toString(), 'main');
          expect(result.errors.length, greaterThan(0));
        });
      });
    });

    test('analyze string', () {
      return createSdk().then((ChromeDartSdk sdk) {
        return analyzeString(sdk, "void main() {\n print('hello world');\n}").then((AnalyzerResult result) {
          expect(result, isNotNull);
          expect(result.ast, isNotNull);
          expect(result.ast.declarations.length, greaterThan(0));
          CompilationUnitMember decl = result.ast.declarations.first;
          expect(decl is FunctionDeclaration, true);
          expect((decl as FunctionDeclaration).name.toString(), 'main');
          expect(result.errors, isEmpty);
        });
      });
    });

    test('analyze string with errors', () {
      return createSdk().then((ChromeDartSdk sdk) {
        return analyzeString(sdk, "void main() {\n println('hello world');\n}").then((AnalyzerResult result) {
          expect(result.ast, isNotNull);
          expect(result.ast.declarations.length, greaterThan(0));
          CompilationUnitMember decl = result.ast.declarations.first;
          expect(decl is FunctionDeclaration, true);
          expect((decl as FunctionDeclaration).name.toString(), 'main');
          expect(result.errors.length, greaterThan(0));
        });
      });
    });

    test('analyze string with dart: imports', () {
      // TODO:

    });
  });
}

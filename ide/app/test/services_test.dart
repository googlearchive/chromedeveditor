// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import 'files_mock.dart';
import '../lib/services.dart';
import '../lib/utils.dart';

defineTests() {
  Workspace workspace = new Workspace();
  Services services = new Services(workspace);

  group('services', () {
    test('ping', () {
      return services.ping().then((result) {
        expect(result, equals("pong"));
      });
    });
  });

  group('services implementation tests', () {
    test('service order', () {
      TestService testService = services.getService("test");
      Completer completer = new Completer();
      List<String> orderedResponses = [];

      // Test 1 (slow A) starts
      testService.longTest("1").then((str) {
        orderedResponses.add(str);
      });

      // Test 2 (fast) starts
      testService.shortTest("2").then((str) {
        orderedResponses.add(str);
      });

      // Test 2 should end
      return new Future.delayed(const Duration(milliseconds: 500)).then((_){
        // Test 3 (slow B) starts
        return testService.longTest("3").then((str) {
          orderedResponses.add(str);
        });
      }).then((_) =>
          expect(orderedResponses, equals(["short2", "long1", "long3"])));
          // Test 1 should end
          // Test 3 should end
    });

    test('basic test', () {
      CompilerService compilerService = services.getService("compiler");
      expect(compilerService, isNotNull);
    });
  });

  group('chrome service', () {
    test('resource read', () {
      MockFileSystem fs = new MockFileSystem();
      FileEntry fileEntry = fs.createFile('test.txt', contents: "some words");
      String fileUuid;
      TestService testService = services.getService("test");
      return workspace.link(createWsRoot(fileEntry)).then((File fileResource) {
        return testService.readText(fileResource);
      }).then((String text) => expect(text, equals("some words")));
    });
  });

  group('services compiler', () {
    Workspace workspace = new Workspace();
    Services services = new Services(workspace);;
    CompilerService compiler = services.getService("compiler");

    test('hello world', () {
      final String str = "void main() { print('hello world'); }";

      return compiler.compileString(str).then((CompilerResult result) {
        expect(result.getSuccess(), true);
        expect(result.output.length, greaterThan(100));
      });
    });

    test('syntax error', () {
      // Missing semi-colon.
      final String str = "void main() { print('hello world') }";

      return compiler.compileString(str).then((CompilerResult result) {
        expect(result.getSuccess(), false);
        expect(result.problems.length, 1);
        expect(result.output, null);
      });
    });

    test('compile file', () {
      DirectoryEntry dir = createSampleDirectory1('foo1');
      return linkSampleProject(dir, workspace).then((Project project) {
        File file = project.getChildPath('web/sample.dart');
        return compiler.compileFile(file).then((CompilerResult result) {
          expect(result.getSuccess(), true);
          expect(result.problems.length, 0);
          expect(result.output.length, greaterThan(100));
        });
      });
    });

    test('compile file with relative references', () {
      DirectoryEntry dir = createSampleDirectory2('foo2');
      return linkSampleProject(dir, workspace).then((Project project) {
        File file = project.getChildPath('web/sample.dart');
        return compiler.compileFile(file).then((CompilerResult result) {
          expect(result.getSuccess(), true);
          expect(result.problems.length, 0);
          expect(result.output.length, greaterThan(100));
        });
      });
    });

    // TODO: Add in when we support package: references in the implementation.
//    test('compile file with package references', () {
//      DirectoryEntry dir = createSampleDirectory3('foo3');
//      return linkSampleProject(dir, workspace).then((Project project) {
//        File file = project.getChildPath('web/sample.dart');
//        return compiler.compileFile(file).then((CompilerResult result) {
//          expect(result.getSuccess(), true);
//          expect(result.problems.length, 0);
//          expect(result.output.length, greaterThan(100));
//        });
//      });
//    });
  });

  group('services analyzer', () {
    // TODO: The analyzer is currently not working when compiled to JavaScript.
    if (isDart2js()) return;

    Workspace workspace = new Workspace();
    Services services = new Services(workspace);;
    AnalyzerService analyzer = services.getService("analyzer");

    test('analyze file', () {
      DirectoryEntry dir = createSampleDirectory1('foo1');
      return linkSampleProject(dir, workspace).then((Project project) {
        File file = project.getChildPath('web/sample.dart');
        return analyzer.buildFiles([file]).then((Map<File, List<AnalysisError>> result) {
          expect(result.length, 1);
          expect(result[file], isEmpty);
        });
      });
    });

    test('analyze file with errors', () {
      DirectoryEntry dir = createSampleDirectory1('foo_error');
      return linkSampleProject(dir, workspace).then((Project project) {
        File file = project.getChildPath('web/sample.dart');
        return file.setContents("void main() {\n  print('hello') \n}\n").then((_) {
          return analyzer.buildFiles([file]).then((Map<File, List<AnalysisError>> result) {
            expect(result.length, 1);
            expect(result[file].length, 1);
          });
        });
      });
    });

    test('analyze file with relative references', () {
      DirectoryEntry dir = createSampleDirectory2('foo2');
      return linkSampleProject(dir, workspace).then((Project project) {
        File file = project.getChildPath('web/sample.dart');
        return analyzer.buildFiles([file]).then((Map<File, List<AnalysisError>> result) {
          expect(result.length, 1);
          expect(result[file], isEmpty);
        });
      });
    });

    test('analyze file with package: references', () {
      DirectoryEntry dir = createSampleDirectory3('foo3');
      return linkSampleProject(dir, workspace).then((Project project) {
        File file = project.getChildPath('web/sample.dart');
        return analyzer.buildFiles([file]).then((Map<File, List<AnalysisError>> result) {
          expect(result.length, 1);
          expect(result[file], isEmpty);
        });
      });
    });
  });
}

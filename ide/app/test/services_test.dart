// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services_test;

import 'dart:async';
import 'dart:isolate';

import 'package:unittest/unittest.dart';

import 'files_mock.dart';
import '../lib/services.dart';

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
    CompilerService compiler;

    setUp(() {
      compiler = services.getService("compiler");
    });

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

    // TODO: This test isn't working right now - the services it's testing
    // against has a different workspace.
//    test('compile file', () {
//      return linkSampleProject(createSampleDirectory1('foo')).then((Project project) {
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
    // TODO: add some analyzer integration tests

  });

//  group('services_impl', () {
//    test('setup', () {
//      MockSendPort mockSendPort = new MockSendPort();
//      servicesIsolate = new impl.ServicesIsolate(mockSendPort);
//      expect(mockSendPort.wasSent, isNotNull);
//    });
//    //test('compiler start', () {
//    //  MockSendPort mockSendPort = new MockSendPort();
//    //  servicesIsolate = new impl.ServicesIsolate(mockSendPort);
//    //  impl.CompilerServiceImpl compilerImpl =
//    //      servicesIsolate.getServiceImpl("compiler");
//    //  });
//    //});
//  });
}

class MockSendPort extends SendPort {
  bool operator ==(other) => super == other;
  int get hashCode => null;
  var wasSent = null;
  void send(var message) {
    wasSent = message;
  }
}

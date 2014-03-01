// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services_test;

import 'dart:async';
import 'dart:isolate';

import 'package:unittest/unittest.dart';

import 'files_mock.dart';
import '../lib/services.dart';
import '../lib/workspace.dart' as ws;

defineTests() {
  ws.Workspace workspace = new ws.Workspace();

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

      return compilerService.start().then((_) {
        // TODO(ericarnold): What's a better way to do this?
        expect(true, equals(true));
      });
    });

    test('analyzer test', () {
      TestService testService = services.getService("test");

      return testService.analyzerSdkTest()
          .then((success) => expect(success, isTrue));
    });

  });

  group('chrome service', () {
    test('resource read', () {
      MockFileSystem fs = new MockFileSystem();
      FileEntry fileEntry = fs.createFile('test.txt', contents: "some words");
      String fileUuid;
      TestService testService = services.getService("test");
      return workspace.link(createWsRoot(fileEntry))
          .then((ws.File fileResource) {
            return testService.readText(fileResource);
          }).then((String text) => expect(text, equals("some words")));
    });
  });

  group('services compiler', () {
    test('hello world', () {
      final String str = "void main() { print('hello world'); }";

      CompilerService compiler = services.getService("compiler");

      return compiler.compileString(str).then((CompilerResult result) {
        expect(result.getSuccess(), true);
        expect(result.output.length, greaterThan(100));
      });
    });

    test('syntax error', () {
      // Missing semi-colon.
      final String str = "void main() { print('hello world') }";

      CompilerService compiler = services.getService("compiler");

      return compiler.compileString(str).then((CompilerResult result) {
        expect(result.getSuccess(), false);
        expect(result.problems.length, 1);
        expect(result.output, null);
      });
    });
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

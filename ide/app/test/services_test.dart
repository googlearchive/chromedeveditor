// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services_test;

import 'dart:async';
import 'dart:isolate';

import 'package:unittest/unittest.dart';

import '../lib/services/services.dart';
import '../services_impl.dart' as impl;

Services services;
impl.ServicesIsolate servicesIsolate;

defineTests() {
  group('services', () {
    setUp(() {
      services = new Services();
    });

    test('ping', () {
      return services.ping().then((result) {
        expect(result, equals("pong"));
      });
    });

    test('example service order', () {
      ExampleService exampleService = services.getService("example");
      Completer completer = new Completer();
      List<String> orderedResponses = [];

      // Test 1 (slow A) starts
      exampleService.longTest("1").then((str) {
        orderedResponses.add(str);
      });

      // Test 2 (fast) starts
      exampleService.shortTest("2").then((str) {
        orderedResponses.add(str);
      });

      // Test 2 should end
      return new Future.delayed(const Duration(milliseconds: 500)).then((_){
        // Test 3 (slow B) starts
        return exampleService.longTest("3").then((str) {
          orderedResponses.add(str);
        });
      }).then((_) =>
          expect(orderedResponses, equals(["short2", "long1", "long3"])));
          // Test 1 should end
          // Test 3 should end
    });

    test('compiler basic test', () {
      CompilerService compilerService = services.getService("compiler");

      return compilerService.start().then((_) {
        // TODO(ericarnold): What's a better way to do this?
        expect(true, equals(true));
      });
    });
  });


  group('services_impl', () {
    test('setup', () {
      MockSendPort mockSendPort = new MockSendPort();
      servicesIsolate = new impl.ServicesIsolate(mockSendPort);
      expect(mockSendPort.wasSent, isNotNull);
    });
    test('compiler start', () {
      MockSendPort mockSendPort = new MockSendPort();
      servicesIsolate = new impl.ServicesIsolate(mockSendPort);
      impl.CompilerServiceImpl compilerImpl =
          servicesIsolate.getServiceImpl("compiler");
      });
    });
  });
}

class MockSendPort extends SendPort {
  bool operator ==(other) => super == other;
  int get hashCode => null;
  var wasSent = null;
  void send(var message) {
    wasSent = message;
  }
}

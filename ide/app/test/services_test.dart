// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services_test;

import 'dart:isolate';

import 'package:unittest/unittest.dart';

import '../lib/services/services.dart';
import '../services_impl.dart';

Services services;
ServicesIsolate servicesIsolate;

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
  });

  group('services_impl', () {
    test('setup', () {
      MockSendPort mockSendPort = new MockSendPort();
      servicesIsolate = new ServicesIsolate(mockSendPort);
      expect(mockSendPort.wasSent, isNotNull);
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

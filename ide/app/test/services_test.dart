// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../lib/services/services.dart';

Services services;

defineTests() {
  group('services', () {
    //

    setUp(() {
      services = new Services();
    });

//    tearDown(() {
//
//    }

    test('ping', () {
      services.ping().then((result) {
        expect("abc", equals("abc"));
      });
    });
  });
}


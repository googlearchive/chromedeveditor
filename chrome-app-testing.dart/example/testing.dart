// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:html';

import 'package:chrome_testing/testing_app.dart';
import 'package:unittest/unittest.dart';

void main() {
  TestDriver testDriver = new TestDriver(
      defineTests, connectToTestListener: true);
}

void display(String str) {
  querySelector('#display').text = str;
}

void defineTests() {
  group('test group 1', () {
    test('test 1', () {
      return new Future.delayed(new Duration(seconds: 1));
    });

    test('test 2', () {
      //fail('test failure');
      return new Future.delayed(new Duration(seconds: 1));
    });

    test('test 3', () {
      return new Future.delayed(new Duration(seconds: 1));
    });

    test('test 4', () {
      return new Future.delayed(new Duration(seconds: 1));
    });
  });

  group('test group 2', () {
    test('test 1', () {
      return new Future.delayed(new Duration(seconds: 1));
    });
  });
}

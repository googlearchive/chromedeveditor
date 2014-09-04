// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library cde_core.adaptable_test;

import 'package:cde_core/adaptable.dart';
import 'package:unittest/unittest.dart';

void defineTests() {
  group('adaptable', () {
    test('simple', () {
      FooAdaptable foo = new FooAdaptable('foo bar');
      expect(foo.adapt(String), isNotNull);
      expect(foo.adapt(DateTime), isNull);
    });
  });
}

class FooAdaptable implements Adaptable {
  final String _data;

  FooAdaptable(this._data);

  dynamic adapt(Type type) {
    if (type == String) return toString();

    return null;
  }

  String toString() => _data;
}

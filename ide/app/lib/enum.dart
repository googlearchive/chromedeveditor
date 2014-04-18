// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// NOTE: Dart doesn't like 'spark.enum': 'enum' must be reserved for future use.
library spark.enum_;

abstract class Enum<T> {
  final T _value;
  const Enum(this._value);
  String get enumName;
  String toString() => '$enumName.$_value';
}

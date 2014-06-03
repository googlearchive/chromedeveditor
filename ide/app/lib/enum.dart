// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.enumerations;

abstract class Enum<T> {
  final T value;
  const Enum(this.value);
  String get enumName;
  String toString() => '$enumName.$value';
}

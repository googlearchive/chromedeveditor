// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.utils;

import 'dart:core';

/**
 * Converts [shaBytes] to HEX string.
 */
String shaBytesToString(List<int> shaBytes) {
  String sha;

  shaBytes.forEach((int byte) {
    sha += byte.toRadixString(16);
  });
  return sha;
}

/**
 * Convertes [sha] string to sha bytes.
 */
List<int> shaToBytes(String sha) {
  List<int> bytes = [];
  for (int i = 0; i < sha.length; ++i) {
    bytes.add(sha.codeUnitAt(i) & 0xff);
  }
  return bytes;
}
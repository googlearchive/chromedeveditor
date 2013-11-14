// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.utils;

import 'dart:core';

/**
 * Convertes [sha] string to sha bytes.
 */
List<int> shaToBytes(String sha) {
  List<int> bytes = [];

  for (var i = 0; i < sha.length; i+=2) {
    bytes.add(int.parse('0x' + sha[i] + sha[i+1]));
  }
  return bytes;
}

/**
 * Converts [shaBytes] to HEX string.
 */
String shaBytesToString(List<int> shaBytes) {
  String sha = "";
  shaBytes.forEach((int byte) {
    sha += byte.toRadixString(16);
  });
  return sha;
}
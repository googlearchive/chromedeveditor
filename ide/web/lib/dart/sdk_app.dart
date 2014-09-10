// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This library exposes the ability to create a Dart SDK from the binary in
 * `sdk/dart-sdk.bz`.
 */
library spark.sdk_app;

import 'dart:async';

import 'sdk.dart';
import '../utils.dart';

/**
 * Create a return a [DartSdk]. Generally, an application will only have one
 * of these object's instantiated. They are however relatively lightweight
 * objects.
 */
Future<DartSdk> createSdk() {
  return getAppContentsBinary('packages/spark/sdk/dart-sdk.bz').then(
      (List<int> contents) {
    return new DartSdk.withContents(contents);
  }).catchError((e) {
    return new DartSdk.fromVersion('');
  });
}

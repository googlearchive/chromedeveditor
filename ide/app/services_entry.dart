// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This is a separate application spawned by Spark (via Services) as an isolate
 * for use in running long-running / heaving tasks.
 */
library spark.services_entry;

import 'dart:isolate';

import 'lib/services/services_impl.dart' as services_impl;

void main(List<String> args, SendPort sendPort) {
  services_impl.init(sendPort);
}

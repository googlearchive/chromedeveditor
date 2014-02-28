// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This is a separate application spawned by Spark (via Services) as an isolate
 * for use in running long-running / heaving tasks.
 */
library spark.services_entry;

import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';

import 'lib/services/services_impl.dart' as services_impl;

SendPort _sendPort;

void main(List<String> args, SendPort sendPort) {
  _sendPort = sendPort;

  // Capture all log messages.
  Logger.root.onRecord.listen((LogRecord r) {
    // if (r.loggerName != 'spark.tests')
    _printToPort(r.toString() + (r.error != null ? ', ${r.error}' : ''));
  });

  _createIsolateZone().runGuarded(() {
    services_impl.init(sendPort);
  });
}

/**
 * Create a [Zone] with an overridden exception handler and print method.
 */
Zone _createIsolateZone() {
  var specification = new ZoneSpecification(
      handleUncaughtError: _handleUncaughtError,
      print: _print);
  return Zone.current.fork(specification: specification);
}

void _handleUncaughtError(Zone self, ZoneDelegate parent, Zone zone,
                              error, StackTrace stackTrace) {
  _printToPort('${error}');
  if (stackTrace != null) _printToPort('${stackTrace}');
}

void _print(Zone self, ZoneDelegate parent, Zone zone, String line) {
  _printToPort(line);
}

/**
 * Print to the matching [SendPort]. Host will know it's a print because it's a
 * simple string instead of a map.
 */
void _printToPort(String str) => _sendPort.send(str);

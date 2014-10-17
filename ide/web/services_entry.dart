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

import 'lib/services/services_common.dart';
import 'lib/services/services_impl.dart' as services_impl;

SendPort _sendPort;

class IsolateWorkerToHostHandler implements WorkerToHostHandler {
  final SendPort _sendPort;
  ReceivePort _receivePort;

  IsolateWorkerToHostHandler(this._sendPort) {
    _receivePort = new ReceivePort();
    _sendPort.send(_receivePort.sendPort);
  }

  @override
  void sendToHost(dynamic message) {
    _sendPort.send(message);
  }

  @override
  void listenFromHost(void onData(var message)) {
    _receivePort.listen(onData);
  }
}

void main(List<String> args, SendPort sendPort) {
  _sendPort = sendPort;

  // Capture all log messages.
  Logger.root.onRecord.listen((LogRecord r) {
    // if (r.loggerName != 'spark.tests')
    _printToPort(r.toString() + (r.error != null ? ', ${r.error}' : ''));
  });

  _createIsolateZone().runGuarded(() {
    services_impl.init(new IsolateWorkerToHostHandler(sendPort));
  });
}

/**
 * Create a [Zone] with an overridden exception handler and print method.
 */
Zone _createIsolateZone() {
  var specification = new ZoneSpecification(
      handleUncaughtError: _handleUncaughtError,
      createTimer: _createTimer,
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
 * Create a 'Timer' implementation for the services isolate that can handle
 * 0 duration timers. If we need support for non-zero durations, we'll need to
 * do some communications back to the main isolate and have it run the timer
 * callbacks for us.
 */
Timer _createTimer(Zone self, ZoneDelegate parent, Zone zone, Duration duration,
    void f()) {

  if (duration.inMilliseconds == 0) {
    return new _Timer(f);
  } else {
    // UnimplementedError: Timers on background isolates are not supported in
    // the browser.
    return parent.createTimer(zone, duration, f);
  }
}

/**
 * Print to the matching [SendPort]. Host will know it's a print because it's a
 * simple string instead of a map.
 */
void _printToPort(String str) => _sendPort.send(str);

class _Timer implements Timer {
  final Function f;
  bool _active = true;

  _Timer(this.f) {
    scheduleMicrotask(() {
      if (isActive) {
        try {
          f();
        } finally {
          _active = false;
        }
      }
    });
  }

  void cancel() { _active = false; }

  bool get isActive => _active;
}

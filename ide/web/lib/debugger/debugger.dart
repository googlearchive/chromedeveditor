// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Model classes for a debugger connection.
 */
library spark.debugger;

import 'dart:async';

class DebuggerManager {
  List<DebuggerConnection> connections = [];

  StreamController _controller = new StreamController.broadcast();

  DebuggerManager();

  void addConnection(DebuggerConnection connection) {
    connections.add(connection);
    _controller.add(connection);

    connection.onClose.listen((_) => connections.remove(connection));
  }

  Stream<DebuggerConnection> get onConnect => _controller.stream;
}

abstract class DebuggerConnection {
  String get name;
  bool get paused;
  List<Frame> get frames;

  Future pause();
  Future resume();

  Future stepIn();
  Future stepOver();
  Future stepOut();

  void terminate();

  Stream<bool> get onSuspended;
  Stream<bool> get onResumed;
  Stream<String> get onConsole;
  Stream get onClose;
}

abstract class Frame {
  Location get location;
  String get name;

  Frame();

  String toString() => '[${name}]';
}

class Location {
  final String url;
  final int lineNumber;
  final int columnNumber;

  Location(this.url, this.lineNumber, [this.columnNumber]);

  String toString() => '${url}:${lineNumber}:${columnNumber}';
}

// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A debugger model implementation for WIP.
 */
library spark.debugger_wip;

import 'dart:async';

import 'debugger.dart';
import 'wip.dart';

class WipDebuggerConnection extends DebuggerConnection {
  final WipConnection connection;
  bool _paused = false;
  List<_WipFrame> _frames = [];

  StreamController _suspendedController = new StreamController.broadcast();
  StreamController _resumedController = new StreamController.broadcast();
  StreamController _consoleController = new StreamController.broadcast();
  StreamController _closeController = new StreamController.broadcast();

  WipDebuggerConnection(this.connection) {
    connection.onClose.listen((_) => _closeController.add(this));

    connection.console.onMessage.listen((ConsoleMessageEvent e) {
      _consoleController.add(e.text);
    });
    connection.console.enable();

    connection.debugger.onPaused.listen(_handlePaused);
    connection.debugger.onResumed.listen((_) => _handleResumed());

    connection.debugger.enable();

    // Send a single event saying that we're running.
    _resumedController.add(null);
  }

  // TODO:
  String get name => 'mobile';

  bool get paused => _paused;

  List<Frame> get frames => _frames;

  Future pause() => connection.debugger.pause();
  Future resume() => connection.debugger.resume();

  Future stepIn() => connection.debugger.stepInto();
  Future stepOver() => connection.debugger.stepOver();
  Future stepOut() => connection.debugger.stepOut();

  void terminate() => connection.close();

  Stream<bool> get onSuspended => _suspendedController.stream;
  Stream<bool> get onResumed => _resumedController.stream;
  Stream<String> get onConsole => _consoleController.stream;
  Stream get onClose => _closeController.stream;

  void _handlePaused(DebuggerPausedEvent event) {
    _paused = true;
    _frames = event.getCallFrames().map(
        (f) => new _WipFrame(connection, f)).toList();
    _suspendedController.add(null);
  }

  void _handleResumed() {
    _paused = false;
    _frames = [];
    _resumedController.add(null);
  }
}

class _WipFrame extends Frame {
  WipCallFrame frame;
  WipScript script;
  Location location;

  _WipFrame(WipConnection connection, this.frame) {
    WipLocation loc = frame.location;
    script = connection.debugger.getScript(loc.scriptId);
    location = new Location(script.url, loc.lineNumber, loc.columnNumber);
  }

  String get name => frame.functionName.isNotEmpty ?
      frame.functionName : _filename(script.url);

  String toString() => '${name}, line ${location.lineNumber}';
}

String _filename(String path) {
  int index = path.lastIndexOf('/');
  return index == -1 ? path : path.substring(index + 1);
}

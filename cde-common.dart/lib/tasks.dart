// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// TODO: WIP - not finished

library cde_common.tasks;

import 'dart:async';

typedef Future<dynamic> TaskEntry(TaskStatus status);

// TODO: timeout of 500ms

/**
 * A [Task] is an abstraction over a long running operation. It supports
 * the ability to cancel the task while its running. The task executes in its
 * own [Zone]. This lets us pro-actively cancel the task if it is not
 * responsive.
 */
class Task {
  final Completer _completer = new Completer();
  final TaskStatus _status = new TaskStatus();

  Task(TaskEntry function) {
    // TODO: also override the timers?
    var spec = new ZoneSpecification(
        handleUncaughtError: _handleUncaughtError,
        scheduleMicrotask: _scheduleMicrotask);
    Zone zone = Zone.current.fork(specification: spec);
    zone.runGuarded(() => _runInZone(function));
  }

  TaskStatus get status => _status;

  /**
   * This returns either the result of the task, an exception, or a
   * [UserCancelledException].
   */
  Future<dynamic> getTaskResult() => _completer.future;

  void _runInZone(TaskEntry function) {
    try {
      var result = function(status);

      if (result is Future) {
        result.then((val) {
          _complete(val);
        }).catchError((e) {
          _completeError(e);
        });
      } else {
        _completeError('TaskEntry result must be a Future');
      }
    } catch (e) {
      _completeError(e);
    }
  }

  dynamic _handleUncaughtError(Zone self, ZoneDelegate parent, Zone zone,
      error, StackTrace stackTrace) {
    if (!_completer.isCompleted) {
      _completer.completeError(error);
      return null;
    } else {
      return parent.handleUncaughtError(zone, error, stackTrace);
    }
  }

  void _scheduleMicrotask(Zone self, ZoneDelegate parent, Zone zone, f()) {
    // TODO:

    parent.scheduleMicrotask(zone, f);
  }

  void _complete(val) {
    if (!_completer.isCompleted) _completer.complete(val);
  }

  void _completeError(e) {
    if (!_completer.isCompleted) _completer.completeError(e);
  }
}

class TaskStatus {
  static void throwCancelled() => throw new UserCancelledException();

  StreamController _controller = new StreamController.broadcast();
  bool _cancelled = false;

  TaskStatus();

  bool get cancelled => _cancelled;

  set cancelled(bool val) {
    _cancelled = val;
    _controller.add(null);
  }

  Stream get onCancelled => _controller.stream;
}

/**
 * TODO: doc
 */
class UserCancelledException implements Exception {

}

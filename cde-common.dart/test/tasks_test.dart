// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library cde_common.tasks_test;

import 'dart:async';

import 'package:cde_common/tasks.dart';
import 'package:unittest/unittest.dart';

void defineTests() {
  group('tasks', () {
    test('simple', () {
      Task task = new Task((TaskStatus status) => new Future(() => 'foo'));
      return task.getTaskResult();
    });

    test('returns Future', () {
      TaskEntry taskFn = (((_) => 'foo') as TaskEntry);
      Task task = new Task(taskFn);
      return task.getTaskResult().then((_) {
        fail('exception expected');
      })
      .catchError((e) {
        expect(e, isNotNull);
      });
    });

    test('exception', () {
      Task task = new Task((TaskStatus status) => new Future.error('foo'));
      return task.getTaskResult().then((_) {
        fail('exception expected');
      })
      .catchError((e) {
        expect(e, isNotNull);
      });
    });

    test('cancelled', () {
      // TODO:

//      TaskStatus _status;
//
//      var cycle;
//      cycle = () {
//        if (_status.cancelled) TaskStatus.throwCancelled();
//        Timer.run(cycle);
//      };
//
//      Task task = new Task((TaskStatus status) {
//        _status = status;
//        cycle();
//      });
//
//      expect(task.getTaskResult(), throwsA(isUserCancelled));
//      _status.cancelled = true;
    });

    test('cancelled unresponsive', () {
      // TODO:

    });
  });
}

const Matcher isUserCancelled = const _IsUserCancelled();

class _IsUserCancelled extends TypeMatcher {
  const _IsUserCancelled() : super("UserCancelledException");
  bool matches(item, Map matchState) => item is UserCancelledException;
}

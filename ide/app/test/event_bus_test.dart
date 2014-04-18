// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.event_bus_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../lib/event_bus.dart';

defineTests() {
  group('event_bus', () {
    test('fire one event', () {
      EventBus bus = new EventBus();
      Future f = bus.onEvent(BusEventType.EDITOR_MANAGER__FILES_SAVED).toList();
      _fireEvents(bus);
      bus.close();
      return f.then((List l) {
        expect(l.length, 1);
      });
    });

    test('fire two events', () {
      EventBus bus = new EventBus();
      Future f = bus.onEvent(BusEventType.EDITOR_MANAGER__FILE_MODIFIED).toList();
      _fireEvents(bus);
      bus.close();
      return f.then((List l) {
        expect(l.length, 2);
      });
    });

    test('receive all events', () {
      EventBus bus = new EventBus();
      Future f = bus.onEvent().toList();
      _fireEvents(bus);
      bus.close();
      return f.then((List l) {
        expect(l.length, 3);
      });
    });
  });
}

void _fireEvents(EventBus bus) {
  bus.addEvent(BusEventType.EDITOR_MANAGER__FILE_MODIFIED, null);
  bus.addEvent(BusEventType.EDITOR_MANAGER__FILE_MODIFIED, null);
  bus.addEvent(BusEventType.EDITOR_MANAGER__FILES_SAVED);
}

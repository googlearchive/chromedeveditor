// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:async';

import 'package:cde_core/dependencies.dart';
import 'package:cde_core/event_bus.dart';
import 'package:unittest/unittest.dart';

void main() => defineTests();

void defineTests() {
  group('dependencies', () {
    test('retrieve dependency', () {
      Dependencies dependency = new Dependencies();
      expect(dependency[String], isNull);
      dependency[String] = 'foo';
      expect(dependency[String], isNotNull);
      expect(dependency[String], 'foo');
    });

    test('runInZone', () {
      expect(Dependencies.instance, isNull);
      Dependencies dependency = new Dependencies();
      expect(Dependencies.instance, isNull);
      dependency[String] = 'foo';
      dependency.runInZone(() {
        expect(Dependencies.instance, isNotNull);
        expect(dependency[String], 'foo');
      });
      expect(Dependencies.instance, isNull);
    });
  });

  group('event_bus', () {
    test('fire one event', () {
      EventBus bus = new EventBus();
      Future f = bus.onEvent('file-save').toList();
      _fireEvents(bus);
      bus.close();
      return f.then((List l) {
        expect(l.length, 1);
      });
    });

    test('fire two events', () {
      EventBus bus = new EventBus();
      Future f = bus.onEvent('file-modified').toList();
      _fireEvents(bus);
      bus.close();
      return f.then((List l) {
        expect(l.length, 2);
        expect(l[0].args['file'], 'a');
        expect(l[1].args['file'], 'b');
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
  bus.addEvent(new BusEvent('file-save', {'file': 'a'}));
  bus.addEvent(new BusEvent('file-modified', {'file': 'a'}));
  bus.addEvent(new BusEvent('file-modified', {'file': 'b'}));
}

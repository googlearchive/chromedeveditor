// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library core.event_bus;

import 'dart:async';

/**
 * An event bus class. Clients can listen for classes of events, optionally
 * filtered by a string type. This can be used to decouple events sources and
 * event listeners.
 */
class EventBus {
  final StreamController<BusEvent> _controller = new StreamController.broadcast();

  EventBus();

  /**
   * Listen for events on the event bus. Clients can pass in an optional [type],
   * which filters the events to only those specific ones.
   */
  Stream<BusEvent> onEvent([String type]) {
    if (type == null) {
      return _controller.stream;
    } else {
      return _controller.stream.where((e) => e.type == type);
    }
  }

  /**
   * Add an event to the event bus.
   */
  void addEvent(BusEvent event) => _controller.add(event);

  /**
   * Close (destroy) this [EventBus]. This is generally not used outside of a
   * testing context. All Stream listeners will be closed and the bus will not
   * fire any more events.
   */
  Future close() => _controller.close();
}

/**
 * An event type for use with [EventBus].
 */
class BusEvent {
  /// The type of the event.
  final String type;

  /// Any args associated with the event. This map can be empty.
  final Map args;

  BusEvent(this.type, [this.args = const {}]);

  String toString() => '[${type}: ${args}]';
}

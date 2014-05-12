// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.event_bus;

import 'dart:async';

import 'enum.dart';

class BusEventType extends Enum<String> {
  const BusEventType._(String value) : super(value);

  String get enumName => 'BusEvent';

  static const PROGRESS_MESSAGE =
      const BusEventType._('PROGRESS_MESSAGE');
  static const ERROR_MESSAGE =
      const BusEventType._('ERROR_MESSAGE');

  static const EDITOR_MANAGER__FILE_MODIFIED =
      const BusEventType._('EDITOR_MANAGER__FILE_MODIFIED');
  static const EDITOR_MANAGER__FILES_SAVED =
      const BusEventType._('EDITOR_MANAGER__FILES_SAVED');
  static const EDITOR_MANAGER__NO_MODIFICATIONS =
      const BusEventType._('EDITOR_MANAGER__NO_MODIFICATIONS');
  static const FILES_CONTROLLER__SELECTION_CHANGED =
      const BusEventType._('FILES_CONTROLLER__SELECTION_CHANGED');
  static const FILES_CONTROLLER__ERROR =
      const BusEventType._('FILES_CONTROLLER__ERROR');
  static const FILES_CONTROLLER__PERSIST_TAB =
      const BusEventType._('FILES_CONTROLLER__PERSIST_TAB');
}

/**
 * An event type for use with [EventBus].
 */
abstract class BusEvent {
  BusEventType get type;

  String toString() => type.toString();
}

class SimpleBusEvent extends BusEvent {
  final BusEventType _type;

  SimpleBusEvent(this._type);

  BusEventType get type => _type;
}

class ProgressMessageBusEvent extends BusEvent {
  final String message;

  ProgressMessageBusEvent(this.message);

  BusEventType get type => BusEventType.PROGRESS_MESSAGE;
}

class ErrorMessageBusEvent extends BusEvent {
  final String title;
  final dynamic error;
  final String stack;

  ErrorMessageBusEvent(this.title, this.error, [this.stack = '']);

  BusEventType get type => BusEventType.ERROR_MESSAGE;
}

/**
 * An event bus class. Clients can listen for classes of events, optionally
 * filtered by a string type. This can be used to decouple events sources and
 * event listeners.
 */
class EventBus {
  StreamController<BusEvent> _controller;

  EventBus() {
    _controller = new StreamController.broadcast();
  }

  /**
   * Listen for events on the event bus. Clients can pass in an optional [type],
   * which filters the events to only those specific ones.
   */
  Stream<BusEvent> onEvent([BusEventType type]) {
    return _controller.stream.where((e) => type == null || e.type == type);
  }

  /**
   * Add an event to the event bus.
   */
  void addEvent(BusEvent event) {
    _controller.add(event);
  }

  /**
   * Close (destroy) this [EventBus]. This is generally not used outside of a
   * testing context. All Stream listeners will be closed and the bus will not
   * fire any more events.
   */
  void close() {
    _controller.close();
  }
}

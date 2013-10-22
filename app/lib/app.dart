/**
 * A lightweight application framework for Spark.
 */
library spark.app;

import 'dart:async';

/**
 * A representation of an application. An application has a lifecycle, and other
 * objects can participate the application's lifecycle state changes.
 */
abstract class Application {
  LifecycleState _state;
  List<LifecycleParticipant> _participants = [];

  Application();

  void addParticipant(LifecycleParticipant participant) {
    // TODO: bring the participant up to the current state, unless the app is
    // closing / closed

    _participants.add(participant);
  }

  LifecycleState get state => _state;

  void start() {
    // TODO: transition to STARTING

    // TODO: transition to STARTED

  }

  void close() {
    // TODO: transition to CLOSING

    // TODO: transition to CLOSED

  }
}

/**
 * The lifecycle of an application is:
 *
 *     STARTING ==> STARTED ==> CLOSING ==> CLOSED
 */
class LifecycleState {
  static const STARTING = const LifecycleState._('starting');
  static const STARTED = const LifecycleState._('started');
  static const CLOSING = const LifecycleState._('closing');
  static const CLOSED = const LifecycleState._('closed');

  final String _value;

  const LifecycleState._(this._value);

  bool operator ==(other) => other is LifecycleState && _value == other._value;

  int get hashCode => _value.hashCode;

  String toString() => _value;
}

/**
 * TODO:
 */
abstract class LifecycleParticipant {

  Future applicationStarting(Application application) => null;

  Future applicationStarted(Application application) => null;

  Future applicationClosing(Application application) => null;

  Future applicationClosed(Application application) => null;
}

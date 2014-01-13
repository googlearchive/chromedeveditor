// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A lightweight application framework for Spark.
 */
library spark.app;

import 'dart:async';

import 'workspace.dart';

/**
 * A representation of an application. An application has a lifecycle and other
 * objects can participate in the application's lifecycle state changes.
 *
 * The lifecycle of an application is:
 *
 *     STARTING ==> STARTED ==> CLOSING ==> CLOSED
 */
abstract class Application {
  FocusManager focusManager = new FocusManager();

  LifecycleState _state;
  List<LifecycleParticipant> _participants = [];

  Future _closing;

  Application();

  /**
   * Add the given [participant] to the list of lifecycle participants. If the
   * application has already started, but has not yet closed, the lifecycle
   * methods will be called on the [participant].
   */
  void addParticipant(LifecycleParticipant participant) {
    _participants.add(participant);

    // Bring the participant up to the current state, unless the app is closing
    // or closed.
    if (state == LifecycleState.STARTING || state == LifecycleState.STARTED) {
      _transition(LifecycleState.STARTING, [participant], recordState: false).then((_) {
        return _transition(LifecycleState.STARTED, [participant], recordState: false);
      });
    }
  }

  LifecycleState get state => _state;

  /**
   * Start the application. Call the `STARTING` and `STARTED` lifecycle change
   * methods on all lifecycle participants. Returns a [Future] which can be used
   * to determine when the application has finished initialization.
   */
  Future start() {
    if (_state != null) {
      throw new StateError('start() can only be called once');
    }

    // transition to STARTING
    return _transition(LifecycleState.STARTING, _participants.toList()).then((_) {
      // transition to STARTED
      return _transition(LifecycleState.STARTED, _participants.toList());
    });
  }

  /**
   * Terminate the application lifecycle. Call the `CLOSING` and `CLOSED`
   * lifecycle methods on all lifecycle participants. Returns a [Future] which
   * can be used to determine when the application has completed closing.
   */
  Future close() {
    if (_closing != null) return _closing;

    // transition to CLOSING
    _closing = _transition(LifecycleState.CLOSING, _participants.toList()).then((_) {
      // transition to CLOSED
      return _transition(LifecycleState.CLOSED, _participants.toList());
    });

    return _closing;
  }

  Future _transition(final LifecycleState newState,
      List<LifecycleParticipant> listeners, {bool recordState: true}) {
    if (recordState) {
      _state = newState;
    }

    return Future.forEach(listeners, (LifecycleParticipant participant) {
      if (newState == LifecycleState.STARTING) {
        return participant.applicationStarting(this);
      } else if (newState == LifecycleState.STARTED) {
        return participant.applicationStarted(this);
      } else if (newState == LifecycleState.CLOSING) {
        return participant.applicationClosing(this);
      } else if (newState == LifecycleState.CLOSED) {
        return participant.applicationClosed(this);
      } else {
        return null;
      }
    });
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
 * An application lifecycle participant. This participant will get notified when
 * the application lifecycle state changes. If it returns a Future from any
 * of it's methods, the lifecycle change will wait on that future before
 * completing.
 */
abstract class LifecycleParticipant {
  /**
   * Return a [Future] to delay the lifecycle change, or `null` otherwise.
   */
  Future applicationStarting(Application application) => null;

  /**
   * Return a [Future] to delay the lifecycle change, or `null` otherwise.
   */
  Future applicationStarted(Application application) => null;

  /**
   * Return a [Future] to delay the lifecycle change, or `null` otherwise.
   */
  Future applicationClosing(Application application) => null;

  /**
   * Return a [Future] to delay the lifecycle change, or `null` otherwise.
   */
  Future applicationClosed(Application application) => null;
}

/**
 * This class is used to track user focus in the application. There are three
 * types of user focus you can track:
 *
 * __Current [Resource].__ This tracks user selection in the Files view and the
 * editor tabs. This can be `null` if there is no user selection. This will
 * generate the highest number of change events.
 *
 * __Current [File] being edited.__ This tracks the file currently being edited
 * in the editor tabs. This file can be different then the current seleciton in
 * the Files view. In can be `null` if there are no open editors.
 *
 * __Currently selected [Project].__ This is derived from the stream of events
 * from the current [Resource]. It changes whenever the currently selected
 * project changes. It can be `null` if there is no selection or if the
 * selected Resource is not in a project.
 */
class FocusManager {
  StreamController<Resource> _resourceController = new StreamController.broadcast();
  StreamController<File> _editedFileController = new StreamController.broadcast();
  StreamController<Project> _projectController = new StreamController.broadcast();

  Resource _currentResource;
  File _currentEditedFile;

  FocusManager();

  /**
   * Indicate that the currently selected [Resource] has changed. This will
   * automatically fire project events if necessary.
   */
  void setCurrentResource(Resource resource) {
    if (_currentResource == resource) return;

    Project oldProject = currentProject;

    _currentResource = resource;
    _resourceController.add(resource);

    if (oldProject != currentProject) {
      _projectController.add(currentProject);
    }
  }

  /**
   * Indicate that the [File] currently being edited has changed. This will
   * automatically fire resource and project events if necessary.
   */
  void setEditedFile(File file) {
    if (_currentEditedFile == file) return;

    _currentEditedFile = file;
    setCurrentResource(file);
    _editedFileController.add(file);
  }

  /**
   * Retrieve the currently selected [Resource]; can be `null`.
   */
  Resource get currentResource => _currentResource;

  /**
   * Retrieve the [File] currently being edited; can be `null`.
   */
  File get currentEditedFile => _currentEditedFile;

  /**
   * Return the [Project] for the currently focused [Resource]; can be `null`.
   */
  Project get currentProject =>
      _currentResource == null ? null : _currentResource.project;

  /**
   * Fires an event when the currently focused [Resource] changes.
   */
  Stream<Resource> get onResourceChange => _resourceController.stream;

  /**
   * Fires an event when the [File] being edited changes.
   */
  Stream<File> get onEditedFileChange => _editedFileController.stream;

  /**
   * Fires an event when the current [Project] changes.
   */
  Stream<Project> get onProjectChange => _projectController.stream;
}

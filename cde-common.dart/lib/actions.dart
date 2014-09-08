// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * TODO:
 */
library cde_common.actions;

import 'dart:async';

/**
 * TODO:
 */
abstract class Action {
  final String name;

  Action(this.name);

  /**
   * Perform the action. This method can return [Future] or `null`. If it
   * returns a `Future`, the action will not be considered to be complete
   * until the `Future` has completed.
   */
  dynamic execute();

  bool get canUndo => false;

  /**
   * Roll back the action. This method can return [Future] or `null`. If it
   * returns a `Future`, the action will not be considered to be undone
   * until the `Future` has completed.
   */
  dynamic undo() => null;

  String toString() => name;
}

/**
 * TODO:
 */
class ActionExecutor {
  final List<Action> _actions = [];
  int _pos = 0;

  StreamController _changeController = new StreamController.broadcast();
  StreamController _exceptionController = new StreamController.broadcast();

  ActionExecutor();

  bool get canRedo => _pos < _actions.length;

  bool get canUndo => _pos > 0 && _currentAction.canUndo;

  Future perform(Action action) {
    if (_pos < _actions.length) {
      _actions.removeRange(_pos, _actions.length);
    }

    _actions.add(action);
    _pos++;

    return _execute(action);
  }

  Future undo() {
    if (!canUndo) return new Future.value();

    Action action = _currentAction;
    _pos--;
    return _execute(action, true);
  }

  Future redo() {
    if (!canRedo) return new Future.value();

    _pos++;
    return _execute(_currentAction);
  }

  /**
   * Remove all `Actions` in this [ActionExecutor] matching the given function.
   */
  void removeMatching(bool matcher(Action action)) {
    // TODO:

  }

  /**
   * This event is fired whenever an action is executed.
   */
  Stream get onChanged => _changeController.stream;

  /**
   * Listen for exceptions that occur as [Action]s are executed.
   */
  Stream<dynamic> get onException => _exceptionController.stream;

  Action get _currentAction => _actions[_pos - 1];

  Future _execute(Action action, [bool undo = false]) {
    try {
      var result = undo ? action.undo() : action.execute();

      if (result is Future) {
        return result.then((_) {
          _changeController.add(null);
        }).catchError((e) {
          _exceptionController.add(e);
          _changeController.add(null);
        });
      } else {
        _changeController.add(null);
        return new Future.value();
      }
    } catch (e) {
      _exceptionController.add(e);
      return new Future.value();
    }
  }
}

// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * TODO:
 */
library cde_common.commands;

import 'dart:async';

/**
 * TODO:
 */
abstract class Command {
  final String description;

  Command(this.description);

  /**
   * Perform the command. This method can return [Future] or `null`. If it
   * returns a `Future`, the command will not be considered to be complete
   * until the `Future` has completed.
   */
  dynamic execute();

  bool get canUndo => false;

  /**
   * Roll back the command. This method can return [Future] or `null`. If it
   * returns a `Future`, the command will not be considered to be undone
   * until the `Future` has completed.
   */
  dynamic undo() => null;

  String toString() => description;
}

/**
 * TODO:
 */
class CommandHistory {
  final List<Command> _commands = [];
  int _pos = 0;

  StreamController _changeController = new StreamController.broadcast();
  StreamController _exceptionController = new StreamController.broadcast();

  CommandHistory();

  bool get canRedo => _pos < _commands.length;

  bool get canUndo => _pos > 0 && _currentCommand.canUndo;

  Future perform(Command command) {
    if (_pos < _commands.length) {
      _commands.removeRange(_pos, _commands.length);
    }

    _commands.add(command);
    _pos++;

    return _execute(command);
  }

  Future undo() {
    if (!canUndo) return new Future.value();

    Command cmd = _currentCommand;
    _pos--;
    return _execute(cmd, true);
  }

  Future redo() {
    if (!canRedo) return new Future.value();

    _pos++;
    return _execute(_currentCommand);
  }

  /**
   * Remove all `Commands` in this [CommandHistory] matching the given function.
   */
  void removeMatching(bool matcher(Command command)) {
    // TODO:

  }

  /**
   * This event is fired whenever a command is executed.
   */
  Stream get onChanged => _changeController.stream;

  /**
   * Listen for exceptions that occur as [Command]s are executed.
   */
  Stream<dynamic> get onException => _exceptionController.stream;

  Command get _currentCommand => _commands[_pos - 1];

  Future _execute(Command command, [bool undo = false]) {
    try {
      var result = undo ? command.undo() : command.execute();

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

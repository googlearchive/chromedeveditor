// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * An [Command] is a builder for [Action]s. [AppAction]s have ids,
 * descriptions, optional text arguments and, given a context, can create
 * commands that can perform work.
 *
 * For example, a command `file-new` may open
 * a new file dialog. It may try and coerce the given [Context] into a file or
 * directory location in which to create the new file.
 *
 * A `sort-lines` command may try and coerce the given context into a text
 * editor. It could create a [Action] which mutated the text editor to sort
 * the given selection. That action could be undoable in order to un-sort the
 * text.
 */
library cde_workbench.commands;

import 'dart:async';

import 'package:cde_common/actions.dart';
import 'package:cde_core/dependencies.dart';
import 'package:logging/logging.dart';

import 'context.dart';

export 'package:cde_common/actions.dart';

Logger _logger = new Logger('cde_workbench.commands');

/**
 * TODO:
 */
abstract class Command {
  static Command create(String id, Function fn) {
    return new _SimpleCommand(id, fn);
  }

  final String id;
  final String description;
  final String argsDescription;

  List<CommandArgument> _args;

  Command(this.id, {this.description, this.argsDescription}) {
    _args = _parseArgs(argsDescription);
  }

  List<CommandArgument> get args => _args;

  // TODO: doc
  Action createAction(Context context, List<String> args);

  List<CommandArgument> _parseArgs(String desc) {
    if (desc == null) return [];

    bool optional = false;

    // Convert '%s %s [%i %s]' into 'string string num (optional) string (optional)'.
    return desc.split(' ').map((str) {
      if (str.startsWith('[')) {
        str = str.substring(1);
        optional = true;
      }

      if (str.endsWith(']')) {
        str = str.substring(0, str.length - 1);
      }

      return new CommandArgument(str == '%s', optional);
    }).toList();
  }

  String toString() => id;
}

class CommandArgument {
  final bool isString;
  final bool optional;

  CommandArgument(this.isString, [this.optional = false]);

  bool get isNum => !isString;

  String toString() =>
      (isString ? 'string' : 'num') + (optional ? ' (optional)' : '');
}

// TODO: perhaps also have a CommandProvider class?

/**
 * TODO:
 */
class CommandManager {
  final List<Command> _commands = [];
  ActionExecutor _actionExecutor;

  CommandManager() {
    _actionExecutor = Dependencies.instance[ActionExecutor];
    assert(_actionExecutor != null);
  }

  void bind(String command, Function fn) =>
      addCommand(Command.create(command, fn));

  void addCommand(Command command) => _commands.add(command);

  Command getCommand(String id) {
    return _commands.firstWhere(
        (command) => command.id == id, orElse: () => null);
  }

  Future executeCommand(Context context, String id, [List args = const []]) {
    Command command = getCommand(id);

    if (command != null) {
      Action action = command.createAction(context, args);
      return _actionExecutor.perform(action);
    } else {
      _logger.warning("command '${id}' not found");
      return new Future.value();
    }
  }
}

class _SimpleCommand extends Command {
  final Function fn;

  _SimpleCommand(String id, this.fn) : super(id);

  Action createAction(Context context, List<String> args) {
    return new SimpleAction(id, fn);
  }
}

class SimpleAction extends Action {
  final Function fn;

  SimpleAction(String description, this.fn) : super(description);

  void execute() => fn();
}

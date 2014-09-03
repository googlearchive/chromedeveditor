// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * An [AppCommand] is a builder for [Command]s. [AppCommand]s have ids,
 * descriptions, optional text arguments and, given a context, can create
 * commands that can perform work.
 *
 * For example, a command `file-new` may open
 * a new file dialog. It may try and coerce the given [Context] into a file or
 * directory location to create the new file in.
 *
 * A `sort-lines` command may try and coerce the given context into a text
 * editor. It could create a [Command] which mutated the text editor to sort
 * the given selection. That command could be undoable in order to un-sort the
 * text.
 */
library cde_workbench.app_commands;

import 'dart:async';

import 'package:cde_common/commands.dart';
import 'package:cde_core/dependencies.dart';
import 'package:logging/logging.dart';

import 'context.dart';

export 'package:cde_common/commands.dart';

Logger _logger = new Logger('cde_workbench.app_commands');

/**
 * TODO:
 */
abstract class AppCommand {
  static AppCommand create(String id, Function fn) {
    return new _SimpleAppCommand(id, fn);
  }

  final String id;
  final String description;
  final String argsDescription;

  List<CommandArgument> _args;

  AppCommand(this.id, {this.description, this.argsDescription}) {
    _args = _parseArgs(argsDescription);
  }

  List<CommandArgument> get args => _args;

  // TODO: doc
  Command createCommand(Context context, List<String> args);

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
  final List<AppCommand> _commands = [];
  CommandHistory _commandExecutor;

  CommandManager() {
    _commandExecutor = Dependencies.instance[CommandHistory];
    assert(_commandExecutor != null);
  }

  void addCommand(AppCommand command) => _commands.add(command);

  AppCommand getAppCommand(String id) {
    return _commands.firstWhere(
        (command) => command.id == id, orElse: () => null);
  }

  Future executeCommand(Context context, String id, [List args = const []]) {
    AppCommand appCommand = getAppCommand(id);

    if (appCommand != null) {
      Command command = appCommand.createCommand(context, args);
      return _commandExecutor.perform(command);
    } else {
      _logger.warning("command '${id}' not found");
      return new Future.value();
    }
  }
}

class _SimpleAppCommand extends AppCommand {
  final Function fn;

  _SimpleAppCommand(String id, this.fn) : super(id);

  Command createCommand(Context context, List<String> args) {
    return new SimpleCommand(id, fn);
  }
}

class SimpleCommand extends Command {
  final Function fn;

  SimpleCommand(String description, this.fn) : super(description);

  void execute() => fn();
}

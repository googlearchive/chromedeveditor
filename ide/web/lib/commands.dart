// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.commands;

// TODO(devoncarew): Add support for listening to command enablement.

import 'dart:async';
import 'dart:html';

/**
 * A [CommandManager] manages a set of commands and [CommandHandler]s.
 */
class CommandManager {
  Map<String, CommandHandler> _handlers = {};

  CommandManager();

  /// Return the list of supported commands.
  List<String> get commands => _handlers.keys.toList();

  /**
   * Listen to a given node (and all child nodes) for `command` custom events.
   * When these events occur, they are dispatched to a registered
   * [CommandHandler] for that particular command.
   */
  void listenToDom(Element element) {
    element.on['command'].listen((e) {
     if (e is CustomEvent && e.type == 'command') {
       String command = e.detail['command'];

       if (supportsCommand(command)) {
         e.stopPropagation();
         performCommand(command, e.detail);
       }
     }
   });
  }

  void registerHandler(String command, CommandHandler handler) {
    _handlers[command] = handler;
  }

  /// Return whether the given command is supported.
  bool supportsCommand(String command) => _handlers.containsKey(command);

  /// Perform the given command.
  void performCommand(String command, [Map detail]) {
    if (_handlers.containsKey(command)) {
      CommandHandler handler = _handlers[command];
      // TODO(devoncarew): Catch exceptions.
      handler.invoke(detail);
    }
  }
}

/**
 * A [CommandProvider] can provide behavior for n commands.
 */
abstract class CommandProvider {
  /// Return the list of supported commands.
  List<String> get commands;

  /// Return whether the given command is supported.
  bool supportsCommand(String command) {
    return commands.contains(command);
  }

  /// Perform the given command.
  void performCommand(String command, [Map detail]);
}

/**
 * A command handler is capable of performing work on request. It has a notion
 * of enablement and enabled events. User's call [invoke] to have it perform its
 * work.
 */
abstract class CommandHandler {
  bool get enabled;

  void invoke([Map args]);

  Stream<bool> get onEnabledChanged;
}

/**
 * An abstract implementation of a [CommandHandler]. This implementation adds
 * behavior behind [enabled] and [onEnabledChanged]. Subclasses will need to
 * implement the [invoke] method;
 */
abstract class AbstractCommandHandler extends CommandHandler {
  bool _enabled = true;
  StreamController<bool> _controller = new StreamController.broadcast();

  void invoke([Map args]);

  bool get enabled => _enabled;
  set enabled(bool value) {
    _enabled = value;
    _controller.add(value);
  }

  Stream<bool> get onEnabledChanged => _controller.stream;
}

/**
 * A [CommandHandler] implmentation that delegates to a no-arg function. This
 * command handler implementation is always enabled.
 */
class FunctionCommandHandler extends CommandHandler {
  final StreamController<bool> _controller = new StreamController.broadcast();
  final Function _fn;

  FunctionCommandHandler(this._fn);

  bool get enabled => true;

  void invoke([Map args]) => _fn();

  Stream<bool> get onEnabledChanged => _controller.stream;
}

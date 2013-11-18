// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * An entrypoint to the [ace.dart](https://github.com/rmsmith/ace.dart) package.
 */
library spark.ace;

import 'dart:async';
import 'dart:html';
import 'dart:js' as js;

import 'package:ace/ace.dart' as ace;

import 'workspace.dart' as workspace;

export 'package:ace/ace.dart' show EditSession;

/**
 * A wrapper around an Ace editor instance.
 */
class AceEditor {
  static final KEY_BINDINGS =
      [null, ace.KeyboardHandler.EMACS, ace.KeyboardHandler.VIM];
  static final THEMES = ['ambiance', 'monokai', 'pastel_on_dark', 'textmate'];

  /// The element to put the editor in.
  final Element parentElement;

  ace.Editor _aceEditor;
  workspace.File _file;

  static bool get available => js.context['ace'] != null;

  AceEditor(this.parentElement) {
    _aceEditor = ace.edit(parentElement);
    _aceEditor.readOnly = true;

    // Fallback
    theme = THEMES[0];
  }

  String get theme => _aceEditor.theme.name;

  set theme(String value) => _aceEditor.theme = new ace.Theme.named(value);

  Future<String> getKeyBinding() {
    var handler = _aceEditor.keyBinding.keyboardHandler;
    return handler.onLoad.then((_) {
      return KEY_BINDINGS.contains(handler.name) ? handler.name : null;
    });
  }

  void setKeyBinding(String name) {
    if (name == null) {
      _aceEditor.keyBinding.keyboardHandler = null;
    } else {
      var handler = new ace.KeyboardHandler.named(name);
      handler.onLoad.then((_) => _aceEditor.keyBinding.keyboardHandler = handler);
    }
  }

  void focus() => _aceEditor.focus();

  void resize() => _aceEditor.resize(false);

  ace.EditSession createEditSession(String text, String fileName) {
    ace.EditSession session = ace.createEditSession(
        text, new ace.Mode.forFile(fileName));
    // Disable Ace's analysis (this shows up in JavaScript files).
    session.useWorker = false;
    return session;
  }

  void switchTo(ace.EditSession session) {
    if (session == null) {
      _aceEditor.session = ace.createEditSession('', new ace.Mode('ace/mode/text'));
      _aceEditor.readOnly = true;
    } else {
      _aceEditor.session = session;

      if (_aceEditor.readOnly) {
        _aceEditor.readOnly = false;
      }
    }
  }
}

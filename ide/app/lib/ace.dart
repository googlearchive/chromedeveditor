// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * An entrypoint to the [ace.dart](https://github.com/rmsmith/ace.dart) package.
 */
library spark.ace;

import 'dart:html';
import 'dart:js' as js;

import 'package:ace/ace.dart' as ace;

import 'workspace.dart' as workspace;
import 'editors.dart';

export 'package:ace/ace.dart' show EditSession;

/**
 * A wrapper around an Ace editor instance.
 */
class AceContainer {
  // 2 light themes, 4 dark ones.
  static final THEMES = [
      'textmate', 'tomorrow',
      'tomorrow_night', 'monokai', 'idle_fingers', 'pastel_on_dark'
  ];

  /**
   * The container for the Ace editor.
   */
  final Element parentElement;

  ace.Editor _aceEditor;
  workspace.File _file;

  static bool get available => js.context['ace'] != null;

  AceContainer(this.parentElement) {
    _aceEditor = ace.edit(parentElement);
    _aceEditor.renderer.fixedWidthGutter = true;
    _aceEditor.highlightActiveLine = false;
    _aceEditor.readOnly = true;
    _aceEditor.printMarginColumn = 80;
    //_aceEditor.renderer.showGutter = false;
    _aceEditor.setOption('scrollPastEnd', true);

    // Fallback
    theme = THEMES[0];
  }

  String get theme => _aceEditor.theme.name;

  set theme(String value) => _aceEditor.theme = new ace.Theme.named(value);

  // TODO: only used by the polymer version
  void setTheme(String theme) {
    _aceEditor.theme = new ace.Theme(theme);
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

class AceEditor extends Editor {
  final AceContainer aceContainer;

  Element get parentElement => aceContainer.parentElement;

  AceEditor(this.aceContainer);

}

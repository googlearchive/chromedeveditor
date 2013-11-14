// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * An entrypoint to the [ace.dart](https://github.com/rmsmith/ace.dart) package.
 */
library spark.editors.ace;

import 'dart:async';
import 'dart:html' show DivElement, Element;
import 'dart:js' as js;
import 'package:ace/ace.dart' as ace;

import 'editor.dart';
import '../workspace.dart';

/**
 * This class tracks the state associated with each open editor.
 */
class AceEditorSession implements EditorSession {
  File file = null;
  int scrollTop = 0;

  final AceEditor _sharedEditor;
  bool _dirty = false;
  ace.EditSession _session = null;
  int _savings = 0;
  Future _pendingSaving = new Future.value();
  Timer _savingTimer = null;

  AceEditorSession(this._sharedEditor);

  bool get dirty => _dirty;

  bool get loaded => _session != null;

  Editor get editor => _sharedEditor;

  Future loadFile() {
    if (_session != null) {
      return new Future.value();
    } else {
      return file.getContents().then((text) {
        _session =
            _sharedEditor.createEditSession(text, file.name);
        _session.scrollTop = scrollTop;
        _session.onChange.listen((delta) {
          _dirty = true;
          _scheduleSave();
        });
      });
    }
  }

  void _scheduleSave({int ms: 150}) {
    if(_savingTimer != null) _savingTimer.cancel();
    _savingTimer = new Timer(new Duration(milliseconds: ms), saveFile);
  }

  // file.setContents(_session.value)
  Future saveFile() {
    if (_dirty) {
      if(_savingTimer != null) _savingTimer.cancel();
      _savings++;
      // There is a chance that [saveFile] is triggered durring the file is
      // saved. That canse we need to wait for the pending write to finish
      // before we start another one. It is rare because the 2 seond cooling
      // time.
      var savingCompleter = new Completer();
      // Wait for pending saving before saving is started;
      _pendingSaving.then((_) => file.setContents(_session.value).then((_) {
        _savings--;
        _dirty = _savings == 0;
        savingCompleter.complete();
      }));
      _pendingSaving = savingCompleter.future;
    } else {
      return new Future.value(null);
    }
  }

  bool fromMap(Map m, Workspace workspace) {
    File f = workspace.restoreResource(m['file']);
    if (f == null) {
      return false;
    } else {
      file = f;
      scrollTop = m['scrollTop'];
      return true;
    }
  }

  Map toMap() {
    return {
      'file': file == null ? null : file.path,
      'scrollTop': scrollTop
    };
  }
}

/**
 * A wrapper around an Ace editor instance.
 */
class AceEditor extends Editor {
  static final THEMES = ['ambiance', 'monokai', 'pastel_on_dark', 'textmate'];

  final Element rootElement;

  ace.Editor _aceEditor;
  bool _dirty = false;
  File _file;
  AceEditorSession _currentState;

  static bool get available => js.context['ace'] != null;

  AceEditor(this.rootElement) {
    _aceEditor = ace.edit(rootElement);
    _aceEditor.readOnly = true;

    // Fallback
    theme = THEMES[0];
  }

  String get theme => _aceEditor.theme.name;

  set theme(String value) => _aceEditor.theme = new ace.Theme.named(value);

  // TODO: only used by the polymer version
  void setTheme(String theme) {
    _aceEditor.theme = new ace.Theme(theme);
  }

  get readOnly =>_aceEditor.readOnly;
  set readOnly(bool value) =>_aceEditor.readOnly = value;

  void focus() => _aceEditor.focus();

  void resize() => _aceEditor.resize(false);

  ace.EditSession createEditSession(String text, String fileName) {
    ace.EditSession session = ace.createEditSession(
        text, new ace.Mode.forFile(fileName));
    // Disable Ace's analysis (this shows up in JavaScript files).
    session.useWorker = false;
    return session;
  }

  @override
  AceEditorSession get session => _currentState;

  @override
  void set session(AceEditorSession state) {
    _currentState = state;
    if (state == null) {
      // Emptying the editor
      // TODO(ikarienator) create an EditorSession for
      _aceEditor.session =
          ace.createEditSession('', new ace.Mode('ace/mode/text'));
      _aceEditor.readOnly = true;
      focus();
    } else {
      session.loadFile().then((_) {
        _aceEditor.session = state._session;
        if (_aceEditor.readOnly) {
          _aceEditor.readOnly = false;
        }
        focus();
      });
    }
  }
}

/**
 * [EditorProvider] for text files.
 */
class AceEditorProvider extends DefaultEditorProvider {
  final AceEditor editor = new AceEditor(new DivElement());

  EditorSession createSession(File file) {
    return new AceEditorSession(editor)..file = file;
  }
}

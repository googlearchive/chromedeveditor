// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * An entrypoint to the [ace.dart](https://github.com/rmsmith/ace.dart) package.
 */
library spark.ace;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html' show Element;
import 'dart:js' as js;

import 'package:ace/ace.dart' as ace;

import 'editors.dart';
import 'preferences.dart';
import 'workspace.dart' as workspace;

/**
 * A wrapper around an Ace editor instance.
 */
class AceEditor implements Editor {
  static final THEMES = ['ambiance', 'monokai', 'pastel_on_dark', 'textmate'];

  /// The element to put the editor in.
  final Element rootElement;

  ace.Editor _aceEditor;
  workspace.File _file;
  AceEditorState _state;

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

  void focus() => _aceEditor.focus();

  void resize() => _aceEditor.resize(false);

  ace.EditSession createEditSession(String text, String fileName) {
    ace.EditSession session = ace.createEditSession(
        text, new ace.Mode.forFile(fileName));
    // Disable Ace's analysis (this shows up in JavaScript files).
    session.useWorker = false;
    return session;
  }

  AceEditorState get state => _state;
  void set state(AceEditorState state) {
    _state = state;
    if (state == null) {
      _aceEditor.session = ace.createEditSession('', new ace.Mode('ace/mode/text'));
      _aceEditor.readOnly = true;
    } else {
      state.withSession().then((state) {
        if (state != _state) return;
        _aceEditor.session = state.session;

        if (_aceEditor.readOnly) {
          _aceEditor.readOnly = false;
        }
      });
    }
  }
}


/**
 * This class tracks the state associated with each open editor.
 */
class AceEditorState implements EditorState {
  AceEditor editor;
  AceEditorManager manager;
  workspace.File file;
  ace.EditSession session;

  int scrollTop = 0;
  bool _dirty = false;

  AceEditorState(this.editor, this.manager);

  bool fromMap(workspace.Workspace workspace, Map m) {
    workspace.File f = workspace.restoreResource(m['file']);

    if (f == null) {
      return false;
    } else {
      file = f;
      scrollTop = m['scrollTop'];
      return true;
    }
  }

  bool get dirty => _dirty;

  set dirty(bool value) {
    if (_dirty != value) {
      _dirty = value;
      if (_dirty) {
        manager._startSaveTimer();
      }
    }
  }

  bool get hasSession => session != null;

  void save() {
    if (dirty) {
      file.setContents(session.value);
      dirty = false;
    }
  }

  /**
   * Return a [Map] representing the persistable state of this editor. This map
   * can later be passed into [AceEditorState.fromMap] to restore the state.
   */
  Map toMap() {
    Map m = {};
    m['file'] = file.persistToToken();
    m['scrollTop'] = session == null ? scrollTop : session.scrollTop;
    return m;
  }

  Future<AceEditorState> withSession() {
    if (hasSession) {
      return new Future.value(this);
    } else {
      return file.getContents().then((text) {
        session = editor.createEditSession(text, file.name);
        session.scrollTop = scrollTop;
        session.onChange.listen((delta) => dirty = true);
        return this;
      });
    }
  }
}


/**
 * Manage a list of open editors.
 */
class AceEditorManager implements EditorProvider {
  final AceEditor editor;
  final workspace.Workspace _workspace;

  final PreferenceStore _prefs;

  final List<AceEditorState> _editorStates = [];

  final Completer<bool> _loadedCompleter = new Completer.sync();
  AceEditorState _currentState;

  final StreamController<workspace.File> _selectedController =
      new StreamController.broadcast();

  AceEditorManager(this._workspace, this.editor, this._prefs) {
    _workspace.whenAvailable().then((_) {
      _prefs.getValue('editorStates').then((String data) {
        if (data != null) {
          for (Map m in JSON.decode(data)) {
            workspace.File f = _workspace.restoreResource(m['file']);
            openOrSelect(f, switching: false);
          }
          _loadedCompleter.complete(true);
        }
      });
    });
  }

  workspace.File get currentFile =>
      _currentState != null ? _currentState.file : null;

  Iterable<workspace.File> get files => _editorStates.map((s) => s.file);
  Future<bool> get loaded => _loadedCompleter.future;

  Stream<workspace.File> get onSelectedChange => _selectedController.stream;

  bool get dirty => _currentState == null ? false : _currentState.dirty;

  void _insertState(AceEditorState state) => _editorStates.add(state);

  bool _removeState(AceEditorState state) => _editorStates.remove(state);

  /**
   * This will open the given [File]. If this file is already open, it will
   * instead be made the active editor.
   */
  void openOrSelect(workspace.File file, {switching: true}) {
    if (file == null) return;
    AceEditorState state = _getStateFor(file);

    if (state == null) {
      state = new AceEditorState(editor, this);
      state.file = file;
      _insertState(state);
    }

    if (switching)
      _switchState(state);
  }

  bool isFileOpend(workspace.File file) => _getStateFor(file) != null;

  void saveAll() => _saveAll();

  void close(workspace.File file) {
    AceEditorState state = _getStateFor(file);

    if (state != null) {
      int index = _editorStates.indexOf(state);
      _removeState(state);

      if (state.dirty) {
        state.save();
      }

      if (_currentState == state) {
        // Switch to the next editor.
        if (_editorStates.isEmpty) {
          _switchState(null);
        } else if (index < _editorStates.length){
          _switchState(_editorStates[index]);
        } else {
          _switchState(_editorStates[index - 1]);
        }
      }

      persistState();
    }
  }

  void persistState() {
    var stateData = _editorStates.map((state) => state.toMap()).toList();
    _prefs.setValue('editorStates', JSON.encode(stateData));
  }

  AceEditorState _getStateFor(workspace.File file) {
    for (AceEditorState state in _editorStates) {
      if (state.file == file) {
        return state;
      }
    }

    return null;
  }

  void _switchState(AceEditorState state) {
    if (_currentState != state) {
      _currentState = state;
      _selectedController.add(currentFile);
      if (state == null) {
          editor.state = null;
          persistState();
      } else {
        state.withSession().then((state) {
          // Test if other state have been set before this state is appiled.
          if (state != _currentState) return;
          _selectedController.add(currentFile);
          editor.state = state;
          persistState();
        });
      }
    }
  }

  Timer _timer;

  void _startSaveTimer() {
    if (_timer != null) _timer.cancel();

    _timer = new Timer(new Duration(seconds: 2), () => _saveAll());
  }

  void _saveAll() {
    if (_timer != null) {
      _timer.cancel();
      _timer = null;
    }

    // TODO: start a workspace change event; this might modify multiple files
    _editorStates.forEach((e) => e.save());
    // TODO: end the workspace change event
  }

  // EditorProvider
  AceEditor createEditorForFile(workspace.Resource file) {
    openOrSelect(file);
    return editor;
  }

  void selectFileForEditor(AceEditor editor, workspace.Resource file) {
    AceEditorState state = _getStateFor(file);
    _switchState(state);
  }
}

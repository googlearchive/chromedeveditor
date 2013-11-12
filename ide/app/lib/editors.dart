// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to manage the list of open editors, and persist their state (like
 * their selection and scroll position) across sessions.
 */
library spark.editors;

import 'dart:async';
import 'dart:convert' show JSON;

import 'ace.dart';
import 'preferences.dart';
import 'workspace.dart';

/**
 * Manage a list of open editors.
 */
class EditorManager {
  Workspace _workspace;
  AceEditor _aceEditor;
  PreferenceStore _prefs;
  List<_EditorState> _editorStates = [];
  _EditorState _currentState;
  StreamController<File> _selectedController = new StreamController.broadcast();

  EditorManager(this._workspace, this._aceEditor, this._prefs) {
    _workspace.whenAvailable().then((_) {
      _prefs.getValue('editorStates').then((String data) {
        if (data != null) {
          for (Map m in JSON.decode(data)) {
            _EditorState state = new _EditorState.fromMap(this, _workspace, m);

            if (state != null) {
              _editorStates.add(state);
            }
          }
        }
      });
    });
  }

  File get currentFile => _currentState != null ? _currentState.file : null;

  Iterable<File> get files => _editorStates.map((s) => s.file);

  Stream<File> get onSelectedChange => _selectedController.stream;

  bool get dirty => _currentState == null ? false : _currentState.dirty;

  void select(File file) {
    _EditorState state = _getStateFor(file);

    if (state == null) {
      state = new _EditorState.fromFile(this, file);
      _editorStates.add(state);
    }

    _switchState(state);
  }

  void saveAll() => _saveAll();

  void close(File file) {
    _EditorState state = _getStateFor(file);

    if (state != null) {
      int index = _editorStates.indexOf(state);
      _editorStates.remove(state);

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
    }
  }

  void persistState() {
    var stateData = _editorStates.map((state) => state.toMap()).toList();
    _prefs.setValue('editorStates', JSON.encode(stateData));
  }

  _EditorState _getStateFor(File file) {
    for (_EditorState state in _editorStates) {
      if (state.file == file) {
        return state;
      }
    }

    return null;
  }

  void _switchState(_EditorState state) {
    if (_currentState != state) {
      if (state != null && !state.isRealized) {
        state.realize().then((_) {
          _switchState(state);
        });
      } else {
        _currentState = state;
        _selectedController.add(currentFile);
        _aceEditor.switchTo(state == null ? null : state.session);

        persistState();
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
}

/**
 * This class tracks the state associated with each open editor.
 */
class _EditorState {
  EditorManager manager;
  File file;
  EditSession session;

  int scrollTop = 0;
  bool _dirty = false;

  _EditorState.fromFile(this.manager, this.file);

  factory _EditorState.fromMap(EditorManager manager, Workspace workspace, Map m) {
    File f = workspace.restoreResource(m['file']);

    if (f == null) {
      return null;
    } else {
      _EditorState state = new _EditorState.fromFile(manager, f);
      state.scrollTop = m['scrollTop'];
      return state;
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

  bool get isRealized => session != null;

  void save() {
    if (dirty) {
      file.setContents(session.value);
      dirty = false;
    }
  }

  Map toMap() {
    Map m = {};
    m['file'] = file.persistToToken();
    m['scrollTop'] = session == null ? scrollTop : session.scrollTop;
    return m;
  }

  Future<_EditorState> realize() {
    return file.getContents().then((text) {
      session = manager._aceEditor.createEditSession(text, file.name);
      session.scrollTop = scrollTop;
      session.onChange.listen((delta) => dirty = true);
      return this;
    });
  }
}

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

class DirtyFlagChangedEvent {
  final File file;
  final bool dirty;
  DirtyFlagChangedEvent(this.file, this.dirty);
}

/**
 * Classes implement this interface provides/refreshes editors for [Resource]s.
 * TODO(ikarienator): Abstract [AceEditor] so we can support more editor types.
 */
abstract class EditorProvider {
  AceEditor createEditorForFile(Resource file);
  void selectFileForEditor(AceEditor editor, Resource file);
  void close(Resource file);
  Stream<DirtyFlagChangedEvent> get onDirtyFlagChanged;
}


/**
 * Manage a list of open editors.
 */
class EditorManager implements EditorProvider {
  final Workspace _workspace;
  final AceEditor _aceEditor;

  final PreferenceStore _prefs;

  final List<_EditorState> _editorStates = [];

  final Completer<bool> _loadedCompleter = new Completer.sync();
  _EditorState _currentState;

  final StreamController<File> _selectedController =
      new StreamController.broadcast();
  final StreamController<DirtyFlagChangedEvent> _dirtyFlagChangedController =
      new StreamController.broadcast();

  EditorManager(this._workspace, this._aceEditor, this._prefs) {
    _workspace.whenAvailable().then((_) {
      _prefs.getValue('editorStates').then((String data) {
        if (data != null) {
          for (Map m in JSON.decode(data)) {
            File f = _workspace.restoreResource(m['file']);
            openOrSelect(f, switching: false);
          }
          _loadedCompleter.complete(true);
        }
      });
    });
  }

  File get currentFile => _currentState != null ? _currentState.file : null;

  Iterable<File> get files => _editorStates.map((s) => s.file);
  Future<bool> get loaded => _loadedCompleter.future;

  Stream<File> get onSelectedChange => _selectedController.stream;

  bool get dirty => _currentState == null ? false : _currentState.dirty;

  void _insertState(_EditorState state) => _editorStates.add(state);

  bool _removeState(_EditorState state) => _editorStates.remove(state);

  /**
   * This will open the given [File]. If this file is already open, it will
   * instead be made the active editor.
   */
  void openOrSelect(File file, {switching: true}) {
    if (file == null) return;
    _EditorState state = _getStateFor(file);

    if (state == null) {
      state = new _EditorState.fromFile(this, file);
      _insertState(state);
    }

    if (switching)
      _switchState(state);
  }

  bool isFileOpend(File file) => _getStateFor(file) != null;

  void saveAll() => _saveAll();

  void close(File file) {
    _EditorState state = _getStateFor(file);

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
      _currentState = state;
      _selectedController.add(currentFile);
      if (state == null) {
          _aceEditor.switchTo(null);
          persistState();
      } else {
        state.withSession().then((state) {
          // Test if other state have been set before this state is appiled.
          if (state != _currentState) return;
          _selectedController.add(currentFile);
          _aceEditor.switchTo(state.session);
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
  AceEditor createEditorForFile(Resource file) {
    openOrSelect(file);
    return _aceEditor;
  }

  void selectFileForEditor(AceEditor editor, Resource file) {
    _EditorState state = _getStateFor(file);
    _switchState(state);
  }

  Stream<DirtyFlagChangedEvent> get onDirtyFlagChanged =>
      _dirtyFlagChangedController.stream;
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

  factory _EditorState.fromMap(EditorManager manager,
                               Workspace workspace,
                               Map m) {
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
      manager._dirtyFlagChangedController.add(
          new DirtyFlagChangedEvent(file, value));
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
   * can later be passed into [_EditorState.fromMap] to restore the state.
   */
  Map toMap() {
    Map m = {};
    m['file'] = file.persistToToken();
    m['scrollTop'] = session == null ? scrollTop : session.scrollTop;
    return m;
  }

  Future<_EditorState> withSession() {
    if (hasSession) {
      return new Future.value(this);
    } else {
      return file.getContents().then((text) {
        session = manager._aceEditor.createEditSession(text, file.name);
        session.scrollTop = scrollTop;
        session.onChange.listen((delta) => dirty = true);
        return this;
      });
    }
  }
}

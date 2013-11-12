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
import 'ui/widgets/tabview.dart';

/**
 * Manage a list of open editors.
 */
class EditorManager {
  final Workspace _workspace;
  final AceEditor _aceEditor;

  // TODO(ikarienator): When we reverse the responsibility of state
  // serialization, abstract opened file collection and move _tabView to
  // higher level (potentially in [Spark] class).
  final TabView _tabView;
  final PreferenceStore _prefs;

  final List<_EditorState> _editorStates = [];
  _EditorState _currentState;

  final StreamController<File> _selectedController =
      new StreamController.broadcast();

  EditorManager(this._workspace, this._tabView, this._aceEditor, this._prefs) {
    _workspace.whenAvailable().then((_) {
      _prefs.getValue('editorStates').then((String data) {
        if (data != null) {
          for (Map m in JSON.decode(data)) {
            File f = _workspace.restoreResource(m['file']);
            openOrSelect(f, switching: false);
          }
          _prefs.getValue('lastSelectedEditor').then((String data) {
            if (_editorStates.isEmpty) return;
            int index = data == null ? 0 : JSON.decode(data);
            if (index != null && index >= 0)
              _switchState(_editorStates[index]);
          });

          _tabView.onSelected.listen((tab) {
            _switchState(_editorStates.firstWhere((state) => state.tab == tab));
          });
        }
      });
    });
  }

  File get currentFile => _currentState != null ? _currentState.file : null;

  Iterable<File> get files => _editorStates.map((s) => s.file);

  Stream<File> get onSelectedChange => _selectedController.stream;

  bool get dirty => _currentState == null ? false : _currentState.dirty;

  void _insertState(_EditorState state) {
    _editorStates.add(state);
    _tabView.add(state.tab);
    if (_tabView.tabs.length > 1) {
      _tabView.tabs.forEach((tab) { tab.closable = true; });
    }
  }

  void _removeState(_EditorState state) {
    _editorStates.remove(state);
    _tabView.remove(state.tab, switchTab: false);

    if (_tabView.tabs.length == 1) {
      _tabView.tabs[0].closable = false;
    }
  }

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

  bool isFileOpend(File file) {
    return _getStateFor(file) != null;
  }

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
    _prefs.setValue('lastSelectedEditor', JSON.encode(
        _editorStates.indexOf(_currentState)));
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
      if (state != null && !state.hasSession) {
        state.createSession().then((_) {
          _switchState(state);
        });
      } else {
        _currentState = state;
        _prefs.setValue('lastSelectedEditor', JSON.encode(
            _editorStates.indexOf(_currentState)));
        _selectedController.add(currentFile);
        _aceEditor.switchTo(state == null ? null : state.session);

        persistState();
      }

      if (state != null)
        _tabView.selectedTab = state.tab;
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
  Tab tab;

  int scrollTop = 0;
  bool _dirty = false;

  _EditorState.fromFile(this.manager, this.file) {
    tab = new Tab(
        manager._tabView,
        manager._aceEditor.parentElement,
        closable: false);
    tab.label = file.name + (_dirty ? '*' : '');
    tab.onClose.listen((tab) { manager.close(file); });
  }

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
      tab.label = file.name + (_dirty ? '*' : '');
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
   * can later be passed into [_EditorState.fromMap] to restore the state.
   */
  Map toMap() {
    Map m = {};
    m['file'] = file.persistToToken();
    m['scrollTop'] = session == null ? scrollTop : session.scrollTop;
    return m;
  }

  Future<_EditorState> createSession() {
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

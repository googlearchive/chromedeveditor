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
import 'dart:html' as html;

import 'ace.dart' as ace;
import 'event_bus.dart';
import 'preferences.dart';
import 'workspace.dart';
import 'ui/widgets/imageviewer.dart';

// The auto-save delay - the time from the last user edit to the file auto-save.
final int _DELAY_MS = 500;

/**
 * Classes implement this interface provides/refreshes editors for [Resource]s.
 * TODO(ikarienator): Abstract [TextEditor] so we can support more editor types.
 */
abstract class EditorProvider {
  Editor createEditorForFile(File file);
  void activate(Editor editor);
  void close(File file);
}

/**
 * An abstract Editor class. It knows:
 *
 *  * the main DOM element it's associated with
 *  * the File it's editing
 *
 * In the future, it will know how to save and restore its session state.
 */
abstract class Editor {
  html.Element get element;
  File get file;
  bool get dirty;

  Stream get onDirtyChange;

  void activate();
  void resize();
  void focus();
  Future save();
}

/**
 * Manage a list of open editors.
 */
class EditorManager implements EditorProvider {
  final Workspace _workspace;
  final ace.AceManager _aceContainer;
  final PreferenceStore _prefs;
  final EventBus _eventBus;

  static final int PREFS_EDITORSTATES_VERSION = 1;

  static final int EDITOR_TYPE_IMAGE = 1;
  static final int EDITOR_TYPE_TEXT = 2;

  // List of files opened in a tab.
  final List<_EditorState> _openedEditorStates = [];
  // Keep state of files that have been opened earlier.
  // Keys are persist tokens of the files.
  final Map<String, _EditorState> _savedEditorStates = {};
  final Map<File, Editor> _editorMap = {};

  final Completer<bool> _loadedCompleter = new Completer.sync();
  _EditorState _currentState;

  final StreamController<File> _selectedController =
      new StreamController.broadcast();

  static final RegExp _imageFileType =
      new RegExp(r'\.(jpe?g|png|gif)$', caseSensitive: false);

  // TODO: Investigate dependency injection OR overridable singletons. We're
  // passing around too many ctor vars.
  EditorManager(this._workspace, this._aceContainer, this._prefs, this._eventBus) {
    _workspace.whenAvailable().then((_) {
      _restoreState().then((_) {
        _loadedCompleter.complete(true);
      });
    });
  }

  File get currentFile => _currentState != null ? _currentState.file : null;

  Iterable<File> get files => _openedEditorStates.map((s) => s.file);
  Future<bool> get loaded => _loadedCompleter.future;
  Iterable<Editor> get editors => _editorMap.values;

  Stream<File> get onSelectedChange => _selectedController.stream;

  void _insertState(_EditorState state) {
    _openedEditorStates.add(state);
    _savedEditorStates[state.file.persistToToken()] = state;
  }

  bool _removeState(_EditorState state) => _openedEditorStates.remove(state);

  /**
   * This will open the given [File]. If this file is already open, it will
   * instead be made the active editor.
   */
  void openFile(File file, {activateEditor: true}) {
    if (file == null) return;
    _EditorState state = _getStateFor(file);

    if (state == null) {
      state = _savedEditorStates[file.persistToToken()];
      if (state == null) {
        state = new _EditorState.fromFile(this, file);
      }
      _insertState(state);
    }

    if (activateEditor) {
      _switchState(state);
    }
  }

  bool isFileOpened(File file) => _getStateFor(file) != null;

  void saveAll() => _saveAll();

  void close(File file) {
    _EditorState state = _getStateFor(file);
    Editor editor = _editorMap[file];

    if (state != null) {
      int index = _openedEditorStates.indexOf(state);
      state.updateState();
      _removeState(state);

      if (editor.dirty) {
        editor.save();
      }

      if (_currentState == state) {
        // Switch to the next editor.
        if (_openedEditorStates.isEmpty) {
          _switchState(null);
        } else if (index < _openedEditorStates.length){
          _switchState(_openedEditorStates[index]);
        } else {
          _switchState(_openedEditorStates[index - 1]);
        }
      }

      _editorMap[file] = null;

      persistState();
    }
  }

  // Save state of the editor manager.
  void persistState() {
    // The value of the pref is a map. The format is the following:
    // openedTabs: [ ... ] -> list of persist token of the opened files.
    // filesState: [ ... ] -> list of states of previously opened files: known
    //     files.
    // version: 1 -> PREFS_EDITORSTATES_VERSION. The version number helps
    //     ensure that the format is valid.
    Map savedMap = {};
    savedMap['openedTabs'] =
        _openedEditorStates.map((_EditorState s) => s.file.persistToToken()).
        toList();
    List<Map> filesState = [];
    _savedEditorStates.forEach((String key, _EditorState value) {
      filesState.add(value.toMap());
    });
    savedMap['filesState'] = filesState;
    savedMap['version'] = PREFS_EDITORSTATES_VERSION;
    _prefs.setValue('editorStates', JSON.encode(savedMap));
  }

  // Restore state of the editor manager.
  Future _restoreState() {
    return _prefs.getValue('editorStates').then((String data) {
      if (data != null) {
        Map savedMap = JSON.decode(data);
        if (savedMap is Map) {
          int version = savedMap['version'];
          if (version == PREFS_EDITORSTATES_VERSION) {
            List<String> openedTabs = savedMap['openedTabs'];
            List<Map> filesState = savedMap['filesState'];
            // Restore state of known files.
            filesState.forEach((Map m) {
              _EditorState state = new _EditorState.fromMap(this, m);
              if (state != null) {
                _savedEditorStates[m['file']] = state;
              }
            });
            // Restore opened files.
            for (String filePersistID in openedTabs) {
              File f = _workspace.restoreResource(filePersistID);
              openFile(f, activateEditor: false);
            }
          }
        }
      }
    });
  }

  _EditorState _getStateFor(File file) {
    for (_EditorState state in _openedEditorStates) {
      if (state.file == file) {
        return state;
      }
    }

    return null;
  }

  void _switchState(_EditorState state) {
    if (_currentState != state) {
      if (_currentState != null) {
        _currentState.updateState();
      }

      _currentState = state;
      _selectedController.add(currentFile);
      if (state == null) {
        _aceContainer.switchTo(null);
        persistState();
      } else {
        state.withSession().then((state) {
          // Test if other state have been set before this state is appiled.
          if (state != _currentState) {
            return;
          }
          if (editorType(state.file.name) == EDITOR_TYPE_IMAGE) {
            _selectedController.add(currentFile);
            persistState();
          } else {
            // TODO: this explicit casting to AceEditor will go away in a future refactoring
            ace.TextEditor textEditor = _editorMap[currentFile];
            textEditor.setSession(state.session);
            _selectedController.add(currentFile);
            _aceContainer.switchTo(state.session, state.file);
            _aceContainer.cursorPosition = state.cursorPosition;
            persistState();
          }
        });
      }
    }
  }

  Timer _timer;

  void _startSaveTimer() {
    _eventBus.addEvent('fileModified', currentFile);

    if (_timer != null) _timer.cancel();

    _timer = new Timer(new Duration(milliseconds: _DELAY_MS), () => _saveAll());
  }

  void _saveAll() {
    if (_timer != null) {
      _timer.cancel();
      _timer = null;
    }

    bool wasDirty = false;

    for (Editor editor in editors) {
      if (editor.dirty) {
        editor.save();
        wasDirty = true;
      }
    }

    if (wasDirty) {
      _eventBus.addEvent('filesSaved', null);
    }
  }

  int editorType(String filename) {
    if (_imageFileType.hasMatch(filename)) {
      return EDITOR_TYPE_IMAGE;
    } else {
      return EDITOR_TYPE_TEXT;
    }
  }

  // EditorProvider
  Editor createEditorForFile(File file) {
    Editor editor = _editorMap[file];
    assert(editor == null);
    if (editorType(file.name) == EDITOR_TYPE_IMAGE) {
      editor = new ImageViewer(file);
    } else {
      editor = new ace.TextEditor(_aceContainer, file);
    }

    _editorMap[file] = editor;
    openFile(file);
    editor.onDirtyChange.listen((_) {
      if (editor.dirty) _startSaveTimer();
    });
    return editor;
  }

  void activate(Editor editor) {
    _EditorState state = _getStateFor(editor.file);
    _switchState(state);
    _aceContainer.setMarkers(editor.file.getMarkers());
  }
}

/**
 * This class tracks the state associated with each open editor.
 */
class _EditorState {
  EditorManager manager;
  File file;
  ace.EditSession session;

  int scrollTop = 0;
  html.Point cursorPosition = new html.Point(0, 0);

  _EditorState.fromFile(this.manager, this.file);

  factory _EditorState.fromMap(EditorManager manager, Map m) {
    File f = manager._workspace.restoreResource(m['file']);

    if (f == null) {
      return null;
    } else {
      _EditorState state = new _EditorState.fromFile(manager, f);
      state.scrollTop = m['scrollTop'];
      state.cursorPosition = new html.Point(m['column'], m['row']);
      return state;
    }
  }

  bool get hasSession => session != null;

  // This method save the ACE editor state in this class.
  // Then, further calls of toMap() to save the state of the editor will return
  // correct values.
  void updateState() {
    if (session != null) {
      scrollTop = session.scrollTop;
      if (manager._currentState == this) {
        cursorPosition = manager._aceContainer.cursorPosition;
      }
    }
  }

  /**
   * Return a [Map] representing the persistable state of this editor. This map
   * can later be passed into [_EditorState.fromMap] to restore the state.
   */
  Map toMap() {
    Map m = {};
    m['file'] = file.persistToToken();
    m['scrollTop'] = scrollTop;
    m['column'] = cursorPosition.x;
    m['row'] = cursorPosition.y;
    return m;
  }

  Future<_EditorState> withSession() {
    if (hasSession) {
      return new Future.value(this);
    } else {
      if (manager.editorType(file.name) == EditorManager.EDITOR_TYPE_IMAGE) {
        return file.getContents().then((text) {
          return this;
        });
      } else {
        return file.getContents().then((text) {
          session = manager._aceContainer.createEditSession(text, file.name);
          session.scrollTop = scrollTop;
          return this;
        });
      }
    }
  }
}

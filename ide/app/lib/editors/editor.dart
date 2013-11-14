// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Abstraction layer of editors.
 */


library spark.editors.editor;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html' show Element;

import '../workspace.dart';
import '../preferences.dart';

class DirtyFlagChangedEvent {
  final Resource file;
  final bool dirty;
  DirtyFlagChangedEvent(this.file, this.dirty);
}

/**
 * Classes implement this interface creates editors and editor sessions for
 * [Resource]s.
 */
abstract class EditorProvider {
  /// Returns `true` if file is previously opened.
  bool isFileOpened(File file);

  /// Creates an editor session for the file. Returns `null` if fails.
  EditorSession getEditorSessionForFile(File file);

  /// Restore an editor session from map; Returns `null` if fails.
  EditorSession restorEditorSessionFromMap(Map map, Workspace ws);

  /// Inform the editor provider that a file is closed.
  Future close(EditorSession session);
}

/**
 * A simplest [EditorProvider]. Classes inherits from this class need to
 * implment [createSession] method in order to work.
 */
abstract class DefaultEditorProvider implements EditorProvider {
  final Map<File, EditorSession> fileToSession = {};

  DefaultEditorProvider();

  EditorSession createSession(File file);

  EditorSession getEditorSessionForFile(File file) {
    if (!fileToSession.containsKey(file)) {
      EditorSession session = createSession(file);
      fileToSession[file] = session;
    }
    return fileToSession[file];
  }

  /// Returns `true` if file is previously open.
  bool isFileOpened(File file) => fileToSession.containsKey(file);

  /// Create an editor for the specific file. In case of shared editor, return
  /// the editor and swtich to file.
  EditorSession restorEditorSessionFromMap(Map map, Workspace ws) {
    if (!map.containsKey('file')) return null;
    File file = ws.restoreResource(map['file']);
    if (file == null) return null;
    return getEditorSessionForFile(file)..fromMap(map, ws);
  }

  /// Inform the editor provider that a file is closed.
  Future close(EditorSession session) {
    if (fileToSession.containsValue(session)) {
      fileToSession.remove(session);
      return session.saveFile();
    }
    return new Future.value();
  }
}

/**
 *  Editor session of an editor. To allowing app suspension, the edit session
 *  requires serialization functionalities.
 *
 *  [EditorSession] creates the binding between an editor behavior and a file.
 */
abstract class EditorSession {
  /// File combined with the editor.
  File get file;

  /// Dirty flag of [EditorSession].
  bool get dirty;

  /// Indicates whether the file is loaded.
  bool get loaded;

  /// Gets/creates the editor bound to the session.
  Editor get editor;

  /// Load the content from the file.
  Future<bool> loadFile();

  /// Save the content to the file.
  Future<bool> saveFile();

  /// Deserialize the state of an editor.
  /// Returns `true` iff success.
  bool fromMap(Map map, Workspace workspace);

  /// Serialize the state of an editor.
  Map toMap();
}

/**
 *  An abstract editor.
 *  To reduce resource consumption, multiple files can share the same editor by
 *  creating separate [EditorSession]s.
 */
abstract class Editor {
  /// The root element to put the editor in.
  Element get rootElement;

  /// Indicates whether the editor is readonly.
  bool readOnly;

  /// Gets/sets the current session.
  EditorSession get session;
  set session(EditorSession session);


  /// Resize the editor.
  void resize();
}

/**
 * Class to maintain [EditorSession]s. It persists [EditorSession]s regularly.
 */
class EditorSessionManager {
  final List<EditorSession> sessions = new List();
  final Completer _availableCompleter = new Completer();
  final PreferenceStore _prefStore;
  final Workspace workspace;
  final EditorProvider provider;
  Timer _saveTimer;

  EditorSessionManager(
      this.workspace,
      this._prefStore,
      this.provider) {
    workspace.whenAvailable().then((_) {
      _prefStore.getValue('editorStates').then((String data) {
        if (data != null) {
          List sessionList = JSON.decode(data);
          sessionList.forEach((Map m) {
            Resource resource = workspace.restoreResource(m['file']);
            if (resource == null) return;
            var session = provider.restorEditorSessionFromMap(m, workspace);
            if (session == null) return;
            // TODO(ikarienator): optimize this O(n^2) insertion.
            if (sessions.contains(session)) return;
            sessions.add(session);
          });
        }
        _availableCompleter.complete();
      }).catchError((error) => _availableCompleter.completeError(error));
    }).catchError((error) => _availableCompleter.completeError(error));
  }

  Future get available => _availableCompleter.future;

  List<File> get files => sessions.map((session) => session.file).toList();

  bool isFileOpened(File file) =>
      sessions.any((session) => session.file == file);

  Future add(EditorSession session) {
    if (sessions.contains(session)) return new Future.value();
    sessions.add(session);
    return persistState();
  }

  Future remove(EditorSession session) {
    sessions.remove(session);
    provider.close(session);
    return persistState();
  }

  Future persistState() {
    var stateData = sessions.map((session) => session.toMap()).toList();
    return _prefStore.setValue('editorStates', JSON.encode(stateData));
  }

  void saveAll() {
    if (_saveTimer != null) _saveTimer.cancel();
    _saveTimer = new Timer(new Duration(seconds: 2), () => saveAll());
  }

  void saveAllNow() {
    if (_saveTimer != null) {
      _saveTimer.cancel();
      _saveTimer = null;
    }
    sessions.map((session) => session.saveFile());
  }
}

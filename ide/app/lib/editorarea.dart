// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A TabView associated with opened documents. It sends request to an
 * [EditorProvider] to create/refresh editors.
 */
library spark.editorarea;

import 'dart:async';
import 'dart:html' show DivElement, Element;

import 'editors/editor.dart';
import 'ui/widgets/tabview.dart';
import 'workspace.dart';
import 'preferences.dart';

class EditorTab extends Tab {
  final EditorSession session;

  EditorTab(EditorArea parent, this.session): super(parent) {
    label = file.name;
    page = createLoadingPlaceHolder();
  }

  File get file => session.file;

  void activate() {
    session.loadFile().then((_) {
      session.editor.session = session;
      page = session.editor.rootElement;
      session.editor.resize();
    });
    super.activate();
  }

  static DivElement createLoadingPlaceHolder() =>
    // TODO(ikarienator): a beautiful loading indicator.
    new DivElement()..classes.add('editor-tab-loader-placeholder');
}

/**
 * Manage a list of open editors.
 */
class EditorArea extends TabView {
  final EditorSessionManager sessionManager;
  final PreferenceStore prefStore;
  final Map<EditorSession, EditorTab> _tabOfSession = {};
  bool _allowsLabelBar = true;

  EditorArea(Element parentElement,
             this.sessionManager,
             this.prefStore,
             {allowsLabelBar: true}) : super(parentElement) {
    _restoreSession();

    onSelected.listen((EditorTab tab) => tab.select());
    onClose.listen((EditorTab tab) => closeFile(tab.file));

    this.allowsLabelBar = allowsLabelBar;
    showLabelBar = false;
  }

  void _restoreSession() {
    sessionManager.available.then((_) {
      sessionManager.sessions.forEach((EditorSession session) {
        getTabForSession(session, switchesTab: false);
      });

      prefStore.getValue('lastFileSelection').then((filePath) {
        if (tabs.isEmpty) return;
        if (filePath == null) {
          tabs[0].select();
          return;
        }
        File file = sessionManager.files.firstWhere(
            (file) => file.path == filePath,
            orElse: () => null);

        if (file == null) {
          tabs[0].select();
          return;
        }

        selectFile(file, switchesTab: true);
      });
    });
  }

  bool get allowsLabelBar => _allowsLabelBar;
  set allowsLabelBar(bool value) {
    _allowsLabelBar = value;
    showLabelBar = _allowsLabelBar && _tabOfSession.length > 1;
  }

  Tab getTabForSession(EditorSession session, {bool switchesTab: true}) {
    if (!_tabOfSession.containsKey(session)) {
      var tab = new EditorTab(this, session);
      add(tab, switchesTab: switchesTab);
    }
    return _tabOfSession[session];
  }

  // TabView
  Tab add(EditorTab tab, {bool switchesTab: true}) {
    _tabOfSession[tab.session] = tab;
    showLabelBar = _allowsLabelBar && _tabOfSession.length > 1;
    sessionManager.add(tab.session);
    return super.add(tab, switchesTab: switchesTab);
  }

  // TabView
  bool remove(EditorTab tab, {bool switchesTab: true}) {
    if (super.remove(tab, switchesTab: switchesTab)) {
      _tabOfSession.remove(tab.session);
      showLabelBar = _allowsLabelBar && _tabOfSession.length > 1;
      sessionManager.remove(tab.session);
      return true;
    }
    return false;
  }

  @override
  void set selectedTab(EditorTab tab) {
    prefStore.setValue('lastFileSelection', tab.file.path);
    super.selectedTab = tab;
  }

  /// Switches to a file. If the file is not opened and [forceOpen] is `true`,
  /// [selectFile] will be called instead. Otherwise the editor provide is
  /// requested to switch the file to the editor in case the editor is shared.
  void selectFile(File file,
                  {bool forceOpen: false, bool switchesTab: true}) {
    var session = sessionManager.provider.getEditorSessionForFile(file);
    if (!_tabOfSession.containsKey(session)) {
      if (forceOpen) {
        _tabOfSession[session] = getTabForSession(session);
      } else {
        return;
      }
    }

    if (switchesTab)
      selectedTab = _tabOfSession[session];
  }

  /// Closes the tab.
  void closeFile(File file) {
    var session = sessionManager.provider.getEditorSessionForFile(file);
    if (_tabOfSession.containsKey(session)) {
      EditorTab tab = _tabOfSession[session];
      remove(tab);
    }
  }
}

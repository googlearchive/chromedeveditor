// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A TabView associated with opened documents. It sends request to an
 * [EditorProvider] to create/refresh editors.
 */
library spark.editorarea;

import 'dart:html';
import 'ace.dart';

import 'editors.dart';
import 'ui/widgets/tabview.dart';
import 'workspace.dart';

class EditorTab extends Tab {
  final Resource file;
  final AceEditor editor;
  EditorTab(EditorArea parent, AceEditor editor, this.file)
      : editor = editor,  // FIXME(ikarienator): cannot use this.editor style.
        super(parent, editor.parentElement) {
    label = file.name;
  }
}

/**
 * Manage a list of open editors.
 */
class EditorArea extends TabView {
  final EditorProvider editorProvider;
  final Map<Resource, EditorTab> _tabOfFile = {};
  bool _allowsLabelBar = true;

  EditorArea(Element parentElement,
             this.editorProvider,
             {allowsLabelBar: true})
      : super(parentElement) {
    onSelected.listen((EditorTab tab) {
      editorProvider.selectFileForEditor(tab.editor, tab.file);
    });
    onClose.listen((EditorTab tab) {
      closeFile(tab.file);
    });
    this.allowsLabelBar = allowsLabelBar;
    showLabelBar = false;
  }

  bool get allowsLabelBar => _allowsLabelBar;
  set allowsLabelBar(bool value) {
    _allowsLabelBar = value;
    showLabelBar = _allowsLabelBar && _tabOfFile.length > 1;
  }

  // TabView
  Tab add(EditorTab tab, {bool switchesTab: true}) {
    _tabOfFile[tab.file] = tab;
    showLabelBar = _allowsLabelBar && _tabOfFile.length > 1;
    return super.add(tab, switchesTab: switchesTab);
  }

  // TabView
  bool remove(EditorTab tab, {bool switchesTab: true}) {
    if (super.remove(tab, switchesTab: switchesTab)) {
      _tabOfFile.remove(tab.file);
      showLabelBar = _allowsLabelBar && _tabOfFile.length > 1;
      return true;
    }
    return false;
  }

  /// Switches to a file. If the file is not opened and [forceOpen] is `true`,
  /// [selectFile] will be called instead. Otherwise the editor provide is
  /// requested to switch the file to the editor in case the editor is shared.
  void selectFile(Resource file,
                {bool forceOpen: false, bool switchesTab: true}) {
    if (!_tabOfFile.containsKey(file)) {
      if (forceOpen) {
        AceEditor editor = editorProvider.createEditorForFile(file);
        var tab = new EditorTab(this, editor, file);
        add(tab, switchesTab: switchesTab);
      } else {
        return;
      }
    }

    EditorTab tab = _tabOfFile[file];
    editorProvider.selectFileForEditor(tab.editor, file);
    if (switchesTab)
      tab.select();
  }

  /// Closes the tab.
  void closeFile(Resource file) {
    if (_tabOfFile.containsKey(file)) {
      EditorTab tab = _tabOfFile[file];
      remove(tab);
      tab.close();
      editorProvider.close(file);
    }
  }
}

// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A TabView associated with opened documents. It sends request to an
 * [EditorProvider] to create/refresh editors.
 */
library spark.editor_area;

import 'dart:async';
import 'dart:html';

import 'ace.dart' as ace;
import 'editors.dart';
import 'ui/widgets/tabview.dart';
import 'ui/widgets/imageviewer.dart';
import 'workspace.dart';

/// A tab associated with a file.
abstract class EditorTab extends Tab {
  final Resource file;

  EditorTab(EditorArea parent, this.file) : super(parent) {
    label = file.name;
  }

  void resize();
}

/// An [EditorTab] that contains an [AceEditor].
class AceEditorTab extends EditorTab {
  final Editor editor;
  final EditorProvider provider;

  AceEditorTab(EditorArea parent, this.provider, this.editor, Resource file)
    : super(parent, file) {
    page = editor.element;
  }

  void activate() {
    editor.activate();
    provider.activate(editor);
    super.activate();
  }

  void focus() => editor.focus();

  void resize() => editor.resize();
}

/// An [EditorTab] that contains an [ImageViewerTab].
class ImageViewerTab extends EditorTab {
  final ImageViewer imageViewer;
  final EditorProvider provider;

  ImageViewerTab(EditorArea parent, this.provider, this.imageViewer, Resource file)
    : super(parent, file) {
    page = imageViewer.element;
  }

  void activate() {
    provider.activate(imageViewer);
    super.activate();
    resize();
  }

  void resize() => imageViewer.resize();
}

/**
 * Manages a list of open editors.
 */
class EditorArea extends TabView {
  static final RegExp _imageFileType =
      new RegExp(r'\.(jpe?g|png|gif)$', caseSensitive: false);

  final EditorProvider editorProvider;
  final Map<Resource, EditorTab> _tabOfFile = {};

  final Workspace _workspace;

  bool _allowsLabelBar = true;

  StreamController<String> _nameController = new StreamController.broadcast();

  EditorArea(Element parentElement,
             this.editorProvider, this._workspace,
             {bool allowsLabelBar: true})
      : super(parentElement) {
    onClose.listen((EditorTab tab) => closeFile(tab.file));
    this.allowsLabelBar = allowsLabelBar;
    showLabelBar = false;

    _workspace.onResourceChange.listen((event) {
      bool hasDeletes = event.changes.any(
          (d) => d.isDelete && d.resource.isFile);
      if (hasDeletes) {
        _processEvent(event);
      }
    });
  }

  void _processEvent(ResourceChangeEvent event) {
    event.changes
      .where((change) => change.isDelete && change.resource.isFile)
      .forEach((change) => closeFile(change.resource));
  }

  bool get shouldDisplayName => tabs.length == 1;

  Stream<String> get onNameChange => _nameController.stream;

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
  Tab replace(EditorTab tabToReplace, EditorTab tab, {bool switchesTab: true}) {
    _tabOfFile[tab.file] = tab;
    showLabelBar = _allowsLabelBar && _tabOfFile.length > 1;
    return super.replace(tabToReplace, tab, switchesTab: switchesTab);
  }

  // TabView
  bool remove(EditorTab tab, {bool switchesTab: true}) {
    if (super.remove(tab, switchesTab: switchesTab)) {
      _tabOfFile.remove(tab.file);
      editorProvider.close(tab.file);
      showLabelBar = _allowsLabelBar && _tabOfFile.length > 1;
      return true;
    }
    return false;
  }

  /// Inform the editor area to layout it self according to the new size.
  void resize() {
    if (selectedTab != null) {
      (selectedTab as EditorTab).resize();
    }
  }

  /// Switches to a file. If the file is not opened and [forceOpen] is `true`,
  /// [selectFile] will be called instead. Otherwise the editor provide is
  /// requested to switch the file to the editor in case the editor is shared.
  void selectFile(Resource file,
                  {bool forceOpen: false, bool switchesTab: true,
                  bool replaceCurrent: true, bool forceFocus: false}) {
    if (_tabOfFile.containsKey(file)) {
      EditorTab tab = _tabOfFile[file];
      if (switchesTab) tab.select(forceFocus: forceFocus);
      _nameController.add(file.name);
      return;
    }

    if (forceOpen || replaceCurrent) {
      EditorTab tab;

      Editor editor = editorProvider.createEditorForFile(file);
      if (editor is ace.TextEditor) {
        tab = new AceEditorTab(this, editorProvider, editor, file);
      } else if (editor is ImageViewer) {
        tab = new ImageViewerTab(this, editorProvider, editor, file);
      } else {
        assert(editor is ace.TextEditor || editor is ImageViewer);
      }

      if (replaceCurrent) {
        replace(selectedTab, tab, switchesTab: switchesTab);
      } else {
        add(tab, switchesTab: switchesTab);
      }

      if (forceFocus) tab.select(forceFocus: forceFocus);

      _nameController.add(file.name);
    }
  }

  void set selectedTab(Tab tab) {
    super.selectedTab = tab;
    if (tab != null) (tab as EditorTab).focus();
  }

  /// Closes the tab.
  void closeFile(Resource file) {
    if (_tabOfFile.containsKey(file)) {
      EditorTab tab = _tabOfFile[file];
      remove(tab);
      tab.close();
      editorProvider.close(file);
      _nameController.add(selectedTab == null ? null : selectedTab.label);
    }
  }

  // Replaces the file loaded in a tab with a renamed version of the file
  // The new tab is not selected.
  void renameFile(Resource file) {
    if (_tabOfFile.containsKey(file)) {
      EditorTab tab = _tabOfFile[file];
      tab.label = file.name;
      _nameController.add(selectedTab.label);
    }
  }
}

// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A TabView associated with opened documents. It sends request to an
 * [EditorProvider] to create/refresh editors.
 */
library spark.editor_area;

import 'dart:async';
import 'dart:html' hide File;

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

  /**
   * Notify the Editor that the file contents have changed on disk.
   */
  void fileContentsChanged();
}

/// An [EditorTab] that contains an [AceEditor].
class AceEditorTab extends EditorTab {
  final Editor editor;
  final EditorProvider provider;

  AceEditorTab(EditorArea parent, this.provider, this.editor, Resource file)
    : super(parent, file) {
    page = editor.element;
    editor.onModification.listen((_) => parent.persistTab(file));
  }

  void activate() {
    editor.activate();
    provider.activate(editor);
    super.activate();
  }

  void deactivate() {
    editor.deactivate();
    super.deactivate();
  }

  void focus() => editor.focus();

  void resize() => editor.resize();

  void fileContentsChanged() => editor.fileContentsChanged();
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

  void fileContentsChanged() => imageViewer.fileContentsChanged();
}

/**
 * Manages a list of open editors.
 */
class EditorArea extends TabView {
  static final RegExp _imageFileType =
      new RegExp(r'\.(jpe?g|png|gif|ico)$', caseSensitive: false);

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
    showLabelBar = true;

    _workspace.onResourceChange.listen((ResourceChangeEvent event) {
      // TODO(dvh): reflect name change instead of closing the file.
      event =
          new ResourceChangeEvent.fromList(event.changes, filterRename: true);
      for (ChangeDelta delta in event.changes) {
        if (delta.isDelete && delta.resource.isFile) {
          closeFile(delta.resource);
        } else if (delta.isChange && delta.resource.isFile) {
          _updateFile(delta.resource);
        }
      }
    });
  }

  Stream<String> get onNameChange => _nameController.stream;

  bool get allowsLabelBar => _allowsLabelBar;
  set allowsLabelBar(bool value) {
    _allowsLabelBar = value;
  }

  // TabView
  Tab add(EditorTab tab, {bool switchesTab: true}) {
    _tabOfFile[tab.file] = tab;
    return super.add(tab, switchesTab: switchesTab);
  }

  // TabView
  Tab replace(EditorTab tabToReplace, EditorTab tab, {bool switchesTab: true}) {
    _tabOfFile[tab.file] = tab;
    return super.replace(tabToReplace, tab, switchesTab: switchesTab);
  }

  // TabView
  bool remove(EditorTab tab, {bool switchesTab: true, bool layoutNow: true}) {
    if (super.remove(tab, switchesTab: switchesTab, layoutNow: layoutNow)) {
      _tabOfFile.remove(tab.file);
      editorProvider.close(tab.file);
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
  Future selectFile(Resource file,
                    {bool forceOpen: false, bool switchesTab: true,
                    bool replaceCurrent: true, bool forceFocus: false}) {
    if (_tabOfFile.containsKey(file)) {
      EditorTab tab = _tabOfFile[file];
      if (switchesTab) tab.select(forceFocus: forceFocus);
      _nameController.add(file.name);
      return new Future.value();
    }

    Future editorReadyFuture;

    if (forceOpen || replaceCurrent) {
      EditorTab tab;

      Editor editor = editorProvider.createEditorForFile(file);
      editorReadyFuture = editor.whenReady;

      if (editor is ace.TextEditor) {
        tab = new AceEditorTab(this, editorProvider, editor, file);
      } else if (editor is ImageViewer) {
        tab = new ImageViewerTab(this, editorProvider, editor, file);
      } else {
        assert(false);
      }

      // On explicit request to open a tab, persist the new tab.
      if (!replaceCurrent) tab.persisted = true;

      // Don't replace the current tab if it's persisted.
      if ((selectedTab is AceEditorTab) &&
          (selectedTab as AceEditorTab).persisted) {
        replaceCurrent = false;
      }

      EditorTab tabToReplace = null;
      if (replaceCurrent) {
        tabToReplace = selectedTab;
      } else {
        tabToReplace = tabs.firstWhere((t) => !t.persisted, orElse: () => null);
      }

      if (tabToReplace != null) {
        replace(tabToReplace, tab, switchesTab: switchesTab);
      } else {
        add(tab, switchesTab: switchesTab);
      }

      if (forceFocus) tab.select(forceFocus: forceFocus);

      _nameController.add(file.name);
    } else {
      editorReadyFuture = new Future.value();
    }

    _savePersistedTabs();
    return editorReadyFuture;
  }

  void persistTab(File file) {
    EditorTab tab = _tabOfFile[file];
    if (tab != null) tab.persisted = true;
    _savePersistedTabs();
  }

  void _savePersistedTabs() {
    List<String> filesUuids = [];
    for(EditorTab tab in tabs) {
      if (tab.persisted) filesUuids.add(tab.file.uuid);
    }

    EditorManager manager = (editorProvider as EditorManager);
    manager.persistedFilesUuids = filesUuids;
    manager.persistState();
  }

  /// Closes the tab.
  void closeFile(File file) {
    EditorTab tab = _tabOfFile[file];
    if (tab != null) {
      remove(tab);
      tab.close();
      editorProvider.close(file);
      _nameController.add(selectedTab == null ? null : selectedTab.label);
    }

    _savePersistedTabs();
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

  void _updateFile(File file) {
    EditorTab tab = _tabOfFile[file];
    if (tab != null) {
      tab.fileContentsChanged();
    }
  }
}

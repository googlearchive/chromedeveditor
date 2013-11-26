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
import 'ui/widgets/imageviewer.dart';
import 'workspace.dart';

class EditorTab extends Tab {
  final Resource file;
  EditorTab(EditorArea parent, this.file) : super(parent) {
    label = file.name;
  }
}

class AceEditorTab extends EditorTab {
  final AceEditor editor;
  AceEditorTab(EditorArea parent, this.editor, Resource file)
    : super(parent, file) {
    label = file.name;
    page = editor.parentElement;
  }
}


class ImageViewerTab extends EditorTab {
  final ImageViewer imageViewer;
  ImageViewerTab(EditorArea parent, this.imageViewer, Resource file)
    : super(parent, file) {
    label = file.name;
    page = imageViewer.rootElement;
    imageViewer.loadFile();
  }
}

/**
 * Manage a list of open editors.
 */
class EditorArea extends TabView {
  final EditorProvider editorProvider;
  final Map<Resource, Tab> _tabOfFile = {};
  static final RegExp _imageFileType =
      new RegExp(r'\.(jpe?g|png|gif|bmp|tiff)$', caseSensitive: false);

  bool _allowsLabelBar = true;

  EditorArea(Element parentElement,
             this.editorProvider,
             {allowsLabelBar: true})
      : super(parentElement) {
    onSelected.listen((EditorTab tab) {
      if (tab is AceEditorTab)
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

  Tab replace(EditorTab tabToReplace, EditorTab tab, {bool switchesTab: true}) {
    _tabOfFile[tab.file] = tab;
    showLabelBar = _allowsLabelBar && _tabOfFile.length > 1;
    return super.replace(tabToReplace, tab, switchesTab: switchesTab);
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
                {bool forceOpen: false, bool switchesTab: true,
                 bool replaceCurrent: true}) {
    if (_tabOfFile.containsKey(file)) {
      EditorTab tab = _tabOfFile[file];
      if (tab is AceEditorTab)
        editorProvider.selectFileForEditor(tab.editor, file);
      if (switchesTab) {
        tab.select();
      }
      return;
    }

    if (forceOpen || replaceCurrent) {
      EditorTab tab;
      if (_imageFileType.hasMatch(file.name)) {
        ImageViewer viewer = new ImageViewer(file);
        tab = new ImageViewerTab(this, viewer, file);
      } else {
        AceEditor editor = editorProvider.createEditorForFile(file);
        tab = new AceEditorTab(this, editor, file);
      }
      if (replaceCurrent) {
        replace(selectedTab, tab, switchesTab: switchesTab);
      } else {
        add(tab, switchesTab: switchesTab);
      }
    }
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

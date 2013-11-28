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
  final AceEditor editor;
  final EditorProvider provider;
  AceEditorTab(EditorArea parent, this.provider, this.editor, Resource file)
    : super(parent, file) {
    page = editor.parentElement;
  }

  void activate() {
    provider.selectFileForEditor(editor, file);
    super.activate();
  }

  void resize() => editor.resize();
}

/// An [EditorTab] that contains an [ImageViewerTab].
class ImageViewerTab extends EditorTab {
  final ImageViewer imageViewer;
  ImageViewerTab(EditorArea parent, this.imageViewer, Resource file)
    : super(parent, file) {
    page = imageViewer.rootElement;
  }

  void resize() => imageViewer.layout();
}

/**
 * Manages a list of open editors.
 */
class EditorArea extends TabView {
  final EditorProvider editorProvider;
  final Map<Resource, EditorTab> _tabOfFile = {};
  static final RegExp _imageFileType =
      new RegExp(r'\.(jpe?g|png|gif)$', caseSensitive: false);

  bool _allowsLabelBar = true;

  EditorArea(Element parentElement,
             this.editorProvider,
             {allowsLabelBar: true})
      : super(parentElement) {
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
                 bool replaceCurrent: true}) {
    if (_tabOfFile.containsKey(file)) {
      EditorTab tab = _tabOfFile[file];
      if (switchesTab) tab.select();
      return;
    }

    if (forceOpen || replaceCurrent) {
      EditorTab tab;
      if (_imageFileType.hasMatch(file.name)) {
        ImageViewer viewer = new ImageViewer(file);
        tab = new ImageViewerTab(this, viewer, file);
      } else {
        AceEditor editor = editorProvider.createEditorForFile(file);
        tab = new AceEditorTab(this, editorProvider, editor, file);
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

// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class implements the controller for the list of files.
 */
library spark.ui.widgets.files_controller;

import 'dart:html';

import 'files_controller_delegate.dart';
import 'widgets/file_item_cell.dart';
import 'widgets/listview.dart';
import 'widgets/listview_cell.dart';
import 'widgets/treeview.dart';
import 'widgets/treeview_delegate.dart';
import '../workspace.dart';

class FilesController implements TreeViewDelegate {
  TreeView _treeView;
  Workspace _workspace;
  List<Resource> _files;
  FilesControllerDelegate _delegate;
  Map<String, Resource> _filesMap;

  bool openOnSelection = true;

  FilesController(Workspace workspace, FilesControllerDelegate delegate) {
    _workspace = workspace;
    _delegate = delegate;
    _files = [];
    _filesMap = {};
    _treeView = new TreeView(querySelector('#fileViewArea'), this);
    _treeView.dropEnabled = true;

    _workspace.onResourceChange.listen((event) {
      _processEvents(event);
    });
  }

  void selectFile(Resource file, {bool forceOpen: false}) {
    if (_files.isEmpty) {
      return;
    }
    int index = _files.indexOf(file);
    if (index >= 0 &&
        _treeView.listView.selection.length == 1 &&
        _treeView.listView.selection.first == index) return;
    _treeView.listView.selection = [index];
    _delegate.selectInEditor(file, forceOpen: forceOpen);
  }

  void selectLastFile({bool forceOpen: false}) {
    if (_files.isEmpty) {
      return;
    }

    _treeView.listView.selection = [_files.length - 1];
    _delegate.selectInEditor(_files.last, forceOpen: forceOpen);
  }

  void selectFirstFile({bool forceOpen: false}) {
    if (_files.isEmpty) {
      return;
    }

    _treeView.listView.selection = [0];
    _delegate.selectInEditor(_files.first, forceOpen: forceOpen);
  }

  // Implementation of [TreeViewDelegate] interface.

  bool treeViewHasChildren(TreeView view, String nodeUID) {
    if (nodeUID == null) {
      return true;
    } else {
      return false;
    }
  }

  int treeViewNumberOfChildren(TreeView view, String nodeUID) {
    if (nodeUID == null) {
      return _files.length;
    } else {
      return 0;
    }
  }

  String treeViewChild(TreeView view, String nodeUID, int childIndex) {
    if (nodeUID == null) {
      return _files[childIndex].path;
    } else {
      return null;
    }
  }

  List<Resource> getSelection() {
    List resources = [];
    _treeView.listView.selection.forEach((index) {
        resources.add(_files[index]);
     });
    return resources;
  }

  ListViewCell treeViewCellForNode(TreeView view, String nodeUID) {
    return new FileItemCell(_filesMap[nodeUID].name);
  }

  int treeViewHeightForNode(TreeView view, String nodeUID) => 20;

  void treeViewSelectedChanged(TreeView view, List<String> nodeUIDs) {
    if (nodeUIDs.isEmpty) {
      return;
    }

    _delegate.selectInEditor(_filesMap[nodeUIDs[0]], forceOpen: openOnSelection);
  }

  void treeViewDoubleClicked(TreeView view, List<String> nodeUIDs) {
    if (nodeUIDs.isEmpty) {
      return;
    }

    _delegate.selectInEditor(_filesMap[nodeUIDs[0]], forceOpen: true);
  }

  String treeViewDropEffect(TreeView view) {
    return 'copy';
  }

  void treeViewDrop(TreeView view, String nodeUID, DataTransfer dataTransfer) {
    // TODO(dvh): Import to the workspace the files referenced by
    // dataTransfer.files
  }

  /**
   * Event handler for workspace events.
   */
  void _processEvents(ResourceChangeEvent event) {
    // TODO: process other types of events
    if (event.type == ResourceEventType.ADD) {
      _files.add(event.resource);
      _filesMap[event.resource.path] = event.resource;
      _treeView.reloadData();
    }
    if (event.type == ResourceEventType.DELETE) {
      _files.remove(event.resource);
      // TODO: make a more informed selection, maybe before the delete?
      selectLastFile();
      _treeView.reloadData();
    }
  }
}

// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class implements the controller for the list of files.
 */
library spark.ui.widgets.files_controller;

import 'dart:html' as html;

import 'files_controller_delegate.dart';
import 'utils/html_utils.dart';
import 'widgets/file_item_cell.dart';
import 'widgets/listview.dart';
import 'widgets/listview_cell.dart';
import 'widgets/treeview.dart';
import 'widgets/treeview_delegate.dart';
import '../actions.dart';
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

    _treeView = new TreeView(html.querySelector('#fileViewArea'), this);
    _treeView.dropEnabled = true;

    _workspace.onResourceChange.listen((event) {
      _processEvents(event);
    });
  }

  void selectFile(Resource file, {bool forceOpen: false}) {
    if (_files.isEmpty) {
      return;
    }
    _treeView.selection = [file.path];
    _delegate.selectInEditor(file, forceOpen: forceOpen);
  }

  void selectLastFile({bool forceOpen: false}) {
    if (_files.isEmpty) {
      return;
    }
    selectFile(_files.last, forceOpen: forceOpen);
  }

  void selectFirstFile({bool forceOpen: false}) {
    if (_files.isEmpty) {
      return;
    }
    selectFile(_files[0], forceOpen: forceOpen);
  }

  // Implementation of [TreeViewDelegate] interface.

  bool treeViewHasChildren(TreeView view, String nodeUID) {
    if (nodeUID == null) {
      return true;
    } else {
      return (_filesMap[nodeUID] is Container);
    }
  }

  int treeViewNumberOfChildren(TreeView view, String nodeUID) {
    if (nodeUID == null) {
      return _files.length;
    } else if (_filesMap[nodeUID] is Container) {
      return (_filesMap[nodeUID] as Container).getChildren().length;
    } else {
      return 0;
    }
  }

  String treeViewChild(TreeView view, String nodeUID, int childIndex) {
    if (nodeUID == null) {
      return _files[childIndex].path;
    } else {
      return (_filesMap[nodeUID] as Container).getChildren()[childIndex].path;
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
    FileItemCell cell = new FileItemCell(_filesMap[nodeUID].name);
    cell.element.onContextMenu.listen((e) => _handleContextMenu(e, _filesMap[nodeUID]));
    cell.menuElement.onClick.listen((e) => _handleMenuClick(cell, _filesMap[nodeUID]));
    return cell;
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

  void treeViewDrop(TreeView view, String nodeUID, html.DataTransfer dataTransfer) {
    // TODO(dvh): Import to the workspace the files referenced by
    // dataTransfer.files
  }

  /**
   * Event handler for workspace events.
   */
  void _processEvents(ResourceChangeEvent event) {
    // TODO: process other types of events
    if (event.type == ResourceEventType.ADD) {

      var resource = event.resource;
      _files.add(resource);
      _recursiveAddResource(resource);
      _treeView.reloadData();
    }
    if (event.type == ResourceEventType.DELETE) {
      var resource = event.resource;
      _files.remove(resource);
      _recursiveRemoveResource(resource);
      // TODO: make a more informed selection, maybe before the delete?
      selectLastFile();
      _treeView.reloadData();
    }
  }

  void _recursiveAddResource(Resource resource) {
    _filesMap[resource.path] = resource;
    if (resource is Container) {
      resource.getChildren().forEach((child) {
        _recursiveAddResource(child);
      });
    }
  }

  void _recursiveRemoveResource(Resource resource) {
    _filesMap.remove(resource.path);
    if (resource is Container) {
      resource.getChildren().forEach((child) {
        _recursiveRemoveResource(child);
      });
    }
  }

  void _handleContextMenu(html.Event e, Resource resource) {
    // TODO: show the context menu

    cancelEvent(e);
  }

  void _handleMenuClick(FileItemCell cell, Resource resource) {
    List<ContextAction> actions = _delegate.getActionsFor(resource);

    // TODO: show the context menu

//    html.Element element = createContextMenu(actions, showAccelerators: false);
//    cell.menuElement.children.add(element);
//    bootjack.Dropdown dropdown = bootjack.Dropdown.wire(element);
//    dropdown.toggle();
  }
}

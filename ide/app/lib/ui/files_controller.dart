// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class implements the controller for the list of files.
 */
library spark.ui.widgets.files_controller;

import 'dart:html' as html;

import 'package:bootjack/bootjack.dart' as bootjack;

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

  FilesController(Workspace workspace, FilesControllerDelegate delegate) {
    _workspace = workspace;
    _delegate = delegate;
    _files = [];
    _filesMap = {};

    _treeView = new TreeView(html.querySelector('#fileViewArea'), this);
    _treeView.dropEnabled = true;

    _workspace.whenAvailable().then((_) {
      _addAllFiles();
    });

    _workspace.onResourceChange.listen((event) {
      _processEvents(event);
    });
  }

  void selectFile(Resource file, {bool forceOpen: false}) {
    if (_files.isEmpty) {
      return;
    }
    _treeView.selection = [file.path];
    if (file is File) {
      _delegate.selectInEditor(file, forceOpen: forceOpen);
    }
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
    // TODO: add an onContextMenu listening, call _handleContextMenu().
    cell.menuElement.onClick.listen(
        (e) => _handleMenuClick(cell, _filesMap[nodeUID], e));
    return cell;
  }

  int treeViewHeightForNode(TreeView view, String nodeUID) => 20;

  void treeViewSelectedChanged(TreeView view,
                               List<String> nodeUIDs,
                               html.Event event) {
    if (nodeUIDs.isEmpty) {
      return;
    }

    Resource resource = _filesMap[nodeUIDs.first];
    if (resource is File) {
      bool altKeyPressed = false;
      if (event != null) {
        altKeyPressed = ((event as html.MouseEvent).altKey);
      }
      // If alt key is pressed, it will open a new tab.
      _delegate.selectInEditor(resource, forceOpen: true,
          replaceCurrent: !altKeyPressed);
    }
  }

  void treeViewDoubleClicked(TreeView view,
                             List<String> nodeUIDs,
                             html.Event event) {
    // Do nothing.
  }

  String treeViewDropEffect(TreeView view) {
    return 'copy';
  }

  void treeViewDrop(TreeView view, String nodeUID, html.DataTransfer dataTransfer) {
    // TODO(dvh): Import to the workspace the files referenced by
    // dataTransfer.files
  }

  void _addAllFiles() {
    for (Resource resource in _workspace.getChildren()) {
      _files.add(resource);
      _recursiveAddResource(resource);
    }

    _treeView.reloadData();
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

  void _handleContextMenu(FileItemCell cell, Resource resource, html.Event e) {
    cancelEvent(e);

    _treeView.selection = [resource.path];

    _showMenu(cell, resource);
  }

  void _handleMenuClick(FileItemCell cell, Resource resource, html.Event e) {
    cancelEvent(e);
    _showMenu(cell, resource);
  }

  void _showMenu(FileItemCell cell, Resource resource) {
    // delete any existing menus
    cell.menuElement.children.removeWhere((c) => c.classes.contains('dropdown-menu'));

    // get all applicable actions
    List<ContextAction> actions = _delegate.getActionsFor(resource);

    // create and show the menu
    html.Element menuElement = createContextMenu(actions, resource);
    cell.menuElement.children.add(menuElement);
    bootjack.Dropdown dropdown = bootjack.Dropdown.wire(menuElement);
    menuElement.onMouseLeave.listen((_) {
      cell.menuElement.children.remove(menuElement);
    });
    dropdown.toggle();
  }
}

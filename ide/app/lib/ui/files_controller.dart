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
    _treeView.draggingEnabled = true;

    _workspace.whenAvailable().then((_) {
      _addAllFiles();
    });

    _workspace.onResourceChange.listen((event) {
      _processEvents(event);
    });
  }

  bool isFileSelected(Resource file) {
    return _treeView.selection.contains(file.path);
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
    _treeView.selection.forEach((String nodeUID) {
        resources.add(_filesMap[nodeUID]);
     });
    return resources;
  }

  ListViewCell treeViewCellForNode(TreeView view, String nodeUID) {
    Resource resource = _filesMap[nodeUID];
    FileItemCell cell = new FileItemCell(resource.name);
    if (resource is Folder) {
      cell.acceptDrop = true;
    }
    // TODO: add an onContextMenu listening, call _handleContextMenu().
    cell.menuElement.onClick.listen(
        (e) => _handleMenuClick(cell, resource, e));
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

  void treeViewDropCells(TreeView view,
                         List<String> nodesUIDs,
                         String targetNodeUID) {
    // TODO(dvh): Move files designated by `nodesUIDs` to the folder
    // designated by `targetNodeUID`.
  }

  TreeViewDragImage treeViewDragImage(TreeView view,
                                      List<String> nodesUIDs,
                                      html.MouseEvent event) {
    if (nodesUIDs.length == 0) {
      return null;
    }

    // The generated image will show a stack of files. The first file will be
    // on the top of it.
    //
    // placeholderCount is the number of files other than the first file that
    // will be shown in the stack.
    // The number of files will also be shown in a badge if there's more than
    // one file.
    int placeholderCount = nodesUIDs.length - 1;

    // We will shows 4 placeholders maximum.
    if (placeholderCount >= 4) {
      placeholderCount = 4;
    }

    // Font for the filenames in the stack.
    final String fontName = '15px Helvetica';
    // Font for the counter.
    final String counterFontName = '12px Helvetica';
    // Basic height of an item in the stack.
    final int stackItemHeight = 30;
    // Stack item radius.
    final int stackItemRadius = 15;
    // Additional space for shadow.
    final int additionalShadowSpace = 10;
    // Space between stack and counter.
    final int stackCounterSpace = 5;
    // Stack item interspace.
    final int stackItemInterspace = 3;
    // Text padding in the stack item.
    final int stackItemPadding = 10;
    // Counter padding.
    final int counterPadding = 10;
    // Counter height.
    final int counterHeight = 20;
    // Stack item text vertical position
    final int stackItemTextPosition = 20;
    // Counter text vertical position
    final int counterTextPosition = 15;

    html.CanvasElement canvas = new html.CanvasElement();

    // Measure text size.
    html.CanvasRenderingContext2D context = canvas.getContext("2d");
    context.font = fontName;
    Resource resource = _filesMap[nodesUIDs.first];
    html.TextMetrics metrics = context.measureText(resource.name);
    int width = metrics.width.toInt();
    context.font = counterFontName;
    String counterString = '${nodesUIDs.length}';
    metrics = context.measureText(counterString);
    int counterWidth = metrics.width.toInt();

    // Set canvas size.
    int globalHeight = stackItemHeight + placeholderCount *
        stackItemInterspace + additionalShadowSpace;
    canvas.width = width + stackItemPadding * 2 + placeholderCount *
        stackItemInterspace + stackCounterSpace + counterWidth +
        counterPadding * 2 + additionalShadowSpace;
    canvas.height = globalHeight;

    context = canvas.getContext("2d");

    // Set shadows.
    context.shadowBlur = 5;
    context.shadowColor = 'rgba(0, 0, 0, 0.3)';
    context.shadowOffsetX = 0;
    context.shadowOffsetY = 1;

    // Draws items of the stack.
    context.setFillColorRgb(255, 255, 255, 1);
    context.setStrokeColorRgb(128, 128, 128, 1);
    context.lineWidth = 1;
    for(int i = placeholderCount ; i >= 0 ; i --) {
      html.Rectangle rect = new html.Rectangle(0.5 + i * stackItemInterspace,
          0.5 + i * stackItemInterspace,
          width + stackItemPadding * 2,
          stackItemHeight);
      roundRect(context,
          rect,
          radius: stackItemRadius,
          fill: true,
          stroke: true);
    }

    // No shadows.
    context.shadowBlur = 0;
    context.shadowColor = 'rgba(0, 0, 0, 0)';
    context.shadowOffsetX = 0;
    context.shadowOffsetY = 0;

    // Draw text in the stack item.
    context.font = fontName;
    context.setFillColorRgb(0, 0, 0, 1);
    context.fillText(resource.name, stackItemPadding, stackItemTextPosition);

    if (placeholderCount > 0) {
      // Draw counter bezel.
      context.lineWidth = 3;
      context.setFillColorRgb(128, 128, 255, 1);
      html.Rectangle rect = new html.Rectangle(width + stackItemPadding * 2 +
          stackCounterSpace + placeholderCount * 2,
          (globalHeight - additionalShadowSpace - counterHeight) / 2,
          counterWidth + counterPadding * 2,
          counterHeight);
      roundRect(context, rect, radius: 10, fill: true, stroke: false);

      // Draw text of counter.
      context.font = counterFontName;
      context.setFillColorRgb(255, 255, 255, 1);
      context.fillText(counterString,
          width + stackItemPadding * 2 + stackCounterSpace + placeholderCount *
          2 + counterPadding,
          (globalHeight - additionalShadowSpace - counterHeight) / 2 +
          counterTextPosition);
    }

    html.ImageElement img = new html.ImageElement();
    img.src = canvas.toDataUrl();
    return new TreeViewDragImage(img, event.offset.x, event.offset.y);
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

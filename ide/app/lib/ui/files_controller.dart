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
    if (nodeUIDs.length == 1 && _filesMap[nodeUIDs.first] is Container) {
      view.toggleNodeExpanded(nodeUIDs.first);
    }
  }

  String treeViewDropEffect(TreeView view,
                            html.DataTransfer dataTransfer,
                            String nodeUID) {
    return "move";
  }

  void treeViewDrop(TreeView view, String nodeUID, html.DataTransfer dataTransfer) {
    // TODO(dvh): Import to the workspace the files referenced by
    // dataTransfer.files
  }

  // Returns true if the move is valid:
  // - We don't allow moving a file to its parent since it's a no-op.
  // - We don't allow moving an ancestor folder to one of its descendant.
  bool _isValidMove(List<String> nodesUIDs, String targetNodeUID) {
    if (targetNodeUID == null) {
      return false;
    }
    Resource destination = _filesMap[targetNodeUID];
    // Collect list of ancestors of the destination.
    Set<String> ancestorsUIDs = new Set();
    Resource currentNode = destination;
    while (currentNode != null) {
      ancestorsUIDs.add(currentNode.path);
      currentNode = currentNode.parent;
    }
    // Make sure that source items are not one of them.
    for(String nodeUID in nodesUIDs) {
      if (ancestorsUIDs.contains(nodeUID)) {
        // Unable to move this file.
        return false;
      }
    }
    // Check whether a resource is moved to its current directory, which would
    // make it a no-op.
    for(String nodeUID in nodesUIDs) {
      Resource node = _filesMap[nodeUID];
      if (node.parent == destination) {
        // Unable to move this file.
        return false;
      }
    }

    return true;
  }

  void treeViewDropCells(TreeView view,
                         List<String> nodesUIDs,
                         String targetNodeUID) {
    Resource destination = _filesMap[targetNodeUID];
    if (_isValidMove(nodesUIDs, targetNodeUID)) {
      _workspace.moveTo(nodesUIDs.map((f) => _filesMap[f]).toList(), destination);
    }
  }

  bool treeViewAllowsDropCells(TreeView view,
                               List<String> nodesUIDs,
                               String destinationNodeUID) {
    return _isValidMove(nodesUIDs, destinationNodeUID);
  }

  bool treeViewAllowsDrop(TreeView view,
                          html.DataTransfer dataTransfer,
                          String destinationNodeUID) {
    return false;
  }

  /*
   * Drawing the drag image.
   */

  // Constants to draw the drag image.

  // Font for the filenames in the stack.
  final String stackItemFontName = '15px Helvetica';
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

    html.CanvasElement canvas = new html.CanvasElement();

    // Measure text size.
    html.CanvasRenderingContext2D context = canvas.getContext("2d");
    Resource resource = _filesMap[nodesUIDs.first];
    int stackLabelWidth = _getTextWidth(context, stackItemFontName, resource.name);
    String counterString = '${nodesUIDs.length}';
    int counterWidth =
        _getTextWidth(context, counterFontName, counterString);

    // Set canvas size.
    int globalHeight = stackItemHeight + placeholderCount *
        stackItemInterspace + additionalShadowSpace;
    canvas.width = stackLabelWidth + stackItemPadding * 2 + placeholderCount *
        stackItemInterspace + stackCounterSpace + counterWidth +
        counterPadding * 2 + additionalShadowSpace;
    canvas.height = globalHeight;

    context = canvas.getContext("2d");

    _drawStack(context, placeholderCount, stackLabelWidth, resource.name);
    if (placeholderCount > 0) {
      int x = stackLabelWidth + stackItemPadding * 2 + stackCounterSpace +
          placeholderCount * 2;
      int y = (globalHeight - additionalShadowSpace - counterHeight) ~/ 2;
      _drawCounter(context, x, y, counterWidth, counterString);
    }

    html.ImageElement img = new html.ImageElement();
    img.src = canvas.toDataUrl();
    return new TreeViewDragImage(img, event.offset.x, event.offset.y);
  }

  /**
   * Returns width of a text in pixels.
   */
  int _getTextWidth(html.CanvasRenderingContext2D context,
                    String fontName,
                    String text) {
    context.font = fontName;
    html.TextMetrics metrics = context.measureText(text);
    return metrics.width.toInt();
  }

  /**
   * Set the rendering shadow on the given context.
   */
  void _setShadow(html.CanvasRenderingContext2D context,
                  int blurSize,
                  String color,
                  int offsetX,
                  int offsetY) {
    context.shadowBlur = blurSize;
    context.shadowColor = color;
    context.shadowOffsetX = offsetX;
    context.shadowOffsetY = offsetY;
  }

  /**
   * Draw the stack.
   * `placeholderCount` is the number of items in the stack.
   * `stackLabelWidth` is the width of the text of the first stack item.
   * `stackLabel` is the string to show for the first stack item.
   */
  void _drawStack(html.CanvasRenderingContext2D context,
                  int placeholderCount,
                  int stackLabelWidth,
                  String stackLabel) {
    // Set shadows.
    _setShadow(context, 5, 'rgba(0, 0, 0, 0.3)', 0, 1);

    // Draws items of the stack.
    context.setFillColorRgb(255, 255, 255, 1);
    context.setStrokeColorRgb(128, 128, 128, 1);
    context.lineWidth = 1;
    for(int i = placeholderCount ; i >= 0 ; i --) {
      html.Rectangle rect = new html.Rectangle(0.5 + i * stackItemInterspace,
          0.5 + i * stackItemInterspace,
          stackLabelWidth + stackItemPadding * 2,
          stackItemHeight);
      roundRect(context,
          rect,
          radius: stackItemRadius,
          fill: true,
          stroke: true);
    }

    // No shadows.
    _setShadow(context, 0, 'rgba(0, 0, 0, 0)', 0, 0);

    // Draw text in the stack item.
    context.font = stackItemFontName;
    context.setFillColorRgb(0, 0, 0, 1);
    context.fillText(stackLabel, stackItemPadding, stackItemTextPosition);
  }

  /**
   * Draw the counter and its bezel.
   *
   */
  void _drawCounter(html.CanvasRenderingContext2D context,
                    int x,
                    int y,
                    int counterWidth,
                    String counterString) {
    // Draw counter bezel.
    context.lineWidth = 3;
    context.setFillColorRgb(128, 128, 255, 1);
    html.Rectangle rect = new html.Rectangle(x,
        y,
        counterWidth + counterPadding * 2,
        counterHeight);
    roundRect(context, rect, radius: 10, fill: true, stroke: false);

    // Draw text of counter.
    context.font = counterFontName;
    context.setFillColorRgb(255, 255, 255, 1);
    context.fillText(counterString,
        x + counterPadding,
        y + counterTextPosition);
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
      if (resource.isTopLevel) {
        _files.add(resource);
      }
      _recursiveAddResource(resource);
      _treeView.reloadData();
    }
    if (event.type == ResourceEventType.DELETE) {
      var resource = event.resource;
      _files.remove(resource);
      _recursiveRemoveResource(resource);
      _treeView.reloadData();

    }
    if (event.type == ResourceEventType.CHANGE) {
      // refresh the container that has changed.
      // remove all old paths and add anew.
      var resource = event.resource;
      var keys = _filesMap.keys.toList();
      keys.forEach((key) {
        if (key.startsWith(resource.path)) _filesMap.remove(key);
      });
      _recursiveAddResource(resource);
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
    _showMenu(cell, cell.menuElement, resource);
  }

  void _handleMenuClick(FileItemCell cell, Resource resource, html.Event e) {
    cancelEvent(e);
    _showMenu(cell, cell.menuElement, resource);
  }

  void _showMenu(FileItemCell cell, html.Element disclosureButton, Resource resource) {
    if (!_treeView.selection.contains(resource.path)) {
      _treeView.selection = [resource.path];
    }

    html.Element menuContainer = html.querySelector('#file-item-context-menu');
    html.Element contextMenu =
        html.querySelector('#file-item-context-menu .dropdown-menu');
    // Delete any existing menu items.
    contextMenu.children.clear();

    List<Resource> resources = getSelection();
    // Get all applicable actions.
    List<ContextAction> actions = _delegate.getActionsFor(resources);
    fillContextMenu(contextMenu, actions, resources);

    // Position the context menu at the expected location.
    html.Point position = getAbsolutePosition(disclosureButton);
    position += new html.Point(0, disclosureButton.clientHeight);
    contextMenu.style.left = '${position.x}px';
    contextMenu.style.top = '${position.y - 2}px';

    // Keep the disclosure button visible when the menu is opened.
    cell.menuElement.classes.add('open');
    // Show the menu.
    bootjack.Dropdown dropdown = bootjack.Dropdown.wire(contextMenu);
    dropdown.toggle();

    void _closeContextMenu(html.Event event) {
      cell.menuElement.classes.remove('open');
      // We workaround an issue with bootstrap/boojack: There's no other way
      // to close the dropdown. For example dropdown.toggle() won't work.
      menuContainer.classes.remove('open');
      cancelEvent(event);
    }

    // When the user clicks outside the menu, we'll close it.
    html.Element backdrop =
        html.querySelector('#file-item-context-menu .backdrop');
    backdrop.onClick.listen((event) {
      _closeContextMenu(event);
    });
    // When the user click on an item in the list, the menu will be closed.
    contextMenu.children.forEach((html.Element element) {
      element.onClick.listen((html.Event event) {
        _closeContextMenu(event);
      });
    });
  }
}

// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class implements the controller for the list of files.
 */
library spark.ui.widgets.files_controller;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html' as html;

import 'package:bootjack/bootjack.dart' as bootjack;

import 'files_controller_delegate.dart';
import 'utils/html_utils.dart';
import 'widgets/file_item_cell.dart';
import 'widgets/listview_cell.dart';
import 'widgets/treeview.dart';
import 'widgets/treeview_cell.dart';
import 'widgets/treeview_delegate.dart';
import '../actions.dart';
import '../preferences.dart' as preferences;
import '../workspace.dart';

class FilesController implements TreeViewDelegate {
  // TreeView that's used to show the workspace.
  TreeView _treeView;
  // Workspace that references all the resources.
  Workspace _workspace;
  // List of top-level resources.
  List<Resource> _files;
  // Implements callbacks required for the FilesController.
  FilesControllerDelegate _delegate;
  // Map of nodeUID to the resources of the workspace for a quick lookup.
  Map<String, Resource> _filesMap;
  // Cache of sorted children of nodes.
  Map<String, List<String>> _childrenCache;
  // Preferences where to store tree expanded/collapsed state.
  preferences.PreferenceStore localPrefs = preferences.localStore;
  // The file selection stream controller.
  StreamController<Resource> _selectionController = new StreamController.broadcast();

  FilesController(Workspace workspace,
                  FilesControllerDelegate delegate,
                  html.Element fileViewArea) {
    _workspace = workspace;
    _delegate = delegate;
    _files = [];
    _filesMap = {};
    _childrenCache = {};

    _treeView = new TreeView(fileViewArea, this);
    _treeView.dropEnabled = true;
    _treeView.draggingEnabled = true;

    _workspace.whenAvailable().then((_) {
      _addAllFiles();
    });

    _workspace.onResourceChange.listen((event) {
      bool hasAddsDeletes = event.changes.any(
          (d) => d.isAdd || d.isDelete || !d.resource.isFile);
      if (hasAddsDeletes) {
        _processEvents(event);
      }
    });

    _workspace.onMarkerChange.listen((_) {
      _processMarkerChange();
    });
  }

  bool isFileSelected(Resource file) {
    return _treeView.selection.contains(file.path);
  }

  void selectFile(Resource file, {bool forceOpen: false}) {
    if (_files.isEmpty) {
      return;
    }

    List parents = _collectParents(file, []);

    parents.forEach((Container container) {
      if (!_treeView.isNodeExpanded(container.path)) {
        _treeView.setNodeExpanded(container.path, true);
      }
    });

    _treeView.selection = [file.path];
    if (file is File) {
      _delegate.selectInEditor(file, forceOpen: forceOpen);
    }
    _selectionController.add(file);
    _treeView.scrollIntoNode(file.path, html.ScrollAlignment.CENTER);
  }

  void selectFirstFile({bool forceOpen: false}) {
    if (_files.isEmpty) {
      return;
    }
    selectFile(_files[0], forceOpen: forceOpen);
  }

  void setFolderExpanded(Container resource) {
    for (Container container in _collectParents(resource, [])) {
      if (!_treeView.isNodeExpanded(container.path)) {
        _treeView.setNodeExpanded(container.path, true);
      }
    }

    _treeView.setNodeExpanded(resource.path, true);
  }

  /**
   * Listen for selection change events.
   */
  Stream<Resource> get onSelectionChange => _selectionController.stream;

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
      _cacheChildren(nodeUID);
      return _childrenCache[nodeUID].length;
    } else {
      return 0;
    }
  }

  String treeViewChild(TreeView view, String nodeUID, int childIndex) {
    if (nodeUID == null) {
      return _files[childIndex].path;
    } else {
      _cacheChildren(nodeUID);
      return _childrenCache[nodeUID][childIndex];
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
    FileItemCell cell = new FileItemCell(resource);
    if (resource is Folder) {
      cell.acceptDrop = true;
    }
    return cell;
  }

  int treeViewHeightForNode(TreeView view, String nodeUID) => 20;

  void treeViewSelectedChanged(TreeView view,
                               List<String> nodeUIDs) {
    if (nodeUIDs.isNotEmpty) {
      Resource resource = _filesMap[nodeUIDs.first];
      if (resource is File) {
        _delegate.selectInEditor(resource, forceOpen: true, replaceCurrent: true);
      }
      _selectionController.add(resource);
    }
  }

  bool treeViewRowClicked(html.MouseEvent event, String uid) {
    if (uid == null) {
      return true;
    }

    Resource resource = _filesMap[uid];
    if (resource is File) {
      bool altKeyPressed = event.altKey;
      bool shiftKeyPressed = event.shiftKey;
      bool ctrlKeyPressed = event.ctrlKey || event.metaKey;

      // Open in editor only if alt key or no modifier key is down.  If alt key
      // is pressed, it will open a new tab.
      if (altKeyPressed && !shiftKeyPressed && !ctrlKeyPressed) {
        _delegate.selectInEditor(resource, forceOpen: true,
            replaceCurrent: false);
        return false;
      }
    }

    return true;
  }

  void treeViewDoubleClicked(TreeView view,
                             List<String> nodeUIDs,
                             html.Event event) {
    if (nodeUIDs.length == 1 && _filesMap[nodeUIDs.first] is Container) {
      view.toggleNodeExpanded(nodeUIDs.first, animated: true);
    }
  }

  void treeViewContextMenu(TreeView view,
                           List<String> nodeUIDs,
                           String nodeUID,
                           html.Event event) {
    cancelEvent(event);
    Resource resource = _filesMap[nodeUID];
    FileItemCell cell = new FileItemCell(resource);
    _showMenuForEvent(cell, event, resource);
  }

  String treeViewDropEffect(TreeView view,
                            html.DataTransfer dataTransfer,
                            String nodeUID) {
    if (dataTransfer.types.contains('Files')) {
      if (nodeUID == null) {
        // Importing to top-level is not allowed for now.
        return "none";
      } else {
        // Import files into a folder.
        return "copy";
      }
    } else {
      // Move files inside top-level folder.
      return "move";
    }
  }

  void treeViewDrop(TreeView view, String nodeUID, html.DataTransfer dataTransfer) {
    Folder destinationFolder = _filesMap[nodeUID] as Folder;
    for(html.File file in dataTransfer.files) {
      html.FileReader reader = new html.FileReader();
      reader.onLoadEnd.listen((html.ProgressEvent event) {
        destinationFolder.createNewFile(file.name).then((File file) {
          file.setBytes(reader.result);
        });
      });
      reader.readAsArrayBuffer(file);
    }
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

    Project destinationProject = destination is Project ? destination :
        destination.project;
    for(String nodeUID in nodesUIDs) {
      Resource node = _filesMap[nodeUID];
      // Check whether a resource is moved to its current directory, which would
      // make it a no-op.
      if (node.parent == destination) {
        // Unable to move this file.
        return false;
      }
      // Check if the resource have the same top-level container.
      if (node.project != destinationProject) {
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
    if (destinationNodeUID == null) {
      return false;
    }
    return dataTransfer.types.contains('Files');
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

  void treeViewSaveExpandedState(TreeView view) {
    localPrefs.setValue('FilesExpandedState',
        JSON.encode(_treeView.expandedState));
  }

  // Cache management for sorted list of resources.

  void _cacheChildren(String nodeUID) {
    if (_childrenCache[nodeUID] == null) {
      Container container = _filesMap[nodeUID];
      _childrenCache[nodeUID] = container.getChildren().
          where(_showResource).map((r) => r.path).toList();
      _childrenCache[nodeUID].sort(
          (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
    }
  }

  void _clearChildrenCache() {
    _childrenCache.clear();
  }

  void _sortTopLevel() {
    // Show top-level files before folders.
    _files.sort((Resource a, Resource b) {
      if (a is File && b is Container) {
        return -1;
      } else if (a is Container && b is File) {
        return 1;
      } else {
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      }
    });
  }

  void _reloadData() {
    _clearChildrenCache();
    _treeView.reloadData();
  }

  // Processing workspace events.

  void _addAllFiles() {
    for (Resource resource in _workspace.getChildren()) {
      _files.add(resource);
      _recursiveAddResource(resource);
    }
    _sortTopLevel();
    localPrefs.getValue('FilesExpandedState').then((String state) {
      if (state != null) {
        _treeView.restoreExpandedState(JSON.decode(state));
      } else {
        _treeView.reloadData();
      }
    });
  }

  /**
   * Event handler for workspace events.
   */
  void _processEvents(ResourceChangeEvent event) {
    event.changes.where((d) => _showResource(d.resource)).forEach((change) {
      if (change.type == EventType.ADD) {
        var resource = change.resource;
        if (resource.isTopLevel) {
          _files.add(resource);
        }
        _sortTopLevel();
        _recursiveAddResource(resource);
      }

      if (change.type == EventType.DELETE) {
        var resource = change.resource;
        _files.remove(resource);
        _recursiveRemoveResource(resource);
      }

      if (change.type == EventType.CHANGE) {
        // refresh the container that has changed.
        // remove all old paths and add new.
        var resource = change.resource;
        _recursiveRemoveResource(resource);
        _recursiveAddResource(resource);
      }
    });
    _reloadData();
  }

  /**
   * Returns whether the given resource should be filtered from the Files view.
   */
  bool _showResource(Resource resource) {
    if (resource is Folder && resource.name == '.git') {
      return false;
    }
    return true;
  }

  /**
   * Traverse all the created [FileItemCell]s, calling `updateFileStatus()`.
   */
  void _processMarkerChange() {
    for (String uid in _filesMap.keys) {
      TreeViewCell treeViewCell = _treeView.getTreeViewCellForUID(uid);

      if (treeViewCell != null) {
        FileItemCell fileItemCell = treeViewCell.embeddedCell;
        fileItemCell.updateFileStatus();
      }
    }
  }

  void _recursiveAddResource(Resource resource) {
    _filesMap[resource.path] = resource;
    if (resource is Container) {
      resource.getChildren().forEach((child) {
        if (_showResource(child)) {
          _recursiveAddResource(child);
        }
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

  /**
   * Shows the context menu under the menu disclosure button.
   */
  void _showMenu(FileItemCell cell,
                 html.Element disclosureButton,
                 Resource resource) {
    // Position the context menu at the expected location.
    html.Point position = getAbsolutePosition(disclosureButton);
    position += new html.Point(0, disclosureButton.clientHeight - 2);
    _showMenuAtLocation(cell, position, resource);
  }

  /**
   * Shows the context menu at the location of the mouse event.
   */
  void _showMenuForEvent(FileItemCell cell,
                         html.Event event,
                         Resource resource) {
    html.Point position = getEventAbsolutePosition(event);
    _showMenuAtLocation(cell, position, resource);
  }

  /**
   * Shows the context menu at given location.
   */
  void _showMenuAtLocation(FileItemCell cell,
                           html.Point position,
                           Resource resource) {
    if (!_treeView.selection.contains(resource.path)) {
      _treeView.selection = [resource.path];
    }

    html.Element menuContainer = _delegate.getContextMenuContainer();
    html.Element contextMenu = menuContainer.querySelector('.dropdown-menu');
    // Delete any existing menu items.
    contextMenu.children.clear();

    List<Resource> resources = getSelection();
    // Get all applicable actions.
    List<ContextAction> actions = _delegate.getActionsFor(resources);
    fillContextMenu(contextMenu, actions, resources);

    // Position the context menu at the expected location.
    contextMenu.style.left = '${position.x}px';
    contextMenu.style.top = '${position.y}px';

    // Show the menu.
    bootjack.Dropdown dropdown = bootjack.Dropdown.wire(contextMenu);
    dropdown.toggle();

    void _closeContextMenu(html.Event event) {
      // We workaround an issue with bootstrap/boojack: There's no other way
      // to close the dropdown. For example dropdown.toggle() won't work.
      menuContainer.classes.remove('open');
      cancelEvent(event);

      _treeView.focus();
    }

    // When the user clicks outside the menu, we'll close it.
    html.Element backdrop = menuContainer.querySelector('.backdrop');
    backdrop.onClick.listen((event) {
      _closeContextMenu(event);
    });
    backdrop.onContextMenu.listen((event) {
      _closeContextMenu(event);
    });
    // When the user click on an item in the list, the menu will be closed.
    contextMenu.children.forEach((html.Element element) {
      element.onClick.listen((html.Event event) {
        _closeContextMenu(event);
      });
    });
  }

  List _collectParents(Resource resource, List parents) {
    if (resource.isTopLevel) return parents;

    Container parent = resource.parent;

    if (parent != null) {
      parents.insert(0, parent);
      return _collectParents(parent, parents);
    } else {
      return parents;
    }
  }
}

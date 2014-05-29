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

import 'utils/html_utils.dart';
import 'widgets/file_item_cell.dart';
import 'widgets/listview_cell.dart';
import 'widgets/treeview.dart';
import 'widgets/treeview_cell.dart';
import 'widgets/treeview_delegate.dart';
import '../actions.dart';
import '../event_bus.dart';
import '../preferences.dart' as preferences;
import '../scm.dart';
import '../workspace.dart';

/**
 * An event that is sent to indicate the user would like to select a given
 * resource.
 */
class FilesControllerSelectionChangedEvent extends BusEvent {
  final Resource resource;

  FilesControllerSelectionChangedEvent(this.resource);

  BusEventType get type => BusEventType.FILES_CONTROLLER__SELECTION_CHANGED;
}

/**
 * An event that is sent to indicate the user would like to select a given
 * resource, in a persistent manner.
 */
class FilesControllerPersistTabEvent extends BusEvent {
  File file;

  FilesControllerPersistTabEvent(this.file);

  BusEventType get type => BusEventType.FILES_CONTROLLER__PERSIST_TAB;
}

class FilesController implements TreeViewDelegate {
  // TreeView that's used to show the workspace.
  TreeView _treeView;
  // Workspace that references all the resources.
  final Workspace _workspace;
  // Used to get a list of actions in the context menu for a resource.
  final ActionManager _actionManager;
  // The SCMManager is used to help us decorate files with their SCM status.
  final ScmManager _scmManager;
  // List of top-level resources.
  final List<Resource> _files = [];
  // Map of node UIDs to the resources of the workspace for a quick lookup.
  final Map<String, Resource> _filesMap = {};
  // Cache of sorted children of nodes.
  final Map<String, List<String>> _childrenCache = {};
  // Preferences where to store tree expanded/collapsed state.
  final preferences.PreferenceStore localPrefs = preferences.localStore;
  // The event bus to post events for file selection in the tree.
  final EventBus _eventBus;
  // HTML container for the context menu.
  html.Element _menuContainer;
  // Filter the list of files by filename containing this string.
  String _filterString;
  // List of filtered top-level resources.
  List<Resource> _filteredFiles;
  // Sorted children of nodes.
  Map<String, List<String>> _filteredChildrenCache;
  // Expanded state when no search filter is applied.
  List<String> _currentExpandedState = [];

  FilesController(this._workspace,
                  this._actionManager,
                  this._scmManager,
                  this._eventBus,
                  this._menuContainer,
                  html.Element fileViewArea) {
    _treeView = new TreeView(fileViewArea, this);
    _treeView.dropEnabled = true;
    _treeView.draggingEnabled = true;

    _workspace.whenAvailable().then((_) => _addAllFiles());

    _workspace.onResourceChange.listen((event) {
      bool shouldProcessEvent = event.changes.any((d) =>
          d.isAdd || d.isDelete || d.isRename);
      if (shouldProcessEvent) _processEvents(event);
    });

    _workspace.onMarkerChange.listen((_) => _processMarkerChange());
    _scmManager.onStatusChange.listen((_) => _processScmChange());
  }

  bool isFileSelected(Resource file) {
    return _treeView.selection.contains(file.uuid);
  }

  List<Resource> _currentFiles() {
    return _filteredFiles != null ?  _filteredFiles : _files;
  }

   Map<String, List<String>> _currentChildrenCache() {
    return  _filteredChildrenCache != null ? _filteredChildrenCache : _childrenCache;
  }

  void selectFile(Resource file) {
    if (_currentFiles().isEmpty) {
      return;
    }

    List parents = _collectParents(file, []);

    parents.forEach((Container container) {
      if (!_treeView.isNodeExpanded(container.uuid)) {
        _treeView.setNodeExpanded(container.uuid, true);
      }
    });

    _treeView.selection = [file.uuid];
    _treeView.scrollIntoNode(file.uuid, html.ScrollAlignment.CENTER);
  }

  void selectFirstFile() {
    if (_currentFiles().isEmpty) {
      return;
    }
    selectFile(_currentFiles()[0]);
  }

  void setFolderExpanded(Container resource) {
    for (Container container in _collectParents(resource, [])) {
      if (!_treeView.isNodeExpanded(container.uuid)) {
        _treeView.setNodeExpanded(container.uuid, true);
      }
    }

    _treeView.setNodeExpanded(resource.uuid, true);
  }

  // Implementation of [TreeViewDelegate] interface.

  bool treeViewHasChildren(TreeView view, String nodeUid) {
    if (nodeUid == null) {
      return true;
    } else {
      return (_filesMap[nodeUid] is Container);
    }
  }

  int treeViewNumberOfChildren(TreeView view, String nodeUid) {
    if (nodeUid == null) {
      return _currentFiles().length;
    } else if (_filesMap[nodeUid] is Container) {
      _cacheChildren(nodeUid);
      if (_currentChildrenCache()[nodeUid] == null) {
        return 0;
      }
      return _currentChildrenCache()[nodeUid].length;
    } else {
      return 0;
    }
  }

  String treeViewChild(TreeView view, String nodeUid, int childIndex) {
    if (nodeUid == null) {
      return _currentFiles()[childIndex].uuid;
    } else {
      _cacheChildren(nodeUid);
      return _currentChildrenCache()[nodeUid][childIndex];
    }
  }

  List<Resource> getSelection() {
    List resources = [];
    _treeView.selection.forEach((String nodeUid) {
      resources.add(_filesMap[nodeUid]);
    });
    return resources;
  }

  void setSelection(List<Resource> resources) {
    _treeView.selection = resources.map((r) => r.uuid);
  }

  ListViewCell treeViewCellForNode(TreeView view, String nodeUid) {
    Resource resource = _filesMap[nodeUid];
    if (resource == null) {
      print('no resource for ${nodeUid}');
      assert(resource != null);
    }
    FileItemCell cell = new FileItemCell(resource);
    if (resource is Folder) {
      cell.acceptDrop = true;
    }
    _updateScmInfo(cell);
    return cell;
  }

  int treeViewHeightForNode(TreeView view, String nodeUid) {
    Resource resource = _filesMap[nodeUid];
    return resource is Project ? 40 : 20;
  }

  void treeViewSelectedChanged(TreeView view, List<String> nodeUids) {
    if (nodeUids.isNotEmpty) {
      Resource resource = _filesMap[nodeUids.first];
      _eventBus.addEvent(new FilesControllerSelectionChangedEvent(resource));
    }
  }

  bool treeViewRowClicked(html.MouseEvent event, String uid) => true;

  void treeViewDoubleClicked(TreeView view,
                             List<String> nodeUids,
                             html.Event event) {
    if (nodeUids.length == 1) {
      Resource resource = _filesMap[nodeUids.first];
      if (resource is Container) {
        view.toggleNodeExpanded(nodeUids.first, animated: true);
      } else if (resource is File) {
        _eventBus.addEvent(new FilesControllerPersistTabEvent(resource));
      }
    }
  }

  void treeViewContextMenu(TreeView view,
                           List<String> nodeUids,
                           String nodeUid,
                           html.Event event) {
    cancelEvent(event);
    Resource resource = _filesMap[nodeUid];
    FileItemCell cell = new FileItemCell(resource);
    _showMenuForEvent(cell, event, resource);
  }

  String treeViewDropEffect(TreeView view,
                            html.DataTransfer dataTransfer,
                            String nodeUid) {
    if (dataTransfer.types.contains('Files')) {
      if (nodeUid == null) {
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

  String treeViewDropCellsEffect(TreeView view,
                                 List<String> nodesUids,
                                 String nodeUid) {
    if (nodeUid == null) {
      return "none";
    }
    if (_isDifferentProject(nodesUids, nodeUid)) {
      return "copy";
    } else {
      if (_isValidMove(nodesUids, nodeUid)) {
        return "move";
      } else {
        return "none";
      }
    }
  }

  void treeViewDrop(TreeView view,
                    String nodeUuid,
                    html.DataTransfer dataTransfer) {
    Folder destinationFolder = _filesMap[nodeUuid] as Folder;
    List<Future<File>> futureFiles = new List<Future<File>>();

    for(html.File file in dataTransfer.files) {
      futureFiles.add(_CopyHtmlFileToWorkspace(file, destinationFolder));
    }
    Future.wait(futureFiles).then((List<File> files) {
      setSelection(files);
    });
  }

  static Future<File> _CopyHtmlFileToWorkspace(html.File file,
                                               Folder destination) {
    Completer<File> c = new Completer();
    html.FileReader reader = new html.FileReader();
    reader.onLoadEnd.listen((html.ProgressEvent event) {
      destination.createNewFile(file.name).then((File f) {
        f.setBytes(reader.result);
        c.complete(f);
      });
    });
    reader.readAsArrayBuffer(file);
    return c.future;
  }

  bool _isDifferentProject(List<String> nodesUids, String targetNodeUid) {
    if (targetNodeUid == null) {
      return false;
    }
    Resource destination = _filesMap[targetNodeUid];
    Project destinationProject = destination is Project ? destination :
        destination.project;
    for (String nodeUid in nodesUids) {
      Resource node = _filesMap[nodeUid];
      // Check if the resource have the same top-level container.
      if (node.project == destinationProject) {
        return false;
      }
    }
    return true;
  }

  // Returns true if the move is valid:
  // - We don't allow moving a file to its parent since it's a no-op.
  // - We don't allow moving an ancestor folder to one of its descendant.
  bool _isValidMove(List<String> nodesUids, String targetNodeUid) {
    if (targetNodeUid == null) {
      return false;
    }
    Resource destination = _filesMap[targetNodeUid];
    // Collect list of ancestors of the destination.
    Set<String> ancestorsUids = new Set();
    Resource currentNode = destination;
    while (currentNode != null) {
      ancestorsUids.add(currentNode.uuid);
      currentNode = currentNode.parent;
    }
    // Make sure that source items are not one of them.
    for (String nodeUid in nodesUids) {
      if (ancestorsUids.contains(nodeUid)) {
        // Unable to move this file.
        return false;
      }
    }

    Project destinationProject = destination is Project ? destination :
        destination.project;
    for (String nodeUid in nodesUids) {
      Resource node = _filesMap[nodeUid];
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
                         List<String> nodesUids,
                         String targetNodeUid) {
    Folder destination = _filesMap[targetNodeUid] as Folder;
    if (_isDifferentProject(nodesUids, targetNodeUid)) {
      List<Future> futures = [];
      for (String nodeUid in nodesUids) {
        Resource res = _filesMap[nodeUid];
        futures.add(destination.importResource(res));
      }
      Future.wait(futures).catchError((e) {
        _eventBus.addEvent(
            new ErrorMessageBusEvent('Error while importing files', e));
      });
    } else {
      if (_isValidMove(nodesUids, targetNodeUid)) {
        _workspace.moveTo(nodesUids.map((f) => _filesMap[f]).toList(), destination);
      }
    }
  }

  bool treeViewAllowsDropCells(TreeView view,
                               List<String> nodesUids,
                               String destinationNodeUid) {
    if (_isDifferentProject(nodesUids, destinationNodeUid)) {
      return true;
    } else {
      return _isValidMove(nodesUids, destinationNodeUid);
    }
  }

  bool treeViewAllowsDrop(TreeView view,
                          html.DataTransfer dataTransfer,
                          String destinationNodeUid) {
    if (destinationNodeUid == null) {
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
                                      List<String> nodesUids,
                                      html.MouseEvent event) {
    if (nodesUids.length == 0) {
      return null;
    }

    // The generated image will show a stack of files. The first file will be
    // on the top of it.
    //
    // placeholderCount is the number of files other than the first file that
    // will be shown in the stack.
    // The number of files will also be shown in a badge if there's more than
    // one file.
    int placeholderCount = nodesUids.length - 1;

    // We will shows 4 placeholders maximum.
    if (placeholderCount >= 4) {
      placeholderCount = 4;
    }

    html.CanvasElement canvas = new html.CanvasElement();

    // Measure text size.
    html.CanvasRenderingContext2D context = canvas.getContext("2d");
    Resource resource = _filesMap[nodesUids.first];
    int stackLabelWidth = _getTextWidth(context, stackItemFontName, resource.name);
    String counterString = '${nodesUids.length}';
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
    for (int i = placeholderCount; i >= 0; i--) {
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
    if (_filterString != null) return;
    _currentExpandedState = _treeView.expandedState;
    localPrefs.setValue('FilesExpandedState',
        JSON.encode(_treeView.expandedState));
  }

  html.Element treeViewSeparatorForNode(TreeView view, String nodeUid) {
    Resource resource = _filesMap[nodeUid];
    if (resource is! Project) return null;
    if (_files.length == 0) return null;

    // Don't show a separator before the first item.
    if (_files[0] == resource) return null;

    html.DocumentFragment template =
        (html.querySelector('#fileview-separator') as html.TemplateElement)
        .content;
    html.DocumentFragment templateClone = template.clone(true);
    return templateClone.querySelector('.fileview-separator');
  }

  int treeViewSeparatorHeightForNode(TreeView view, String nodeUid) => 25;

  // Cache management for sorted list of resources.

  void _cacheChildren(String nodeUid) {
    if (_childrenCache[nodeUid] == null) {
      Container container = _filesMap[nodeUid];
      List<Resource> children =
          container.getChildren().where(_showResource).toList();
      // Sort folders first, then files.
      children.sort(_compareResources);
      _childrenCache[nodeUid] = children.map((r) => r.uuid).toList();
    }
  }

  void _clearChildrenCache() {
    _childrenCache.clear();
  }

  void _sortTopLevel() {
    _files.sort(_compareResources);
  }

  int _compareResources(Resource a, Resource b) {
    // Show top-level files before folders.
    if (a is File && b is Container) {
      return 1;
    } else if (a is Container && b is File) {
      return -1;
    } else {
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
  }

  void _reloadData() {
    _clearChildrenCache();
    _treeView.reloadData();
  }

  // This method will be more efficient than _reloadData() then restoring the
  // state.
  void _reloadDataAndRestoreExpandedState(List<String> expandedState) {
    List<String> selection = _treeView.selection;
    for(String nodeUid in selection) {
      Resource res = _filesMap[nodeUid];
      if (res == null) continue;
      List<Container> parents = _collectParents(res, []);
      List<String> parentsUuid =
          parents.map((Container container) => container.uuid).toList();
      expandedState.addAll(parentsUuid);
    }

    _clearChildrenCache();
    _treeView.restoreExpandedState(expandedState);
    // Restore selection.
    _treeView.selection = selection;
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
        _currentExpandedState = JSON.decode(state);
        _treeView.restoreExpandedState(_currentExpandedState);
      } else {
        _treeView.reloadData();
      }
    });
  }

  /**
   * Event handler for workspace events.
   */
  void _processEvents(ResourceChangeEvent event) {
    bool needsReloadData = false;
    bool needsSortTopLevel = false;
    bool needsUpdateExpandedState = false;
    bool needsUpdateSelection = false;
    List<String> updatedSelection = new List.from(_treeView.selection);
    List<String> updatedExpanded = new List.from(_treeView.expandedState);

    event.changes.where((d) => _showResource(d.resource))
        .forEach((ChangeDelta change) {
      if (change.type == EventType.ADD) {
        var resource = change.resource;
        if (resource.isTopLevel) {
          _files.add(resource);
          needsSortTopLevel = true;
        }
        _filesMap[resource.uuid] = resource;
        needsReloadData = true;
      } else if (change.type == EventType.DELETE) {
        var resource = change.resource;
        if (resource.isTopLevel) {
          _files.remove(resource);
          needsSortTopLevel = true;
        }
        _filesMap.remove(resource.uuid);
        needsReloadData = true;
      } else if (change.type == EventType.RENAME) {
        // Update expanded state of the tree view.
        List<String> expanded = [];
        for(String uuid in updatedExpanded) {
          String newUuid = change.resourceUuidsMapping[uuid];
          if (newUuid != null) {
            expanded.add(newUuid);
          } else {
            expanded.add(uuid);
          }
        }
        updatedExpanded = expanded;
        needsUpdateExpandedState = true;
        // Update the selection of the tree view.
        updatedSelection = [change.resource.uuid];
        needsUpdateSelection = true;

        var resource = change.resource;
        if (resource.isTopLevel) {
          _files.remove(change.originalResource);
          _files.add(resource);
          needsSortTopLevel = true;
        }
        // Remove old resources from map.
        change.resourceUuidsMapping.forEach((String oldUuid, String newUuid) {
          _filesMap.remove(oldUuid);
        });
        // Add new resources.
        _recursiveAddResource(resource);
      }
    });

    if (needsSortTopLevel) {
      _sortTopLevel();
      needsReloadData = true;
    }
    if (needsUpdateExpandedState) {
      _reloadDataAndRestoreExpandedState(updatedExpanded);
        // Save expanded state in prefs.
      treeViewSaveExpandedState(_treeView);
    }
    else if (needsReloadData) {
      _reloadData();
    }
    if (needsUpdateSelection) {
      _treeView.selection = updatedSelection;
    }
  }

  /**
   * Returns whether the given resource should be filtered from the Files view.
   */
  bool _showResource(Resource resource) => !resource.isScmPrivate();

  /**
   * Traverse all the created [FileItemCell]s, calling `updateFileStatus()`.
   */
  void _processMarkerChange() {
    for (String uid in _filesMap.keys) {
      TreeViewCell treeViewCell = _treeView.getTreeViewCellForUid(uid);

      if (treeViewCell != null) {
        FileItemCell fileItemCell = treeViewCell.embeddedCell;
        fileItemCell.updateFileStatus();
      }
    }
  }

  void _processScmChange() {
    for (String uid in _filesMap.keys) {
      TreeViewCell treeViewCell = _treeView.getTreeViewCellForUid(uid);
      if (treeViewCell != null) {
        _updateScmInfo(treeViewCell.embeddedCell);
      }
    }
  }

  void _updateScmInfo(FileItemCell fileItemCell) {
    Resource resource = fileItemCell.resource;
    ScmProjectOperations scmOperations =
        _scmManager.getScmOperationsFor(resource.project);

    if (scmOperations != null) {
      if (resource is Project) {
        String branchName = scmOperations.getBranchName();
        final String repoIcon = '<span class="glyphicon glyphicon-random small"></span>';
        if (branchName == null) branchName = '';
        fileItemCell.setFileInfo('${repoIcon} [${branchName}]');
      }

      // TODO(devoncarew): for now, just show git status for files. We need to
      // also implement this for folders.
      if (resource is File) {
        FileStatus status = scmOperations.getFileStatus(resource);
        fileItemCell.setGitStatus(dirty: (status != FileStatus.COMMITTED));
      }
    }
  }

  void _recursiveAddResource(Resource resource) {
    _filesMap[resource.uuid] = resource;
    if (resource is Container) {
      resource.getChildren().forEach((child) {
        if (_showResource(child)) {
          _recursiveAddResource(child);
        }
      });
    }
  }

  /**
   * Shows the context menu at the location of the mouse event.
   */
  void _showMenuForEvent(FileItemCell cell,
                         html.MouseEvent event,
                         Resource resource) {
    _showMenuAtLocation(cell, event.client, resource);
  }

  /**
   * Position the context menu at the expected location.
   */
  void _positionContextMenu(html.Point clickPoint, html.Element contextMenu) {
    var topUi = html.document.querySelector("#topUi");
    final int separatorHeight = 19;
    final int itemHeight = 26;
    int estimatedHeight = 12; // Start with value padding and border.
    contextMenu.children.forEach((child) {
      estimatedHeight += child.className == "divider" ? separatorHeight : itemHeight;
    });

    contextMenu.style.left = '${clickPoint.x}px';
    // If context menu exceed Window area.
    if (estimatedHeight + clickPoint.y > topUi.offsetHeight) {
      var positionY = clickPoint.y - estimatedHeight;
      if (positionY < 0) {
        // Add additional 5px to show boundary of context menu.
        contextMenu.style.top = '${topUi.offsetHeight - estimatedHeight - 5}px';
      } else {
        contextMenu.style.top = '${positionY}px';
      }
    } else {
      contextMenu.style.top = '${clickPoint.y}px';
    }
  }

  /**
   * Shows the context menu at given location.
   */
  void _showMenuAtLocation(FileItemCell cell,
                           html.Point position,
                           Resource resource) {
    if (!_treeView.selection.contains(resource.uuid)) {
      _treeView.selection = [resource.uuid];
    }

    html.Element contextMenu = _menuContainer.querySelector('.dropdown-menu');
    // Delete any existing menu items.
    contextMenu.children.clear();

    List<Resource> resources = getSelection();
    // Get all applicable actions.
    List<ContextAction> actions = _actionManager.getContextActions(resources);
    fillContextMenu(contextMenu, actions, resources);
    _positionContextMenu(position, contextMenu);

    // Show the menu.
    bootjack.Dropdown dropdown = bootjack.Dropdown.wire(contextMenu);
    dropdown.toggle();

    void _closeContextMenu(html.Event event) {
      // We workaround an issue with bootstrap/boojack: There's no other way
      // to close the dropdown. For example dropdown.toggle() won't work.
      _menuContainer.classes.remove('open');
      cancelEvent(event);

      _treeView.focus();
    }

    // When the user clicks outside the menu, we'll close it.
    html.Element backdrop = _menuContainer.querySelector('.backdrop');
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

  /**
   * Add the given resource to the results.
   * [result] is a set that contains uuid of resources that have already been
   * added.
   * [roots] is the resulting list of top-level resources.
   * [childrenCache] is the resulting map between the resource UUID and the
   * list of children.
   * [res] is the resource to add.
   */
  void _filterAddResult(Set result,
      List<Resource> roots,
      Map<String, List<String>> childrenCache,
      Resource res) {
    if (result.contains(res.uuid)) {
      return;
    }
    if (res.parent == null) {
      return;
    }
    result.add(res.uuid);
    if (res.parent.parent == null) {
      roots.add(res);
      return;
    }
    List<String> children = childrenCache[res.parent.uuid];
    if (children == null) {
      children = [];
      childrenCache[res.parent.uuid] = children;
    }
    children.add(res.uuid);
    _filterAddResult(result, roots, childrenCache, res.parent);
  }

  /**
   * Filters the files using [filterString] as part of the name and returns
   * true if matches are found. If [filterString] is null, cancells all
   * filtering and returns true.
   */
  bool performFilter(String filterString) {
    if (filterString != null && filterString.length < 2) {
      filterString = null;
    }
    _filterString = filterString;
    if (_filterString == null) {
      _filteredFiles = null;
      _filteredChildrenCache = null;
      _reloadDataAndRestoreExpandedState(_currentExpandedState);
      return true;
    } else {
      Set<String> filtered = new Set();
      _filteredFiles = [];
      _filteredChildrenCache = {};
      _filesMap.forEach((String key, Resource res) {
        if (res.name.contains(_filterString) && !res.isDerived()) {
          _filterAddResult(filtered, _filteredFiles, _filteredChildrenCache, res);
        }
      });
      _filteredChildrenCache.forEach((String key, List<String> value) {
        value.sort((String a, String b) {
          Resource resA = _filesMap[a];
          Resource resB = _filesMap[b];
          return _compareResources(resA, resB);
        });
      });

      _reloadDataAndRestoreExpandedState(filtered.toList());
      return _filteredFiles.isNotEmpty;
    }
  }
}

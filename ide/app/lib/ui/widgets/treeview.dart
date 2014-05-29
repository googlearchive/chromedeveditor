// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class implements a treeview widget.
 */

library spark.ui.widgets.treeview;

import 'dart:async';
import 'dart:collection';
import 'dart:html';

import 'package:uuid/uuid_client.dart';

import 'treeview_cell.dart';
import 'treeview_row.dart';
import 'listview.dart';
import 'listview_cell.dart';
import 'listview_delegate.dart';
import 'treeview_delegate.dart';
import '../utils/html_utils.dart';

class TreeViewDragImage {
  ImageElement image;
  Point location;

  TreeViewDragImage(this.image, int x, int y) {
    location = new Point(x, y);
  }
}

class TreeView implements ListViewDelegate {
  // ListView that's used to helps implementing the TreeView.
  ListView _listView;
  // Implements the callbacks required for the `TreeView`.
  // The callbacks will provide the data and the behavior when interacting
  // on the tree.
  // The delegate will assign each node a UID.
  TreeViewDelegate _delegate;
  // List of info about visible items in the treeview. See `TreeViewRow`.
  List<TreeViewRow> _rows;
  // Map from node UID to info.
  Map<String, TreeViewRow> _rowsMap;
  // Saved expanded state of the nodes when reloading the content of the tree.
  Set<String> _expandedState;
  // When dragging over a cell the tree view, it's the highlighted cell.
  TreeViewCell _currentDragOverCell;
  // Whether the user can drag a cell.
  bool draggingEnabled = false;
  // Timer to expand cell on dragover
  Timer _pendingExpansionTimer;
  // Node UID associated with above timer
  String _pendingExpansionNodeUid;
  // Unique identifier of the tree.
  String _uuid;

  String get uuid => _uuid;

  /**
   * Constructor of a `TreeView`.
   * `element` is the container of the tree.
   * `delegate` is the callbacks for the data of the list and behavior when
   * interacting with the tree.
   */
  TreeView(Element element, TreeViewDelegate delegate) {
    Uuid uuidGenerator = new Uuid();
    _uuid = uuidGenerator.v4();
    _delegate = delegate;
    _listView = new ListView(element, this);
    _rows = null;
    _rowsMap = null;
    _pendingExpansionTimer = null;
    _pendingExpansionNodeUid = null;
    reloadData();
  }

  /**
   * Fills _rows and _rowsMap using the callbacks of the delegate.
   */
  void _fillRows() {
    _rows = [];
    _rowsMap = {};
    _recursiveFill(null, -1);
  }

  /**
   * Add to _rows and _rowsMap the given node given by node UID and its
   * sub-nodes recursively if it's expanded.
   */
  void _recursiveFill(String nodeUid, int level) {
    // At this point, _expandedState contains the list of UIDs of nodes that
    // were previously expanded. Expands the node if it was previously
    // expanded.
    bool expanded = _expandedState.contains(nodeUid);
    if (nodeUid == null) {
      expanded = true;
    }

    // nodeUid == null means it's the root node.
    if (nodeUid != null) {
      // Adds the current node.
      TreeViewRow row = new TreeViewRow(nodeUid);
      row.expanded = expanded;
      row.level = level;
      row.rowIndex = _rows.length;
      _rows.add(row);
      _rowsMap[nodeUid] = row;
    }

    if (expanded) {
      int childrenCount = _delegate.treeViewNumberOfChildren(this, nodeUid);
      for(int i = 0 ; i < childrenCount ; i ++) {
        String _rows = _delegate.treeViewChild(this, nodeUid, i);
        _recursiveFill(_rows, level + 1);
      }
    }
  }

  /**
   * Cleans the selection to not include non-showing elements
   */
  void _cleanSelection() {
    for(String nodeUid in selection) {
      TreeViewRow row = _rowsMap[nodeUid];
      if (row == null) {
        selection.remove(nodeUid);
      }
    }
  }

  /**
   * This method can be called to refresh the content when the data provided
   * by the delegate changed.
   */
  void reloadData() {
    // Save selection
    Set<String> savedSelection = new HashSet();
    _listView.selection.forEach((rowIndex) {
      savedSelection.add(_rows[rowIndex].nodeUid);
    });
    // Reset selection.
    _listView.selection = [];

    // Save expanded state.
    _expandedState = new Set();
    if (_rows != null) {
      _expandedState = new Set.from(expandedState);
    }

    _fillRows();
    _expandedState.clear();
    _listView.reloadData();

    // Restore selection
    List<int> restoredSelection = [];
    int idx = 0;
    _rows.forEach((TreeViewRow row) {
      if (savedSelection.contains(row.nodeUid)) {
        restoredSelection.add(idx);
      }
      idx++;
    });
    _listView.selection = restoredSelection;
  }

  bool isNodeExpanded(String nodeUid) {
    return _rowsMap[nodeUid] == null ? false : _rowsMap[nodeUid].expanded;
  }

  List<String> get expandedState {
    if (_rows == null) {
      return [];
    } else {
      return _rows.where((row) => row.expanded).map((row) => row.nodeUid).
          toList();
    }
  }

  void restoreExpandedState(List<String> expandedState) {
    _expandedState = new Set.from(expandedState);
    _fillRows();
    _expandedState.clear();
    _listView.reloadData();
  }

  /**
   * Sets expanded state of a node.
   */
  void setNodeExpanded(String nodeUid, bool expanded, {bool animated: false}) {
    if (isNodeExpanded(nodeUid) != expanded) {
      if (animated) {
        int rowIndex = _rowsMap[nodeUid].rowIndex;
        TreeViewCell cell = _listView.cellForRow(rowIndex);
        // We can use toggleExpanded() here since we made sure that it was
        // different from the current value.
        // TreeViewCell.toggleExpanded() will animate, then call
        // TreeView.setNodeExpanded with animated = false when animation is
        // done.
        cell.toggleExpanded();
      } else {
        HashSet<String> previousSelection = new HashSet.from(selection);
        _rowsMap[nodeUid].expanded = expanded;
        reloadData();
        HashSet<String> currentSelection = new HashSet.from(selection);

        // Testing previousSelection == currentSelection won't behaves as expected
        // then, we're testing if the set are the same using intersection.
        bool changed = false;
        if (previousSelection.length != currentSelection.length) {
          changed = true;
        }
        if (previousSelection.length !=
            previousSelection.intersection(currentSelection).length) {
          changed = true;
        }
        if (changed) {
          _delegate.treeViewSelectedChanged(this,
              _rowIndexesToNodeUids(_listView.selection));
        }

        _delegate.treeViewSaveExpandedState(this);
      }
    }
  }

  void toggleNodeExpanded(String nodeUid, {bool animated: false}) {
    setNodeExpanded(nodeUid, !isNodeExpanded(nodeUid), animated: animated);
  }

  void scrollIntoNode(String nodeUid, [ScrollAlignment align]) {
    TreeViewRow row = _rowsMap[nodeUid];

    if (row != null) {
      _listView.scrollIntoRow(row.rowIndex, align);
    }
  }

  List<String> get selection => _rowIndexesToNodeUids(_listView.selection);

  set selection(List<String> selection) {
    HashSet<String> selectionSet = new HashSet.from(selection);
    int idx = 0;
    List<int> listSelection = [];
    _rows.forEach((TreeViewRow row) {
      if (selectionSet.contains(row.nodeUid)) {
        listSelection.add(idx);
      }
      idx ++;
    });
    _listView.selection = listSelection;
  }

  // ListViewDelegate implementation.

  int listViewNumberOfRows(ListView view) {
    if (_rows == null) {
      return 0;
    }
    return _rows.length;
  }

  // Embed the cell returned by the delegate into a `TreeViewCell`.
  ListViewCell listViewCellForRow(ListView view, int rowIndex) {
    ListViewCell cell =
        _delegate.treeViewCellForNode(this, _rows[rowIndex].nodeUid);
    bool hasChildren =
        _delegate.treeViewHasChildren(this, _rows[rowIndex].nodeUid);
    TreeViewCell treeCell = new TreeViewCell(this, cell, _rows[rowIndex],
        hasChildren, draggingEnabled);
    return treeCell;
  }

  int listViewHeightForRow(ListView view, int rowIndex) {
    return _delegate.treeViewHeightForNode(this, _rows[rowIndex].nodeUid);
  }

  TreeViewCell getTreeViewCellForUid(String nodeUid) {
    if (_rowsMap[nodeUid] == null) return null;
    int rowIndex = _rowsMap[nodeUid].rowIndex;
    return _listView.cellForRow(rowIndex);
  }

  /**
   * Returns the list of node UIDs based on the list of row indexes.
   */
  List<String> _rowIndexesToNodeUids(List<int> rowIndexes) {
    List<String> result = [];
    rowIndexes.forEach((rowIndex) {
      result.add(_rows[rowIndex].nodeUid);
    });
    return result;
  }

  void listViewSelectedChanged(ListView view,
                               List<int> rowIndexes) {
    _delegate.treeViewSelectedChanged(this,
        _rowIndexesToNodeUids(rowIndexes));
  }

  bool listViewRowClicked(Event event, int rowIndex) {
    return _delegate.treeViewRowClicked(event, _rows[rowIndex].nodeUid);
  }

  void listViewDoubleClicked(ListView view,
                             List<int> rowIndexes,
                             Event event) {
    _delegate.treeViewDoubleClicked(this,
        _rowIndexesToNodeUids(rowIndexes),
        event);
  }

  bool listViewKeyDown(KeyboardEvent event) {
    if (_listView.selectedRow == -1) return true;

    // Ignore navigation events that have modifiers.
    // TODO: We should support alt-left/alt-right to collapse/expand all.
    if (event.altKey || event.ctrlKey || event.metaKey) {
      return true;
    }

    String uuid = _rows[_listView.selectedRow].nodeUid;

    switch (event.which) {
      case KeyCode.RIGHT:
        setNodeExpanded(uuid, true, animated: true);
        cancelEvent(event);
        return false;
      case KeyCode.LEFT:
        bool canHaveChildren = _delegate.treeViewHasChildren(this,  uuid);
        bool expanded = isNodeExpanded(uuid);

        if (canHaveChildren && expanded) {
          // Collapse the node.
          setNodeExpanded(uuid, false, animated: true);
        } else {
          // Select the parent.
          String parentUuid = getParentUuid(uuid);
          if (parentUuid != null) {
            int index = _rows.indexOf(_rowsMap[parentUuid]);
            _listView.selection = [index];
            scrollIntoNode(parentUuid);
          }
        }

        cancelEvent(event);
        return false;
    }

    return true;
  }

  void listViewContextMenu(ListView view,
                           List<int> rowIndexes,
                           int rowIndex,
                           Event event) {
    _delegate.treeViewContextMenu(this,
        _rowIndexesToNodeUids(rowIndexes),
        _rows[rowIndex].nodeUid,
        event);
  }

  String listViewDropEffect(ListView view, MouseEvent event) {
    List<String> dragSelection = _innerDragSelection(event.dataTransfer);
    String nodeUid = null;
    if (_currentDragOverCell != null) {
      nodeUid = _currentDragOverCell.nodeUid;
    }
    if (dragSelection != null) {
      return _delegate.treeViewDropCellsEffect(this, dragSelection, nodeUid);
    } else {
      return _delegate.treeViewDropEffect(this, event.dataTransfer, nodeUid);
    }
  }

  List<String> _innerDragSelection(DataTransfer dataTransfer) {
    if (dataTransfer.types.contains('application/x-spark-treeview')) {
      // TODO(dvh): dataTransfer.getData returns empty string when
      // it's called in dragOver event handler. Then, we can't check if uuid
      // matches. We'll improve the behavior when it will be fixed.
      return selection;
    } else {
      return null;
    }
  }

  void listViewDrop(ListView view, int rowIndex, DataTransfer dataTransfer) {
    List<String> dragSelection = _innerDragSelection(dataTransfer);
    String nodeUid = null;
    if (_currentDragOverCell != null) {
      nodeUid = _currentDragOverCell.nodeUid;
    }
    if (dragSelection != null) {
      if (_delegate.treeViewAllowsDropCells(this, dragSelection, nodeUid)) {
        _delegate.treeViewDropCells(this, dragSelection, nodeUid);
      }
    } else {
      // Dropping from somewhere else.
      if (_delegate.treeViewAllowsDrop(this, dataTransfer, nodeUid)) {
        _delegate.treeViewDrop(this, nodeUid, dataTransfer);
      }
    }
    if (_currentDragOverCell != null) {
      _currentDragOverCell.dragOverlayVisible = false;
      _currentDragOverCell = null;
    }
  }

  void listViewDragOver(ListView view, MouseEvent event) {
    Element element = event.target;
    // Lookup for the treeviewcell HTML element.
    Element targetCell = null;
    while (element != null) {
      if (element.classes.contains('treeviewcell')) {
        targetCell = element;
      }
      element = element.parent;
    }

    // Finds the corresponding TreeViewCell.
    TreeViewCell cell = null;
    if (targetCell != null) {
      cell = TreeViewCell.TreeViewCellForElement(targetCell);
      // And if it's accepting drop ...
      if (cell != null && !cell.acceptDrop) {
        cell = null;
      }
    }

    String nodeUid = null;
    if (cell != null) {
      nodeUid = cell.nodeUid;
    }
    List<String> dragSelection = _innerDragSelection(event.dataTransfer);
    if (dragSelection != null) {
      if (!_delegate.treeViewAllowsDropCells(this, dragSelection, nodeUid)) {
        cell = null;
      }
    } else {
      // Dropping from somewhere else.
      if (!_delegate.treeViewAllowsDrop(this, event.dataTransfer, nodeUid)) {
        cell = null;
      }
    }

    // Shows an overlay on the cell.
    if (_currentDragOverCell != cell) {
      if (_currentDragOverCell != null) {
        _currentDragOverCell.dragOverlayVisible = false;
      }
      if (cell != null) {
        cell.dragOverlayVisible = true;

        if(_pendingExpansionNodeUid != cell.nodeUid && _pendingExpansionTimer != null) {
            _pendingExpansionTimer.cancel();
            _pendingExpansionTimer = null;
        }
        if(_pendingExpansionTimer == null) {
          // Queue cell for expanding if it's a pausing drag hover.
          _pendingExpansionNodeUid = cell.nodeUid;
          _pendingExpansionTimer = new Timer(const Duration(milliseconds: 1000), () {
            if(_currentDragOverCell != null &&
                nodeUid == _currentDragOverCell.nodeUid &&
                !isNodeExpanded(nodeUid)) {
              setNodeExpanded(nodeUid, true, animated: true);
            }
          });
        }
      }
      _currentDragOverCell = cell;
    }
  }

  void listViewDragEnter(ListView view, MouseEvent event) {
    bool allowed = true;
    List<String> dragSelection = _innerDragSelection(event.dataTransfer);
    if (dragSelection != null) {
      if (!_delegate.treeViewAllowsDropCells(this, dragSelection, null)) {
        allowed = false;
      }
    } else {
      // Dropping from somewhere else.
      if (!_delegate.treeViewAllowsDrop(this, event.dataTransfer, null)) {
        allowed = false;
      }
    }
    _listView.globalDraggingOverAllowed = allowed;
  }

  void listViewDragLeave(ListView view, MouseEvent event) {
    // Unhighlight the current cell.
    if (_currentDragOverCell != null) {
      _currentDragOverCell.dragOverlayVisible = false;
      _currentDragOverCell = null;
    }
  }

  Element listViewSeparatorForRow(ListView view, int rowIndex) {
    return _delegate.treeViewSeparatorForNode(this, _rows[rowIndex].nodeUid);
  }

  int listViewSeparatorHeightForRow(ListView view, int rowIndex) {
    return _delegate.treeViewSeparatorHeightForNode(this, _rows[rowIndex].nodeUid);
  }

  ListView get listView => _listView;

  void set dropEnabled(bool enabled) {
    _listView.dropEnabled = enabled;
  }

  bool get dropEnabled => _listView.dropEnabled;

  String getParentUuid(String childUuid) {
    int childIndex = _rows.indexOf(_rowsMap[childUuid]);
    int childLevel = _rows[childIndex].level;

    while (childIndex > -1) {
      if (_rows[childIndex].level < childLevel) {
        return _rows[childIndex].nodeUid;
      }
      childIndex--;
    }

    return null;
  }

  /**
   *  Make sure the given node is selected.
   *  Note: it's a private method for TreeViewCell.
   */
  void privateCheckSelectNode(String nodeUid) {
    List<String> currentSelection = selection;
    if (currentSelection.contains(nodeUid)) {
      return;
    }
    selection = [nodeUid];
  }

  /**
   *  This method returns a drag image and location for the current selection.
   *  Note: it's a private method for TreeViewCell.
   */
  TreeViewDragImage privateDragImage(MouseEvent event) {
    return _delegate.treeViewDragImage(this, selection, event);
  }

  /**
   * This method will focus the tree view. The key input will be handled by
   * the tree view once the list view has the focus.
   */
  void focus() {
    _listView.focus();
  }
}

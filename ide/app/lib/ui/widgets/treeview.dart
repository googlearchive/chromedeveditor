// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class implements a treeview widget.
 */

library spark.ui.widgets.treeview;

import 'dart:collection';
import 'dart:html';

import 'package:uuid/uuid.dart';

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
  void _recursiveFill(String nodeUID, int level) {
    // At this point, _expandedState contains the list of UIDs of nodes that
    // were previously expanded. Expands the node if it was previously
    // expanded.
    bool expanded = _expandedState.contains(nodeUID);
    if (nodeUID == null) {
      expanded = true;
    }

    // nodeUID == null means it's the root node.
    if (nodeUID != null) {
      // Adds the current node.
      TreeViewRow row = new TreeViewRow(nodeUID);
      row.expanded = expanded;
      row.level = level;
      row.rowIndex = _rows.length;
      _rows.add(row);
      _rowsMap[nodeUID] = row;
    }

    if (expanded) {
      int childrenCount = _delegate.treeViewNumberOfChildren(this, nodeUID);
      for(int i = 0 ; i < childrenCount ; i ++) {
        String _rows = _delegate.treeViewChild(this, nodeUID, i);
        _recursiveFill(_rows, level + 1);
      }
    }
  }

  /**
   * Cleans the selection to not include non-showing elements
   */
  void _cleanSelection() {
    for(String nodeUID in selection) {
      TreeViewRow row = _rowsMap[nodeUID];
      if (row == null) {
        selection.remove(nodeUID);
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
      savedSelection.add(_rows[rowIndex].nodeUID);
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
      if (savedSelection.contains(row.nodeUID)) {
        restoredSelection.add(idx);
      }
      idx++;
    });
    _listView.selection = restoredSelection;
  }

  bool isNodeExpanded(String nodeUID) {
    return _rowsMap[nodeUID] == null ? false : _rowsMap[nodeUID].expanded;
  }

  List<String> get expandedState {
    if (_rows == null) {
      return [];
    } else {
      return _rows.where((row) => row.expanded).map((row) => row.nodeUID).
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
  void setNodeExpanded(String nodeUID, bool expanded, {bool animated: false}) {
    if (isNodeExpanded(nodeUID) != expanded) {
      if (animated) {
        int rowIndex = _rowsMap[nodeUID].rowIndex;
        TreeViewCell cell = _listView.cellForRow(rowIndex);
        // We can use toggleExpanded() here since we made sure that it was
        // different from the current value.
        // TreeViewCell.toggleExpanded() will animate, then call
        // TreeView.setNodeExpanded with animated = false when animation is
        // done.
        cell.toggleExpanded();
      } else {
        HashSet<String> previousSelection = new HashSet.from(selection);
        _rowsMap[nodeUID].expanded = expanded;
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
              _rowIndexesToNodeUIDs(_listView.selection));
        }

        _delegate.treeViewSaveExpandedState(this);
      }
    }
  }

  void toggleNodeExpanded(String nodeUID, {bool animated: false}) {
    setNodeExpanded(nodeUID, !isNodeExpanded(nodeUID), animated: animated);
  }

  void scrollIntoNode(String nodeUID, [ScrollAlignment align]) {
    TreeViewRow row = _rowsMap[nodeUID];

    if (row != null) {
      _listView.scrollIntoRow(row.rowIndex, align);
    }
  }

  List<String> get selection => _rowIndexesToNodeUIDs(_listView.selection);

  set selection(List<String> selection) {
    HashSet<String> selectionSet = new HashSet.from(selection);
    int idx = 0;
    List<int> listSelection = [];
    _rows.forEach((TreeViewRow row) {
      if (selectionSet.contains(row.nodeUID)) {
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
        _delegate.treeViewCellForNode(this, _rows[rowIndex].nodeUID);
    bool hasChildren =
        _delegate.treeViewHasChildren(this, _rows[rowIndex].nodeUID);
    TreeViewCell treeCell = new TreeViewCell(this, cell, _rows[rowIndex],
        hasChildren, draggingEnabled);
    return treeCell;
  }

  int listViewHeightForRow(ListView view, int rowIndex) {
    return _delegate.treeViewHeightForNode(this, _rows[rowIndex].nodeUID);
  }

  TreeViewCell getTreeViewCellForUID(String nodeUID) {
    if (_rowsMap[nodeUID] == null) return null;
    int rowIndex = _rowsMap[nodeUID].rowIndex;
    return _listView.cellForRow(rowIndex);
  }

  /**
   * Returns the list of node UIDs based on the list of row indexes.
   */
  List<String> _rowIndexesToNodeUIDs(List<int> rowIndexes) {
    List<String> result = [];
    rowIndexes.forEach((rowIndex) {
      result.add(_rows[rowIndex].nodeUID);
    });
    return result;
  }

  void listViewSelectedChanged(ListView view,
                               List<int> rowIndexes) {
    _delegate.treeViewSelectedChanged(this,
        _rowIndexesToNodeUIDs(rowIndexes));
  }

  bool listViewRowClicked(Event event, int rowIndex) {
    return _delegate.treeViewRowClicked(event, _rows[rowIndex].nodeUID);
  }

  void listViewDoubleClicked(ListView view,
                             List<int> rowIndexes,
                             Event event) {
    _delegate.treeViewDoubleClicked(this,
        _rowIndexesToNodeUIDs(rowIndexes),
        event);
  }

  bool listViewKeyDown(KeyboardEvent event) {
    int keyCode = event.which;
    bool expand;

    switch (keyCode) {
      case KeyCode.RIGHT:
        expand = true;
        break;
      case KeyCode.LEFT:
        expand = false;
        break;
      default:
        return true;
    }

    if (_listView.selectedRow != -1) {
      setNodeExpanded(_rows[_listView.selectedRow].nodeUID, expand,
          animated: true);
    }

    cancelEvent(event);
  }

  void listViewContextMenu(ListView view,
                           List<int> rowIndexes,
                           int rowIndex,
                           Event event) {
    _delegate.treeViewContextMenu(this,
        _rowIndexesToNodeUIDs(rowIndexes),
        _rows[rowIndex].nodeUID,
        event);
  }

  String listViewDropEffect(ListView view, MouseEvent event) {
    String nodeUID = null;
    if (_currentDragOverCell != null) {
      nodeUID = _currentDragOverCell.nodeUID;
    }
    return _delegate.treeViewDropEffect(this, event.dataTransfer, nodeUID);
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
    String nodeUID = null;
    if (_currentDragOverCell != null) {
      nodeUID = _currentDragOverCell.nodeUID;
    }
    if (dragSelection != null) {
      if (_delegate.treeViewAllowsDropCells(this, dragSelection, nodeUID)) {
        _delegate.treeViewDropCells(this, dragSelection, nodeUID);
      }
    } else {
      // Dropping from somewhere else.
      if (_delegate.treeViewAllowsDrop(this, dataTransfer, nodeUID)) {
        _delegate.treeViewDrop(this, nodeUID, dataTransfer);
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

    String nodeUID = null;
    if (cell != null) {
      nodeUID = cell.nodeUID;
    }
    List<String> dragSelection = _innerDragSelection(event.dataTransfer);
    if (dragSelection != null) {
      if (!_delegate.treeViewAllowsDropCells(this, dragSelection, nodeUID)) {
        cell = null;
      }
    } else {
      // Dropping from somewhere else.
      if (!_delegate.treeViewAllowsDrop(this, event.dataTransfer, nodeUID)) {
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

  ListView get listView => _listView;

  void set dropEnabled(bool enabled) {
    _listView.dropEnabled = enabled;
  }

  bool get dropEnabled => _listView.dropEnabled;

  /**
   *  Make sure the given node is selected.
   *  Note: it's a private method for TreeViewCell.
   */
  void privateCheckSelectNode(String nodeUID) {
    List<String> currentSelection = selection;
    if (currentSelection.contains(nodeUID)) {
      return;
    }
    selection = [nodeUID];
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

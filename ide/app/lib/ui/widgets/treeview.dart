// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class implements a treeview widget.
 */

library spark.ui.widgets.treeview;

import 'dart:collection';
import 'dart:html';

import 'treeview_cell.dart';
import 'treeview_row.dart';
import 'listview.dart';
import 'listview_cell.dart';
import 'listview_delegate.dart';
import 'treeview_delegate.dart';

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
  HashSet<String> _expandedState;
  TreeViewCell _currentDragOverCell;

  /**
   * Constructor of a `TreeView`.
   * `element` is the container of the tree.
   * `delegate` is the callbacks for the data of the list and behavior when
   * interacting with the tree.
   */
  TreeView(Element element, TreeViewDelegate delegate) {
    _delegate = delegate;
    _listView = new ListView(element, this);
    _rows = null;
    _rowsMap = null;
    reloadData();
  }

  /**
   * This method can be called to refresh the content when the data provided
   * by the delegate changed.
   */
  void reloadData() {
    _refreshRows();
    _listView.reloadData();
  }

  // Populate _rows.

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
   * Refresh the content of the tree and keep nodes expanded and restore
   * selection properly.
   */
  void _refreshRows() {
    // Save selection
    Set<String> savedSelection = new HashSet();
    _listView.selection.forEach((rowIndex) {
      savedSelection.add(_rows[rowIndex].nodeUID);
    });
    // Reset selection.
    _listView.selection = [];

    // Save expanded state.
    _expandedState = new HashSet();
    if (_rows != null) {
      // Save expanded state.
      _rows.forEach((TreeViewRow row) {
        if (row.expanded) {
          _expandedState.add(row.nodeUID);
        }
      });
    }

    _fillRows();
    _expandedState.clear();

    // Restore selection
    List<int> restoredSelection = [];
    int idx = 0;
    _rows.forEach((TreeViewRow row) {
      if (savedSelection.contains(row.nodeUID)) {
        restoredSelection.add(idx);
        idx++;
      }
    });
    _listView.selection = restoredSelection;
  }

  /**
   * Sets expanded state of a node.
   */
  void setNodeExpanded(String nodeUID, bool expanded) {
    _rowsMap[nodeUID].expanded = expanded;
    reloadData();
    _delegate.treeViewSelectedChanged(this,
        _rowIndexesToNodeUIDs(_listView.selection),
        null);
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
    ListViewCell cell = _delegate.treeViewCellForNode(this, _rows[rowIndex].nodeUID);
    bool hasChildren = _delegate.treeViewHasChildren(this, _rows[rowIndex].nodeUID);
    TreeViewCell treeCell = new TreeViewCell(this, cell, _rows[rowIndex], hasChildren);
    return treeCell;
  }

  int listViewHeightForRow(ListView view, int rowIndex) {
    return _delegate.treeViewHeightForNode(this, _rows[rowIndex].nodeUID);
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
                               List<int> rowIndexes,
                               Event event) {
    _delegate.treeViewSelectedChanged(this,
        _rowIndexesToNodeUIDs(rowIndexes),
        event);
  }

  void listViewDoubleClicked(ListView view,
                             List<int> rowIndexes,
                             Event event) {
    _delegate.treeViewDoubleClicked(this,
        _rowIndexesToNodeUIDs(rowIndexes),
        event);
  }

  String listViewDropEffect(ListView view) {
    return _delegate.treeViewDropEffect(this);
  }

  void listViewDrop(ListView view, int rowIndex, DataTransfer dataTransfer) {
    String nodeUID = null;
    if (rowIndex != -1) {
      nodeUID = _rowIndexesToNodeUIDs([rowIndex])[0];
    }
    _delegate.treeViewDrop(this, nodeUID, dataTransfer);
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
      if (!cell.acceptDrop)
        cell = null;
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

  void listViewDragEnter(ListView view) {
    // Do nothing
  }

  void listViewDragLeave(ListView view) {
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
}

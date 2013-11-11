// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class encapsulates a list view.
 */

library spark.ui.widgets.listview;

import 'dart:collection';
import 'dart:html';

import 'listview_cell.dart';
import 'listview_row.dart';
import 'listview_delegate.dart';

class ListView {
  // The HTML element containing the list of items.
  Element _element;
  // A container for the items will be created by the `ListView` implementation.
  DivElement _container;
  // Implements the callbacks required for the `ListView`.
  // The callbacks will provide the data and the behavior when interacting
  // on the list.
  ListViewDelegate _delegate;
  // Selected rows stored as a set of row indexes.
  HashSet<int> _selection;
  // In case of multiple selection using shift, it's the starting row index.
  // -1 is used when there's not starting row.
  int _selectedRow;
  // Stores info about the cells of the ListView.
  List<ListViewRow> _rows;

  /**
   * Constructor of a `ListView`.
   * `element` is the container of the list.
   * `delegate` is the callbacks for the data of the list and behavior when
   * interacting with the list.
   */
  ListView(Element element, ListViewDelegate delegate) {
    _element = element;
    _delegate = delegate;
    _container = new DivElement();
    _container.classes.add('listview-container');
    _element.children.add(_container);
    _selection = new HashSet();
    _rows = [];
    _selectedRow = -1;
    _container.onClick.listen((event) {
      _removeCurrentSelectionHighlight();
      _selection.clear();
      _delegate.listViewSelectedChanged(this, _selection.toList());
    });
    reloadData();
  }

  /**
   * This method can be called to refresh the content when the data provided
   * by the delegate changed.
   */
  void reloadData() {
    _rows.clear();
    _container.children.clear();
    int count = _delegate.listViewNumberOfRows(this);
    int y = 0;
    for(int i = 0 ; i < count ; i ++) {
      int cellHeight = _delegate.listViewHeightForRow(this, i);
      ListViewRow row = new ListViewRow();
      row.cell = _delegate.listViewCellForRow(this, i);
      row.container = new DivElement();
      row.container.children.add(row.cell.element);
      row.container.style
        ..width = '100%'
        ..height = cellHeight.toString() + 'px'
        ..position = 'absolute'
        ..top = y.toString() + 'px';
      // Set events callback.
      row.container.onClick.listen((event) {
        _onClicked(i, event);
        event.stopPropagation();
      });
      row.container.onDoubleClick.listen((event) {
        _onDoubleClicked(i, event);
        event.stopPropagation();
      });
      y += cellHeight;
      _rows.add(row);
      _container.children.add(row.container);
    }
    _container.clientHeight;
    // Fix selection if needed.
    if (_selectedRow >= count) {
      _selectedRow = -1;
    }
    List<int> itemsToRemove = [];
    List<int> selectionList = _selection.toList();
    selectionList.sort();
    selectionList.reversed.forEach((rowIndex) {
      if (rowIndex >= count) {
        itemsToRemove.add(rowIndex);
      }
    });
    itemsToRemove.forEach((rowIndex) {
      _selection.remove(rowIndex);
    });
    _addCurrentSelectionHighlight();
  }

  /**
   * Callback on a single click.
   */
  void _onClicked(int rowIndex, Event event) {
    _removeCurrentSelectionHighlight();
    if ((event as MouseEvent).shiftKey) {
      // Click while holding shift.
      if (_selectedRow == -1) {
        _selectedRow = rowIndex;
        _selection.clear();
        _selection.add(rowIndex);
      } else if (_selectedRow < rowIndex) {
        _selection.clear();
        for(int i = _selectedRow ; i <= rowIndex ; i++) {
          _selection.add(i);
        }
      } else {
        _selection.clear();
        for(int i = rowIndex ; i <= _selectedRow ; i++) {
          _selection.add(i);
        }
      }
    } else if ((event as MouseEvent).metaKey || (event as MouseEvent).ctrlKey) {
      // Click while holding Ctrl (Mac/Linux) or Command (for Mac).
      _selectedRow = rowIndex;
      _selection.add(rowIndex);
    } else {
      // Click without any modifiers.
      _selectedRow = rowIndex;
      _selection.clear();
      _selection.add(rowIndex);
    }
    _addCurrentSelectionHighlight();
    _delegate.listViewSelectedChanged(this, _selection.toList());
  }

  List<int> get selection => _selection.toList();

  set selection(List<int> selection) {
    _removeCurrentSelectionHighlight();
    _selection.clear();
    selection.forEach((rowIndex) {
      _selection.add(rowIndex);
    });
    _addCurrentSelectionHighlight();
  }

  /**
   * Callback on a double click.
   */
  void _onDoubleClicked(int rowIndex, Event event) {
    _delegate.listViewDoubleClicked(this, _selection.toList());
  }

  /**
   * Cancel highlight of the current rows selection.
   */
  void _removeCurrentSelectionHighlight() {
    _selection.forEach((rowIndex) {
      _rows[rowIndex].cell.highlighted = false;
      _rows[rowIndex].container.style.backgroundColor =  'rgba(0, 0, 0, 0)';
    });
  }

  /**
   * Shows highlight of the current rows selection.
   */
  void _addCurrentSelectionHighlight() {
    _selection.forEach((rowIndex) {
      _rows[rowIndex].cell.highlighted = true;
      _rows[rowIndex].container.style.backgroundColor = '#ddf';
    });
  }
}
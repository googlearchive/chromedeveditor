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
  // Stores all the cells of the ListView.
  List<ListViewCell> _cells;
  
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
    _container.style
      ..width = '100%'
      ..position = 'relative'
      ..overflowX = 'hidden'
      ..overflowY = 'scroll'
      ..height = '100%';
    _element.children.add(_container);
    _selection = new HashSet();
    _cells = [];
    _selectedRow = -1;
    reloadData();
  }

  /**
   * This method can be called to refresh the content when the data provided
   * by the delegate changed.
   */
  void reloadData() {
    _cells.clear();
    _container.children.clear();
    int count = _delegate.listViewNumberOfRows(this);
    int y = 0;
    for(int i = 0 ; i < count ; i ++) {
      int cellHeight = _delegate.listViewHeightForRow(this, i);
      ListViewCell cell = _delegate.listViewCellForRow(this, i);
      Element item = new DivElement();
      item.children.add(cell.element);
      item.style
        ..width = '100%'
        ..height = cellHeight.toString() + 'px'
        ..position = 'absolute'
        ..top = y.toString() + 'px';
      // Set events callback.
      item.onClick.listen((event) {
        _onClicked(i, event);
      });
      item.onDoubleClick.listen((event) {
        _onDoubleClicked(i, event);
      });
      y += cellHeight;
      _cells.add(cell);
      _container.children.add(item);
    }
    _container.clientHeight;
    // Fix selection if needed.
    if (_selectedRow >= count) {
      _selectedRow = -1;
      List<int> itemsToRemove = [];
      _selection.forEach((rowIndex) {
        if (rowIndex > count) {
          itemsToRemove.add(rowIndex);
        }
      });
      itemsToRemove.forEach((rowIndex) {
        _selection.remove(rowIndex);
      });
    }
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
      _cells[rowIndex].highlighted = false;
    });
  }

  /**
   * Shows highlight of the current rows selection.
   */
  void _addCurrentSelectionHighlight() {
    _selection.forEach((rowIndex) {
      _cells[rowIndex].highlighted = true;
    });
  }
}
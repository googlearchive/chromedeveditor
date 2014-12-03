// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class encapsulates a list view.
 */

library spark.ui.widgets.listview;

import 'dart:async';
import 'dart:collection';
import 'dart:html';

import 'listview_cell.dart';
import 'listview_row.dart';
import 'listview_delegate.dart';
import '../html_utils.dart';

class ListView {
  // The HTML element containing the list of items.
  Element _element;
  // HTML element to show the highlight when we drag an item over the
  // `ListView`.
  DivElement _dragoverVisual;
  // A container for the items will be created by the `ListView` implementation.
  DivElement _container;
  // This div will help set the size of the scrollable area in the container.
  DivElement _placeholder;
  // Implements the callbacks required for the `ListView`.
  // The callbacks will provide the data and the behavior when interacting
  // on the list.
  ListViewDelegate _delegate;
  // Selected rows stored as a set of row indexes.
  HashSet<int> _selection;
  // In case of multiple selection using shift, it's the starting row index.
  // -1 is used when there's not starting row.
  int _selectedRow;
  int _extendedSelectionRow;
  // Stores info about the cells of the ListView.
  List<ListViewRow> _rows;
  // Whether dropping items on the listView is allowed.
  bool _dropEnabled;
  // dragenter event listener.
  StreamSubscription<MouseEvent> _dragEnterSubscription;
  // dragleave event listener.
  StreamSubscription<MouseEvent> _dragLeaveSubscription;
  // dragover event listener.
  StreamSubscription<MouseEvent> _dragOverSubscription;
  // drop event listener.
  StreamSubscription<MouseEvent> _dropSubscription;
  // window resize event listener.
  StreamSubscription<Event> _resizeSubscription;
  // Counter for the dragenter/dragleave events to workaround the behavior of
  // drag and drop. See `dropEnabled` setter for more information.
  int _draggingCount;
  // True if the mouse entered the listview while dragging an item.
  bool _draggingOver;
  // True if any cell is highlighted when dragging an item on it.
  // In this case, we don't want to highlight the whole list.
  bool _cellHighlightedOnDragover;
  // True if the list should be highlighted when dragging over and no cell
  // accepts the drop.
  bool _globalDraggingOverAllowed;

  /**
   * Constructor of a `ListView`.
   * `element` is the container of the list.
   * `delegate` is the callbacks for the data of the list and behavior when
   * interacting with the list.
   */
  ListView(Element element, ListViewDelegate delegate) {
    _element = element;
    _delegate = delegate;
    _dragoverVisual = new DivElement();
    _dragoverVisual.classes.add('listview-dragover');
    _container = new DivElement();
    _container.tabIndex = 1;
    _container.classes.add('listview-container');
    _container.onKeyDown.listen(_onKeyDown);
    _placeholder = new DivElement();
    _dropEnabled = false;
    _element.children.add(_container);
    _element.children.add(_dragoverVisual);
    _selection = new HashSet();
    _rows = [];
    _selectedRow = -1;
    _extendedSelectionRow = -1;
    _container.onClick.listen((event) {
      _removeCurrentSelectionHighlight();
      _selection.clear();
      _delegate.listViewSelectedChanged(this, _selection.toList());
    });
    _container.onScroll.listen((event) => _showVisible());
    _resizeSubscription = window.onResize.listen((event) => _showVisible());
    _draggingCount = 0;
    _draggingOver = false;
    _cellHighlightedOnDragover = false;
    _globalDraggingOverAllowed = true;
    reloadData();
  }

  void _onKeyDown(KeyboardEvent event) {
    if (!_delegate.listViewKeyDown(event)) {
      return;
    }

    int keyCode = event.which;
    switch (keyCode) {
      case KeyCode.UP:
        if (_selectedRow > 0) {
          if (event.shiftKey) {
            if (_extendedSelectionRow == -1) {
              _extendedSelectionRow = _selectedRow;
            }
            _setSelection(_selectedRow - 1,
                endSelectionIndex: _extendedSelectionRow);
          } else {
            _extendedSelectionRow = -1;
            _setSelection(_selectedRow - 1);
          }
          _makeSureRowIsVisible(_selectedRow);
          cancelEvent(event);
        }
        break;
      case KeyCode.DOWN:
        if (_selectedRow < _rows.length - 1) {
          if (event.shiftKey) {
            if (_extendedSelectionRow == -1) {
              _extendedSelectionRow = _selectedRow;
            }
            _setSelection(_selectedRow + 1,
                endSelectionIndex: _extendedSelectionRow);
          } else {
            _extendedSelectionRow = -1;
            _setSelection(_selectedRow + 1);
          }
          _makeSureRowIsVisible(_selectedRow);
          cancelEvent(event);
        }
        break;
    }
  }

  /**
   * This method can be called to refresh the content when the data provided
   * by the delegate changed.
   */
  void reloadData() {
    _rows.clear();
    _container.children.clear();
    _container.children.add(_placeholder);
    int count = _delegate.listViewNumberOfRows(this);
    int y = 0;
    for(int i = 0 ; i < count ; i ++) {
      Element separator = _delegate.listViewSeparatorForRow(this, i);
      int separatorHeight = _delegate.listViewSeparatorHeightForRow(this, i);
      int separatorY = y;
      if (separator != null) {
        separator.style
          ..position = 'absolute'
          ..left = '0'
          ..right = '0'
          ..height = '${separatorHeight}px'
          ..top = '${y}px';
        y += separatorHeight;
      } else {
        separatorHeight = 0;
      }

      int cellHeight = _delegate.listViewHeightForRow(this, i);
      ListViewRow row = new ListViewRow();
      row.cell = _delegate.listViewCellForRow(this, i);
      row.container = new DivElement();
      row.container.classes.add('listview-row');
      row.container.children.add(row.cell.element);
      row.container.style
        ..left = '0'
        ..right = '0'
        ..height = '${cellHeight - 2}px'
        ..position = 'absolute'
        ..top = '${y}px';
      // Set events callback.
      row.y = y;
      row.height = cellHeight;
      row.separator = separator;
      row.separatorY = separatorY;
      row.separatorHeight = separatorHeight;
      y += cellHeight;
      _rows.add(row);
      row.container.onClick.listen((event) {
        _onClicked(i, event);
        event.stopPropagation();
      });
      row.container.onDoubleClick.listen((event) {
        _onDoubleClicked(i, event);
        event.stopPropagation();
      });
      row.container.onContextMenu.listen((event) {
        _onContextMenu(i, event);
        cancelEvent(event);
      });
    }
    _placeholder.style
      ..position = 'absolute'
      ..top = '0'
      ..left = '0'
      ..right = '0'
      ..height = '${y}px';
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
    _showVisible();
  }

  // This method performs a dichotomy to find out in which row y is located.
  int _findRow(int y, int left, int right) {
    int middle = ((left + right) / 2).floor();
    if (middle == left) {
      if (y >= _rows[right].separatorY) {
        return right;
      } else {
        return left;
      }
    }

    if (y >= _rows[middle].separatorY) {
      return _findRow(y, middle, right);
    } else {
      return _findRow(y, 0, middle - 1);
    }
  }

  /**
   * This method adds in the DOM the visible cells.
   */
  void _showVisible() {
    int scopeTop = _container.scrollTop;
    int scopeBottom = _container.scrollTop + _container.offsetHeight;

    if (_rows.length == 0) {
      return;
    }
    int left = _findRow(scopeTop, 0, _rows.length - 1);
    for(int i = left ; i < _rows.length ; i ++) {
      ListViewRow row = _rows[i];
      if (row.separator != null) {
        int y = row.separatorY;
        if ((row.separator.parent == null) && (y >= scopeTop - row.separatorHeight) && (y < scopeBottom)) {
          _container.children.add(row.separator);
        }
      }
      if (row.container != null) {
        int y = row.y;
        if ((row.container.parent == null) && (y >= scopeTop - row.height) && (y < scopeBottom)) {
          _container.children.add(row.container);
        }
      }
      if (row.y > scopeBottom) {
        break;
      }
    }
  }

  /**
   * Callback on a single click.
   */
  void _onClicked(int rowIndex, Event event) {
    _extendedSelectionRow = -1;
    focus();

    if (!_delegate.listViewRowClicked(event, rowIndex)) {
      // If listViewRowClicked returns false, don't handle.
      return;
    }

    if ((event as MouseEvent).shiftKey) {
      // Click while holding shift.
      _setSelection(
          (_selectedRow != -1) ? _selectedRow : rowIndex,
          endSelectionIndex: rowIndex);
    } else if ((event as MouseEvent).metaKey || (event as MouseEvent).ctrlKey) {
      // Click while holding Ctrl (Mac/Linux) or Command (for Mac).
      _toggleSelectedRow(rowIndex);
    } else {
      // Click without any modifiers.
      _setSelection(rowIndex);
    }
  }

  void _toggleSelectedRow(int rowIndex) {
    _removeCurrentSelectionHighlight();

    _selectedRow = rowIndex;

    if (_selection.contains(rowIndex)) {
      _selection.remove(rowIndex);
    } else {
      _selection.add(rowIndex);
    }

    _addCurrentSelectionHighlight();
    _delegate.listViewSelectedChanged(this, _selection.toList());
  }

  void _makeSureRowIsVisible(int selectionIndex) {
    ListViewRow row = _rows[selectionIndex];
    if (row.container.parent == null) {
      _container.children.add(row.container);
    }
    if (row.container.offsetTop + row.container.offsetHeight >
        _container.scrollTop + _container.offsetHeight) {
      _container.scrollTop = row.container.offsetTop +
          row.container.offsetHeight - _container.offsetHeight;
    }
    if (row.container.offsetTop < _container.scrollTop) {
      _container.scrollTop = row.container.offsetTop;
    }
  }

  void _setSelection(int selectionIndex, {int endSelectionIndex: -1}) {
    _removeCurrentSelectionHighlight();

    // If endSelection is -1 (default for not-provided), one item is being selected.
    if (endSelectionIndex == -1) {
      endSelectionIndex = selectionIndex;
    }

    selectionIndex = selectionIndex.clamp(0, _rows.length);
    endSelectionIndex = endSelectionIndex.clamp(0, _rows.length);

    if (selectionIndex < endSelectionIndex) {
      _selection.clear();
      for(int i = selectionIndex ; i <= endSelectionIndex ; i++) {
        _selection.add(i);
      }
    } else {
      _selection.clear();
      for(int i = endSelectionIndex ; i <= selectionIndex ; i++) {
        _selection.add(i);
      }
    }

    _selectedRow = selectionIndex;

    _addCurrentSelectionHighlight();
    _delegate.listViewSelectedChanged(this, _selection.toList());
  }

  void _onContextMenu(int rowIndex, Event event) {
    _delegate.listViewContextMenu(this, _selection.toList(), rowIndex, event);
  }

  List<int> get selection => _selection.toList();

  set selection(List<int> selection) {
    _removeCurrentSelectionHighlight();
    _selection.clear();
    selection.forEach((rowIndex) {
      _selection.add(rowIndex);
    });
    _addCurrentSelectionHighlight();

    if (selection.length > 0) {
      _selectedRow = selection.first;
    } else {
      _selectedRow = -1;
    }
  }

  void scrollIntoRow(int rowIndex, [ScrollAlignment align]) {
    ListViewRow row = _rows[rowIndex];
    if (row.container.parent == null) {
      _container.children.add(row.container);
    }
    row.cell.element.parent.scrollIntoView(align);
  }

  /**
   * Callback on a double click.
   */
  void _onDoubleClicked(int rowIndex, Event event) {
    _delegate.listViewDoubleClicked(this, _selection.toList(), event);
  }

  /**
   * Cancel highlight of the current rows selection.
   */
  void _removeCurrentSelectionHighlight() {
    _selection.forEach((rowIndex) {
      _rows[rowIndex].cell.highlighted = false;
      _rows[rowIndex].container.classes.remove('listview-cell-highlighted');
    });
  }

  /**
   * Shows highlight of the current rows selection.
   */
  void _addCurrentSelectionHighlight() {
    _selection.forEach((rowIndex) {
      _rows[rowIndex].cell.highlighted = true;
      _rows[rowIndex].container.classes.add('listview-cell-highlighted');
    });
  }

  void set dropEnabled(bool enabled) {
    if (_dropEnabled == enabled)
      return;

    _dropEnabled = enabled;
    if (_dropEnabled) {
      _dragEnterSubscription = _container.onDragEnter.listen((event) {
        // Ignore when we get additional dragenter events when children are
        // entered/left.
        _draggingCount ++;
        if (_draggingCount == 1) {
          cancelEvent(event);
          String effect = _delegate.listViewDropEffect(this, event);
          if (effect == null) {
            return;
          }
          _draggingOver = true;
          _updateDraggingVisual();
          event.dataTransfer.dropEffect = effect;
          _delegate.listViewDragEnter(this, event);
        }
      });
      _dragLeaveSubscription = _container.onDragLeave.listen((event) {
        // Ignore when we get additional dragleave events when children are
        // entered/left.
        _draggingCount --;
        if (_draggingCount == 0) {
          cancelEvent(event);
          _draggingOver = false;
          _updateDraggingVisual();
          _delegate.listViewDragLeave(this, event);
        }
      });
      _dragOverSubscription = _container.onDragOver.listen((event) {
        cancelEvent(event);
        _delegate.listViewDragOver(this, event);

        String effect = _delegate.listViewDropEffect(this, event);
        if (effect != null) {
          event.dataTransfer.dropEffect = effect;
        }
      });
      _dropSubscription = _container.onDrop.listen((event) {
        cancelEvent(event);
        _draggingCount = 0;
        _draggingOver = false;
        _updateDraggingVisual();
        int dropRowIndex = -1;
        _delegate.listViewDrop(this, dropRowIndex, event.dataTransfer);
      });
    } else {
      _dragEnterSubscription.cancel();
      _dragEnterSubscription = null;
      _dragLeaveSubscription.cancel();
      _dragLeaveSubscription = null;
      _dragOverSubscription.cancel();
      _dragOverSubscription = null;
      _dropSubscription.cancel();
      _dropSubscription = null;
    }
  }

  bool get cellHighlightedOnDragOver => _cellHighlightedOnDragover;

  void set cellHighlightedOnDragOver(bool cellHighlightedOnDragOver) {
    _cellHighlightedOnDragover = cellHighlightedOnDragOver;
    _updateDraggingVisual();
  }

  bool get globalDraggingOverAllowed => _globalDraggingOverAllowed;

  void set globalDraggingOverAllowed(bool allowed) {
    _globalDraggingOverAllowed = allowed;
    _updateDraggingVisual();
  }

  void _updateDraggingVisual() {
    // We highlight is dragging is over the list and no cells is highlighted.
    if (_draggingOver && !_cellHighlightedOnDragover &&
        _globalDraggingOverAllowed) {
      _dragoverVisual.classes.add('listview-dragover-active');
    } else {
      _dragoverVisual.classes.remove('listview-dragover-active');
    }
  }

  ListViewCell cellForRow(int rowIndex) {
    return _rows[rowIndex].cell;
  }

  /**
   * This method will focus the list view.
   */
  void focus() {
    _container.focus();
  }

  bool get dropEnabled => _dropEnabled;

  int get selectedRow => _selectedRow;
}

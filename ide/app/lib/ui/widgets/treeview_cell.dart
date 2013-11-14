// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.widgets.treeview_cell;

import 'dart:html';
import 'dart:async';

import 'listview_cell.dart';
import 'treeview.dart';
import 'treeview_row.dart';

Expando<TreeViewCell> treeViewCellExpando = new Expando<TreeViewCell>();

class TreeViewCell implements ListViewCell {
  // HTML element of the view.
  Element _element;
  // Cell returned by the delegate of the treeview.
  ListViewCell _embeddedCell;
  // <div> element that will contain _embeddedCell element.
  DivElement _embeddedCellContainer;
  // The disclosure arrow.
  DivElement _arrow;
  // Highlighted state of the node.
  bool _highlighted;
  // The TreeView that owns this node.
  TreeView _treeView;
  // Information about the displayed node.
  TreeViewRow _row;
  // Whether the disclosure arrow is animating.
  bool _animating;
  // When the user is dragging an item over the _embeddedCell, we show a
  // "drag over" highlight.
  DivElement _dragOverlay;
  // Whether the "drag over" highlight is visible.
  bool _dragOverlayVisible;

  static TreeViewCell TreeViewCellForElement(DivElement element) {
    return treeViewCellExpando[element];
  }

  TreeViewCell(TreeView treeView, ListViewCell embeddedCell, TreeViewRow row,
               bool hasChildren) {
    _treeView = treeView;
    _row = row;
    _embeddedCell = embeddedCell;
    _embeddedCellContainer = new DivElement();
    int margin = (_row.level * 10);
    _embeddedCellContainer.classes.add('treeviewcell-content');
    _embeddedCellContainer.style.left = '${margin + 20}px';
    int offsetX = margin + 30;
    _embeddedCellContainer.style.width = 'calc(100% - ${offsetX}px)';
    _embeddedCellContainer.children.add(_embeddedCell.element);

    _element = new DivElement();
    _element.classes.add('treeviewcell');
    _element.children.add(_embeddedCellContainer);

    _dragOverlay = new DivElement();
    _dragOverlay.classes.add('treeviewcell-dragoverlay');
    _dragOverlay.style.left = '${margin + 15}px';
    offsetX = margin + 20;
    _dragOverlay.style.width = 'calc(100% - ${offsetX}px)';
    _element.children.add(_dragOverlay);

    if (hasChildren) {
      // Adds an arrow in front the cell.
      _arrow = new DivElement();
      _arrow.classes.add('treeviewcell-disclosure');
      _arrow.style.left = '${margin}px';
      _arrow.appendHtml('&#9654;');
      _applyExpanded(_row.expanded);
      _element.children.add(_arrow);

      // Click handler for the arrow: toggle expanded state of the node.
      _arrow.onClick.listen((event) {
        event.stopPropagation();

        // Don't change the expanded state if it's already animating to change
        // the expanded state.
        if (_animating) {
          return;
        }

        // Change visual appearance.
        _applyExpanded(!_row.expanded);

        // Wait for animation to finished before effectively changing the
        // expanded state.
        _animating = true;
        _arrow.on['transitionend'].listen((event) {
          _animating = false;
          treeView.setNodeExpanded(_row.nodeUID, !_row.expanded);
        });
      });
    }

    _animating = false;
    treeViewCellExpando[_element] = this;
  }

  Element get element => _element;
  set element(Element element) => _element = element;

  bool get highlighted => _highlighted;

  set highlighted(bool value) {
    _highlighted = value;
    _embeddedCell.highlighted = value;
  }

  bool get dragOverlayVisible => _dragOverlayVisible;

  set dragOverlayVisible(bool value) {
    _dragOverlayVisible = value;
    if (_dragOverlayVisible) {
      _dragOverlay.style.opacity = '1';
    } else {
      _dragOverlay.style.opacity = '0';
    }
    // Notify the TreeView that a cell is being highlighted.
    _treeView.listView.cellHighlightedOnDragOver = _dragOverlayVisible;
  }

  String get nodeUID => _row.nodeUID;

  // Change visual appearance of the disclosure arrow, depending whether the
  // node is expanded or not.
  void _applyExpanded(bool expanded) {
    _arrow.style.transform = expanded ? 'rotate(90deg)' : 'rotate(0deg)';
  }

  bool get acceptDrop => _embeddedCell.acceptDrop;
  set acceptDrop(bool value) => _embeddedCell.acceptDrop = value;
}

// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.widgets.treeview_cell;

import 'dart:html';
import 'dart:convert' show JSON;

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

  TreeViewCell(this._treeView, this._embeddedCell, this._row,
               bool hasChildren, bool draggable) {
    DocumentFragment template =
        (querySelector('#treeview-cell-template') as TemplateElement).content;
    DocumentFragment templateClone = template.clone(true);
    _element = templateClone.querySelector('.treeviewcell');

    _embeddedCellContainer = _element.querySelector('.treeviewcell-content');
    int margin = _row.level == 0 ? 0 : (_row.level - 1) * 15 + 1;
    _embeddedCellContainer.classes.add('treeviewcell-content');
    _embeddedCellContainer.style.left = '${margin + 20}px';
    int offsetX = margin + 20;
    _embeddedCellContainer.style.width = 'calc(100% - ${offsetX}px)';
    if (draggable) {
      _embeddedCellContainer.setAttribute('draggable', 'true');
    }
    _embeddedCellContainer.children.add(_embeddedCell.element);

    _dragOverlay = _element.querySelector('.treeviewcell-dragoverlay');
    _dragOverlay.style.left = '${margin + 15}px';
    offsetX = margin + 20;
    _dragOverlay.style.width = 'calc(100% - ${offsetX}px)';

    // Adds an arrow in front the cell.
    _arrow = _element.querySelector('.treeviewcell-disclosure');
    _arrow.style.left = '${margin + 5}px';
    _applyExpanded(_row.expanded);
    if (!hasChildren) {
      _arrow.style.visibility = 'hidden';
    }

    // Click handler for the arrow: toggle expanded state of the node.
    _arrow.onClick.listen((event) {
      event.stopPropagation();
      toggleExpanded();
    });

    _embeddedCellContainer.onDragStart.listen((event) {
      _treeView.privateCheckSelectNode(_row.nodeUid);
      // Dragged data.
      Map dragInfo = {'uuid': _treeView.uuid, 'selection': _treeView.selection};
      event.dataTransfer.setData('application/x-spark-treeview',
          JSON.encode(dragInfo));
      TreeViewDragImage imageInfo = _treeView.privateDragImage(event);
      if (imageInfo != null) {
        event.dataTransfer.setDragImage(imageInfo.image,
            imageInfo.location.x, imageInfo.location.y);
      }
    });

    _animating = false;
    treeViewCellExpando[_element] = this;
  }

  ListViewCell get embeddedCell => _embeddedCell;

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

  String get nodeUid => _row.nodeUid;

  void toggleExpanded() {
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
    _arrow.onTransitionEnd.listen((event) {
      _animating = false;
      _treeView.setNodeExpanded(_row.nodeUid, !_row.expanded);
    });
  }

  // Change visual appearance of the disclosure arrow, depending whether the
  // node is expanded or not.
  void _applyExpanded(bool expanded) {
    if (expanded) {
      _arrow.classes.add('treeviewcell-disclosed');
    } else {
      _arrow.classes.remove('treeviewcell-disclosed');
    }
  }

  bool get acceptDrop => _embeddedCell.acceptDrop;
  set acceptDrop(bool value) => _embeddedCell.acceptDrop = value;
}

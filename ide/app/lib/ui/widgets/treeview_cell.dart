// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.widgets.treeview_cell;

import 'dart:html';
import 'dart:async';
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
  bool get isAnimating => _animating;
  
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
    Element templateClone = template.clone(true);
    _element = templateClone.querySelector('.treeviewcell');

    _embeddedCellContainer = _element.querySelector('.treeviewcell-content');
    int margin = (_row.level * 10);
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
    _arrow.style.left = '${margin + 4}px';
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
      _treeView.privateCheckSelectNode(_row.nodeUID);
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

  void toggleExpanded() => 
	  _treeView.toggleNodeExpanded(_row.nodeUID, animated: true);
  
  /**
   * Animate the disclosure arrow to reflect the change in expanded state
   * of the cell.
   */
  void animateDisclosure() {
    //FIXME: The following doesn't work -- I'm not sure why.
    //       There's no reason I can see why it shouldn't
    //       Apply expanded seems to complete *after* setting the transition
    //       because if you place a breakpoint at the line indicated, it works.
    //       Strange!
    
//    _animating = true;
//    _applyExpanded(!row.expanded);
//    _arrow.style.transition = '-webkit-transition 250ms'; //breakpoint here.
//    StreamSubscription subscription;
//    subscription = _arrow.onTransitionEnd.listen((event) {
//      _arrow.style.transition = 'none';
//      _animating = false;
//      subscription.cancel();
//    });
    
    _animating = true;
    StreamSubscription subscription;
    _arrow.style.transition = '-webkit-transform 0.01ms';
    subscription = _arrow.onTransitionEnd.listen((event) {
      print('Transition end');
      _animating = false;
      _arrow.style.transition = '-webkit-transform 250ms';
      subscription.cancel();
      subscription = _arrow.onTransitionEnd.listen((event) {
        _animating = false;
        subscription.cancel();
      });
      _applyExpanded(_row.expanded);
    });
    _applyExpanded(!_row.expanded);
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

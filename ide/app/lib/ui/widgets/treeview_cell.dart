// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.widgets.treeview_cell;

import 'dart:html';
import 'dart:async';

import 'listview_cell.dart';
import 'treeview.dart';
import 'treeview_row.dart';

class TreeViewCell implements ListViewCell {
  // HTML element of the view.
  Element _element;
  // cell returned by the delegate of the treeview.
  ListViewCell _embeddedCell;
  // Highlighted state of the node.
  bool _highlighted;
  TreeView _treeView;
  TreeViewRow _row;
  bool _animating;
  // Speed of animation in milliseconds when opening a node.
  static const ANIMATION_SPEED = 250;

  TreeViewCell(TreeView treeView, ListViewCell embeddedCell, TreeViewRow row,
               bool hasChildren) {
    _treeView = treeView;
    _row = row;
    _embeddedCell = embeddedCell;
    _element = new DivElement();
    _animating = false;

    int margin = (_row.level * 10);
    _embeddedCell.element.style.position = 'absolute';
    _embeddedCell.element.style.top = '0px';
    _embeddedCell.element.style.left = (margin + 15).toString() + 'px';
    int offsetX = margin + 20;
    _embeddedCell.element.style.width = 'calc(100% - ${offsetX}px)';
    _element.children.add(_embeddedCell.element);

    if (hasChildren) {
      // Adds an arrow in front the cell.
      DivElement arrow = new DivElement();
      arrow.style.width = '15px';
      arrow.style.height = '15px';
      arrow.style.position = 'absolute';
      arrow.style.top = '0px';
      arrow.style.textAlign = 'center';
      arrow.style.left = margin.toString() + 'px';
      arrow.style.transition = '-webkit-transform 250ms';
      arrow.appendHtml('&#9654;');
      if (_row.expanded) {
        arrow.style.transform = 'rotate(90deg)';
      }
      _element.children.add(arrow);

      // Click handler for the arrow: toggle expanded state of the node.
      arrow.onClick.listen((event) {
        event.stopPropagation();

        // Don't change the expanded state if it's already animating to change
        // the expanded state.
        if (_animating) {
          return;
        }

        // Change visual appearance.
        if (_row.expanded) {
          arrow.style.transform = 'rotate(0deg)';
        } else {
          arrow.style.transform = 'rotate(90deg)';
        }

        // Wait for animation to finished before effectively changing the
        // expanded state.
        _animating = true;
        new Timer(new Duration(milliseconds: ANIMATION_SPEED), () {
          _animating = false;
          treeView.setNodeExpanded(_row.nodeUID, !_row.expanded);
        });
      });
    }
  }

  Element get element => _element;

  set element(Element element) => _element = element;

  bool get highlighted => _highlighted;

  set highlighted(value) {
    _highlighted = value;
    _embeddedCell.highlighted = value;
  }
}

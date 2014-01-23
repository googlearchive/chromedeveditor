// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.widgets.treeview_delegate;

import 'dart:html';

import 'treeview.dart';
import 'listview_cell.dart';

/**
 * This class is the list of callbacks methods needed for [TreeView].
 */

abstract class TreeViewDelegate {
  /**
    * Returns the UID string for the n-th children of a node given by
    * UID (`nodeUID`). `nodeUID` is null for the root node.
    */
  String treeViewChild(TreeView view, String nodeUID, int childIndex);

  /**
   * Returns true if the node given by node UID has children.
   * It will help the `TreeView` shows a disclosure arrow when needed.
   */
  bool treeViewHasChildren(TreeView view, String nodeUID);

  /**
   * Returns the number of children of a given node.
   */
  int treeViewNumberOfChildren(TreeView view, String nodeUID);

  /**
   * Returns the visual representation of a given node.
   */
  ListViewCell treeViewCellForNode(TreeView view, String nodeUID);

  /**
   * Returns the height of the given node.
   */
  int treeViewHeightForNode(TreeView view, String nodeUID);

  /**
   * The implementation of this method will be run when the selection
   * has changed.
   */
  void treeViewSelectedChanged(TreeView view,
                               List<String> nodeUIDs);

  /**
   * The implementation of this method will be triggered when a node is
   * clicked.  Returning false will cancel further selection operations.
   */
  bool treeViewRowClicked(Event event, String uid);

  /**
   * This method will be called when the given node is double-clicked.
   */
  void treeViewDoubleClicked(TreeView view,
                             List<String> nodeUIDs,
                             Event event) {}

  /**
   * This method will be called when the user open the context menu on the
   * given node.
   */
  void treeViewContextMenu(TreeView view,
                           List<String> nodeUIDs,
                           String nodeUID,
                           Event event);

  /**
   * This method is called on dragenter.
   * Return 'copy', 'move', 'link' or 'none'.
   * It will adjust the visual of the mouse cursor when the item is
   * dragged over the treeview.
   */
  String treeViewDropEffect(TreeView view,
                            DataTransfer dataTransfer,
                            String nodeUID) => null;

  /**
   * This method is called when the dragged item is actually dropped on the
   * tree or on a specific node in the treeview.
   */
  void treeViewDrop(TreeView view, String nodeUID, DataTransfer dataTransfer) {}

  /**
   * This method is called when a selection of the TreeView is actually dropped
   * on the tree or on a specific node of the treeview.
   */
  void treeViewDropCells(TreeView view,
                         List<String> nodesUIDs,
                         String targetNodeUID) {}

  /**
   * This method is called when the user dropped nodes from the treeview to one
   * of its node.
   * This method is called with a null destinationNodeUID if the nodes are not
   * dropped on a specific node.
   */
  bool treeViewAllowsDropCells(TreeView view,
                               List<String> nodesUIDs,
                               String destinationNodeUID) {}

  /**
   * This method is called when the user dropped an external item to one of its
   * node.
   * This method is called with a null destinationNodeUID if the external item
   * is not not dropped on a specific node.
   */
  bool treeViewAllowsDrop(TreeView view,
                          DataTransfer dataTransfer,
                          String destinationNodeUID) {}

  /**
   * This method provides a drag image and location for the given nodes UIDs.
   */
  TreeViewDragImage treeViewDragImage(TreeView view,
                                      List<String> nodesUIDs,
                                      MouseEvent event) => null;

  /**
   * This method is called whenever it's a good time to save the state of the
   * tree.
   */
  void treeViewSaveExpandedState(TreeView view) {}
}

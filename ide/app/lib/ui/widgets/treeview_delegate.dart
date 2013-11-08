// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.widgets.treeview_delegate;

import 'treeview.dart';
import 'listview_delegate.dart';
import 'listview_cell.dart';

/**
 * This class is the list of callbacks methods needed for `TreeView`.
 */

abstract class TreeViewDelegate extends ListViewDelegate {
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
   * The implementation of this method will be run when the given node is
   * clicked.
   */
  void treeViewSelectedChanged(TreeView view, List<String> nodeUIDs);

  /**
   * The implementation of this method will be run when the give node is
   * double-clicked.
   */
  void treeViewDoubleClicked(TreeView view, List<String> nodeUIDs);
}

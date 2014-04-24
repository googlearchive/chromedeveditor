// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.tree_view_model;

import '../common/spark_widget.dart';

abstract class SparkTreeViewModel {
  Iterable<String> getChildrenNames(String nodePath);

  String getInnerHtml(String nodePath);

  // TODO(ussuri): All these could be replaced by custom events fired from
  // [SparkTreeNodeView].

  void select(String nodePath);

  /// Should return a list of [SparkMenuItem]s and [SparkMenuSeparator]s.
  List<SparkWidget> getContextMenu(String nodePath);

  /// The returned bool indicates whether the tree-node has changed as a result of
  /// the action, and thus needs to be redrawn.
  bool applyContextMenuAction(String nodePath, String actionId);

  void startDragging(List<String> nodePaths);

  void drop(List<String> nodePaths, String targetNodePath);
}

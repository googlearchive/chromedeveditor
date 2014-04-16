// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.tree_view_model;

import '../common/spark_widget.dart';

abstract class SparkTreeViewModel {
  Iterable<String> getChildrenIds(String path);

  String getNodeInnerHtml(String path);

  // TODO(ussuri): The following two are possibly not needed and should be
  // replaced by firing a 'context-menu-requested' custom event from
  // [SparkTreeNodeView] and letting the client handle it.

  /// Should return a list of [SparkMenuItem]s and [SparkMenuSeparator]s.
  List<SparkWidget> getContextMenuActions(String path);

  /// The returned bool indicates whether the tree-node has changed as a result of
  /// the action, and thus needs to be redrawn.
  bool applyContextMenuAction(String path, String actionId);
}

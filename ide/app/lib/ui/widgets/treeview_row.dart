// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.widgets.treeview_row;

class TreeViewRow {
  // UID of the node.
  String nodeUID;
  // Expanded state of the node.
  bool expanded = false;
  // Indentation level of the node.
  int level = 0;

  TreeViewRow(this.nodeUID);
}

// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.tree_view_node;

import 'package:polymer/polymer.dart';

import '../../common/spark_widget.dart';
import '../spark_tree_view_model.dart';

@CustomTag('spark-tree-view-node')
class SparkTreeViewNode extends SparkWidget {
  @published SparkTreeViewModel treeModel;
  @published String name;
  @published String path;
  @published int level;
  @published bool expanded;

  @observable String selfHtml;
  @observable List<SparkTreeViewNode> childrenNames;

  /// Constructor.
  SparkTreeViewNode.created() : super.created();

  @override
  void enteredView() {
    super.enteredView();

    redraw();
  }

  /// If, after the initial draw, this particular node in [treeModel] changes,
  /// this method must be explicitly called to redraw the node
  /// (alternatively, the entire tree can be redrawn).
  // TODO(ussuri): Possibly can be redone by adding some kind of a flag to
  // [SparkTreeViewModel] (perhaps a List<String> of ids that have changed)
  // and attaching a PathObserver to it.
  void redraw() {
    selfHtml = treeModel.getNodeInnerHtml(path);
    childrenNames = expanded ? treeModel.getChildrenNames(path) : [];
  }
}

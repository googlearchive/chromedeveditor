// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This class implements the controller for search results.
 */
library spark.ui.search_view_controller;

import 'dart:async';
import 'dart:html' as html;

import 'package:spark_widgets/spark_status/spark_status.dart';
import 'package:spark_widgets/common/spark_widget.dart';

import 'widgets/file_item_cell.dart';
import 'widgets/listview_cell.dart';
import 'widgets/treeview.dart';
import 'widgets/treeview_delegate.dart';
import '../navigation.dart';
import '../workspace.dart';
import '../workspace_search.dart';

class SearchResultLineCell implements ListViewCell {
  html.Element element = null;
  bool acceptDrop = false;
  bool highlighted = false;

  SearchResultLineCell(WorkspaceSearchResultLine line) {
    element = new html.DivElement();
    element.classes.add('search-result-line');
    // TODO: the matching term should be highlighted.
    // TODO: ellipsis should be added on the left in case the matching term is
    // is further on the right.
    element.text = '${line.lineNumber}: ${line.line}';
  }
}

class SearchMaxResultsCell implements ListViewCell {
  html.Element element = null;
  bool acceptDrop = false;
  bool highlighted = false;

  SearchMaxResultsCell() {
    element = new html.DivElement();
    element.classes.add('search-max-results');
    element.text = 'Showing only the first 1,000 matches';
  }
}

abstract class SearchViewControllerDelegate {
  void searchViewControllerNavigate(SearchViewController controller,
      NavigationLocation location);
}

class SearchViewController implements TreeViewDelegate, WorkspaceSearchDelegate {
  static final String reachedMaxResultsCellUid = "reachedMaxResults";
  TreeView _treeView;
  // Workspace that references all the resources.
  final Workspace _workspace;
  WorkspaceSearch _search;
  bool _searching = false;
  bool _reachedMaxResults = false;
  List<WorkspaceSearchResultItem> _items = [];
  Map<String, WorkspaceSearchResultItem> _filesMap = {};
  Map<String, WorkspaceSearchResultLine> _linesMap = {};
  Timer _updateTimer;
  SparkStatus _statusComponent;
  DateTime _lastUpdateTime;
  SearchViewControllerDelegate delegate;
  bool visibility = false;

  SearchViewController(this._workspace,
                  html.Element searchViewArea) {
    _treeView = new TreeView(searchViewArea, this);
    SparkWidget ui = html.querySelector('#topUi');
    _statusComponent = ui.getShadowDomElement('#sparkStatus');
  }

  bool performFilter(String filterString) {
    if (_search != null) {
      _statusComponent.spinning = false;
      _statusComponent.progressMessage = null;
      _search.cancel();
      _search = null;
      _searching = false;
    }

    if (filterString != null) {
      _searching = true;
      _search = new WorkspaceSearch();
      _search.delegate = this;
      _search.performSearch(_workspace, filterString).catchError((_) {});
      _statusComponent.spinning = true;
      _statusComponent.progressMessage = 'Searching...';
      _setShowSearchResultPlaceholder(false);
    } else {
      _setShowSearchResultPlaceholder(true);
    }

    _updateResultsNow();

    return true;
  }

  void workspaceSearchFile(WorkspaceSearch search, File file) {
    if (_lastUpdateTime != null) {
      if (new DateTime.now().difference(_lastUpdateTime).inMilliseconds < 500) {
        return;
      }
    }

    _statusComponent.progressMessage = 'Searching ${file.path}';
    _lastUpdateTime = new DateTime.now();
  }

  void workspaceSearchUpdated(WorkspaceSearch search) {
    _updateResults();
  }

  void workspaceSearchFinished(WorkspaceSearch search) {
    _searching = false;
    _statusComponent.progressMessage = null;
    _statusComponent.spinning = false;
    _statusComponent.temporaryMessage = 'Search finished';
    _updateResultsNow();
  }

  void _updateResults() {
    if (_updateTimer != null) return;

    _updateTimer = new Timer(new Duration(milliseconds: 1000), () {
      _updateTimer = null;
      _updateResultsNow();
    });
  }

  void _updateResultsNow() {
    if (_updateTimer != null) {
      _updateTimer.cancel();
      _updateTimer = null;
    }
    if (_search != null) {
      _reachedMaxResults = _search.reachedMaxResults;
      _items = new List.from(_search.results);
    } else {
      _reachedMaxResults = false;
      _items = [];
    }
    _filesMap = {};
    _linesMap = {};
    List<String> uuids = [];
    _items.forEach((WorkspaceSearchResultItem item) {
      uuids.add(item.file.uuid);
      _filesMap[item.file.uuid] = item;
      item.lines.forEach((WorkspaceSearchResultLine lineInfo) {
        _linesMap['${item.file.uuid}:${lineInfo.lineNumber}'] = lineInfo;
      });
    });
    _treeView.restoreExpandedState(uuids);

    _setShowNoResults(_items.length == 0 && _search != null);
  }

  void _setShowNoResults(bool visible) {
    html.querySelector('#searchViewNoResult').classes.toggle('hidden',
        !visible || !visibility);
  }

  void _setShowSearchResultPlaceholder(bool visible) {
    html.querySelector('#searchViewPlaceholder').classes.toggle('hidden',
        !visible || !visibility);
  }

  // Implementation of TreeViewDelegate interface.

  String treeViewChild(TreeView view, String nodeUid, int childIndex) {
    if (nodeUid == null) {
      if (childIndex < _items.length) {
        WorkspaceSearchResultItem item = _items[childIndex];
        return item.file.uuid;
      } else {
        return reachedMaxResultsCellUid;
      }
    } else if (_filesMap[nodeUid] != null) {
      WorkspaceSearchResultItem item = _filesMap[nodeUid];
      WorkspaceSearchResultLine lineInfo = item.lines[childIndex];
      return '${item.file.uuid}:${lineInfo.lineNumber}';
    } else {
      return null;
    }
  }

  bool treeViewHasChildren(TreeView view, String nodeUid) {
    if (nodeUid == null) {
      return _items.length > 0;
    } else if (_filesMap[nodeUid] != null) {
      return true;
    } else {
      return false;
    }
  }

  int treeViewNumberOfChildren(TreeView view, String nodeUid) {
    if (nodeUid == null) {
      return _reachedMaxResults ? _items.length + 1 : _items.length;
    } else if (_filesMap[nodeUid] != null) {
      WorkspaceSearchResultItem item = _filesMap[nodeUid];
      return item.lines.length;
    } else {
      return 0;
    }
  }

  ListViewCell treeViewCellForNode(TreeView view, String nodeUid) {
    if (_filesMap[nodeUid] != null) {
      WorkspaceSearchResultItem item = _filesMap[nodeUid];
      return new FileItemCell(item.file);
    } else if (_linesMap[nodeUid] != null) {
      WorkspaceSearchResultLine lineInfo = _linesMap[nodeUid];
      return new SearchResultLineCell(lineInfo);
    } else if (nodeUid == reachedMaxResultsCellUid) {
      return new SearchMaxResultsCell();
    } else {
      return null;
    }
  }

  int treeViewHeightForNode(TreeView view, String nodeUid) {
    if (_filesMap[nodeUid] != null) {
      return FileItemCell.height;
    } else if (nodeUid == reachedMaxResultsCellUid) {
      return 50;
    } else {
      return 18;
    }
  }

  void treeViewSelectedChanged(TreeView view,
                               List<String> nodeUids) {
    if (nodeUids.length == 0) return;
    String nodeUid = nodeUids.first;
    if (_filesMap[nodeUid] != null) {
      WorkspaceSearchResultItem item = _filesMap[nodeUid];
      NavigationLocation location = new NavigationLocation(item.file);
      delegate.searchViewControllerNavigate(this, location);
    } else if (_linesMap[nodeUid] != null) {
      WorkspaceSearchResultLine lineInfo = _linesMap[nodeUid];
      Span selection = new Span(lineInfo.position, lineInfo.length);
      NavigationLocation location = new NavigationLocation(lineInfo.file, selection);
      delegate.searchViewControllerNavigate(this, location);
    }
  }

  bool treeViewRowClicked(html.Event event, String uid) => uid != reachedMaxResultsCellUid;

  void treeViewDoubleClicked(TreeView view,
                             List<String> nodeUids,
                             html.Event event) {}
  void treeViewContextMenu(TreeView view,
                           List<String> nodeUids,
                           String nodeUid,
                           html.Event event) {}
  String treeViewDropEffect(TreeView view,
                            html.DataTransfer dataTransfer,
                            String nodeUid) => null;
  String treeViewDropCellsEffect(TreeView view,
                                 List<String> nodesUIDs,
                                 String nodeUid) => null;
  void treeViewDrop(TreeView view, String nodeUid, html.DataTransfer dataTransfer) {}
  void treeViewDropCells(TreeView view,
                         List<String> nodesUIDs,
                         String targetNodeUID) {}
  bool treeViewAllowsDropCells(TreeView view,
                               List<String> nodesUIDs,
                               String destinationNodeUID) => false;
  bool treeViewAllowsDrop(TreeView view,
                          html.DataTransfer dataTransfer,
                          String destinationNodeUID) => false;
  TreeViewDragImage treeViewDragImage(TreeView view,
                                      List<String> nodesUIDs,
                                      html.MouseEvent event) => null;
  void treeViewSaveExpandedState(TreeView view) {}
  html.Element treeViewSeparatorForNode(TreeView view, String nodeUID) => null;
  int treeViewSeparatorHeightForNode(TreeView view, String nodeUID) => 1;
  int treeViewDisclosurePositionForNode(TreeView view, String nodeUID) => 2;
}

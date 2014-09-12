// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.workspace_search;

import 'utils.dart';
import 'workspace.dart';

import 'dart:async';

class WorkspaceSearchResultLine {
  final File file;
  final String line;
  final int lineNumber;
  final int position;
  final int length;

  WorkspaceSearchResultLine(this.file, this.line, this.lineNumber,
      this.position, this.length);
}

class WorkspaceSearchResultItem {
  final File file;
  final List<WorkspaceSearchResultLine> lines;

  WorkspaceSearchResultItem(this.file, this.lines);
}

abstract class WorkspaceSearchDelegate {
  void workspaceSearchFile(WorkspaceSearch search, File file) {}
  void workspaceSearchUpdated(WorkspaceSearch search) {}
  void workspaceSearchFinished(WorkspaceSearch search) {}
}

class WorkspaceSearch {
  static final int maxResultsCount = 1000;
  List<WorkspaceSearchResultItem> results;
  WorkspaceSearchDelegate delegate;
  bool _cancelled = false;
  bool _reachedMaxResults = false;
  int _matchesCount = 0;

  WorkspaceSearch() {
    results = [];
  }

  bool get reachedMaxResults => _reachedMaxResults;

  Future performSearch(Resource res, String token) {
    return _performSearchOnResource(res, token.toLowerCase()).then((_) {
      if (!_cancelled) {
        delegate.workspaceSearchFinished(this);
      }
    });
  }

  void cancel() {
    _cancelled = true;
  }

  Future _performSearchOnResource(Resource res, String token) {
    if (res.isScmPrivate() || res.isDerived()) {
      return new Future.value();
    }

    if (res is Container) {
      return _performSearchOnContainer(res, token);
    } else {
      return _performSearchOnFile(res as File, token);
    }
  }

  Future _performSearchOnFile(File file, String token) {
    if (!_cancelled) {
      delegate.workspaceSearchFile(this, file);
    }

    if (_cancelled) {
      return new Future.error('interrupted');
    }

    if (isImageFilename(file.name)) {
      return new Future.value();
    }

    return file.getContents().then((String content) {
      // If the file contains control characters, it's likely that it's a binary
      // file, then we don't search text in it.
      if (content.contains(new RegExp(r'[\000-\010]|[\013-\014]|[\016-\037]'))) {
        return new Future.value();
      }

      int currentIndex = 0;
      int lineNumber = 1;
      List<WorkspaceSearchResultLine> matches = [];
      while (currentIndex < content.length) {
        int nextIndex = content.indexOf('\n', currentIndex);
        if (nextIndex == -1) {
          nextIndex = content.length;
        }

        String line = content.substring(currentIndex, nextIndex);
        String lowerCaseString = line.toLowerCase();
        int tokenPosition = lowerCaseString.indexOf(token);
        if (tokenPosition != -1) {
          matches.add(new WorkspaceSearchResultLine(file, line, lineNumber,
              currentIndex + tokenPosition, token.length));
          _matchesCount++;
          if (_matchesCount >= maxResultsCount) {
            _reachedMaxResults = true;
            delegate.workspaceSearchFinished(this);
            return new Future.error('reachedMaxResults');
          }
        }
        currentIndex = nextIndex + 1;
        lineNumber++;
      }
      if (matches.length > 0) {
        _addResult(file, matches);
      }
    });
  }

  Future _performSearchOnContainer(Container container, String token) {
    return Future.forEach(container.getChildren(), (Resource res) {
      return _performSearchOnResource(res, token);
    });
  }

  void _addResult(File file, List<WorkspaceSearchResultLine> lines) {
    WorkspaceSearchResultItem item =
        new WorkspaceSearchResultItem(file, lines);
    results.add(item);
    if (!_cancelled) {
      delegate.workspaceSearchUpdated(this);
    }
  }
}

// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.workspace_search;

import 'editors.dart';
import 'utils.dart';
import 'workspace.dart';

import 'dart:async';

class WorkspaceSearchResultLine {
  final ContentProvider contentProvider;
  final String line;
  final int lineNumber;
  final int position;
  final int length;

  WorkspaceSearchResultLine(this.contentProvider, this.line, this.lineNumber,
      this.position, this.length);
}

class WorkspaceSearchResultItem {
  final ContentProvider contentProvider;
  final List<WorkspaceSearchResultLine> lines;

  WorkspaceSearchResultItem(this.contentProvider, this.lines);
}

abstract class WorkspaceSearchDelegate {
  void workspaceSearchFile(WorkspaceSearch search, ContentProvider contentProvider) {}
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

  void cancel() {
    _cancelled = true;
  }

  Future searchContentProvider(ContentProvider contentProvider, String token) {
    token = token.toLowerCase();

    if (contentProvider is FileContentProvider &&
        (contentProvider.file.isScmPrivate() || contentProvider.file.isDerived())) {
      return new Future.value();
    }

    if (!_cancelled) {
      delegate.workspaceSearchFile(this, contentProvider);
    }

    if (_cancelled) {
      return new Future.error('interrupted');
    }

    if (isImageFilename(contentProvider.name)) {
      return new Future.value().then((_) => delegate.workspaceSearchFinished(this));
    }

    return contentProvider.read().then((String content) {
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
          matches.add(new WorkspaceSearchResultLine(contentProvider, line,
              lineNumber, currentIndex + tokenPosition, token.length));
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
        _addResult(contentProvider, matches);
      }
    }).then((_) => delegate.workspaceSearchFinished(this));
  }

  Future searchContainer(Container container, String token) {
    token = token.toLowerCase();

    return Future.forEach(container.getChildren(), (Resource res) {
      if (res is Container) {
        return searchContainer(res, token);
      } else {
        ContentProvider contentProvider = new FileContentProvider(res);
        return searchContentProvider(contentProvider, token);
      }
    });
  }

  void _addResult(ContentProvider contentProvider, List<WorkspaceSearchResultLine> lines) {
    WorkspaceSearchResultItem item =
        new WorkspaceSearchResultItem(contentProvider, lines);
    results.add(item);
    if (!_cancelled) {
      delegate.workspaceSearchUpdated(this);
    }
  }
}

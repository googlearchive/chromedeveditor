// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.fetch;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

import '../constants.dart';
import '../exception.dart';
import '../file_operations.dart';
import '../http_fetcher.dart';
import '../object.dart';
import '../objectstore.dart';
import '../options.dart';
import '../pack.dart';
import '../upload_pack_parser.dart';
import '../utils.dart';
import 'status.dart';

/**
 * A git fetch command implementation.
 *
 * TODO(grv): Add unittests.
*/

class Fetch {

  GitOptions options;
  chrome.DirectoryEntry root;
  ObjectStore store;
  Function progress;
  String branchName;

  Fetch(this.options) {
    root = options.root;
    store = options.store;
    progress = options.progressCallback;
    branchName = options.branchName == null ? 'master' : options.branchName;

    if (progress == null) progress = nopFunction;
  }

   Future fetch() {
    String username = options.username;
    String password = options.password;

    Function fetchProgress;
    // TODO(grv): Add fetchProgress chunker.

    return Status.isWorkingTreeClean(store).then((_) {
      String url = store.config.url;

      HttpFetcher fetcher = new HttpFetcher(
          store, 'origin', url, username, password);

      // get current branch.
      String headRefName = 'refs/heads/' + branchName;
      return _updateAndGetRemoteRefs(store, fetcher).then((List<GitRef> refs) {
        GitRef branchRef = refs.firstWhere(
            (GitRef ref) => ref.name == headRefName, orElse: () => null);

        if (branchRef == null) {
          return new Future.error(
              new GitException(GitErrorConstants.GIT_REMOTE_BRANCH_NOT_FOUND));
        }

        // See if we know about the branch's head commit. If so we're up to
        // date. If not, request from remote.
        return store.getRemoteHeadForRef(headRefName).then((sha) {
          if (sha != branchRef.sha) {
            return _handleFetch(branchRef, branchRef, fetcher);
          }
          return store.getCommitGraph([sha]).then((CommitGraph graph) {
            if (graph.commits.isNotEmpty) {
              return new Future.error(
                  new GitException(GitErrorConstants.GIT_FETCH_UP_TO_DATE));
            } else {
              return _handleFetch(branchRef, branchRef, fetcher);
            }
          });
        });
      });
    });
  }

  static Future<List<GitRef>> updateAndGetRemoteRefs(GitOptions options) {
    ObjectStore store = options.store;
    HttpFetcher fetcher = new HttpFetcher(options.store, 'origin',
        store.config.url, options.username, options.password);
    return _updateAndGetRemoteRefs(store, fetcher);
  }

  static Future<List<GitRef>> _updateAndGetRemoteRefs(
      ObjectStore store, HttpFetcher fetcher) {
    return fetcher.fetchUploadRefs().then((List<GitRef> refs) {
      return store.writeRemoteRefs(refs).then((_) => refs);
    });
  }

  Future _createAndUpdateRef(GitRef branchRef, GitRef wantRef) {
    String path = GIT_REFS_REMOTES_ORIGIN_PATH + branchRef.name.split('/').last;
    return FileOps.createFileWithContent(root, path, branchRef.sha, "Text");
  }

  Future _handleFetch(GitRef branchRef, GitRef wantRef, HttpFetcher fetcher) {

    // Get the sha from the ref name.
    return store.getRemoteHeadForRef(branchRef.name).then((String sha) {
      branchRef.localHead = sha;
      return store.getCommitGraph([sha], 32).then((CommitGraph graph) {
        List<String> haveRefs = graph.commits.map((CommitObject commit)
            => commit.treeSha).toList();
        if (haveRefs.isEmpty) {
          haveRefs = null;
        }

        Future<PackParseResult> fetcherFuture = fetcher.fetchRef(
            [wantRef.sha],
            haveRefs,
            store.config.shallow,
            options.depth,
            graph.nextLevel,
            null,
            progress);
        return fetcherFuture.then((result) {
          return Pack.createPackFiles(store, result).then((_) {
            return _createAndUpdateRef(branchRef, wantRef);
          });
        });
      });
    });
  }
}

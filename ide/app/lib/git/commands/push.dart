// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.push;

import 'dart:async';

import '../config.dart';
import '../http_fetcher.dart';
import '../objectstore.dart';
import '../options.dart';
import '../pack.dart';
import '../utils.dart';

/**
 * This class implements the git push command.
 */
class Push {

  static Future push(GitOptions options) {
    ObjectStore store = options.store;
    String username = options.username;
    String password = options.password;

    Function remotePushProgress;

    if (options.progressCallback != null) {
      // TODO add progress chunker.
    } else {
      remotePushProgress = nopFunction;
    }

    Config config = store.config;
    String url = config.url != null ? config.url : options.repoUrl;

    if (url == null) {
      // TODO throw push_no_remote.
      return null;
    }

    HttpFetcher fetcher = new HttpFetcher(store, 'origin', url, username,
        password);
    return fetcher.fetchReceiveRefs().then((List<GitRef> refs) {
      return store.getCommitsForPush(refs, config.remoteHeads).then(
          (commits) {
        if (commits == null) {
          // no commits to push.
          // TODO(grv) : throw Custom exceptions.
          throw "no commits to push.";
        }
        PackBuilder builder = new PackBuilder(commits.commits, store);
        return builder.build().then((packData) {
          return fetcher.pushRefs([commits.ref], packData,
              remotePushProgress).then((_) {
            config.remoteHeads[commits.ref.name] = commits.ref.head;
            config.url = url;
            return store.writeConfig();
          });
        });
      });
    });
  }
}

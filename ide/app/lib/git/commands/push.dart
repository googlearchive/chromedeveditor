// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.push;

import 'dart:async';

import '../git.dart';
import '../http_fetcher.dart';
import '../objectstore.dart';
import '../pack.dart';
import '../utils.dart';

class Push {

  Future push(GitOptions options) {
    ObjectStore store = options.store;
    String username = options.username;
    String password = options.password;

    Function remotePushProgress;

    if (options.progressCallback != null) {
      // TODO add progress chunker.
    } else {
      remotePushProgress = nopFunction;
    }

    return store.getConfig().then((GitConfig config) {
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
              GitRef ref;
          return Pack.buildPack(commits, store).then((packData) {
            return fetcher.pushRefs([ref], packData, remotePushProgress).then(
                (_) {
                  config.remoteHeads[ref.name] = ref.head;
                  config.url = url;
                  return store.setConfig(config);
            });
          });
        });
      });
    });
  }
}
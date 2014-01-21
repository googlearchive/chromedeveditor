// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.push;

import 'dart:async';

import '../http_fetcher.dart';
import '../objectstore.dart';
import '../options.dart';
import '../pack.dart';
import '../utils.dart';

import 'dart:html';

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

    return store.getConfig().then((GitConfig config) {
      String url = config.url != null ? config.url : options.repoUrl;

      url = 'https://github.com/gaurave/test-app.git';
      if (url == null) {
        // TODO throw push_no_remote.
        return null;
      }

      HttpFetcher fetcher = new HttpFetcher(store, 'origin', url, username,
          password);
      return fetcher.fetchReceiveRefs().then((List<GitRef> refs) {
        print('fetched refs');
        return store.getCommitsForPush(refs, config.remoteHeads).then(
            (commits) {
              GitRef ref;
              window.console.log(commits);
              return new Future.value();
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

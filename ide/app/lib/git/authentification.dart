// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.authentification;

import 'dart:async';
import 'dart:html';

import 'exception.dart';

/**
 * This class exposes a git authentification service. Currently only github
 * authentication is supported.
 *
 * TODO(grv): Add 2-step authentifaction support.
 * TODO(grv) : Add unittests.
 */
class GitAuthentification {
  static final url = "https://api.github.com";

  static Future<bool> verifyGithubCredentials(String username, String password) {
    Completer completer = new Completer();
    HttpRequest xhr = new HttpRequest();
    xhr.open("GET", url, async: true , user: username , password: password);

    xhr.onLoad.listen((event) {
      if (xhr.readyState == 4) {
        if (xhr.status == 200) {
          return completer.complete(true);
        } else {
          completer.completeError(new GitException(
              GitErrorConstants.GIT_INVALID_USERNAME_OR_PASSWORD));
        }
      }
    });
    xhr.send();
    return completer.future;
  }
}


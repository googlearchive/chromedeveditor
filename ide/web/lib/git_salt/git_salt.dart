// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.


library spark.gitsalt;

import 'dart:js' as js;

/**
 * A javascript interface for git-nacl library.
 */
class GitSalt {
  // Javascript object to wrap.
  static js.JsObject jsGitSalt = js.context['GitSalt'];

  /**
   * Load the companion NaCl plugin.  This call isn't strictly required as
   * we'll load the plugin the first time its needed.  You may call it
   * separately if you want to pay the loading cost up front.
   */
  static void loadPlugin() {
    jsGitSalt.callMethod('loadPlugin', ['git_salt', 'lib/git_salt']);
  }
}

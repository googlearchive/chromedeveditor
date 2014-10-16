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
  static js.JsObject jsGitSalt = js.context['gitSalt'];
  static int messageId = 1;

  static String genMessageId() {
    messageId++;
    return messageId.toString();
  }

  /**
   * Load the companion NaCl plugin.  This call isn't strictly required as
   * we'll load the plugin the first time its needed.  You may call it
   * separately if you want to pay the loading cost up front.
   */
  static void loadPlugin() {
    jsGitSalt.callMethod('loadPlugin', ['git_salt', 'lib/git_salt']);
  }

  static void cloneCb(var result) {
    //TODO(grv): to be implemented.
    print(result);
    print("clone successful");
  }

  static void clone(entry, String url) {

    var arg = new js.JsObject.jsify({
      "entry": entry.toJs(),
      "filesystem": entry.filesystem.toJs(),
      "fullPath": entry.fullPath,
      "url": url
    });

    var message = new js.JsObject.jsify({
      "subject" : genMessageId(),
      "name" : "clone",
      "arg": arg
    });

    jsGitSalt.callMethod('postMessage', [message, cloneCb]);
  }
}

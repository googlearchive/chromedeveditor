// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.


library spark.gitsalt;

import 'dart:async';
import 'dart:js' as js;

/**
 * GitSalt Factory class which contains the active git-salt instances.
 * The instances are indexed by the root directotry path of the git
 * repository.
 */
class GitSaltFactory {

  static Map<String, Gitsalt> _instances = {};

  static GitSalt getInstance(String path) {
    if (getInstanceForPath(path) == null) {
      GitSalt gitSalt = new GitSalt(path);
      _instances[path] = gitSalt;
    }
    return _instances[path];
  }
  static GitSalt getInstanceForPath(String path) => _instances[path];
}

/**
 * A javascript interface for git-nacl library.
 */
class GitSalt {
  js.JsObject _jsGitSalt;
  int messageId = 1;
  String url;
  Completer _completer = null;

  GitSalt(String path) {
    _jsGitSalt = new js.JsObject(js.context['GitSalt']);
    loadPlugin(path);
  }

  String genMessageId() {
    messageId++;
    return messageId.toString();
  }

  /**
   * Load the companion NaCl plugin.
   */
  void loadPlugin(path) {
    _jsGitSalt.callMethod('loadPlugin', ['git_salt', 'lib/git_salt', path]);
  }

  void cloneCb(var result) {
    //TODO(grv): to be implemented.
    print("clone successful");
    _completer.complete();
    _completer = null;
  }

  bool isActive() {
    return (_completer != null)
  }

  Future load(entry) {
    return clone(entry);
  }

  Future clone(entry, String url) {
    if (isActive) {
      return new Future.error("Another git operation in progress.");
    }

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

    _completer = new Completer();
    const delay = const Duration(milliseconds:1000);
    //TODO(grv) : implement callback completion for loadPlugin.
     new Timer(delay, () {
      _jsGitSalt.callMethod('postMessage', [message, cloneCb]);
     });
    return _completer.future;
  }

  void commitCb(var result) {
    //TODO(grv): to be implemented.
    print("commit successful");
  }

  void commit(entry, String url) {

    var arg = new js.JsObject.jsify({
      "entry": entry.toJs(),
      "filesystem": entry.filesystem.toJs(),
      "fullPath": entry.fullPath,
      "url": url
    });

    var message = new js.JsObject.jsify({
      "subject" : genMessageId(),
      "name" : "commit",
      "arg": arg
    });

    _jsGitSalt.callMethod('postMessage', [message, commitCb]);
  }
}

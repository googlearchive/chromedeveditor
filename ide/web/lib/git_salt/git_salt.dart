// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.


library spark.gitsalt;

import 'package:chrome/chrome_app.dart' as chrome;

import 'dart:async';
import 'dart:js' as js;

import 'constants.dart';

/**
 * GitSalt Factory class which contains the active git-salt instances.
 * The instances are indexed by the root directotry path of the git
 * repository.
 */
class GitSaltFactory {

  static Map<String, GitSalt> _instances = {};

  static GitSalt getInstance(String path) {
    if (getInstanceForPath(path) == null) {
      GitSalt gitSalt = new GitSalt();
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
  chrome.DirectoryEntry root;
  Completer _completer = null;

  GitSalt() {
    _jsGitSalt = new js.JsObject(js.context['GitSalt']);
  }

  String genMessageId() {
    messageId++;
    return messageId.toString();
  }

  void loadCb() {
    _completer.complete();
    _completer = null;
  }

  Future load(entry) {
    return clone(entry, "");
  }

  /**
   * Load the companion NaCl plugin.
   */
  Future loadPlugin() {
    _completer = new Completer();
    _jsGitSalt.callMethod('loadPlugin', ['git_salt', 'lib/git_salt', loadCb]);
    return _completer.future;
  }

  void cloneCb(var result) {
    //TODO(grv): to be implemented.
    print(result["message"]);
    _completer.complete();
    _completer = null;
  }

  bool get isActive => _completer != null;

  Future clone(entry, String url) {

    root = entry;

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

    _jsGitSalt.callMethod('postMessage', [message, cloneCb]);
    _completer = new Completer();
    return _completer.future;
  }

  Future init(entry) {

    root = entry;

    var arg = new js.JsObject.jsify({
      "entry": entry.toJs(),
      "filesystem": entry.filesystem.toJs(),
      "fullPath": entry.fullPath,
      "url": ""
    });

    var message = new js.JsObject.jsify({
      "subject" : genMessageId(),
      "name" : "init",
      "arg": arg
    });

    Function cb = (result) {
      _completer.complete();
      _completer = null;
    };

    _jsGitSalt.callMethod('postMessage', [message, cb]);
    _completer = new Completer();
    return _completer.future;
  }

  Future commit(Map options) {

    var arg = new js.JsObject.jsify(options);

    var message = new js.JsObject.jsify({
      "subject" : genMessageId(),
      "name" : "commit",
      "arg": arg
    });

    Completer completer = new Completer();

    Function cb = (result) {
      completer.complete();
    };

    _jsGitSalt.callMethod('postMessage', [message, cb]);

    return completer.future;
  }

  Future<String> getCurrentBranch() {

    var message = new js.JsObject.jsify({
      "subject" : genMessageId(),
      "name" : "currentBranch",
      "arg": {}
    });

    Completer completer = new Completer();

    Function cb = (result) {
      completer.complete(result["branch"]);
    };

    _jsGitSalt.callMethod('postMessage', [message, cb]);

    return completer.future;
  }

  Future<List<String>> getLocalBranches() {
    return getBranches(GitSaltConstants.GIT_SALT_LOCAL_BRANCHES);
  }

  Future<List<String>> getRemoteBranches() {
    return getBranches(GitSaltConstants.GIT_SALT_REMOTE_BRANCHES);
  }

  Future<List<String>> getAllBranches() {
    return getBranches(GitSaltConstants.GIT_SALT_ALL_BRANCHES);
  }

  Future<List<String>> getBranches(int flags) {
    var arg = new js.JsObject.jsify({
      "flags" : flags
    });

    var message = new js.JsObject.jsify({
      "subject" : genMessageId(),
      "name" : "getBranches",
      "arg": arg
    });

    Completer completer = new Completer();

    Function cb = (result) {
      completer.complete(result["branches"].toList());
    };

    _jsGitSalt.callMethod('postMessage', [message, cb]);

    return completer.future;
  }

  Future add(List<chrome.Entry> entries) {

    entries = entries.map((entry) {
      if (entry.fullPath.length > root.fullPath.length) {
        return entry.fullPath.substring(root.fullPath.length + 1);
      } else {
        return entry.fullPath;
      }
    }).toList();

    var arg = new js.JsObject.jsify({
      "entries" : entries
    });

    var message = new js.JsObject.jsify({
      "subject" : genMessageId(),
      "name" : "add",
      "arg": arg
    });

    Completer completer = new Completer();

    Function cb = (result) {
      completer.complete();
    };

    _jsGitSalt.callMethod('postMessage', [message, cb]);

    return completer.future;
  }

  Future<Map<String, String>> status() {

    var message = new js.JsObject.jsify({
      "subject" : genMessageId(),
      "name" : "status",
      "arg": {}
    });

    Completer completer = new Completer();

    Function cb = (result) {
      js.JsObject statuses = result["statuses"];
      completer.complete(toDartMap(statuses));
    };

    _jsGitSalt.callMethod('postMessage', [message, cb]);

    return completer.future;
  }

  Future<List<String>> lsRemoteRefs(String url) {
    var arg = new js.JsObject.jsify({
      "url" : url
    });

    var message = new js.JsObject.jsify({
      "subject" : genMessageId(),
      "name" : "lsRemote",
      "arg": arg
    });

    Completer completer = new Completer();

    Function cb = (result) {
      completer.complete(result["refs"].toList());
    };

    _jsGitSalt.callMethod('postMessage', [message, cb]);

    return completer.future;
  }

  Map toDartMap(js.JsObject jsMap) {
    Map map = {};
    List<String> keys = js.context['Object'].callMethod('keys', [jsMap]);
    keys.forEach((key) {
      map[key] = jsMap[key];
    });
    return map;
  }
}

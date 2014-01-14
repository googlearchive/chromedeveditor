// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git;

import 'dart:async';
import 'dart:js' as js;

import 'package:chrome/src/files.dart' as chrome_files;
import 'package:chrome/chrome_app.dart' as chrome;

import 'options.dart';

/**
 * The class encapsulates the result returned by the git api.
 *
 * TODO(grv): break the result into different types returned by the apis.
 *
 */
class GitResult {
  var result;
  GitResult.fromData(this.result);
}

Future<chrome_files.CrFileSystem> getGitTestFileSystem() {
  Completer completer = new Completer();
  callback(fs) {
    completer.complete(new chrome_files.CrFileSystem.fromProxy(fs));
  }
  js.JsObject fs = js.context['GitApi'].callMethod('getFs', [callback]);
  return completer.future;
}

Future<chrome_files.CrFileSystem> getSyncFileSystem() {
  return chrome.syncFileSystem.requestFileSystem();
}

/**
 * This class encapsulates the various options that can be passed to the git
 * api. Currently the library is a wrapper on the existing git.js open source
 * library.
 *
 * Example usage:
 *     git.clone(gitOptions)
 *       .then(successCallback)
 *       .catchError((e) => errorCallback(e));
 *
 * TODO(grv): Add unittests for the apis.
 *
 */
class Git {
  static final js.JsObject _jsgit = js.context['GitApi'];

  static bool get available => _jsgit != null;

  Git() {
    print('Git Api initialized.');
  }

  Future<GitResult> clone(GitOptions options) {
    return _apiCall('clone', options);
  }

  Future<GitResult> push(GitOptions options) {
    return _apiCall('push', options);
  }

  Future<GitResult> pull(GitOptions options) {
    return _apiCall('pull', options);
  }

  Future<GitResult> commit(GitOptions options) {
    return _apiCall('commit', options);
  }

  Future<GitResult> branch(GitOptions options) {
    return _apiCall('branch', options);
  }

  Future<GitResult> checkout(GitOptions options) {
    return _apiCall('checkout', options);
  }

  Future<GitResult> checkForUncommittedChanges(GitOptions options) {
    return _apiCall('checkForUncommittedChanges', options);
  }

  Future<GitResult> getCurrentBranch(GitOptions options) {
    return _apiCall('getCurrentBranch', options);
  }

  Future<GitResult> getLocalBranches(GitOptions options) {
    return _apiCall('getLocalBranches', options);
  }

  Future<GitResult> getRemoteBranches(GitOptions options) {
    return _apiCall('getRemoteBranches', options);
  }

  Future<GitResult> _apiCall(String functionName, GitOptions options) {
    Completer<GitResult> completer = new Completer();

    var successCallback = (result) {
       completer.complete(new GitResult.fromData(result));
    };

    var errorCallback = (String message) {
      completer.completeError(message);
    };

    _jsgit.callMethod(functionName, [options.toJsMap(), successCallback, errorCallback]);

    return completer.future;
  }
}

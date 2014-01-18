// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.options;

import 'dart:html';
import 'dart:js' as js;

import 'objectstore.dart';

class GitOptions {

  // The directory entry where the git checkout resides.
  DirectoryEntry root;

  // Optional

  // Remote repository username
  String username;
  // Remote repository password
  String password;
  // Repository url
  String repoUrl;
  // Current branch name
  String branchName;

  // Git objectstore.
  ObjectStore store;

  String email;
  String commitMessage;
  String name;
  int depth;
  Function progressCallback;

  GitOptions({this.root, this.repoUrl, this.depth, this.store,
              this.branchName, this.commitMessage});

  js.JsObject toJsMap() {
    Map<String, dynamic> options = new Map<String, dynamic>();

    options['dir'] = this.root;
    options['username'] = this.username;
    options['password'] = this.password;
    options['branch'] = this.branchName;
    options['email'] = this.email;
    options['name'] = this.name;
    options['depth'] = this.depth;
    options['url'] = this.repoUrl;
    options['progress'] = this.progressCallback;
    options['commitMsg'] = this.commitMessage;
    return new js.JsObject.jsify(options);
  }

  // TODO(grv): Specialize the verification for different api methods.
  bool verify() {
    return this.root != null;
  }
}

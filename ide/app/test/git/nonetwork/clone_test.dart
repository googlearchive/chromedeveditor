// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git_no_network_clone_test;

import 'package:unittest/unittest.dart';

import 'dart:async';

import 'mock_http_request.dart';
import '../../files_mock.dart';
import '../../../lib/git/commands/clone.dart';
import '../../../lib/git/exception.dart';
import '../../../lib/git/http_fetcher.dart';
import '../../../lib/git/objectstore.dart';
import '../../../lib/git/options.dart';

const VALID_REPO_URL_ENDING_WITH_DOT_GIT = 1;
const VALID_REPO_URL_NOT_ENDING_WITH_DOT_GIT = 2;
const VALID_REPO_IF_DOT_GIT_APPENDED = 3;
const INVALID_REPO_404_ERROR = 4;
const PRIVATE_REPO_AUTHORIZATION_ERROR = 5;
const PRIVATE_REPO_WITH_CREDENTIALS = 6;

class MockHttpFetcher extends HttpFetcher {

  int testNumber;

  MockHttpFetcher(ObjectStore store, String name, String repoUrl,
      [String username, String password])
      : super (store, name, repoUrl, username, password);

  MockHttpRequest getNewHttpRequest() => new MockHttpRequestClone(testNumber);

}

class MockHttpRequestClone extends MockHttpRequest {

  int testNumber;
  String _url;
  String _username;
  String _password;

  MockHttpRequestClone(this.testNumber) : super();
  bool open(_a, url, {async : true, user, password}) {
    this._url = url;
    this._username = user;
    this._password = password;
    return true;
  }

  bool send([dynamic body]) {
    switch (testNumber) {
      case VALID_REPO_URL_ENDING_WITH_DOT_GIT:
        break;
      case VALID_REPO_URL_NOT_ENDING_WITH_DOT_GIT:
        break;
      case VALID_REPO_IF_DOT_GIT_APPENDED:
        if (!_url.contains('.git'))
          throw new GitException(GitErrorConstants.GIT_HTTP_404_ERROR);
        break;
      case INVALID_REPO_404_ERROR:
        throw new GitException(GitErrorConstants.GIT_HTTP_404_ERROR);
        break;
      case PRIVATE_REPO_AUTHORIZATION_ERROR:
        if (!verifyCredentials(_username, _password))
          throw new GitException(GitErrorConstants.GIT_AUTH_REQUIRED);
        break;
      case PRIVATE_REPO_WITH_CREDENTIALS:
        if (!verifyCredentials(_username, _password))
          throw new GitException(GitErrorConstants.GIT_AUTH_REQUIRED);
        break;
    }

    loadStream.add("response text");
    return true;
  }

  bool verifyCredentials(String username, String password) {
    return (username != null && password != null);
  }
}

class MockClone extends Clone {

  int testNumber;

  MockClone(options, this.testNumber) : super(options);

  HttpFetcher getHttpFetcher(ObjectStore store, String origin, String url,
      String username, String password) {
    MockHttpFetcher fetcher = new MockHttpFetcher(store, origin, url, username,
        password);
    fetcher.testNumber = testNumber;
    return fetcher;
  }

  /// Mock that the cloning from server is always successful.
  Future startClone(HttpFetcher fetcher) {
    return new Future.value("success");
  }
}

defineTests() {

  group('git.nonetwork.clone', () {
    test('invalid repo', () {
      MockFileSystem fs = new MockFileSystem();
      DirectoryEntry dir = fs.createDirectory('test/git/clone');
      GitOptions options = new GitOptions(root: dir,
          repoUrl: "https://github.com/gaurave/invalid.git", depth: 1,
        store: new ObjectStore(dir));
      MockClone clone = new MockClone(options, INVALID_REPO_404_ERROR);
      return clone.clone().catchError((e) {
        if (e is GitException)
          return true;
        throw e;
      });
    });

    test('private repo with credentials', () {
      MockFileSystem fs = new MockFileSystem();
      DirectoryEntry dir = fs.createDirectory('test/git/clone');
      GitOptions options = new GitOptions(root: dir,
          repoUrl: "https://github.com/gaurave/spark-t.git", depth: 1,
        store: new ObjectStore(dir), username: "user", password: "pass");
      MockClone clone = new MockClone(options, PRIVATE_REPO_WITH_CREDENTIALS);
        return clone.clone().then((String result) {
          return (result == "success");
        });
    });
  });

  test('private repo with no credentials', () {
    MockFileSystem fs = new MockFileSystem();
    DirectoryEntry dir = fs.createDirectory('test/git/clone');
    GitOptions options = new GitOptions(root: dir,
        repoUrl: "https://github.com/gaurave/spark-t.git", depth: 1,
      store: new ObjectStore(dir));
    MockClone clone = new MockClone(options, PRIVATE_REPO_AUTHORIZATION_ERROR);
    return clone.clone().catchError((e) {
      if (e is GitException) {
        return true;
      }
      throw e;
    });
  });

  test('valid repo ending with .git', () {
    MockFileSystem fs = new MockFileSystem();
    DirectoryEntry dir = fs.createDirectory('test/git/clone');
    GitOptions options = new GitOptions(root: dir,
        repoUrl: "https://github.com/gaurave/spark.git", depth: 1,
      store: new ObjectStore(dir));
    MockClone clone = new MockClone(options, VALID_REPO_URL_ENDING_WITH_DOT_GIT);
    return clone.clone().then((String result) {
      return (result == "success");
    });
  });

  test('valid repo not ending with .git', () {
    MockFileSystem fs = new MockFileSystem();
    DirectoryEntry dir = fs.createDirectory('test/git/clone');
    GitOptions options = new GitOptions(root: dir,
        repoUrl: "https://github.com/gaurave/spark", depth: 1,
      store: new ObjectStore(dir));
    MockClone clone = new MockClone(options,
        VALID_REPO_URL_NOT_ENDING_WITH_DOT_GIT);
    return clone.clone().then((String result) {
      return (result == "success");
    });
  });

  test('valid repo if dot git appended', () {
    MockFileSystem fs = new MockFileSystem();
    DirectoryEntry dir = fs.createDirectory('test/git/clone');
    GitOptions options = new GitOptions(root: dir,
        repoUrl: "https://github.com/gaurave/spark", depth: 1,
      store: new ObjectStore(dir));
    MockClone clone = new MockClone(options, VALID_REPO_IF_DOT_GIT_APPENDED);
    return clone.clone().then((String result) {
      return (result == "success");
    });
  });
}

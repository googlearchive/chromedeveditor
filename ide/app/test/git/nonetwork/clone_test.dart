// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git_no_network_clone_test;

import 'package:unittest/unittest.dart';

import 'mock_http_request.dart';
import '../../files_mock.dart';
import '../../../lib/git/commands/clone.dart';
import '../../../lib/git/http_fetcher.dart';
import '../../../lib/git/objectstore.dart';
import '../../../lib/git/options.dart';

class MockHttpFetcher extends HttpFetcher {

  MockHttpFetcher(ObjectStore store, name, repoUrl, [username, password])
      : super (store, name, repoUrl, username, password);

  MockHttpRequest getNewHttpRequest() => new MockHttpRequestClone();

}

class MockHttpRequestClone extends MockHttpRequest {
  open(_a, _b, {async : true, user, password}) => throw "some error";

}

class MockClone extends Clone {

  MockClone(options) : super(options);

  HttpFetcher getHttpFetcher(ObjectStore store, String origin, String url,
      String username, String password) {
    return new MockHttpFetcher(store, origin, url, username, password);
  }
}

defineTests() {

  group('git.nonetwork.clone', () {
    test('todo', () {
      MockFileSystem fs = new MockFileSystem();
      DirectoryEntry dir = fs.createDirectory('test/git/clone');
      GitOptions options = new GitOptions(
          root: dir, repoUrl: "https://github.com/gaurave/spark-t", depth: 1, store: new ObjectStore(dir));
      MockClone clone = new MockClone(options);
      try {
        return clone.clone();
      } catch (e) {
        print(e);
        return true;
      }
    });
  });
}

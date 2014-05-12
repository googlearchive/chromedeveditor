// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git_pull_test;

import 'package:unittest/unittest.dart';

import '../../../lib/git/commands/clone.dart';
import '../../../lib/git/commands/pull.dart';
import '../../../lib/git/objectstore.dart';
import 'utils.dart';

defineTests() {
  group('git.commands.pull', () {
    GitLocation location;

    setUp(() {
      location = new GitLocation();
      return location.init();
    });

    tearDown(() {
      return location.dispose();
    });

    test('pull with no changes', () {
      ObjectStore store = new ObjectStore(location.entry);
      Clone clone = new Clone(new GitOptions(
          repoUrl: sampleRepoUrl,
          root: location.entry,
          depth: 1,
          store: store));
      return clone.clone().then((_) {
        store = new ObjectStore(location.entry);
        store.init();
      }).then((_) {
        Pull pull = new Pull(
            new GitOptions(root: clone.root, store: clone.store));
        return pull.pull().catchError((e) {
          // TODO: It would be nice if this exception was a little more
          // semantic. For instance, a non-error result that is `null`, or a
          // result status object that indicated no changes.
          expect(e, 'Branch is up-to-date.');
        });
      });
    });
  });
}

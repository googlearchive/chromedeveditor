// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.search_test;

import 'package:unittest/unittest.dart';

// BUG(ussuri): https://github.com/dart-lang/spark/issues/500
import '../packages/spark_widgets/spark_suggest/spark_suggest_box.dart';

import '../lib/search.dart';
import '../lib/workspace.dart';
import 'files_mock.dart';

defineTests() {
  group('SearchOracle', () {
    MockFileSystem fs;
    Workspace ws;
    DirectoryEntry rootDir;
    SearchOracle oracle;

    setUp(() {
      fs = new MockFileSystem();
      ws = new Workspace();
      rootDir = fs.createDirectory('/root');
      [
       '/root/Spark.DART',  // mixed-case on purpose
       '/root/rocks.dart',
       '/root/multi1.dart',
       '/root/multi2.dart',
       '/root/i_has-underdashes.txt',
      ].forEach(fs.createFile);
      oracle = new SearchOracle(
          () => ws,
          (f) { fail('Should not have reached this line'); });
    });

    whenReady(test()) =>
        () => ws.link(createWsRoot(rootDir)).then((_) => test());

    test('should find single matching file', whenReady(() {
      oracle.getSuggestions('spark').listen(expectAsync((List<Suggestion> list) {
        expect(list, hasLength(1));
        expect(list[0].label, 'Spark.DART');
        expect(list[0].details, '[/root]');
      }));
    }));

    test('should find all matching files', whenReady(() {
      oracle.getSuggestions('multi').listen(expectAsync((List<Suggestion> list) {
        expect(list, hasLength(2));
        expect(list[0].label, 'multi1.dart');
        expect(list[0].details, '[/root]');
        expect(list[1].label, 'multi2.dart');
        expect(list[1].details, '[/root]');
      }));
    }));

    test('should ignore case', whenReady(() {
      oracle.getSuggestions('SP').listen(expectAsync((List<Suggestion> list) {
        expect(list, hasLength(1));
        expect(list[0].label, 'Spark.DART');
        expect(list[0].details, '[/root]');
      }));
    }));

    test('should ignore underscores', whenReady(() {
      oracle.getSuggestions('ih-asunder_dashes').listen(expectAsync((List<Suggestion> list) {
        expect(list, hasLength(1));
        expect(list[0].label, 'i_has-underdashes.txt');
        expect(list[0].details, '[/root]');
      }));
    }));

    test('should not return non-matching suggestions', whenReady(() {
      oracle.getSuggestions('does_not_match').listen(expectAsync((List list) {
        expect(list, hasLength(0));
      }));
    }));

    test('should not return anything on empty/null text', whenReady(() {
      oracle.getSuggestions('').listen(expectAsync((list) {
        expect(list, hasLength(0));
      }));
      oracle.getSuggestions(null).listen(expectAsync((list) {
        expect(list, hasLength(0));
      }));
    }));
  });
}

// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.search_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

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

    whenReady(test()) => () => ws.link(rootDir).then((_) => test());

    test('should find single matching file', whenReady(() {
      oracle.getSuggestions('spark').listen(expectAsync1((list) {
        expect(list, hasLength(1));
        expect(list[0].displayLabel, 'Spark.DART (/root)');
      }));
    }));

    test('should find all matching files', whenReady(() {
      oracle.getSuggestions('multi').listen(expectAsync1((list) {
        expect(list, hasLength(2));
        expect(list[0].displayLabel, 'multi1.dart (/root)');
        expect(list[1].displayLabel, 'multi2.dart (/root)');
      }));
    }));

    test('should ignore case', whenReady(() {
      oracle.getSuggestions('SP').listen(expectAsync1((list) {
        expect(list, hasLength(1));
        expect(list[0].displayLabel, 'Spark.DART (/root)');
      }));
    }));

    test('should ignore underscores', whenReady(() {
      oracle.getSuggestions('ih-asunder_dashes').listen(expectAsync1((list) {
        expect(list, hasLength(1));
        expect(list[0].displayLabel, 'i_has-underdashes.txt (/root)');
      }));
    }));

    test('should not return non-matching suggestions', whenReady(() {
      oracle.getSuggestions('does_not_match').listen(expectAsync1((list) {
        expect(list, hasLength(0));
      }));
    }));

    test('should not return anything on empty/null text', whenReady(() {
      oracle.getSuggestions('').listen(expectAsync1((list) {
        expect(list, hasLength(0));
      }));
      oracle.getSuggestions(null).listen(expectAsync1((list) {
        expect(list, hasLength(0));
      }));
    }));
  });
}

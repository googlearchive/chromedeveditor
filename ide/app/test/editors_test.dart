// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.editors_test;

import 'dart:async';
import 'package:unittest/unittest.dart';

import '../lib/ace.dart';
import '../lib/editors.dart';
import '../lib/preferences.dart';
import '../lib/workspace.dart';
import 'ace_test.dart';
import 'workspace_test.dart';

main() {
  group('editors', () {
    test('general test', () {
      Workspace workspace = new Workspace();
      AceEditor editor = new MockAceEditor();
      PreferenceStore store = new MapPreferencesStore();
      EditorManager manager = new EditorManager(workspace, editor, store);

      MockFileEntry fileEntry = new MockFileEntry('test.txt', 'foobar');
      File fileResource = new File(workspace, fileEntry, false);

      Completer completer = new Completer();
      manager.onSelectedChange.first.then((f) {
        expect(f.name, fileResource.name);
        completer.complete();
      });

      manager.select(fileResource);
      return completer.future;
    });
  });
}

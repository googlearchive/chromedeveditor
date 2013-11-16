// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.editors_test;

import 'dart:async';
import 'package:unittest/unittest.dart';

import 'ace_test.dart';
import 'files_mock.dart';
import '../lib/editors/ace.dart';
import '../lib/editors/editor.dart';
import '../lib/preferences.dart';
import '../lib/workspace.dart';

main() {
  group('editors', () {
    test('general test', () {
      Workspace workspace = new Workspace();
      AceEditor editor = new MockAceEditor();
      PreferenceStore store = new MapPreferencesStore();
      EditorProvider provider = new AceEditorProvider();
      EditorSessionManager manager = new EditorSessionManager(workspace, store, provider);

      MockFileSystem fs = new MockFileSystem();

      FileEntry fileEntry = fs.createFile('test.txt', contents: 'foobar');
      File fileResource = new File(workspace, fileEntry, false);

      Completer completer = new Completer();
      EditorSession session = provider.getEditorSessionForFile(fileResource);
      expect(session.file, fileResource);
      expect(provider.getEditorSessionForFile(fileResource), session);
      expect(manager.isFileOpened(fileResource), false);
      manager.add(session);
      expect(manager.isFileOpened(fileResource), true);
      completer.complete();
      return completer.future;
    });
  });
}

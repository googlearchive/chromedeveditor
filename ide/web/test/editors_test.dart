// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.editors_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import 'ace_test.dart';
import 'workspace_test.dart';
import '../lib/ace.dart';
import '../lib/editors.dart';
import '../lib/event_bus.dart';
import '../lib/files_mock.dart';
import '../lib/preferences.dart';
import '../lib/workspace.dart';

defineTests() {
  group('editors', () {
    test('general test', () {
      Workspace workspace = new Workspace();
      AceManager aceManager = new MockAceManager();
      SparkPreferences store = new SparkPreferences(new MapPreferencesStore());
      EditorManager manager = new EditorManager(
          workspace, aceManager, store, new EventBus(), null);

      MockFileSystem fs = new MockFileSystem();

      FileEntry fileEntry = fs.createFile('test.txt', contents: 'foobar');
      File fileResource = new File(workspace, fileEntry);

      Completer completer = new Completer();
      manager.onSelectedChange.first.then((f) {
        expect(f.name, fileResource.name);
        completer.complete();
      });

      manager.openFile(fileResource);
      return completer.future;
    });
  });

  group('test FileContentProvider', () {
    test('read / write file', () {
      Workspace workspace = createWorkspace();
      MockFileSystem fs = new MockFileSystem();
      FileEntry fileEntry = fs.createFile('test.txt', contents: "foo bar");
      File file = new File(workspace, fileEntry);
      FileContentProvider provider = new FileContentProvider(file);
      Completer<String> contentCompleter = new Completer();
      provider.onChange.listen((String content) {
        contentCompleter.complete("onChange");
      });

      return provider.read().then((String text) {
        expect(text, 'foo bar');
        return provider.write("new bar");
      }).then((_) => provider.read()).then((String text) {
        expect(text, 'new bar');
        return contentCompleter.future;
      }).then((String changed) {
        expect(changed, 'onChange');
      });
    });

    test('read / write empty file', () {
      Workspace workspace = createWorkspace();
      MockFileSystem fs = new MockFileSystem();
      FileEntry fileEntry = fs.createFile('test.txt', contents: "");
      File file = new File(workspace, fileEntry);
      FileContentProvider provider = new FileContentProvider(file);
      return provider.read().then((String text) {
        expect(text, '');
        return provider.write("foo bar");
      }).then((_) => provider.read()).then((String text) {
        expect(text, 'foo bar');
      });
    });
  });
  
  group('test PreferencesContentProvider', () {
    test('read / write preference values', () {
      PreferenceStore store = new MapPreferencesStore();
      PreferenceContentProvider provider = new PreferenceContentProvider(store, "foo");

      provider.write("bar baz");
      return provider.read().then((String content) {
        expect(content, "bar baz");
        return provider.write("altered");
      }).then((String content) {
        return provider.read();
      }).then((String content) {
        expect(content, "altered");
      });
    });
  });
}

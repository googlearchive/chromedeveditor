// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.files_test;

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:unittest/unittest.dart';

import 'files_mock.dart';

defineTests() {
  group('files', () {
    test('package directory available', () {
      return chrome.runtime.getPackageDirectoryEntry().then((chrome.DirectoryEntry dir) {
        expect(dir, isNotNull);
      });
    });

    test('can list directories', () {
      return chrome.runtime.getPackageDirectoryEntry().then((chrome.DirectoryEntry dir) {
        return dir.createReader().readEntries().then((List<chrome.Entry> entries) {
          expect(entries.length, greaterThan(1));
        });
      });
    });

    test('can get file', () {
      return chrome.runtime.getPackageDirectoryEntry().then((chrome.DirectoryEntry dir) {
        return dir.getFile('manifest.json').then((chrome.Entry file) {
          expect(file, isNotNull);
          expect(file.name, 'manifest.json');
        });
      });
    });

    test('can retain and restore file', () {
      return chrome.runtime.getPackageDirectoryEntry().then((chrome.DirectoryEntry dir) {
        return dir.getFile('manifest.json').then((chrome.Entry file) {
          expect(file, isNotNull);
          String id = chrome.fileSystem.retainEntry(file);
          return chrome.fileSystem.restoreEntry(id).then((chrome.Entry restoredFile) {
            expect(restoredFile, isNotNull);
            expect(restoredFile.name, 'manifest.json');
          });
        });
      });
    });
    test('ChromeFileEntry readText()', () {
      return chrome.runtime.getPackageDirectoryEntry().then((chrome.DirectoryEntry dir) {
        return dir.getFile('manifest.json').then((chrome.ChromeFileEntry file) {
          expect(file, isNotNull);
          return file.readText().then((String text) {
            expect(text.length, greaterThan(1));
          });
        });
      });
    });
  });

  group('syncFileSystem', () {
    test('is available', () {
      // TODO: this fails if the app is not signed in
//      return chrome.syncFileSystem.requestFileSystem().then((chrome.FileSystem fs) {
//        expect(fs, isNotNull);
//      });
    });
  });

  group('mockFileSystem', () {
    test('create file', () {
      MockFileSystem fs = new MockFileSystem();
      fs.createFile('foo.txt');
      fs.createFile('/baz/foo.txt');

      expect(fs.getEntry('foo.txt'), isNotNull);
      expect(fs.getEntry('foo.txt').name, 'foo.txt');

      expect(fs.getEntry('baz/foo.txt'), isNotNull);
      expect(fs.getEntry('baz/foo.txt').name, 'foo.txt');
    });

    test('remove file', () {
      MockFileSystem fs = new MockFileSystem();
      fs.createFile('foo.txt');
      fs.createFile('/baz/foo.txt');

      fs.removeFile('foo.txt');
      fs.removeFile('/baz/foo.txt');

      expect(fs.getEntry('foo.txt'), null);
      expect(fs.getEntry('baz/foo.txt'), null);
    });

    test('file contents', () {
      MockFileSystem fs = new MockFileSystem();
      fs.createFile('foo.txt', contents: 'bar baz');
      ChromeFileEntry entry = fs.getEntry('foo.txt');
      expect(entry, isNotNull);
      expect(entry.name, 'foo.txt');
      return entry.readText().then((text) {
        expect(text, 'bar baz');
      });
    });

    test('create dir', () {
      MockFileSystem fs = new MockFileSystem();
      fs.createDirectory('bar');
      fs.createDirectory('/aaa/bar');
      fs.createFile('/baz/foo.txt');

      expect(fs.getEntry('bar'), isNotNull);
      expect(fs.getEntry('bar'), new isInstanceOf<DirectoryEntry>('DirectoryEntry'));

      expect(fs.getEntry('aaa/bar'), isNotNull);
      expect(fs.getEntry('aaa/bar'), new isInstanceOf<DirectoryEntry>('DirectoryEntry'));

      expect(fs.getEntry('baz'), isNotNull);
      expect(fs.getEntry('baz'), new isInstanceOf<DirectoryEntry>('DirectoryEntry'));
    });

    test('write to files', () {
      final CONTENTS = 'foo bar';
      MockFileSystem fs = new MockFileSystem();
      return fs.root.createFile('foo.txt').then((ChromeFileEntry file) {
        return file.writeText(CONTENTS).then((_) {
          return file.readText().then((contents) {
            expect(contents, CONTENTS);
          });
        });
      });
    });

    test('create files', () {
      MockFileSystem fs = new MockFileSystem();
      return fs.root.createFile('a.txt', exclusive: true).then((_) {
        expect(fs.root.createFile('a.txt', exclusive: true), throws);
      });
    });

    test('create directories', () {
      MockFileSystem fs = new MockFileSystem();
      return fs.root.createDirectory('abc', exclusive: true).then((_) {
        expect(fs.root.createDirectory('abc', exclusive: true), throws);
      });
    });
  });
}

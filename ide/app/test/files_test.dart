// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.files_test;

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;
import 'package:unittest/unittest.dart';

import 'files_mock.dart';

main() {
  group('files', () {
    test('package directory available', () {
      return chrome_gen.runtime.getPackageDirectoryEntry().then((chrome_gen.DirectoryEntry dir) {
        expect(dir, isNotNull);
      });
    });

    test('can list directories', () {
      return chrome_gen.runtime.getPackageDirectoryEntry().then((chrome_gen.DirectoryEntry dir) {
        return dir.createReader().readEntries().then((List<chrome_gen.Entry> entries) {
          expect(entries.length, greaterThan(1));
        });
      });
    });

    test('can get file', () {
      return chrome_gen.runtime.getPackageDirectoryEntry().then((chrome_gen.DirectoryEntry dir) {
        return dir.getFile('manifest.json').then((chrome_gen.Entry file) {
          expect(file, isNotNull);
          expect(file.name, 'manifest.json');
        });
      });
    });

    test('can retain and restore file', () {
      return chrome_gen.runtime.getPackageDirectoryEntry().then((chrome_gen.DirectoryEntry dir) {
        return dir.getFile('manifest.json').then((chrome_gen.Entry file) {
          expect(file, isNotNull);
          String id = chrome_gen.fileSystem.retainEntry(file);
          return chrome_gen.fileSystem.restoreEntry(id).then((chrome_gen.Entry restoredFile) {
            expect(restoredFile, isNotNull);
            expect(restoredFile.name, 'manifest.json');
          });
        });
      });
    });
    test('ChromeFileEntry readText()', () {
      return chrome_gen.runtime.getPackageDirectoryEntry().then((chrome_gen.DirectoryEntry dir) {
        return dir.getFile('manifest.json').then((chrome_gen.ChromeFileEntry file) {
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
//      return chrome_gen.syncFileSystem.requestFileSystem().then((chrome_gen.FileSystem fs) {
//        expect(fs, isNotNull);
//      });
    });
  });

  group('mockFileSystem', () {
    test('create file', () {
      MockFileSystem fs = new MockFileSystem();
      fs.createFile('foo.txt');
      expect(fs.getEntry('foo.txt'), isNotNull);
      expect(fs.getEntry('foo.txt').name, 'foo.txt');
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
      fs.createFile('/baz/foo.txt');

      expect(fs.getEntry('bar'), isNotNull);
      expect(fs.getEntry('bar'), new isInstanceOf<DirectoryEntry>('DirectoryEntry'));

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

    });

  });

}

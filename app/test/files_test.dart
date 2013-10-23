// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.files_test;

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;
import 'package:unittest/unittest.dart';

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
}

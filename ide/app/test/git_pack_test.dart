// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git_pack_test;

import 'dart:typed_data';

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;
import 'package:unittest/unittest.dart';


import '../lib/git/git_pack.dart';

final String PACK_FILE_PATH = 'test/data/pack_test.pack';
final String PACK_INDEX_FILE_PATH = 'test/data/pack-_index_test.idx';


main() {
  group('git.pack', () {
    test('parsePack', () {
      return chrome_gen.runtime.getPackageDirectoryEntry().then(
          (chrome_gen.DirectoryEntry dir) {
        return dir.getFile(PACK_FILE_PATH).then(
            (chrome_gen.ChromeFileEntry entry) {
          return entry.readBytes().then((chrome_gen.ArrayBuffer binaryData) {
            Uint8List data = new Uint8List.fromList(binaryData.getBytes());
            Pack pack = new Pack(data, null);
            return pack.parseAll().then((_) {
              // TODO: this fails in applyDelta() - not yet implemented

              // TODO: add more expects for the pack state?
              expect(pack.objects.length, 15);
            }, onError: (e) {
              // TODO(grv) : catch custom exceptions, and fail the test.
            });
          });
        });
      });
    });
  });
}

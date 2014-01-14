// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git_pack_index_test;

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:unittest/unittest.dart';

import '../../lib/git/pack.dart';
import '../../lib/git/pack_index.dart';

final String PACK_FILE_PATH = 'test/data/pack_test.pack';
final String PACK_INDEX_FILE_PATH = 'test/data/pack_index_test.idx';

Future<Pack> initPack() {
  return chrome.runtime.getPackageDirectoryEntry().then(
      (chrome.DirectoryEntry dir) {
    return dir.getFile(PACK_FILE_PATH).then((chrome.ChromeFileEntry entry) {
      return entry.readBytes().then((chrome.ArrayBuffer binaryData) {
        Uint8List data = new Uint8List.fromList(binaryData.getBytes());
        Pack pack = new Pack(data, null);
        return pack.parseAll(null).then((_) {
          return new Future.value(pack);
        });
      });
    });
  });
}

Future<PackIndex> initPackIndex() {
  return chrome.runtime.getPackageDirectoryEntry().then(
      (chrome.DirectoryEntry dir) {
    return dir.getFile(PACK_INDEX_FILE_PATH).then(
        (chrome.ChromeFileEntry entry) {
      return entry.readBytes().then((chrome.ArrayBuffer binaryData) {
        Uint8List data = new Uint8List.fromList(binaryData.getBytes());
        PackIndex packIdx = new PackIndex(data.buffer);
        return new Future.value(packIdx);
      });
    });
  });
}

String shaToString(List<int> sha) {
  return UTF8.decode(sha);
}

defineTests() {
  group('git.packIndex', () {
    test('packIndexParse', () {
      return initPack().then((Pack pack) {
        return initPackIndex().then((PackIndex packIdx) {
          pack.objects.forEach((PackObject obj) {
            // asserts the object found by index has correct offset.
            expect(obj.offset,packIdx.getObjectOffset(obj.sha));
          });
        });
      });
    });
  });
}

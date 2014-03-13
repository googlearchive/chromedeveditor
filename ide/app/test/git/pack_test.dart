// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git_pack_test;

import 'dart:async';
import 'dart:typed_data';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:logging/logging.dart';
import 'package:unittest/unittest.dart';

import '../../lib/git/pack.dart';

final String PACK_FILE_PATH = 'test/data/pack_test.pack';
final String PACK_INDEX_FILE_PATH = 'test/data/pack-_index_test.idx';

Logger _logger = new Logger('tests.git.pack_test');

defineTests() {
  group('git.pack', () {
    test('parsePack', () {
      Future f = chrome.runtime.getPackageDirectoryEntry();
      return f.then((chrome.DirectoryEntry dir) {
        _logger.info('got package directory entry');
        return dir.getFile(PACK_FILE_PATH).then((chrome.ChromeFileEntry entry) {
          _logger.info('got pack file (${entry.fullPath})');
          return entry.readBytes().then((chrome.ArrayBuffer binaryData) {
            _logger.info('got data');
            Pack pack = new Pack(new Uint8List.fromList(binaryData.getBytes()));
            return pack.parseAll().then((_) {
              _logger.info('got result from parseAll()');

              // TODO: add more expects for the pack state?
              expect(pack.objects.length, 15);
            });
          });
        });
      });
    });
  });
}

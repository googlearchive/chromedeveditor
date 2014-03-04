// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.outline_test;

import 'dart:async';
import 'dart:isolate';

import 'package:unittest/unittest.dart';

import 'files_mock.dart';
import '../lib/services.dart';
import '../lib/workspace.dart' as ws;

defineTests() {
  ws.Workspace workspace = new ws.Workspace();

  Services services = new Services(workspace);

  group('outline service tests', () {
    test('resource read', () {
      String code = """
          main() {}
          class A {
            methA() {}
            int propA = 1;
            String propB
          }""";
//      MockFileSystem fs = new MockFileSystem();
//      FileEntry fileEntry = fs.createFile('test.txt', contents: );
//      String fileUuid;

      AnalyzerService analyzerService = services.getService("analyzer");
      analyzerService.getOutlineFor(code).then((Map outline) {
        /*%TRACE3*/ print("""(4> 3/3/14): outline: ${outline}"""); // TRACE%
      });
//      return workspace.link(createWsRoot(fileEntry))
//          .then((ws.File fileResource) {
//            return testService.readText(fileResource);
//          }).then((String text) => expect(text, equals("some words")));
    });
  });
}

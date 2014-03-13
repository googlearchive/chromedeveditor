// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.outline_test;

import 'package:unittest/unittest.dart';

import '../lib/pub.dart';
import '../lib/services.dart';
import '../lib/workspace.dart' as ws;

defineTests() {
  ws.Workspace workspace = new ws.Workspace();

  Services services = new Services(workspace, new PubManager(workspace));

  group('outline service tests', () {
    test('resource read', () {
      String code = """
          int topLevelVariableName, topLevelVariable2Name = 1;
          topLevelFunctionName() {}
          class classDeclarationName {
            String method1Name(param1, int param2) {}
            static method2Name() {}
            int classVariable1Name, classVariable2Name = 1;
          }""";

      AnalyzerService analyzerService = services.getService("analyzer");
      return analyzerService.getOutlineFor(code).then((Outline outline) {
        List<OutlineTopLevelEntry> entries = outline.entries;
        expect(entries[0] is OutlineTopLevelVariable, isTrue);
        expect(entries[0].name, equals("topLevelVariableName"));
        expect(entries[1] is OutlineTopLevelVariable, isTrue);
        expect(entries[1].name, equals("topLevelVariable2Name"));
        expect(entries[2] is OutlineTopLevelFunction, isTrue);
        expect(entries[2].name, equals("topLevelFunctionName"));
        expect(entries[3] is OutlineClass, isTrue);
        OutlineClass outlineClass = entries[3];
        expect(outlineClass.name, equals("classDeclarationName"));
        List<OutlineMember> members = outlineClass.members;
        expect(members[0] is OutlineMethod, isTrue);
        OutlineMethod method = members[0];
        expect(method.name, equals("method1Name"));
        expect(members[1] is OutlineMethod, isTrue);
        method = members[1];
        expect(method.name, equals("method2Name"));
        expect(members[2] is OutlineClassVariable, isTrue);
        OutlineClassVariable field = members[2];
        expect(field.name, equals("classVariable1Name"));
        field = members[3];
        expect(field.name, equals("classVariable2Name"));
      });
    });
  });
}

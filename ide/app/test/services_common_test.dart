// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.services_common_test;

import 'package:unittest/unittest.dart';

import '../lib/services/services_common.dart';

expectOutlineTopLevelVariable(OutlineTopLevelVariable varEntry) {
  expect(varEntry.name, equals("varName"));
}

expectOutlineClass(OutlineClass classEntry) {
  expect(classEntry.name, equals("className"));
  expect(classEntry.abstract, isTrue);
}

expectOutlineEmptyClass(OutlineClass classEntry) {
  expectOutlineClass(classEntry);
  expect(classEntry.members.length, 0);
}

expectOutlineFilledClass(OutlineClass classEntry) {
  expectOutlineClass(classEntry);
  expect(classEntry.members.length, 2);
}

expectOutlineFunction(OutlineTopLevelFunction functionEntry) {
  expect(functionEntry.name, equals("functionName"));
}

Map outlineTopLevelVariableMap = {
    "name": "varName",
    "bodyStartOffset": 10,
    "bodyEndOffset": 25,
    "nameStartOffset": 10,
    "nameEndOffset": 20,
    "type": "top-level-variable"};

Map _outlineClassMap = {
    "name": "className",
    "bodyStartOffset": 30,
    "bodyEndOffset": 45,
    "nameStartOffset": 30,
    "nameEndOffset": 40,
    "abstract": true,
    "members": [],
    "type": "class"};

Map outlineFunctionMap = {
    "name": "functionName",
    "bodyStartOffset": 50,
    "bodyEndOffset": 65,
    "nameStartOffset": 50,
    "nameEndOffset": 60,
    "type": "function"};

Map outlineMethodMap = {
    "static": false,
    "name": "methodName",
    "bodyStartOffset": 70,
    "bodyEndOffset": 85,
    "nameStartOffset": 70,
    "nameEndOffset": 80,
    "type": "method"};

Map outlineClassVariableMap = {
    "static": false,
    "name": "variableName",
    "bodyStartOffset": 90,
    "bodyEndOffset": 105,
    "nameStartOffset": 90,
    "nameEndOffset": 100,
    "type": "class-variable"};


defineTests() {
  group('services.outline', () {
    test('instantiate individual entries', () {
      // Make copies before we mutate the test data.
      Map outlineClassMap = new Map.from(_outlineClassMap);
      outlineClassMap['members'] = [];

      OutlineTopLevelVariable outlineTopLevelVariable =
          new OutlineTopLevelEntry.fromMap(outlineTopLevelVariableMap);
      expectOutlineTopLevelVariable(outlineTopLevelVariable);
      expect(outlineTopLevelVariable.toMap(), equals(outlineTopLevelVariableMap));

      OutlineClass outlineEmptyClass =
          new OutlineTopLevelEntry.fromMap(outlineClassMap);
      expectOutlineEmptyClass(outlineEmptyClass);
      expect(outlineEmptyClass.toMap(), equals(outlineClassMap));

      // Fill the class and re-test
      outlineClassMap['members'].add(outlineClassVariableMap);
      outlineClassMap['members'].add(outlineMethodMap);

      OutlineClass outlineClass =
          new OutlineTopLevelEntry.fromMap(outlineClassMap);
      expectOutlineFilledClass(outlineClass);
      expect(outlineClass.toMap(), equals(outlineClassMap));

      OutlineTopLevelFunction outlineFunction =
          new OutlineTopLevelEntry.fromMap(outlineFunctionMap);
      expectOutlineFunction(outlineFunction);
      expect(outlineFunction.toMap(), equals(outlineFunctionMap));
    });

    test('instantiate full outline', () {
      Map outlineClassMap = new Map.from(_outlineClassMap);

      Outline outline = new Outline.fromMap({
        "entries": [outlineTopLevelVariableMap, outlineClassMap, outlineFunctionMap]});
      expect(outline.entries.length, equals(3));
      expectOutlineTopLevelVariable(outline.entries[0]);
      expectOutlineEmptyClass(outline.entries[1]);
      expectOutlineFunction(outline.entries[2]);
    });
  });
}

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
    "startOffset": 10,
    "endOffset": 20,
    "type": "top-level-variable"};

Map outlineClassMap = {
    "name": "className",
    "startOffset": 30,
    "endOffset": 40,
    "abstract": true,
    "members": [],
    "type": "class"};

Map outlineFunctionMap = {
    "name": "functionName",
    "startOffset": 50,
    "endOffset": 60,
    "type": "function"};

Map outlineMethodMap = {
    "name": "methodName",
    "startOffset": 70,
    "endOffset": 80,
    "type": "method"};

Map outlineClassVariableMap = {
    "name": "variableName",
    "startOffset": 90,
    "endOffset": 100,
    "type": "class-variable"};


defineTests() {
  group('Outline Instantiation Tests', () {
    test('Instnantiate individual entries', () {
      OutlineTopLevelVariable outlineTopLevelVariable =
          new OutlineTopLevelEntry.fromMap(outlineTopLevelVariableMap);
      expectOutlineTopLevelVariable(outlineTopLevelVariable);
      expect(outlineTopLevelVariable.toMap(),
          equals(outlineTopLevelVariableMap));

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

    test('Instnantiate full outline', () {
      Outline outline = new Outline.fromMap({
        "entries": [outlineTopLevelVariableMap, outlineClassMap, outlineFunctionMap]});
      expect(outline.entries.length, equals(3));
      expectOutlineTopLevelVariable(outline.entries[0]);
      expectOutlineFilledClass(outline.entries[1]);
      expectOutlineFunction(outline.entries[2]);
    });
  });
}
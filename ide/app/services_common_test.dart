import 'package:unittest/unittest.dart';

import 'lib/services/services_common.dart';

expectOutlineClass(OutlineClass outlineEntry) {
  expect(outlineEntry.name, equals("abc"));
  expect(outlineEntry.abstract, isTrue);
}

expectOutlineFunction(TopLevelFunction functionEntry) {
  expect(functionEntry.name, equals("abc"));
}

Map outlineClassMap = {
    "name": "abc",
    "abstract": true,
    "type": "class"};

Map outlineFunctionMap = {
    "name": "abc",
    "type": "function"};


main() {
  group('Outline Instantiation Tests', () {
    test('Instnantiate individual entries', () {
      OutlineClass outlineClass =
          new OutlineTopLevelEntry.fromMap(outlineClassMap);
      expectOutlineClass(outlineClass);
      expect(outlineClass.toMap(), equals(outlineClassMap));

      TopLevelFunction outlineFunction =
          new OutlineTopLevelEntry.fromMap(outlineFunctionMap);
      expectOutlineFunction(outlineFunction);
      expect(outlineFunction.toMap(), equals(outlineFunctionMap));
    });

    test('Instnantiate full outline', () {
      Outline outline = new Outline.fromMap({
        "entries": [outlineClassMap, outlineFunctionMap]});
      expect(outline.entries.length, equals(2));
      expectOutlineClass(outline.entries[0]);
      expectOutlineFunction(outline.entries[1]);
    });
  });
}
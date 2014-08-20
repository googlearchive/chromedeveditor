// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.json_parser_test;

import 'package:unittest/unittest.dart';

import '../lib/json/json_parser.dart';
import '../lib/json/json_utils.dart';

/**
 * Event data collected for each json parser event.
 */
class _LoggingEvent {
  static const int STRING_VALUE = 0;
  static const int NUMBER_VALUE = 1;
  static const int BOOL_VALUE = 2;
  static const int NULL_VALUE = 3;
  static const int BEGIN_OBJECT = 4;
  static const int END_OBJECT = 5;
  static const int PROPERTY_NAME = 6;
  static const int PROPERTY_VALUE = 7;
  static const int BEGIN_ARRAY = 8;
  static const int END_ARRAY = 9;
  static const int ARRAY_ELEMENT = 10;

  final int kind;
  final Span span;
  final value;
  final LineColumn startLineColumn;
  final LineColumn endLineColumn;

  _LoggingEvent(
      this.kind,
      this.span,
      this.value,
      this.startLineColumn,
      this.endLineColumn);
}

/**
 * Json parser listener that collects all events into a flat list of
 * [_LoggingEvent].
 */
class _LoggingListener extends JsonListener {
  final String contents;
  final StringLineOffsets lineOffsets;
  final List<_LoggingEvent> events = new List();

  _LoggingListener(String contents) :
      this.contents = contents,
      lineOffsets = new StringLineOffsets(contents);

  void _addEvent(int kind, Span span, var value) {
    events.add(new _LoggingEvent(
        kind,
        span,
        value,
        lineOffsets.getLineColumn(span.start),
        lineOffsets.getLineColumn(span.end)));
  }

  void handleString(Span span, String value) =>
      _addEvent(_LoggingEvent.STRING_VALUE, span, value);
  void handleNumber(Span span, num value) =>
      _addEvent(_LoggingEvent.NUMBER_VALUE, span, value);
  void handleBool(Span span, bool value) =>
      _addEvent(_LoggingEvent.BOOL_VALUE, span, value);
  void handleNull(Span span) =>
      _addEvent(_LoggingEvent.NULL_VALUE, span, null);
  void beginObject(int position) =>
      _addEvent(_LoggingEvent.BEGIN_OBJECT, new Span(position, position), null);
  void propertyName(Span span) =>
      _addEvent(_LoggingEvent.PROPERTY_NAME, span, null);
  void propertyValue(Span span) =>
      _addEvent(_LoggingEvent.PROPERTY_VALUE, span, null);
  void endObject(Span span) =>
      _addEvent(_LoggingEvent.END_OBJECT, span, null);
  void beginArray(int position) =>
      _addEvent(_LoggingEvent.BEGIN_ARRAY, new Span(position, position), null);
  void arrayElement(Span span) =>
      _addEvent(_LoggingEvent.ARRAY_ELEMENT, span, null);
  void endArray(Span span) =>
      _addEvent(_LoggingEvent.END_ARRAY, span, null);
}

class _LoggingEventChecker {
  final _LoggingListener listener;
  int eventIndex;

  _LoggingEventChecker(this.listener): eventIndex = 0;

  void event(
      int kind,
      int startLine,
      int startColumn,
      int endLine,
      int endColumn,
      [var value]) {
    expect(eventIndex, lessThan(listener.events.length));
    _LoggingEvent event = listener.events[eventIndex];
    if (value == null) {
      value = event.value;
    }
    expect(event.kind, equals(kind));
    expect(event.startLineColumn.line, equals(startLine));
    expect(event.startLineColumn.column, equals(startColumn));
    expect(event.endLineColumn.line, equals(endLine));
    expect(event.endLineColumn.column, equals(endColumn));
    expect(event.value, equals(value));
    eventIndex++;
  }

  void end() {
    expect(eventIndex, equals(listener.events.length));
  }
}

void defineTests() {
  group('Json parser tests -', () {
    test('empty object', () {
      String contents = """
{
}
""";
      _LoggingListener listener = new _LoggingListener(contents);
      JsonParser parser = new JsonParser(contents, listener);
      parser.parse();

      _LoggingEventChecker checker = new _LoggingEventChecker(listener);
      checker.event(_LoggingEvent.BEGIN_OBJECT, 1, 1, 1, 1);
      checker.event(_LoggingEvent.END_OBJECT, 1, 1, 2, 2);
      checker.end();
    });

    test('empty array', () {
      String contents = """
[
]
""";
      _LoggingListener listener = new _LoggingListener(contents);
      JsonParser parser = new JsonParser(contents, listener);
      parser.parse();

      _LoggingEventChecker checker = new _LoggingEventChecker(listener);
      checker.event(_LoggingEvent.BEGIN_ARRAY, 1, 1, 1, 1);
      checker.event(_LoggingEvent.END_ARRAY, 1, 1, 2, 2);
      checker.end();
    });

    test('single number', () {
      String contents = """
123
""";
      _LoggingListener listener = new _LoggingListener(contents);
      JsonParser parser = new JsonParser(contents, listener);
      parser.parse();

      _LoggingEventChecker checker = new _LoggingEventChecker(listener);
      checker.event(_LoggingEvent.NUMBER_VALUE, 1, 1, 1, 4, 123);
      checker.end();
    });

    test('single string literal', () {
      String contents = """
"hhh"
""";
      _LoggingListener listener = new _LoggingListener(contents);
      JsonParser parser = new JsonParser(contents, listener);
      parser.parse();

      _LoggingEventChecker checker = new _LoggingEventChecker(listener);
      checker.event(_LoggingEvent.STRING_VALUE, 1, 1, 1, 6, "hhh");
      checker.end();
    });

    test('single "true" literal', () {
      String contents = """
true
""";
      _LoggingListener listener = new _LoggingListener(contents);
      JsonParser parser = new JsonParser(contents, listener);
      parser.parse();

      _LoggingEventChecker checker = new _LoggingEventChecker(listener);
      checker.event(_LoggingEvent.BOOL_VALUE, 1, 1, 1, 5, true);
      checker.end();
    });

    test('single "false" literal', () {
      String contents = """
false
""";
      _LoggingListener listener = new _LoggingListener(contents);
      JsonParser parser = new JsonParser(contents, listener);
      parser.parse();

      _LoggingEventChecker checker = new _LoggingEventChecker(listener);
      checker.event(_LoggingEvent.BOOL_VALUE, 1, 1, 1, 5, false);
      checker.end();
    });

    test('single "null" literal', () {
      String contents = """
null
""";
      _LoggingListener listener = new _LoggingListener(contents);
      JsonParser parser = new JsonParser(contents, listener);
      parser.parse();

      _LoggingEventChecker checker = new _LoggingEventChecker(listener);
      checker.event(_LoggingEvent.NULL_VALUE, 1, 1, 1, 5, null);
      checker.end();
    });

    test('object containing single property and value', () {
      String contents = """
{
  "foo": 1
}
""";
      _LoggingListener listener = new _LoggingListener(contents);
      JsonParser parser = new JsonParser(contents, listener);
      parser.parse();

      _LoggingEventChecker checker = new _LoggingEventChecker(listener);
      checker.event(_LoggingEvent.BEGIN_OBJECT, 1, 1, 1, 1);
      checker.event(_LoggingEvent.STRING_VALUE, 2, 3, 2, 8, "foo");
      checker.event(_LoggingEvent.PROPERTY_NAME, 2, 3, 2, 8);
      checker.event(_LoggingEvent.NUMBER_VALUE, 2, 10, 2, 11, 1);
      checker.event(_LoggingEvent.PROPERTY_VALUE, 2, 10, 2, 11);
      checker.event(_LoggingEvent.END_OBJECT, 1, 1, 3, 2);
      checker.end();
    });

    test('object containing a property with a nested object', () {
      String contents = """
{
  "foo": { "a"  :  "b"   ,  "c"   :   null }
}
""";
      _LoggingListener listener = new _LoggingListener(contents);
      JsonParser parser = new JsonParser(contents, listener);
      parser.parse();

      _LoggingEventChecker checker = new _LoggingEventChecker(listener);
      checker.event(_LoggingEvent.BEGIN_OBJECT, 1, 1, 1, 1);
      checker.event(_LoggingEvent.STRING_VALUE, 2, 3, 2, 8, "foo");
      checker.event(_LoggingEvent.PROPERTY_NAME, 2, 3, 2, 8);
      checker.event(_LoggingEvent.BEGIN_OBJECT, 2, 10, 2, 10);
      checker.event(_LoggingEvent.STRING_VALUE, 2, 12, 2, 15, "a");
      checker.event(_LoggingEvent.PROPERTY_NAME, 2, 12, 2, 15);
      checker.event(_LoggingEvent.STRING_VALUE, 2, 20, 2, 23, "b");
      checker.event(_LoggingEvent.PROPERTY_VALUE, 2, 20, 2, 23);
      checker.event(_LoggingEvent.STRING_VALUE, 2, 29, 2, 32, "c");
      checker.event(_LoggingEvent.PROPERTY_NAME, 2, 29, 2, 32);
      checker.event(_LoggingEvent.NULL_VALUE, 2, 39, 2, 43, null);
      checker.event(_LoggingEvent.PROPERTY_VALUE, 2, 39, 2, 43);
      checker.event(_LoggingEvent.END_OBJECT, 2, 10, 2, 45);
      checker.event(_LoggingEvent.PROPERTY_VALUE, 2, 10, 2, 45);
      checker.event(_LoggingEvent.END_OBJECT, 1, 1, 3, 2);
      checker.end();
    });

    test('comprehensive json document', () {
      String contents = """
{
  "foo": 1,
  "bar": [1, 2, 3, 4, 5],
  "blah": "boo",
  "bob": [{ "bar": {}, "blah": [], "bob": true }]
}
""";
      _LoggingListener listener = new _LoggingListener(contents);
      JsonParser parser = new JsonParser(contents, listener);
      parser.parse();

      _LoggingEventChecker checker = new _LoggingEventChecker(listener);
      checker.event(_LoggingEvent.BEGIN_OBJECT, 1, 1, 1, 1);
      checker.event(_LoggingEvent.STRING_VALUE, 2, 3, 2, 8, "foo");
      checker.event(_LoggingEvent.PROPERTY_NAME, 2, 3, 2, 8);
      checker.event(_LoggingEvent.NUMBER_VALUE, 2, 10, 2, 11, 1);
      checker.event(_LoggingEvent.PROPERTY_VALUE, 2, 10, 2, 11);
      checker.event(_LoggingEvent.STRING_VALUE, 3, 3, 3, 8, "bar");
      checker.event(_LoggingEvent.PROPERTY_NAME, 3, 3, 3, 8);
      checker.event(_LoggingEvent.BEGIN_ARRAY, 3, 10, 3, 10);
      checker.event(_LoggingEvent.NUMBER_VALUE, 3, 11, 3, 12, 1);
      checker.event(_LoggingEvent.ARRAY_ELEMENT, 3, 11, 3, 12);
      checker.event(_LoggingEvent.NUMBER_VALUE, 3, 14, 3, 15, 2);
      checker.event(_LoggingEvent.ARRAY_ELEMENT, 3, 14, 3, 15);
      checker.event(_LoggingEvent.NUMBER_VALUE, 3, 17, 3, 18, 3);
      checker.event(_LoggingEvent.ARRAY_ELEMENT, 3, 17, 3, 18);
      checker.event(_LoggingEvent.NUMBER_VALUE, 3, 20, 3, 21, 4);
      checker.event(_LoggingEvent.ARRAY_ELEMENT, 3, 20, 3, 21);
      checker.event(_LoggingEvent.NUMBER_VALUE, 3, 23, 3, 24, 5);
      checker.event(_LoggingEvent.ARRAY_ELEMENT, 3, 23, 3, 24);
      checker.event(_LoggingEvent.END_ARRAY, 3, 10, 3, 25);
      checker.event(_LoggingEvent.PROPERTY_VALUE, 3, 10, 3, 25);
      checker.event(_LoggingEvent.STRING_VALUE, 4, 3, 4, 9, "blah");
      checker.event(_LoggingEvent.PROPERTY_NAME, 4, 3, 4, 9);
      checker.event(_LoggingEvent.STRING_VALUE, 4, 11, 4, 16, "boo");
      checker.event(_LoggingEvent.PROPERTY_VALUE, 4, 11, 4, 16);
      checker.event(_LoggingEvent.STRING_VALUE, 5, 3, 5, 8, "bob");
      checker.event(_LoggingEvent.PROPERTY_NAME, 5, 3, 5, 8);
      checker.event(_LoggingEvent.BEGIN_ARRAY, 5, 10, 5, 10);
      checker.event(_LoggingEvent.BEGIN_OBJECT, 5, 11, 5, 11);
      checker.event(_LoggingEvent.STRING_VALUE, 5, 13, 5, 18, "bar");
      checker.event(_LoggingEvent.PROPERTY_NAME, 5, 13, 5, 18);
      checker.event(_LoggingEvent.BEGIN_OBJECT, 5, 20, 5, 20);
      checker.event(_LoggingEvent.END_OBJECT, 5, 20, 5, 22);
      checker.event(_LoggingEvent.PROPERTY_VALUE, 5, 20, 5, 22);
      checker.event(_LoggingEvent.STRING_VALUE, 5, 24, 5, 30, "blah");
      checker.event(_LoggingEvent.PROPERTY_NAME, 5, 24, 5, 30);
      checker.event(_LoggingEvent.BEGIN_ARRAY, 5, 32, 5, 32);
      checker.event(_LoggingEvent.END_ARRAY, 5, 32, 5, 34);
      checker.event(_LoggingEvent.PROPERTY_VALUE, 5, 32, 5, 34);
      checker.event(_LoggingEvent.STRING_VALUE, 5, 36, 5, 41, "bob");
      checker.event(_LoggingEvent.PROPERTY_NAME, 5, 36, 5, 41);
      checker.event(_LoggingEvent.BOOL_VALUE, 5, 43, 5, 47, true);
      checker.event(_LoggingEvent.PROPERTY_VALUE, 5, 43, 5, 47);
      checker.event(_LoggingEvent.END_OBJECT, 5, 11, 5, 49);
      checker.event(_LoggingEvent.ARRAY_ELEMENT, 5, 11, 5, 49);
      checker.event(_LoggingEvent.END_ARRAY, 5, 10, 5, 50);
      checker.event(_LoggingEvent.PROPERTY_VALUE, 5, 10, 5, 50);
      checker.event(_LoggingEvent.END_OBJECT, 1, 1, 6, 2);
      checker.end();
    });
  });
}

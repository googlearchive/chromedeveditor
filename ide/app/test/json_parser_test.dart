// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.jason_parser_test;

import 'package:unittest/unittest.dart';
import '../lib/json/json_parser.dart';
import '../lib/json/utils.dart';

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

  _LoggingEvent(this.kind, this.span, this.value, this.startLineColumn, this.endLineColumn);
}

/**
 * Json parse listener that collects all events into a flat list of [_LoggingEvent].
 */
class _LoggingListener extends JsonListener {
  final String contents;
  final List<_LoggingEvent> events = new List();
  StringLineOffsets lineOffsets;

  _LoggingListener(this.contents) {
    lineOffsets = new StringLineOffsets(contents);
  }
  void _addEvent(int kind, Span span, var value) {
    events.add(new _LoggingEvent(kind, span, value, lineOffsets.getLineColumn(span.start), lineOffsets.getLineColumn(span.end)));
  }
  void handleString(Span span, String value) {
    _addEvent(_LoggingEvent.STRING_VALUE, span, value);
  }
  void handleNumber(Span span, num value) {
    _addEvent(_LoggingEvent.NUMBER_VALUE, span, value);
  }
  void handleBool(Span span, bool value) {
    _addEvent(_LoggingEvent.BOOL_VALUE, span, value);
  }
  void handleNull(Span span) {
    _addEvent(_LoggingEvent.NULL_VALUE, span, null);
  }
  void beginObject(int position) {
    _addEvent(_LoggingEvent.BEGIN_OBJECT, new Span(position, position), null);
  }
  void propertyName(Span span) {
    _addEvent(_LoggingEvent.PROPERTY_NAME, span, null);
  }
  void propertyValue(Span span) {
    _addEvent(_LoggingEvent.PROPERTY_VALUE, span, null);
  }
  void endObject(Span span) {
    _addEvent(_LoggingEvent.END_OBJECT, span, null);
  }
  void beginArray(int position) {
    _addEvent(_LoggingEvent.BEGIN_ARRAY, new Span(position, position), null);
  }
  void arrayElement(Span span) {
    _addEvent(_LoggingEvent.ARRAY_ELEMENT, span, null);
  }
  void endArray(Span span) {
    _addEvent(_LoggingEvent.END_ARRAY, span, null);
  }
}

void defineTests() {
  void expectEvent(_LoggingListener listener, int eventIndex, int kind, int startLine, int startColumn, int endLine, int endColumn, [var value]) {
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
  }

  void expectEventEnd(_LoggingListener listener, int eventIndex) {
    expect(eventIndex, equals(listener.events.length));
  }

  group('Json parser tests -', () {
    test('empty object', () {
      String contents = """
{
}
""";
      _LoggingListener listener = new _LoggingListener(contents);
      JsonParser parser = new JsonParser(contents, listener);
      parser.parse();
      int eventIndex = 0;
      expectEvent(listener, eventIndex++, _LoggingEvent.BEGIN_OBJECT, 1, 1, 1, 1);
      expectEvent(listener, eventIndex++, _LoggingEvent.END_OBJECT, 1, 1, 2, 2);
      expectEventEnd(listener, eventIndex++);
    });

    test('empty array', () {
      String contents = """
[
]
""";
      _LoggingListener listener = new _LoggingListener(contents);
      JsonParser parser = new JsonParser(contents, listener);
      parser.parse();
      int eventIndex = 0;
      expectEvent(listener, eventIndex++, _LoggingEvent.BEGIN_ARRAY, 1, 1, 1, 1);
      expectEvent(listener, eventIndex++, _LoggingEvent.END_ARRAY, 1, 1, 2, 2);
      expectEventEnd(listener, eventIndex++);
    });

    test('single number', () {
      String contents = """
123
""";
      _LoggingListener listener = new _LoggingListener(contents);
      JsonParser parser = new JsonParser(contents, listener);
      parser.parse();
      int eventIndex = 0;
      expectEvent(listener, eventIndex++, _LoggingEvent.NUMBER_VALUE, 1, 1, 1, 4, 123);
      expectEventEnd(listener, eventIndex++);
    });

    test('single string literal', () {
      String contents = """
"hhh"
""";
      _LoggingListener listener = new _LoggingListener(contents);
      JsonParser parser = new JsonParser(contents, listener);
      parser.parse();
      int eventIndex = 0;
      expectEvent(listener, eventIndex++, _LoggingEvent.STRING_VALUE, 1, 1, 1, 6, "hhh");
      expectEventEnd(listener, eventIndex++);
    });

    test('single "true" literal', () {
      String contents = """
true
""";
      _LoggingListener listener = new _LoggingListener(contents);
      JsonParser parser = new JsonParser(contents, listener);
      parser.parse();
      int eventIndex = 0;
      expectEvent(listener, eventIndex++, _LoggingEvent.BOOL_VALUE, 1, 1, 1, 5, true);
      expectEventEnd(listener, eventIndex++);
    });

    test('single "false" literal', () {
      String contents = """
false
""";
      _LoggingListener listener = new _LoggingListener(contents);
      JsonParser parser = new JsonParser(contents, listener);
      parser.parse();
      int eventIndex = 0;
      expectEvent(listener, eventIndex++, _LoggingEvent.BOOL_VALUE, 1, 1, 1, 5, false);
      expectEventEnd(listener, eventIndex++);
    });

    test('single "null" literal', () {
      String contents = """
null
""";
      _LoggingListener listener = new _LoggingListener(contents);
      JsonParser parser = new JsonParser(contents, listener);
      parser.parse();
      int eventIndex = 0;
      expectEvent(listener, eventIndex++, _LoggingEvent.NULL_VALUE, 1, 1, 1, 5, null);
      expectEventEnd(listener, eventIndex++);
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
      int eventIndex = 0;
      expectEvent(listener, eventIndex++, _LoggingEvent.BEGIN_OBJECT, 1, 1, 1, 1);
      expectEvent(listener, eventIndex++, _LoggingEvent.STRING_VALUE, 2, 3, 2, 8, "foo");
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_NAME, 2, 3, 2, 8);
      expectEvent(listener, eventIndex++, _LoggingEvent.NUMBER_VALUE, 2, 10, 2, 11, 1);
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_VALUE, 2, 10, 2, 11);
      expectEvent(listener, eventIndex++, _LoggingEvent.END_OBJECT, 1, 1, 3, 2);
      expectEventEnd(listener, eventIndex++);
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
      int eventIndex = 0;
      expectEvent(listener, eventIndex++, _LoggingEvent.BEGIN_OBJECT, 1, 1, 1, 1);
      expectEvent(listener, eventIndex++, _LoggingEvent.STRING_VALUE, 2, 3, 2, 8, "foo");
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_NAME, 2, 3, 2, 8);
      expectEvent(listener, eventIndex++, _LoggingEvent.BEGIN_OBJECT, 2, 10, 2, 10);
      expectEvent(listener, eventIndex++, _LoggingEvent.STRING_VALUE, 2, 12, 2, 15, "a");
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_NAME, 2, 12, 2, 15);
      expectEvent(listener, eventIndex++, _LoggingEvent.STRING_VALUE, 2, 20, 2, 23, "b");
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_VALUE, 2, 20, 2, 23);
      expectEvent(listener, eventIndex++, _LoggingEvent.STRING_VALUE, 2, 29, 2, 32, "c");
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_NAME, 2, 29, 2, 32);
      expectEvent(listener, eventIndex++, _LoggingEvent.NULL_VALUE, 2, 39, 2, 43, null);
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_VALUE, 2, 39, 2, 43);
      expectEvent(listener, eventIndex++, _LoggingEvent.END_OBJECT, 2, 10, 2, 45);
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_VALUE, 2, 10, 2, 45);
      expectEvent(listener, eventIndex++, _LoggingEvent.END_OBJECT, 1, 1, 3, 2);
      expectEventEnd(listener, eventIndex++);
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
      int eventIndex = 0;
      expectEvent(listener, eventIndex++, _LoggingEvent.BEGIN_OBJECT, 1, 1, 1, 1);
      expectEvent(listener, eventIndex++, _LoggingEvent.STRING_VALUE, 2, 3, 2, 8, "foo");
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_NAME, 2, 3, 2, 8);
      expectEvent(listener, eventIndex++, _LoggingEvent.NUMBER_VALUE, 2, 10, 2, 11, 1);
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_VALUE, 2, 10, 2, 11);
      expectEvent(listener, eventIndex++, _LoggingEvent.STRING_VALUE, 3, 3, 3, 8, "bar");
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_NAME, 3, 3, 3, 8);
      expectEvent(listener, eventIndex++, _LoggingEvent.BEGIN_ARRAY, 3, 10, 3, 10);
      expectEvent(listener, eventIndex++, _LoggingEvent.NUMBER_VALUE, 3, 11, 3, 12, 1);
      expectEvent(listener, eventIndex++, _LoggingEvent.ARRAY_ELEMENT, 3, 11, 3, 12);
      expectEvent(listener, eventIndex++, _LoggingEvent.NUMBER_VALUE, 3, 14, 3, 15, 2);
      expectEvent(listener, eventIndex++, _LoggingEvent.ARRAY_ELEMENT, 3, 14, 3, 15);
      expectEvent(listener, eventIndex++, _LoggingEvent.NUMBER_VALUE, 3, 17, 3, 18, 3);
      expectEvent(listener, eventIndex++, _LoggingEvent.ARRAY_ELEMENT, 3, 17, 3, 18);
      expectEvent(listener, eventIndex++, _LoggingEvent.NUMBER_VALUE, 3, 20, 3, 21, 4);
      expectEvent(listener, eventIndex++, _LoggingEvent.ARRAY_ELEMENT, 3, 20, 3, 21);
      expectEvent(listener, eventIndex++, _LoggingEvent.NUMBER_VALUE, 3, 23, 3, 24, 5);
      expectEvent(listener, eventIndex++, _LoggingEvent.ARRAY_ELEMENT, 3, 23, 3, 24);
      expectEvent(listener, eventIndex++, _LoggingEvent.END_ARRAY, 3, 10, 3, 25);
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_VALUE, 3, 10, 3, 25);
      expectEvent(listener, eventIndex++, _LoggingEvent.STRING_VALUE, 4, 3, 4, 9, "blah");
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_NAME, 4, 3, 4, 9);
      expectEvent(listener, eventIndex++, _LoggingEvent.STRING_VALUE, 4, 11, 4, 16, "boo");
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_VALUE, 4, 11, 4, 16);
      expectEvent(listener, eventIndex++, _LoggingEvent.STRING_VALUE, 5, 3, 5, 8, "bob");
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_NAME, 5, 3, 5, 8);
      expectEvent(listener, eventIndex++, _LoggingEvent.BEGIN_ARRAY, 5, 10, 5, 10);
      expectEvent(listener, eventIndex++, _LoggingEvent.BEGIN_OBJECT, 5, 11, 5, 11);
      expectEvent(listener, eventIndex++, _LoggingEvent.STRING_VALUE, 5, 13, 5, 18, "bar");
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_NAME, 5, 13, 5, 18);
      expectEvent(listener, eventIndex++, _LoggingEvent.BEGIN_OBJECT, 5, 20, 5, 20);
      expectEvent(listener, eventIndex++, _LoggingEvent.END_OBJECT, 5, 20, 5, 22);
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_VALUE, 5, 20, 5, 22);
      expectEvent(listener, eventIndex++, _LoggingEvent.STRING_VALUE, 5, 24, 5, 30, "blah");
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_NAME, 5, 24, 5, 30);
      expectEvent(listener, eventIndex++, _LoggingEvent.BEGIN_ARRAY, 5, 32, 5, 32);
      expectEvent(listener, eventIndex++, _LoggingEvent.END_ARRAY, 5, 32, 5, 34);
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_VALUE, 5, 32, 5, 34);
      expectEvent(listener, eventIndex++, _LoggingEvent.STRING_VALUE, 5, 36, 5, 41, "bob");
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_NAME, 5, 36, 5, 41);
      expectEvent(listener, eventIndex++, _LoggingEvent.BOOL_VALUE, 5, 43, 5, 47, true);
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_VALUE, 5, 43, 5, 47);
      expectEvent(listener, eventIndex++, _LoggingEvent.END_OBJECT, 5, 11, 5, 49);
      expectEvent(listener, eventIndex++, _LoggingEvent.ARRAY_ELEMENT, 5, 11, 5, 49);
      expectEvent(listener, eventIndex++, _LoggingEvent.END_ARRAY, 5, 10, 5, 50);
      expectEvent(listener, eventIndex++, _LoggingEvent.PROPERTY_VALUE, 5, 10, 5, 50);
      expectEvent(listener, eventIndex++, _LoggingEvent.END_OBJECT, 1, 1, 6, 2);
      expectEventEnd(listener, eventIndex++);
    });
  });
}

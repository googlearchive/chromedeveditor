// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.json_validator_test;

import 'package:unittest/unittest.dart';

import '../lib/json/json_parser.dart';
import '../lib/json/json_validator.dart';
import '../lib/json/json_utils.dart';

/**
 * Event data collected for each json validator event.
 */
class _ValidatorEvent {
  static const int ROOT_VALUE = 1;
  static const int ENTER_OBJECT = 2;
  static const int LEAVE_OBJECT = 3;
  static const int PROPERTY_NAME = 4;
  static const int PROPERTY_VALUE = 5;
  static const int ENTER_ARRAY = 6;
  static const int LEAVE_ARRAY = 7;
  static const int ARRAY_ELEMENT = 8;

  final int validatorId;
  final int kind;
  final Span span;
  final value;
  final LineColumn startLineColumn;
  final LineColumn endLineColumn;

  _ValidatorEvent(
      this.validatorId,
      this.kind,
      this.span,
      this.value,
      this.startLineColumn,
      this.endLineColumn);
}

/**
 * Common base class for both json logging validator implementations.
 */
abstract class _LoggingValidatorBase implements JsonValidator {
  void _addEvent(int kind, [Span span, var value]) {
    LineColumn startLineColumn;
    LineColumn endLineColumn;
    if (span != null) {
      startLineColumn = lineOffsets.getLineColumn(span.start);
      endLineColumn = lineOffsets.getLineColumn(span.end);
    }
    events.add(new _ValidatorEvent(
        id,
        kind,
        span,
        value,
        startLineColumn,
        endLineColumn));
  }

  void handleRootValue(ValueEntity entity) {
    _addEvent(_ValidatorEvent.ROOT_VALUE, entity.span, entity.value);
  }

  JsonValidator enterArray() {
    _addEvent(_ValidatorEvent.ENTER_ARRAY);
    return createChildValidator(this);
  }

  void leaveArray(ArrayEntity entity) {
    _addEvent(_ValidatorEvent.LEAVE_ARRAY, entity.span);
  }

  void arrayElement(JsonEntity entity) {
    var value = (entity is ValueEntity ? entity.value : null);
    _addEvent(_ValidatorEvent.ARRAY_ELEMENT, entity.span, value);
  }

  JsonValidator enterObject() {
    _addEvent(_ValidatorEvent.ENTER_OBJECT);
    return createChildValidator(this);
  }

  void leaveObject(ObjectEntity entity) {
    _addEvent(_ValidatorEvent.LEAVE_OBJECT, entity.span);
  }

  JsonValidator propertyName(StringEntity entity) {
    _addEvent(_ValidatorEvent.PROPERTY_NAME, entity.span, entity.text);
    checkObjectPropertyName(entity);
    return createChildValidator(this);
  }

  void propertyValue(JsonEntity entity) {
    var value = (entity is ValueEntity ? entity.value : null);
    _addEvent(_ValidatorEvent.PROPERTY_VALUE, entity.span, value);
  }

  StringLineOffsets get lineOffsets;
  List<_ValidatorEvent> get events;
  int get id;
  JsonValidator createChildValidator(JsonValidator parent);
  void checkObjectPropertyName(StringEntity name);
}

/**
 * The logging validator used at the top of the json document.
 */
class _LoggingValidator extends _LoggingValidatorBase {
  static const String errorId = "ERROR_PROPERTY_NAME";
  final String contents;
  final _LoggingErrorCollector errorCollector;
  final List<_ValidatorEvent> events = new List();
  final StringLineOffsets lineOffsets;
  final Set<String> errorPropertyNames = new Set<String>();
  int nextChildId;

  _LoggingValidator(String contents, this.errorCollector)
    : this.contents = contents,
      this.lineOffsets = new StringLineOffsets(contents) {
    nextChildId = 0;
  }

  int get id => 0;

  JsonValidator createChildValidator(JsonValidator parent) {
    return new _ChildLoggingValidator(this, parent, ++nextChildId);
  }

  void addErrorPropertyName(String name) {
    errorPropertyNames.add(name);
  }

  void checkObjectPropertyName(StringEntity name) {
    if (errorPropertyNames.contains(name.text)) {
      errorCollector.addMessage(errorId, name.span, "Invalid property name");
    }
  }
}

/**
 * The logging validator used when traversing json containers.
 */
class _ChildLoggingValidator extends _LoggingValidatorBase {
  final _LoggingValidator root;
  final JsonValidator parent;
  final int id;

  _ChildLoggingValidator(this.root, this.parent, this.id);

  JsonValidator createChildValidator(JsonValidator parent) {
    return root.createChildValidator(parent);
  }

  void checkObjectPropertyName(StringEntity name) {
    root.checkObjectPropertyName(name);
  }

  List<_ValidatorEvent> get events => root.events;
  StringLineOffsets get lineOffsets => root.lineOffsets;
}

/**
 * Event data collected for each validation error.
 */
class _ErrorEvent {
  final messageId;
  final Span span;
  final String message;

  _ErrorEvent(this.messageId, this.span, this.message);
}

/**
 * Sink for json validation errors.
 */
class _LoggingErrorCollector implements ErrorCollector {
  final List<_ErrorEvent> events = new List<_ErrorEvent>();

  void addMessage(String messageId, Span span, String message) {
    _ErrorEvent event = new _ErrorEvent(messageId, span, message);
    events.add(event);
  }
}

class _LoggingEventChecker {
  final _LoggingValidator validator;
  int eventIndex;
  int errorIndex;

  _LoggingEventChecker(this.validator): eventIndex = 0, errorIndex = 0;

  void event(
      int validatorId,
      int kind,
      [int startLine,
      int startColumn,
      int endLine,
      int endColumn,
      var value]) {
    expect(eventIndex, lessThan(validator.events.length));
    _ValidatorEvent event = validator.events[eventIndex];
    if (value == null) {
      value = event.value;
    }
    expect(event.validatorId, equals(validatorId));
    expect(event.kind, equals(kind));
    if (startLine != null) {
      expect(event.startLineColumn.line, equals(startLine));
    }
    if (startColumn != null) {
      expect(event.startLineColumn.column, equals(startColumn));
    }
    if (endLine != null) {
      expect(event.endLineColumn.line, equals(endLine));
    }
    if (endColumn != null) {
      expect(event.endLineColumn.column, equals(endColumn));
    }
    expect(event.value, equals(value));
    eventIndex++;
  }

  void value(int validatorId, int kind, var value) {
    event(validatorId, kind, null, null, null, null, value);
  }

  void end() {
    expect(eventIndex, equals(validator.events.length));
  }

  void error(String messageId) {
    expect(errorIndex, lessThan(validator.errorCollector.events.length));
    _ErrorEvent event = validator.errorCollector.events[errorIndex];
    expect(event.messageId, equals(messageId));
    errorIndex++;
  }

  void errorEnd() {
    expect(errorIndex, equals(validator.errorCollector.events.length));
  }
}

void defineTests() {
  _LoggingValidator validateDocument(
      String contents,
      [void init(_LoggingValidator validator)]) {
    _LoggingErrorCollector errorCollector = new _LoggingErrorCollector();
    _LoggingValidator validator =
        new _LoggingValidator(contents, errorCollector);
    if (init != null){
      init(validator);
    }
    JsonValidatorListener listener =
        new JsonValidatorListener(errorCollector, validator);
    JsonParser parser = new JsonParser(contents, listener);
    parser.parse();
    return validator;
  }

  group('Json validator tests -', () {
    test('empty object', () {
      String contents = """
{
}
""";
      _LoggingValidator validator = validateDocument(contents);

      _LoggingEventChecker checker = new _LoggingEventChecker(validator);
      checker.event(0, _ValidatorEvent.ENTER_OBJECT);
      checker.event(0, _ValidatorEvent.LEAVE_OBJECT, 1, 1, 2, 2);
      checker.end();
    });

    test('empty array', () {
      String contents = """
[
]
""";
      _LoggingValidator validator = validateDocument(contents);

      _LoggingEventChecker checker = new _LoggingEventChecker(validator);
      checker.event(0, _ValidatorEvent.ENTER_ARRAY);
      checker.event(0, _ValidatorEvent.LEAVE_ARRAY, 1, 1, 2, 2);
      checker.end();
    });

    test('single root value', () {
      String contents = """
123456
""";
      _LoggingValidator validator = validateDocument(contents);

      _LoggingEventChecker checker = new _LoggingEventChecker(validator);
      checker.event(0, _ValidatorEvent.ROOT_VALUE, 1, 1, 1, 7, 123456);
      checker.end();
    });

    test('object containing single property and value', () {
      String contents = """
{
  "foo": true
}
""";
      _LoggingValidator validator = validateDocument(contents);

      _LoggingEventChecker checker = new _LoggingEventChecker(validator);
      checker.event(0, _ValidatorEvent.ENTER_OBJECT);
      checker.event(1, _ValidatorEvent.PROPERTY_NAME, 2, 3, 2, 8, "foo");
      checker.event(2, _ValidatorEvent.PROPERTY_VALUE, 2, 10, 2, 14, true);
      checker.event(0, _ValidatorEvent.LEAVE_OBJECT, 1, 1, 3, 2);
      checker.end();
    });

    test('object containing an array and an object property', () {
      String contents = """
{
  "foo": [1, "foo"],
  "bar": { "blah": false, "test": 1 }
}
""";
      _LoggingValidator validator = validateDocument(contents);

      _LoggingEventChecker checker = new _LoggingEventChecker(validator);
      checker.event(0, _ValidatorEvent.ENTER_OBJECT);
      checker.value(1, _ValidatorEvent.PROPERTY_NAME, "foo");
      checker.event(2, _ValidatorEvent.ENTER_ARRAY);
      checker.value(3, _ValidatorEvent.ARRAY_ELEMENT, 1);
      checker.value(3, _ValidatorEvent.ARRAY_ELEMENT, "foo");
      checker.event(2, _ValidatorEvent.LEAVE_ARRAY);
      checker.event(2, _ValidatorEvent.PROPERTY_VALUE);
      checker.value(1, _ValidatorEvent.PROPERTY_NAME, "bar");
      checker.event(4, _ValidatorEvent.ENTER_OBJECT);
      checker.value(5, _ValidatorEvent.PROPERTY_NAME, "blah");
      checker.value(6, _ValidatorEvent.PROPERTY_VALUE, false);
      checker.value(5, _ValidatorEvent.PROPERTY_NAME, "test");
      checker.value(7, _ValidatorEvent.PROPERTY_VALUE, 1);
      checker.event(4, _ValidatorEvent.LEAVE_OBJECT);
      checker.event(4, _ValidatorEvent.PROPERTY_VALUE, 3, 10, 3, 38);
      checker.event(0, _ValidatorEvent.LEAVE_OBJECT, 1, 1, 4, 2);
      checker.end();
    });

    test('errors created for invalid property names', () {
      String contents = """
{
  "foo": 0,
  "boo": 2,
  "blah": { "boo": 1, "bar": true }
}
""";
      _LoggingValidator validator = validateDocument(contents, (validator) {
        validator.addErrorPropertyName("boo");
      });

      _LoggingEventChecker checker = new _LoggingEventChecker(validator);
      checker.error(_LoggingValidator.errorId);
      checker.error(_LoggingValidator.errorId);
      checker.errorEnd();
    });
  });
}

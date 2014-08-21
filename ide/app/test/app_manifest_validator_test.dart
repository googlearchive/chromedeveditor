// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.app_manifest_validator_test;

import 'package:unittest/unittest.dart';

import '../lib/apps/app_manifest_validator.dart';
import '../lib/json/json_parser.dart';
import '../lib/json/json_validator.dart';

/**
 * Event data collected for each validation error.
 */
class _ErrorEvent {
  final Span span;
  final String message;

  _ErrorEvent(this.span, this.message);
}

/**
 * Sink for json validation errors.
 */
class _LoggingErrorCollector implements ErrorCollector {
  final List<_ErrorEvent> events = new List<_ErrorEvent>();
  void addMessage(Span span, String message) {
    _ErrorEvent event = new _ErrorEvent(span, message);
    events.add(event);
  }
}

class _LoggingEventChecker {
  final _LoggingErrorCollector errorCollector;
  int errorIndex;

  _LoggingEventChecker(this.errorCollector): errorIndex = 0;

  void error([String message]) {
    expect(errorIndex, lessThan(errorCollector.events.length));
    _ErrorEvent event = errorCollector.events[errorIndex];
    if (message != null) {
      expect(event.message, equals(message));
    }
    errorIndex++;
  }

  void end() {
    expect(errorIndex, equals(errorCollector.events.length));
  }
}

_LoggingErrorCollector _validateDocument(String contents) {
  _LoggingErrorCollector errorCollector = new _LoggingErrorCollector();
  AppManifestValidator validator = new AppManifestValidator(errorCollector);
  JsonValidatorListener listener =
      new JsonValidatorListener(errorCollector, validator);
  JsonParser parser = new JsonParser(contents, listener);
  parser.parse();
  return errorCollector;
}

void defineTests() {
  group('manifest-json validator tests -', () {
    test('manifest may be an empty object', () {
      String contents = """
{
}
""";
      _LoggingErrorCollector errorCollector = _validateDocument(contents);

      _LoggingEventChecker checker = new _LoggingEventChecker(errorCollector);
      checker.end();
    });

    test('manifest cannot be a single value', () {
      String contents = """
123
""";
      _LoggingErrorCollector errorCollector = _validateDocument(contents);

      _LoggingEventChecker checker = new _LoggingEventChecker(errorCollector);
      checker.error();
      checker.end();
    });

    test('"manifest_version" cannot be a string', () {
      String contents = """
{
  "manifest_version": "string value"
}
""";
      _LoggingErrorCollector errorCollector = _validateDocument(contents);

      _LoggingEventChecker checker = new _LoggingEventChecker(errorCollector);
      checker.error();
      checker.end();
    });

    test('"manifest_version" must be a number', () {
      String contents = """
{
  "manifest_version": 2
}
""";
      _LoggingErrorCollector errorCollector = _validateDocument(contents);

      _LoggingEventChecker checker = new _LoggingEventChecker(errorCollector);
      checker.end();
    });

    test('"scripts" may be an empty array', () {
      String contents = """
{
  "app": { "background": { "scripts": [] } }
}
""";
      _LoggingErrorCollector errorCollector = _validateDocument(contents);

      _LoggingEventChecker checker = new _LoggingEventChecker(errorCollector);
      checker.end();
    });

    test('"scripts" may be an array of strings', () {
      String contents = """
{
  "app": { "background": { "scripts": [ "string-value" ] } }
}
""";
      _LoggingErrorCollector errorCollector = _validateDocument(contents);

      _LoggingEventChecker checker = new _LoggingEventChecker(errorCollector);
      checker.end();
    });

    test('"scripts" cannot contain a number in the array', () {
      String contents = """
{
  "app": { "background": { "scripts": [ "string-value", 1, "boo" ] } }
}
""";
      _LoggingErrorCollector errorCollector = _validateDocument(contents);

      _LoggingEventChecker checker = new _LoggingEventChecker(errorCollector);
      checker.error();
      checker.end();
    });

    test('"scripts" cannot be an object', () {
      String contents = """
{
  "app": { "background": { "scripts": { "foo": "string-value" } } }
}
""";
      _LoggingErrorCollector errorCollector = _validateDocument(contents);

      _LoggingEventChecker checker = new _LoggingEventChecker(errorCollector);
      checker.error();
      checker.end();
    });

  });
}

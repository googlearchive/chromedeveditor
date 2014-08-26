// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.app_manifest_validator_test;

import 'package:unittest/unittest.dart';

import '../lib/apps/app_manifest_validator.dart';
import '../lib/json/json_parser.dart';
import '../lib/json/json_schema_validator.dart' as json_schema_validator;
import '../lib/json/json_validator.dart' as json_validator;

/**
 * Event data collected for each validation error.
 */
class _ErrorEvent {
  final String messageId;
  final Span span;
  final String message;

  _ErrorEvent(this.messageId, this.span, this.message);
}

/**
 * Sink for json validation errors.
 */
class _LoggingErrorCollector implements json_validator.ErrorCollector {
  final List<_ErrorEvent> events = new List<_ErrorEvent>();

  void addMessage(String messageId, Span span, String message) {
    _ErrorEvent event = new _ErrorEvent(messageId, span, message);
    events.add(event);
  }
}

class _LoggingEventChecker {
  final _LoggingErrorCollector errorCollector;
  int errorIndex;

  _LoggingEventChecker(this.errorCollector): errorIndex = 0;

  void error(String messageId) {
    expect(errorIndex, lessThan(errorCollector.events.length));
    _ErrorEvent event = errorCollector.events[errorIndex];
    expect(event.messageId, equals(messageId));
    errorIndex++;
  }

  void end() {
    expect(errorIndex, equals(errorCollector.events.length));
  }
}

_LoggingErrorCollector _validateDocument(String contents) {
  _LoggingErrorCollector errorCollector = new _LoggingErrorCollector();
  AppManifestValidator validator = new AppManifestValidator(errorCollector);
  json_validator.JsonValidatorListener listener =
      new json_validator.JsonValidatorListener(errorCollector, validator);
  JsonParser parser = new JsonParser(contents, listener);
  parser.parse();
  return errorCollector;
}

void _validate(String contents, List<String> errorIds) {
  _LoggingErrorCollector errorCollector = _validateDocument(contents);
  _LoggingEventChecker checker = new _LoggingEventChecker(errorCollector);
  errorIds.forEach((id) => checker.error(id));
  checker.end();
}

void defineTests() {
  group('manifest-json validator tests -', () {
    test('Schema definition is correct.', () {
      var errorCollector = new _LoggingErrorCollector();
      var validator = new AppManifestValidator(errorCollector);
      expect(
          validator.factory.validateSchemaForTesting(AppManifestSchema),
          isTrue);
    });

    test('manifest may be an empty object', () {
      String contents = """{}""";
      _validate(contents, []);
    });

    test('manifest cannot be a single value', () {
      String contents = """123""";
      _validate(contents, [json_schema_validator.ErrorIds.TOP_LEVEL_OBJECT]);
    });

    test('"manifest_version" cannot be a string', () {
      String contents = """{ "manifest_version": "string value" } """;
      _validate(contents, [json_schema_validator.ErrorIds.INTEGER_EXPECTED]);
    });

    test('"manifest_version" value 1 is obsolete', () {
      String contents = """{ "manifest_version": 1 } """;
      _validate(contents, [ErrorIds.OBSOLETE_MANIFEST_VERSION]);
    });

    test('"manifest_version" must be a number', () {
      String contents = """{ "manifest_version": 2 }""";
      _validate(contents, []);
    });

    test('"scripts" may be an empty array', () {
      String contents = """{"app": {"background": {"scripts": []}}} """;
      _validate(contents, []);
    });

    test('"scripts" may be an array of strings', () {
      String contents = """{"app": {"background": {"scripts": ["s"]}}}""";
      _validate(contents, []);
    });

    test('"scripts" cannot contain a number in the array', () {
      String contents = """{"app": {"background": {"scripts": ["s", 1]}}}""";
      _validate(contents, [json_schema_validator.ErrorIds.STRING_EXPECTED]);
    });

    test('"scripts" cannot be an object', () {
      String contents = """{"app": {"background": {"scripts": {"f": "s"}}}}""";
      _validate(contents, [json_schema_validator.ErrorIds.ARRAY_EXPECTED]);
    });

    test('"sockets" may contain 3 known top level properties', () {
      String contents = """{
  "sockets": { "udp": {}, "tcp": {}, "tcpServer": {} }
}
""";
      _validate(contents, []);
    });

    test('"sockets" host pattern may be a single value or an array', () {
      String contents = """{
  "sockets": { "udp": { "send": "*.*", "bind": ["*:80", "*:8080"] } }
}
""";
      _validate(contents, []);
    });

    test('"sockets" cannot contain a unknown property', () {
      String contents = """{ "sockets": { "foo": {} } }""";
      _validate(
          contents, [json_schema_validator.ErrorIds.UNKNOWN_PROPERTY_NAME]);
    });

    test('"permissions" cannot be a dictionary', () {
      String contents = """{ "permissions": {"foo": "bar"} }""";
      _validate(contents, [json_schema_validator.ErrorIds.ARRAY_EXPECTED]);
    });

    test('"permissions" cannot contain an unknown permission', () {
      String contents = """{ "permissions": ["foo"] }""";
      _validate(contents, [ErrorIds.INVALID_PERMISSION]);
    });

    test('"permissions" may contain known permissions', () {
      String contents = """{ "permissions": ["usb", "tabs", "bookmarks"] }""";
      _validate(contents, []);
    });

    test('"permissions" may contain <all_urls> url pattern', () {
      String contents = """{ "permissions": ["<all_urls>"] }""";
      _validate(contents, []);
    });

    test('"permissions" may contain url patterns', () {
      String contents = """{
  "permissions": ["*://mail.google.com/*", "http://127.0.0.1/*", "file:///foo*",
                  "http://example.org/foo/bar.html", "http://*/*",
                  "https://*.google.com/foo*bar", "http://*/foo*"]
}
""";
      _validate(contents, []);
    });

    test('"usbDevices" permission may be an object', () {
      String contents = """{ "permissions": [{"usbDevices": []}] }""";
      _validate(contents, []);
    });

    test('"usbDevices" permission may be a string', () {
      String contents = """{ "permissions": ["usbDevices"] }""";
      _validate(contents, []);
    });

    test('"fileSystem" permission may be an object', () {
      String contents = """{ "permissions": [{"fileSystem": []}] }""";
      _validate(contents, []);
    });

    test('"fileSystem" permission may be a string', () {
      String contents = """{ "permissions": ["fileSystem"] }""";
      _validate(contents, []);
    });

    test('"socket" permission is obsolete', () {
      String contents = """{ "permissions": ["socket"] }""";
      _validate(contents, [ErrorIds.OBSOLETE_ENTRY]);
    });

    test('"socket" permission as dictionary is obsolete', () {
      String contents = """{ "permissions": [{"socket": {}}] }""";
      _validate(contents, [ErrorIds.OBSOLETE_ENTRY]);
    });

  });
}

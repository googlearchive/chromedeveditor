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

    test('"default_locale" may be a string', () {
      String contents = """{ "default_locale": "en" } """;
      _validate(contents, []);
    });

    test('"default_locale" cannot be an arbitrary string', () {
      String contents = """{ "default_locale": "foo" } """;
      _validate(contents, [ErrorIds.INVALID_LOCALE]);
    });

    test('"default_locale" cannot be an integer', () {
      String contents = """{ "default_locale": 0 } """;
      _validate(contents, [ErrorIds.INVALID_LOCALE]);
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

    for(String key in ["version", "minimum_chrome_version"]) {
      test('"$key" can contain 1 integer', () {
        String contents = """{ "$key": "1" }""";
        _validate(contents, []);
      });

      test('"$key" can contain 2 integers', () {
        String contents = """{ "$key": "1.0" }""";
        _validate(contents, []);
      });

      test('"$key" can contain 3 integers', () {
        String contents = """{ "$key": "1.0.1" }""";
        _validate(contents, []);
      });

      test('"$key" can contain 4 integers', () {
        String contents = """{ "$key": "1.0.0.12" }""";
        _validate(contents, []);
      });

      test('"$key" can contain more than 4 integers', () {
        String contents = """{ "$key": "1.0.0.12.13" }""";
        _validate(contents, [ErrorIds.VERSION_STRING_EXPECTED]);
      });

      test('"$key" can contain more negative integers', () {
        String contents = """{ "$key": "1.-1.0.12" }""";
        _validate(contents, [ErrorIds.VERSION_STRING_EXPECTED]);
      });

      test('"$key" can contain intergers greater than 65535', () {
        String contents = """{ "$key": "1.65536" }""";
        _validate(contents, [ErrorIds.VERSION_STRING_EXPECTED]);
      });

      test('"$key" cannot be an integer', () {
        String contents = """{ "$key": 0 }""";
        _validate(contents, [ErrorIds.VERSION_STRING_EXPECTED]);
      });

      test('"$key" cannot be an object', () {
        String contents = """{ "$key": {} }""";
        _validate(contents, [ErrorIds.VERSION_STRING_EXPECTED]);
      });

      test('"$key" cannot be an array', () {
        String contents = """{ "$key": [0] }""";
        _validate(contents, [ErrorIds.VERSION_STRING_EXPECTED]);
      });
    }

    for(String key in ["kiosk_enabled", "kiosk_only"]) {
      test('"$key" cannot be an integer', () {
        String contents = """{ "$key": 0 }""";
        _validate(contents, [json_schema_validator.ErrorIds.BOOLEAN_EXPECTED]);
      });

      test('"$key" may be true', () {
        String contents = """{ "$key": true }""";
        _validate(contents, []);
      });

      test('"$key" may be false', () {
        String contents = """{ "$key": false }""";
        _validate(contents, []);
      });
    }

    test('"webview" may be a dictionary of partitions', () {
      String contents = """{
  "webview": {
    "partitions": [{
        "name": "any name",
        "accessible_resources": ["foo.bar"]
      }, {
        "name": "any-name-2",
        "accessible_resources": ["blah.baz"]
      }
    ]
  }
}""";
      _validate(contents, []);
    });

    test('"webview" cannot contain any other key than "partitions"', () {
      String contents = """{
  "webview": {
    "partitions2": [{
        "name": "any name",
        "accessible_resources": ["foo.bar"]
      }, {
        "name": "any-name-2",
        "accessible_resources": ["blah.baz"]
      }
    ]
  }
}""";
      _validate(contents, [json_schema_validator.ErrorIds.UNKNOWN_PROPERTY_NAME]);
    });

    test('"webview.partitions" cannot contain any other key than "name" and "accessible_resources"', () {
      String contents = """{
  "webview": {
    "partitions": [{
      "name2": "any name",
      "accessible_resources": ["foo.bar"]
    }]
  }
}""";
      _validate(contents, [json_schema_validator.ErrorIds.UNKNOWN_PROPERTY_NAME]);
    });

    test('"webview.partitions" cannot contain any other key than "name" and "accessible_resources"', () {
      String contents = """{
  "webview": {
    "partitions": [{
      "name": "any name",
      "accessible_resources2": ["foo.bar"]
    }]
  }
}""";
      _validate(contents, [json_schema_validator.ErrorIds.UNKNOWN_PROPERTY_NAME]);
    });

    test('"webview.partitions.accessible_resources" cannot be a sinle string value"', () {
      String contents = """{
  "webview": {
    "partitions": [{
      "name": "any name",
      "accessible_resources": "foo.bar"
    }]
  }
}""";
      _validate(contents, [json_schema_validator.ErrorIds.ARRAY_EXPECTED]);
    });

    test('"webview" cannot be an array', () {
      String contents = """{ "webview": [] }""";
      _validate(contents, [json_schema_validator.ErrorIds.OBJECT_EXPECTED]);
    });

    test('"requirements" may be a dictionary', () {
      String contents = """{
  "requirements": {
    "3D": {
      "features": ["webgl", "css3d"]
    },
    "plugins": {
      "npapi": true
    },
    "window": {
      "shape": false
    }
  }
}
""";
      _validate(contents, []);
    });

    test('"requirements" cannot be a dictionary with arbitrary keys', () {
      String contents = """{
  "requirements": {
    "test": {
      "features": ["webgl", "css3d"]
    },
    "bad-plugins": {
      "npapi": true
    },
    "bad-window": {
      "shape": false
    }
  }
}
""";
      _validate(
          contents,
          [json_schema_validator.ErrorIds.UNKNOWN_PROPERTY_NAME,
           json_schema_validator.ErrorIds.UNKNOWN_PROPERTY_NAME,
           json_schema_validator.ErrorIds.UNKNOWN_PROPERTY_NAME]);
    });

    test('"requirements.3d.features" cannot be arbitrary strings', () {
      String contents = """{
  "requirements": {
    "3D": {
      "features": ["foo"]
    },
    "plugins": {
      "npapi": true
    },
    "window": {
      "shape": false
    }
  }
}
""";
      _validate(contents, [ErrorIds.REQUIRMENT_3D_FEATURE_EXPECTED]);
    });

  });
}

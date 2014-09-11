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
  expect(errorCollector.events.length, errorIds.length);
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

    test('manifest cannot be an empty object', () {
      String contents = """{}""";
      _validate(contents, [
          json_schema_validator.ErrorIds.MISSING_MANDATORY_PROPERTY,
          json_schema_validator.ErrorIds.MISSING_MANDATORY_PROPERTY]);
    });

    test('manifest cannot be a single value', () {
      String contents = """123""";
      _validate(contents, [json_schema_validator.ErrorIds.OBJECT_EXPECTED]);
    });

    test('"manifest_version" cannot be a string', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "manifest_version": "string value"
} """;
      _validate(contents, [json_schema_validator.ErrorIds.INTEGER_EXPECTED]);
    });

    test('"manifest_version" value 1 is obsolete', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "manifest_version": 1
} """;
      _validate(contents, [ErrorIds.OBSOLETE_MANIFEST_VERSION]);
    });

    test('"manifest_version" must be a number', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "manifest_version": 2
}""";
      _validate(contents, []);
    });

    test('"default_locale" may be a valid locale string', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "default_locale": "en"
} """;
      _validate(contents, []);
    });

    test('"default_locale" may be a valid locale string with hyphen', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "default_locale": "en-US"
} """;
      _validate(contents, []);
    });

    test('"default_locale" may be a valid locale string with digits', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "default_locale": "es_419"
} """;
      _validate(contents, []);
    });

    test('"default_locale" cannot contain special characters', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "default_locale": "~!@#"
} """;
      _validate(contents, [ErrorIds.INVALID_LOCALE]);
    });

    test('"default_locale" cannot be a single character', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "default_locale": "a"
} """;
      _validate(contents, [ErrorIds.INVALID_LOCALE]);
    });

    test('"default_locale" cannot be an integer', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "default_locale": 0
} """;
      _validate(contents, [ErrorIds.INVALID_LOCALE]);
    });

    test('"default_locale" cannot be an array', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "default_locale": [0]
} """;
      _validate(contents, [ErrorIds.INVALID_LOCALE]);
    });

    test('"default_locale" cannot be an object', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "default_locale": {}
} """;
      _validate(contents, [ErrorIds.INVALID_LOCALE]);
    });

    test('"scripts" may be an empty array', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "app": {"background": {"scripts": []}}
} """;
      _validate(contents, []);
    });

    test('"scripts" may be an array of strings', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "app": {"background": {"scripts": ["s"]}}
}""";
      _validate(contents, []);
    });

    test('"scripts" cannot contain a number in the array', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "app": {"background": {"scripts": ["s", 1]}}
}""";
      _validate(contents, [json_schema_validator.ErrorIds.STRING_EXPECTED]);
    });

    test('"scripts" cannot be an object', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "app": {"background": {"scripts": {"f": "s"}}}
}""";
      _validate(contents, [json_schema_validator.ErrorIds.ARRAY_EXPECTED]);
    });

    test('"sockets" may contain 3 known top level properties', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "sockets": { "udp": {}, "tcp": {}, "tcpServer": {} }
}
""";
      _validate(contents, []);
    });

    test('"sockets" objects may contain arbitrary keys', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "sockets": { "foo": {} }
}""";
      _validate(contents, []);
    });

    test('"sockets.udp" may contain 3 known top level properties', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "sockets": { "udp": { "bind": "", "send": "", "multicastMembership": ""} }
}
""";
      _validate(contents, []);
    });

    test('"sockets.udp" objects may contain arbitrary keys', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "sockets": { "udp": { "foo": "" } }
}""";
      _validate(contents, []);
    });

    test('"sockets.tcp" may contain 1 known top level properties', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "sockets": { "tcp": { "connect": ""} }
}
""";
      _validate(contents, []);
    });

    test('"sockets.tcp" objects may contain arbitrary keys', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "sockets": { "tcp": { "foo": "" } }
}""";
      _validate(contents, []);
    });

    test('"sockets.tcpServer" may contain 1 known top level properties', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "sockets": { "tcpServer": { "listen": ""} }
}""";
      _validate(contents, []);
    });

    test('"sockets.tcpServer" objects may contain arbitrary keys', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "sockets": { "tcpServer": { "foo": "" } } 
}""";
      _validate(contents, []);
    });

    test('"socket_host_pattern" may be a single value or an array', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "sockets": { "udp": { "send": "*.*", "bind": ["*:80", "*:8080"] } }
}
""";
      _validate(contents, []);
    });

    test('"socket_host_pattern" may be an empty string or contain wildcards', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "sockets": { "udp": { "send": ["", "*", "*:", "*:*", ":*"] } }
}
""";
      _validate(contents, []);
    });

    test('socket_host_pattern may only contain host:port', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "sockets": { "udp": { "send": ["foo:123:"] } }
}
""";
      _validate(contents, [ErrorIds.INVALID_SOCKET_HOST_PATTERN]);
    });

    test('"socket_host_pattern" port cannot be >= 65536', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "sockets": { "udp": { "send": "foo:65536" } }
}
""";
      _validate(contents, [ErrorIds.INVALID_SOCKET_HOST_PATTERN]);
    });

    test('"socket_host_pattern" cannot be an object', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "sockets": { "udp": { "send": {"foo": 0} } }
}
""";
      _validate(contents, [ErrorIds.INVALID_SOCKET_HOST_PATTERN]);
    });

    test('"socket_host_pattern" cannot be a nested object', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "sockets": { "udp": { "send": {"bar":{"foo": 0}} } }
}
""";
      _validate(contents, [ErrorIds.INVALID_SOCKET_HOST_PATTERN]);
    });

    test('"socket_host_pattern" cannot be a nested array', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "sockets": { "udp": { "send": [[""]] } }
}
""";
      _validate(contents, [ErrorIds.INVALID_SOCKET_HOST_PATTERN]);
    });

    test('"permissions" cannot be a dictionary', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "permissions": {"foo": "bar"}
}""";
      _validate(contents, [json_schema_validator.ErrorIds.ARRAY_EXPECTED]);
    });

    test('"permissions" cannot contain an unknown permission', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "permissions": ["foo"]
}""";
      _validate(contents, [ErrorIds.INVALID_PERMISSION]);
    });

    test('"permissions" may contain known permissions', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "permissions": ["usb", "tabs", "bookmarks"]
}""";
      _validate(contents, []);
    });

    test('"permissions" may contain <all_urls> url pattern', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "permissions": ["<all_urls>"]
}""";
      _validate(contents, []);
    });

    test('"permissions" may contain url patterns', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "permissions": ["*://mail.google.com/*", "http://127.0.0.1/*", "file:///foo*",
                  "http://example.org/foo/bar.html", "http://*/*",
                  "https://*.google.com/foo*bar", "http://*/foo*"]
}
""";
      _validate(contents, []);
    });

    test('"usbDevices" permission may be a simple string', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "permissions": ["usbDevices"]
}""";
      _validate(contents, [ErrorIds.PERMISSION_MUST_BE_OBJECT]);
    });

    test('"usbDevices" permission may be an empty array', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "permissions": [{"usbDevices": []}]
}""";
      _validate(contents, []);
    });

    test('"usbDevices" permission may be an array of objects', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "permissions": [{
    "usbDevices": [{
      "productId": 1,
      "vendorId": 1,
      "interfaceId": 1
    }]
  }]
}""";
      _validate(contents, []);
    });

    test('"usbDevices" objects may contain have arbitrary keys', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "permissions": [{
    "usbDevices": [{
      "foo": 1
    }]
  }]
}""";
      _validate(contents, [
          json_schema_validator.ErrorIds.MISSING_MANDATORY_PROPERTY,
          json_schema_validator.ErrorIds.MISSING_MANDATORY_PROPERTY]);
    });

    test('"fileSystem" permission may be an object', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "permissions": [{"fileSystem": []}]
}""";
      _validate(contents, []);
    });

    test('"fileSystem" permission may be a string', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "permissions": ["fileSystem"]
}""";
      _validate(contents, []);
    });

    test('"socket" permission is obsolete', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "permissions": ["socket"]
}""";
      _validate(contents, [ErrorIds.OBSOLETE_ENTRY]);
    });

    test('"socket" permission as dictionary is obsolete', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "permissions": [{"socket": {}}]
}""";
      _validate(contents, [ErrorIds.OBSOLETE_ENTRY]);
    });

    for(String key in ["version", "minimum_chrome_version"]) {
      test('"$key" can contain 1 integer', () {
        String contents = """{
  "name": "foo",
  "version": "1",
  "$key": "1"
}""";
        _validate(contents, []);
      });

      test('"$key" can contain 2 integers', () {
        String contents = """{
  "name": "foo",
  "version": "1",
  "$key": "1.0"
}""";
        _validate(contents, []);
      });

      test('"$key" can contain 3 integers', () {
        String contents = """{
  "name": "foo",
  "version": "1",
  "$key": "1.0.1"
}""";
        _validate(contents, []);
      });

      test('"$key" can contain 4 integers', () {
        String contents = """{
  "name": "foo",
  "version": "1",
  "$key": "1.0.0.12"
}""";
        _validate(contents, []);
      });

      test('"$key" can contain more than 4 integers', () {
        String contents = """{
  "name": "foo",
  "version": "1",
  "$key": "1.0.0.12.13"
}""";
        _validate(contents, [ErrorIds.VERSION_STRING_EXPECTED]);
      });

      test('"$key" can contain more negative integers', () {
        String contents = """{
  "name": "foo",
  "version": "1",
  "$key": "1.-1.0.12"
}""";
        _validate(contents, [ErrorIds.VERSION_STRING_EXPECTED]);
      });

      test('"$key" can contain intergers greater than 65535', () {
        String contents = """{
  "name": "foo",
  "version": "1",
  "$key": "1.65536"
}""";
        _validate(contents, [ErrorIds.VERSION_STRING_EXPECTED]);
      });

      test('"$key" cannot be an integer', () {
        String contents = """{
  "name": "foo",
  "version": "1",
  "$key": 0
}""";
        _validate(contents, [ErrorIds.VERSION_STRING_EXPECTED]);
      });

      test('"$key" cannot be an object', () {
        String contents = """{
  "name": "foo",
  "version": "1",
  "$key": {}
}""";
        _validate(contents, [ErrorIds.VERSION_STRING_EXPECTED]);
      });

      test('"$key" cannot be an array', () {
        String contents = """{
  "name": "foo",
  "version": "1",
  "$key": [0]
}""";
        _validate(contents, [ErrorIds.VERSION_STRING_EXPECTED]);
      });
    }

    for(String key in ["kiosk_enabled", "kiosk_only"]) {
      test('"$key" cannot be an integer', () {
        String contents = """{
  "name": "foo",
  "version": "1",
  "$key": 0
}""";
        _validate(contents, [json_schema_validator.ErrorIds.BOOLEAN_EXPECTED]);
      });

      test('"$key" may be true', () {
        String contents = """{
  "name": "foo",
  "version": "1",
  "$key": true
}""";
        _validate(contents, []);
      });

      test('"$key" may be false', () {
        String contents = """{
  "name": "foo",
  "version": "1",
  "$key": false
}""";
        _validate(contents, []);
      });
    }

    test('"webview" may be a dictionary of "partitions"', () {
      String contents = """{
  "name": "foo",
  "version": "1",
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

    test('"webview" must contain a "partitions" dictionary', () {
      String contents = """{
  "name": "foo",
  "version": "1",
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
      _validate(contents, [json_schema_validator.ErrorIds.MISSING_MANDATORY_PROPERTY]);
    });

    test('"webview.partitions" may contain arbitrary keys."', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "webview": {
    "partitions": [{
      "name": "any name",
      "accessible_resources": ["foo.bar"],
      "foo": 1
    }]
  }
}""";
      _validate(contents, []);
    });

    test('"webview.partitions" must contain "accessible_resources"', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "webview": {
    "partitions": [{
      "name": "any name",
      "accessible_resources2": ["foo.bar"]
    }]
  }
}""";
      _validate(contents, [json_schema_validator.ErrorIds.MISSING_MANDATORY_PROPERTY]);
    });

    test('"webview.partitions" must contain "name" and "accessible_resources"', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "webview": {
    "partitions": [{
      "name2": "any name",
      "accessible_resources2": ["foo.bar"]
    }]
  }
}""";
      _validate(contents, [
          json_schema_validator.ErrorIds.MISSING_MANDATORY_PROPERTY,
          json_schema_validator.ErrorIds.MISSING_MANDATORY_PROPERTY]);
    });

    test('"webview.partitions.accessible_resources" cannot be a sinle string value"', () {
      String contents = """{
  "name": "foo",
  "version": "1",
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
      String contents = """{
  "name": "foo",
  "version": "1",
  "webview": []
}""";
      _validate(contents, [json_schema_validator.ErrorIds.OBJECT_EXPECTED]);
    });

    test('"requirements" may be a dictionary', () {
      String contents = """{
  "name": "foo",
  "version": "1",
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
  "name": "foo",
  "version": "1",
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
          [json_schema_validator.ErrorIds.INVALID_PROPERTY_NAME,
           json_schema_validator.ErrorIds.INVALID_PROPERTY_NAME,
           json_schema_validator.ErrorIds.INVALID_PROPERTY_NAME]);
    });

    test('"requirements.3d.features" cannot be arbitrary strings', () {
      String contents = """{
  "name": "foo",
  "version": "1",
  "requirements": {
    "3D": {
      "features": ["foo"]
    }
  }
}
""";
      _validate(contents, [ErrorIds.REQUIREMENT_3D_FEATURE_EXPECTED]);
    });

  });
}

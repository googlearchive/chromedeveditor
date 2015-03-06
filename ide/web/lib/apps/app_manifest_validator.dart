// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.app.manifest_validator;

import '../json/json_schema_validator.dart';
import '../json/json_validator.dart';

class ErrorIds {
  static final String INVALID_MANIFEST_VERSION = "INVALID_MANIFEST_VERSION";
  static final String OBSOLETE_MANIFEST_VERSION = "OBSOLETE_MANIFEST_VERSION";
  static final String INVALID_PERMISSION = "INVALID_PERMISSION";
  static final String PERMISSION_MUST_BE_OBJECT = "PERMISSION_MUST_BE_OBJECT";
  static final String OBSOLETE_ENTRY = "OBSOLETE_ENTRY";
  static final String STRING_OR_OBJECT_EXPECTED = "STRING_OR_OBJECT_EXPECTED";
  static final String VERSION_STRING_EXPECTED = "VERSION_STRING_EXPECTED";
  static final String REQUIREMENT_3D_FEATURE_EXPECTED =
      "REQUIREMENT_3D_FEATURE_EXPECTED";
  static final String INVALID_LOCALE = "INVALID_LOCALE";
  static final String INVALID_SOCKET_HOST_PATTERN =
      "INVALID_SOCKET_HOST_PATTERN";
}

/**
 * Json validator for "manifest.json" contents.
 */
class AppManifestValidator extends RootObjectSchemaValidator {
  factory AppManifestValidator(ErrorCollector errorCollector)
  {
    var factory = new AppManifestValidatorFactory(errorCollector);
    var core_factory = new CoreSchemaValidatorFactory(factory, errorCollector);
    return new AppManifestValidator._(core_factory, errorCollector);
  }

  AppManifestValidator._(
      SchemaValidatorFactory factory, ErrorCollector errorCollector)
    : super(factory, errorCollector, AppManifestSchema);
}

/**
 * From https://developer.chrome.com/extensions/manifest
 * and https://developer.chrome.com/apps/manifest
 */
final Map AppManifestSchema =
{
  "app": {
    "background": {
      "scripts": ["string"]
    },
    "service_worker": "var"  // Undocumented (prototype feature)
  },
  "author": "var",  // Undocumented
  "automation": "var",
  "background": {
    "persistent": "boolean",
    "page": "string",
    "scripts": ["string"]
  },
  "background_page": "string",  // Legacy (manifest v1)
  "bluetooth": {
    "uuids": ["string"],
    "socket": "boolean",
    "low_energy": "boolean"
  },
  "browser_action": {
    "icons": ["string"],
    "id": "string",
    "default_icon": "var",  // Dictionary("string", "string") || "string"
    "default_title": "string",
    "name": "string",
    "popup": "string",
    "default_popup": "string",
  },
  "chrome_settings_overrides": "var",
  "chrome_ui_overrides": "var",
  "chrome_url_overrides": "var",
  "commands": "var",
  "content_pack": "var",
  "content_scripts": "var",
  "content_security_policy": "var",
  "converted_from_user_script": "var",
  "current_locale": "locale",
  "default_locale": "locale",
  "description": "string",
  "devtools_page": "var",
  "externally_connectable": "var",
  "file_browser_handlers": "var",
  "file_handlers": "var",
  "homepage_url": "var",
  "icons": "var",
  "import": "var",
  "incognito": "var",
  "input_components": "var",
  "key": "string",
  "kiosk_enabled": "boolean",
  "kiosk_only": "boolean",
  "manifest_version": "manifest_version",
  "minimum_chrome_version": "version",
  "nacl_modules": "var",
  "name!": "string",
  "oauth2": "var",
  "offline_enabled": "var",
  "omnibox": "var",
  "optional_permissions": ["permission"],
  "options_page": "var",
  "page_action": "var",
  "page_actions": "var",
  "permissions": ["permission"],
  "platforms": "var",
  "plugins": "var",
  "requirements": {
    "<meta-open-ended>": false,
    "3D": {
      "features!": ["3d_feature"] // "webgl" or "css3d"
    },
    "plugins": {
      "<meta-open-ended>": false,
      "npapi": "boolean"
    },
    "window": {
      "<meta-open-ended>": false,
      "shape": "boolean"
    }
  },
  "sandbox": "var",
  "script_badge": "var",
  "short_name": "string",
  "signature": "var",
  "sockets": {
    "udp": {
      "bind": "socket_host_pattern",
      "send": "socket_host_pattern",
      "multicastMembership": "socket_host_pattern"
    },
    "tcp": {
      "connect": "socket_host_pattern"
    },
    "tcpServer": {
      "listen": "socket_host_pattern"
    }
  },
  "spellcheck": "var",
  "storage": "var",
  "system_indicator": "var",
  "tts_engine": "var",
  "update_url": "string",
  "web_accessible_resources": "var",
  "url_handlers": "var",
  "version!": "version",
  "webview": {
    "partitions!": [{
      "name!": "string",
      "accessible_resources!": ["string"]
    }]
  }
};

/**
 * Schema for the "usbDevices" permission entry.
 */
final List UsbDeviceArraySchema = [{
  "vendorId!": "int",
  "productId!": "int",
  "interfaceId": "int"
}];

typedef SchemaValidator SchemaValidatorCreator(
    SchemaValidatorFactory factory, ErrorCollector errorCollector);

/**
 * Custom schema factory implementing schema types specific to the
 * "manifest.json" schema.
 */
class AppManifestValidatorFactory implements SchemaValidatorFactory {
  static final Map<String, SchemaValidatorCreator> _customTypes = {
    "3d_feature": (f, x) => new Requirement3dFeatureValueValidator(x),
    "locale": (f, x) => new LocaleValueValidator(x),
    "manifest_version": (f, x) => new ManifestVersionValueValidator(x),
    "permission": (f, x) => new PermissionValueValidator(f, x),
    "socket_host_pattern": (f, x) => new SocketHostPatternValueValidator(x),
    "version": (f, x) => new VersionValueValidator(x)
  };
  final ErrorCollector errorCollector;

  AppManifestValidatorFactory(this.errorCollector);

  @override
  SchemaValidator createValidator(
      SchemaValidatorFactory rootFactory, dynamic schema) {
    SchemaValidatorCreator creator = _customTypes[schema];
    if (creator == null) {
      return null;
    }

    return creator(rootFactory, errorCollector);
  }

  @override
  bool validateSchemaForTesting(dynamic schema) {
    return _customTypes.containsKey(schema);
  }
}

/**
 * Validator for the "manifest_version" property value.
 */
class ManifestVersionValueValidator extends IntegerValueValidator {
  ManifestVersionValueValidator(ErrorCollector errorCollector)
    : super(errorCollector);

  @override
  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    // The "manifest_version" type is always directly associated to an
    // object key.
    assert(propertyName != null);

    if (entity is NumberEntity && entity.number is int) {
      if (entity.number == 1) {
        errorCollector.addMessage(
            ErrorIds.OBSOLETE_MANIFEST_VERSION,
            entity.span,
            "Value 1 is obsolete for property \"${propertyName.text}\".");
      } else if (entity.number != 2) {
        errorCollector.addMessage(
            ErrorIds.INVALID_MANIFEST_VERSION,
            entity.span,
            "Value 1 or 2 is expected for property \"${propertyName.text}\".");
      }
      return;
    }

    super.checkValue(entity, propertyName);
  }
}

/**
 * Validator for the "permission" type.
 * TODO(rpaquay): It would be nice to be able to express this more
 * declaratively as a Schema type, but the structure is too complex
 * to be expressed easily.
 */
class PermissionValueValidator extends SchemaValidator {
  static final List<String> _permissionNames = [
    // From https://developer.chrome.com/apps/declare_permissions
    "alarms",
    "alwaysOnTopWindows",
    "audio",
    "audioCapture",
    "browser",
    "clipboardRead",
    "clipboardWrite",
    "contextMenus",
    "copresence",
    "desktopCapture",
    "diagnostics",
    "dns",
    "experimental",
    "fileBrowserHandler",
    "fileSystem",
    "fileSystemProvider",
    "gcm",
    "geolocation",
    "hid",
    "identity",
    "idle",
    "infobars",
    "location",
    "mediaGalleries",
    "nativeMessaging",
    "notificationProvider",
    "notifications",
    "pointerLock",
    "power",
    "pushMessaging",
    "serial",
    "signedInDevices",
    "socket",
    "storage",
    "syncFileSystem",
    "system.cpu",
    "system.display",
    "system.memory",
    "system.network",
    "system.storage",
    "tts",
    "unlimitedStorage",
    "usb",
    "usbDevices",
    "videoCapture",
    "wallpaper",
    "webview",
    // From https,//developer.chrome.com/extensions/declare_permissions
    "activeTab",
    "background",
    "bookmarks",
    "browsingData",
    "contentSettings",
    "cookies",
    "debugger",
    "declarativeContent",
    "declarativeWebRequest",
    "downloads",
    "enterprise.platformKeys",
    "fontSettings",
    "history",
    "management",
    "pageCapture",
    "privacy",
    "processes",
    "proxy",
    "sessions",
    "tabCapture",
    "tabs",
    "topSites",
    "ttsEngines",
    "webNavigation",
    "webRequest",
    "webRequestBlocking",

    // Others
    "developerPrivate"
  ];
  static final List<String> _obsoletePermissions = ["socket"];
  static final List<String> _objectOnlyPermissions = ["usbDevices"];

  final SchemaValidatorFactory factory;
  final ErrorCollector errorCollector;

  PermissionValueValidator(this.factory, this.errorCollector);

  @override
  JsonValidator enterObject() {
    return new PermissionObjectValueValidator(factory, errorCollector);
  }

  @override
  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is StringEntity) {
      if (_objectOnlyPermissions.contains(entity.text)) {
        errorCollector.addMessage(
            ErrorIds.PERMISSION_MUST_BE_OBJECT,
            entity.span,
            "Permission value \"${entity.text}\" must be an object.");
      } else if (_obsoletePermissions.contains(entity.text)) {
        errorCollector.addMessage(
             ErrorIds.OBSOLETE_ENTRY,
             entity.span,
             "Permission value \"${entity.text}\" is obsolete.");
      } else if (!_permissionNames.contains(entity.text) &&
          !_isMatchPattern(entity.text)) {
        errorCollector.addMessage(
            ErrorIds.INVALID_PERMISSION,
            entity.span,
            "Permission value \"${entity.text}\" is not recognized.");
      }
    } else if (entity is ObjectEntity) {
      // Validation has been performed by validator from "enterObject".
    } else {
      errorCollector.addMessage(
          ErrorIds.STRING_OR_OBJECT_EXPECTED,
          entity.span,
          "String or object expected for permission entries.");
    }
  }

  bool _isMatchPattern(String text) {
    // See https://developer.chrome.com/apps/match_patterns
    if (text == "<all_urls>") {
      return true;
    }
    // <url-pattern> := <scheme>://<host><path>
    // <scheme> := '*' | 'http' | 'https' | 'file' | 'ftp'
    // <host> := '*' | '*.' <any char except '/' and '*'>+
    // <path> := '/' <any chars>
    //
    // TODO(rpaquay): The syntax for URL patterns is quite complex and
    // incompatible with dart.core.Uri (because of the wildcard character),
    // so we implement a simple heuristic.
    int index = text.indexOf("://");
    return (index > 0 && index < text.length - 4);
  }
}

/**
 * A few permissions can be expressed as a dictionary with a single key
 * containing a permission name.
 */
class PermissionObjectValueValidator extends SchemaValidator {
  final SchemaValidatorFactory factory;
  final ErrorCollector errorCollector;

  PermissionObjectValueValidator(this.factory, this.errorCollector);

  @override
  JsonValidator propertyName(StringEntity propertyName) {
    switch(propertyName.text) {
      case "socket":
        errorCollector.addMessage(
             ErrorIds.OBSOLETE_ENTRY,
             propertyName.span,
             "Permission value \"${propertyName.text}\" is obsolete. " +
             "Use the \"sockets\" manifest key instead.");
        return NullValidator.instance;

      case "usbDevices":
        return new ArraySchemaValidator(factory, errorCollector, UsbDeviceArraySchema);

      // TODO(rpaquay): Implement validators for the permissions below.
      case "fileSystem":
        return NullValidator.instance;

      default:
        errorCollector.addMessage(
            ErrorIds.INVALID_PERMISSION,
            propertyName.span,
            "Permission value \"${propertyName.text}\" is not recognized.");
        return NullValidator.instance;
    }
  }
}

/**
 * Validator for the "socket_host_pattern" property value.
 */
class SocketHostPatternValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;
  final bool arrayAllowed;

  SocketHostPatternValueValidator(
      this.errorCollector, [this.arrayAllowed = true]);

  @override
  JsonValidator enterArray() {
    if (arrayAllowed) {
      SchemaValidator validator =
          new SocketHostPatternValueValidator(errorCollector, false);
      return new ArrayElementsSchemaValidator(validator);
    }
    return NullValidator.instance;
  }

  @override
  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is StringEntity) {
      if (_isValidPattern(entity.text)) {
        return;
      }
    } else if (entity is ArrayEntity) {
      if (arrayAllowed)
        return;
    }
    errorCollector.addMessage(
        ErrorIds.INVALID_SOCKET_HOST_PATTERN,
        entity.span,
        "Invalid socket host:port pattern. " +
        "Values accepted are: \"\" or \"[host|*]:[port|*]\".");
  }

  /**
   * See https://developer.chrome.com/apps/app_network
   *
   * <host-pattern> := <host> | ':' <port> | <host> ':' <port>
   * <host> := '*' | '*.' <anychar except '/' and '*'>+
   * <port> := '*' | <port number between 1 and 65535>)
   */
  static bool _isValidPattern(String value) {
    if (value == "") {
      return true;
    }
    List<String> values = value.split(":");
    if (values.length == 1 && _isValidHost(values[0])) {
      return true;
    }
    if (values.length == 2 &&
        _isValidHost(values[0]) &&
        _isValidPort(values[1])) {
      return true;
    }
    return false;
  }

  // Leave "host" part as free form.
  static bool _isValidHost(String x) => true;

  static bool _isValidPort(String x) {
    if (x == "" || x == "*") {
      return true;
    }
    int result = int.parse(x, onError: (x) => -1);
    return result >= 0 && result <= 65535;
  }
}

/**
 * Validator for "version" values.
 * See https://developer.chrome.com/extensions/manifest/version.
 */
class VersionValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;

  VersionValueValidator(this.errorCollector);

  @override
  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is StringEntity) {
      // See https://developer.chrome.com/extensions/manifest/version.
      List<String> numbers = entity.text.trim().split(".");
      if (numbers.length >= 1 && numbers.length <= 4) {
        if (numbers.every((x) => _isPositiveInteger(x))) {
          return;
        }
      }
    }

    if (propertyName == null) {
      errorCollector.addMessage(
          ErrorIds.VERSION_STRING_EXPECTED,
          entity.span,
          "A string containing 1 to 4 integer separated by a \".\" is expected.");
    } else {
      errorCollector.addMessage(
          ErrorIds.VERSION_STRING_EXPECTED,
          entity.span,
          "A string containing 1 to 4 integer separated by a \".\" is " +
          "expected for property \"${propertyName.text}\".");
    }
  }

  bool _isPositiveInteger(String x) {
    int result = int.parse(x, onError: (x) => -1);
    return result >= 0 && result <= 65535;
  }
}

/**
 * Validator for "requirements.3D.features" values.
 * See https://developer.chrome.com/apps/manifest/requirements.
 */
class Requirement3dFeatureValueValidator extends SchemaValidator {
  static final List<String> _validFeatures = ["webgl", "css3d"];
  final ErrorCollector errorCollector;

  Requirement3dFeatureValueValidator(this.errorCollector);

  @override
  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is StringEntity) {
      if (_validFeatures.contains(entity.text)) {
        return;
      }
    }

    errorCollector.addMessage(
        ErrorIds.REQUIREMENT_3D_FEATURE_EXPECTED,
        entity.span,
        "3D feature must be one of ${getQuotedFeatureList().join(", ")}.");
  }

  Iterable<String> getQuotedFeatureList() {
    return _validFeatures.map((x) => "\"" + x + "\"");
  }
}

/**
 * Validator for "locale" values.
 * See https://developer.chrome.com/webstore/i18n?csw=1#localeTable.
 */
class LocaleValueValidator extends SchemaValidator {
  static final Set<int> _validCodeUnits = _getValidCodeUnits();
  final ErrorCollector errorCollector;

  LocaleValueValidator(this.errorCollector);

  static Set<int> _getValidCodeUnits() {
    final String validCharacters =
        "abcdefghijklmnopqrstuvwxyz" +
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
        "1234567890" +
        "-_";
    return new Set<int>()..addAll(validCharacters.codeUnits);
  }

  @override
  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is StringEntity) {
      if (_isValidLocale(entity.text)) {
        return;
      }
    }

    if (propertyName == null) {
      errorCollector.addMessage(
          ErrorIds.INVALID_LOCALE,
          entity.span,
          "Locale is invalid.");
    } else {
      errorCollector.addMessage(
          ErrorIds.INVALID_LOCALE,
          entity.span,
          "Locale is invalid for property \"${propertyName.text}\".");
    }
  }

  bool _isValidLocale(String text) {
    if (text.length < 2)
      return false;

    for(int i = 0; i < text.length; i++) {
      if (!_validCodeUnits.contains(text.codeUnitAt(0))) {
        return false;
      }
    }
    return true;
  }
}

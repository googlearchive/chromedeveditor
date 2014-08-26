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
  static final String OBSOLETE_ENTRY = "OBSOLETE_ENTRY";
  static final String STRING_OR_OBJECT_EXPECTED = "STRING_OR_OBJECT_EXPECTED";
  static final String VERSION_STRING_EXPECTED = "VERSION_STRING_EXPECTED";
  static final String REQUIRMENT_3D_FEATURE_EXPECTED = "REQUIRMENT_3D_FEATURE_EXPECTED";
  static final String INVALID_LOCALE = "INVALID_LOCALE";
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
Map AppManifestSchema =
{
  "app": {
    "background": {
      "scripts": ["string"],
      "persistent": "boolean",
    },
    "service_worker": "var"
  },
  "author": "var",
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
  "name": "string",
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
    "3D": {
      "features": ["3d_feature"] // "webgl" or "css3d"
    },
    "plugins": {
      "npapi": "boolean"
    },
    "window": {
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
  "version": "version",
  "webview": {
    "partitions": [{
      "name": "string",
      "accessible_resources": ["string"]
    }]
  }
};

typedef SchemaValidator SchemaValidatorCreator(ErrorCollector errorCollector);

/**
 * Custom schema factory implementing schema types specific to the
 * "manifest.json" schema.
 */
class AppManifestValidatorFactory implements SchemaValidatorFactory {
  static final Map<String, SchemaValidatorCreator> _custom_types = {
    "3d_feature": (errorCollector) => new Requirement3dFeatureValueValidator(errorCollector),
    "locale": (errorCollector) => new LocaleValueValidator(errorCollector),
    "manifest_version": (errorCollector) => new ManifestVersionValueValidator(errorCollector),
    "permission": (errorCollector) => new PermissionValueValidator(errorCollector),
    "socket_host_pattern": (errorCollector) => new SocketHostPatternValueValidator(errorCollector),
    "version": (errorCollector) => new VersionValueValidator(errorCollector)
  };
  final ErrorCollector errorCollector;

  AppManifestValidatorFactory(this.errorCollector);

  SchemaValidator createValidator(dynamic schema) {
    SchemaValidatorCreator function = _custom_types[schema];
    if (function == null) {
      return null;
    }

    return function(errorCollector);
  }

  bool validateSchemaForTesting(dynamic schema) {
    return _custom_types.containsKey(schema);
  }
}

/**
 * Validator for the "manifest_version" property value.
 */
class ManifestVersionValueValidator extends IntegerValueValidator {
  ManifestVersionValueValidator(ErrorCollector errorCollector)
    : super(errorCollector);

  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
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
 */
class PermissionValueValidator extends SchemaValidator {
  static final List<String> _permissionNames = [
      // From https://developer.chrome.com/apps/declare_permissions
      "alarms",
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

  final ErrorCollector errorCollector;

  PermissionValueValidator(this.errorCollector);

  JsonValidator enterObject() {
    return new PermissionObjectValueValidator(errorCollector);
  }

  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is StringEntity) {
      if (_obsoletePermissions.contains(entity.text)) {
        errorCollector.addMessage(
             ErrorIds.OBSOLETE_ENTRY,
             entity.span,
             "Permission value \"${entity.text}\" is obsolete.");
      }
      else if (!_permissionNames.contains(entity.text) &&
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
    // <url-pattern> := <scheme>://<host><path>
    // <scheme> := '*' | 'http' | 'https' | 'file' | 'ftp'
    // <host> := '*' | '*.' <any char except '/' and '*'>+
    // <path> := '/' <any chars>
    //
    // TODO(rpaquay): The syntax for URL patterns is quite complex and
    // incompatible with dart.core.Uri (because of the wildcard character),
    // so we implement a simple heuristic.
    if (text == "<all_urls>") {
      return true;
    }
    int index = text.indexOf("://");
    return (index > 0 && index < text.length - 4);
  }
}

/**
 * A few permissions can be expressed as a dictionary with a single key
 * containing a permission name.
 */
class PermissionObjectValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;

  PermissionObjectValueValidator(this.errorCollector);

  JsonValidator propertyName(StringEntity propertyName) {
    switch(propertyName.text) {
      case "socket":
        errorCollector.addMessage(
             ErrorIds.OBSOLETE_ENTRY,
             propertyName.span,
             "Permission value \"${propertyName.text}\" is obsolete. " +
             "Use the \"sockets\" manifest key instead.");
        return NullValidator.instance;

      // TODO(rpaquay): Implement validators for the permissions below.
      case "usbDevices":
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
 * TODO(rpaquay): Validator for the "usbDevices" permission.
 */
class UsbDevicesValidator extends SchemaValidator {

}

/**
 * TODO(rpaquay): Validator for the "socket_host_pattern" property value.
 */
class SocketHostPatternValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;

  SocketHostPatternValueValidator(this.errorCollector);
}

/**
 * Validator for "version" values.
 * See https://developer.chrome.com/extensions/manifest/version.
 */
class VersionValueValidator extends LiteralValueSchemaValidator {
  final ErrorCollector errorCollector;

  VersionValueValidator(this.errorCollector);

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
class Requirement3dFeatureValueValidator extends LiteralValueSchemaValidator {
  final ErrorCollector errorCollector;

  Requirement3dFeatureValueValidator(this.errorCollector);

  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is StringEntity) {
      if (entity.text == "webgl" || entity.text == "css3d") {
        return;
      }
    }

    if (propertyName == null) {
      errorCollector.addMessage(
          ErrorIds.REQUIRMENT_3D_FEATURE_EXPECTED,
          entity.span,
          "3D feature must be \"webgl\" or \"css3d\".");
    } else {
      errorCollector.addMessage(
          ErrorIds.REQUIRMENT_3D_FEATURE_EXPECTED,
          entity.span,
          "3D feature must be \"webgl\" or \"css3d\" for property " +
          "\"${propertyName.text}\".");
    }
  }
}

/**
 * Validator for "locale" values.
 * See https://developer.chrome.com/webstore/i18n?csw=1#localeTable.
 */
class LocaleValueValidator extends LiteralValueSchemaValidator {
  static final Map<String, String> _validLocales = {
    "ar": "Arabic",
    "am": "Amharic",
    "bg": "Bulgarian",
    "bn": "Bengali",
    "ca": "Catalan",
    "cs": "Czech",
    "da": "Danish",
    "de": "German",
    "el": "Greek",
    "en": "English",
    "en_GB": "English (Great Britain)",
    "en_US": "English (USA)",
    "es": "Spanish",
    "es_419": "Spanish (Latin America and Caribbean)",
    "et": "Estonian",
    "fa": "Persian",
    "fi": "Finnish",
    "fil": "Filipino",
    "fr": "French",
    "gu": "Gujarati",
    "he": "Hebrew",
    "hi": "Hindi",
    "hr": "Croatian",
    "hu": "Hungarian",
    "id": "Indonesian",
    "it": "Italian",
    "ja": "Japanese",
    "kn": "Kannada",
    "ko": "Korean",
    "lt": "Lithuanian",
    "lv": "Latvian",
    "ml": "Malayalam",
    "mr": "Marathi",
    "ms": "Malay",
    "nl": "Dutch",
    "no": "Norwegian",
    "pl": "Polish",
    "pt_BR": "Portuguese (Brazil)",
    "pt_PT": "Portuguese (Portugal)",
    "ro": "Romanian",
    "ru": "Russian",
    "sk": "Slovak",
    "sl": "Slovenian",
    "sr": "Serbian",
    "sv": "Swedish",
    "sw": "Swahili",
    "ta": "Tamil",
    "te": "Telugu",
    "th": "Thai",
    "tr": "Turkish",
    "uk": "Ukrainian",
    "vi": "Vietnamese",
    "zh_CN": "Chinese (China)",
    "zh_TW": "Chinese (Taiwan)",
  };
  final ErrorCollector errorCollector;

  LocaleValueValidator(this.errorCollector);

  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is StringEntity) {
      if (_validLocales.containsKey(entity.text)) {
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
}

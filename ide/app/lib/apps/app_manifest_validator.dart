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
  "current_locale": "var",
  "default_locale": "var",
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
  "kiosk_enabled": "var",
  "kiosk_only": "var",
  "manifest_version": "manifest_version",
  "minimum_chrome_version": "var",
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
  "requirements": "var",
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
  "version": "var",
  "webview": "var"
};

/**
 * Custom schema factory implementing schema types specific to the
 * "manifest.json" schema.
 */
class AppManifestValidatorFactory implements SchemaValidatorFactory {
  final ErrorCollector errorCollector;

  AppManifestValidatorFactory(this.errorCollector);

  SchemaValidator createValidator(dynamic schema) {
    if (schema == "manifest_version") {
      return new ManifestVersionValueValidator(errorCollector);
    } else if (schema == "permission") {
      return new PermissionValueValidator(errorCollector);
    } else if (schema == "socket_host_pattern") {
      return new SocketHostPatternValueValidator(errorCollector);
    }
    return null;
  }

  bool validateSchemaForTesting(dynamic schema) {
    if (schema == "manifest_version" ||
        schema == "permission" ||
        schema == "socket_host_pattern") {
      return true;
    }
    return false;
  }

  SchemaValidatorFactory get parentFactory => null;
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

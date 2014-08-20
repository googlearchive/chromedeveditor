// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.app.manifest_validator;

import '../json/json_validator.dart';

/**
 * Json validator for "manifest.json" contents.
 */
class AppManifestValidator extends NullValidator {
  static const String message = "Top level element must be an object";
  final ErrorCollector errorCollector;

  AppManifestValidator(this.errorCollector);

  JsonValidator enterObject() {
    return new TopLevelValidator(errorCollector);
  }

  void leaveArray(ArrayEntity entity) {
    errorCollector.addMessage(entity.span, message);
  }

  void handleRootValue(ValueEntity entity) {
    errorCollector.addMessage(entity.span, message);
  }
}

/////////////////////////////////////////////////////////////////////////////
// The code below should be auto-generated from a manifest schema definition.
//

/**
 * Validator for the top level object of a "manifest.json" file.
 */
class TopLevelValidator extends NullValidator {
  // from https://developer.chrome.com/extensions/manifest
  static final List<String> knownEventPageProperties = [
    "manifest_version",
    "name",
    "version",
    "default_locale",
    "description",
    "icons",
    "browser_action",
    "page_action",
    "author",
    "automation",
    "background",
    "background_page",
    "chrome_settings_overrides",
    "chrome_ui_overrides",
    "chrome_url_overrides",
    "commands",
    "content_pack",
    "content_scripts",
    "content_security_policy",
    "converted_from_user_script",
    "current_locale",
    "devtools_page",
    "externally_connectable",
    "file_browser_handlers",
    "homepage_url",
    "import",
    "incognito",
    "input_components",
    "key",
    "minimum_chrome_version",
    "nacl_modules",
    "oauth2",
    "offline_enabled",
    "omnibox",
    "optional_permissions",
    "options_page",
    "page_actions",
    "permissions",
    "platforms",
    "plugins",
    "requirements",
    "sandbox",
    "script_badge",
    "short_name",
    "signature",
    "spellcheck",
    "storage",
    "system_indicator",
    "tts_engine",
    "update_url",
    "web_accessible_resources",
    ];

  // from https://developer.chrome.com/apps/manifest
  static final List<String> knownAppsProperties = [
    "app",
    "manifest_version",
    "name",
    "version",
    "default_locale",
    "description",
    "icons",
    "author",
    "bluetooth",
    "commands",
    "current_locale",
    "externally_connectable",
    "file_handlers",
    "import",
    "key",
    "kiosk_enabled",
    "kiosk_only",
    "minimum_chrome_version",
    "nacl_modules",
    "oauth2",
    "offline_enabled",
    "optional_permissions",
    "permissions",
    "platforms",
    "requirements",
    "sandbox",
    "short_name",
    "signature",
    "sockets",
    "storage",
    "system_indicator",
    "update_url",
    "url_handlers",
    "webview",
    ];

  static final Set<String> allProperties =
      knownEventPageProperties.toSet().union(knownAppsProperties.toSet());

  final ErrorCollector errorCollector;

  TopLevelValidator(this.errorCollector);

  JsonValidator propertyName(StringEntity entity) {
    if (!allProperties.contains(entity.text)) {
      String message = "Property \"${entity.text}\" is not recognized.";
      errorCollector.addMessage(entity.span, message);
    }

    switch(entity.text) {
      case "manifest_version":
        return new ManifestVersionValidator(errorCollector);
      case "app":
        return new ObjectPropertyValidator(
            errorCollector, entity.text, new AppValidator(errorCollector));
      default:
        return NullValidator.instance;
    }
  }
}

/**
 * Validator for the "manifest_version" element
 */
class ManifestVersionValidator extends NullValidator {
  static final String message =
      "Manifest version must be the integer value 1 or 2.";
  final ErrorCollector errorCollector;

  ManifestVersionValidator(this.errorCollector);

  void propertyValue(JsonEntity entity) {
    if (entity is! NumberEntity) {
      errorCollector.addMessage(entity.span, message);
      return;
    }
    NumberEntity numEntity = entity as NumberEntity;
    if (numEntity.number is! int) {
      errorCollector.addMessage(entity.span, message);
      return;
    }
    if (numEntity.number < 1 || numEntity.number > 2) {
      errorCollector.addMessage(entity.span, message);
      return;
    }
  }
}

/**
 * Validator for the "app" element
 */
class AppValidator extends NullValidator {
  final ErrorCollector errorCollector;

  AppValidator(this.errorCollector);

  JsonValidator propertyName(StringEntity entity) {
    switch(entity.text) {
      case "background":
        return new ObjectPropertyValidator(
            errorCollector,
            entity.text,
            new AppBackgroundValidator(errorCollector));
      case "service_worker":
        return NullValidator.instance;
      default:
        String message = "Property \"${entity.text}\" is not recognized.";
        errorCollector.addMessage(entity.span, message);
        return NullValidator.instance;
    }
  }
}

/**
 * Validator for the "app.background" element
 */
class AppBackgroundValidator extends NullValidator {
  final ErrorCollector errorCollector;

  AppBackgroundValidator(this.errorCollector);

  JsonValidator propertyName(StringEntity entity) {
    switch(entity.text) {
      case "scripts":
        return new ArrayPropertyValidator(
            errorCollector,
            entity.text,
            new StringArrayValidator(errorCollector));
      default:
        String message = "Property \"${entity.text}\" is not recognized.";
        errorCollector.addMessage(entity.span, message);
        return NullValidator.instance;
    }
  }
}

/**
 * Validate that every element of an array is a string value.
 */
class StringArrayValidator extends NullValidator {
  final ErrorCollector errorCollector;

  StringArrayValidator(this.errorCollector);

  void arrayElement(JsonEntity entity) {
    if (entity is! StringEntity) {
      errorCollector.addMessage(entity.span, "String value expected");
    }
  }
}

/**
 * Validates a property value is an object, and use [objectValidator] for
 * validating the contents of the object.
 */
class ObjectPropertyValidator extends NullValidator {
  final ErrorCollector errorCollector;
  final String name;
  final JsonValidator objectValidator;

  ObjectPropertyValidator(
      this.errorCollector, this.name, this.objectValidator);

  // This is called when we are done parsing the whole property value,
  // i.e. just before leaving this validator.
  void propertyValue(JsonEntity entity) {
    if (entity is! ObjectEntity) {
      errorCollector.addMessage(
          entity.span,
          "Property \"${name}\" is expected to be an object.");
    }
  }

  JsonValidator enterObject() {
    return this.objectValidator;
  }
}

/**
 * Validates a property value is an array, and use [arrayValidator] for
 * validating the contents (i.e. elements) of the array.
 */
class ArrayPropertyValidator extends NullValidator {
  final ErrorCollector errorCollector;
  final String name;
  final JsonValidator arrayValidator;

  ArrayPropertyValidator(this.errorCollector, this.name, this.arrayValidator);

  // This is called when we are done parsing the whole property value,
  // i.e. just before leaving this validator.
  void propertyValue(JsonEntity entity) {
    if (entity is! ArrayEntity) {
      errorCollector.addMessage(
          entity.span,
          "Property \"${name}\" is expected to be an array.");
    }
  }

  JsonValidator enterArray() {
    return this.arrayValidator;
  }
}

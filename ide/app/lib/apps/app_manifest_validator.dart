// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.app.manifest_validator;

import '../json/json_validator.dart';

/**
 *  Type :==
 *    "var"
 *    "int" |
 *    "num" |
 *    "string" |
 *    '[' Type ']' |
 *    '{' name ':' Type '}'
 */

// from https://developer.chrome.com/extensions/manifest
// and https://developer.chrome.com/apps/manifest
var app_manifest_schema =
{
  "app": {
    "background": {
      "scripts": ["string"],
    },
    "service_worker": "var"
  },
  "author": "string",
  "automation": "var",
  "background": "var",
  "background_page": "var",
  "bluetooth": "var",
  "browser_action": "var",
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
  "manifest_version": "int",
  "minimum_chrome_version": "var",
  "nacl_modules": "var",
  "name": "string",
  "oauth2": "var",
  "offline_enabled": "var",
  "omnibox": "var",
  "optional_permissions": "var",
  "options_page": "var",
  "page_action": "var",
  "page_actions": "var",
  "permissions": "var",
  "platforms": "var",
  "plugins": "var",
  "requirements": "var",
  "sandbox": "var",
  "script_badge": "var",
  "short_name": "string",
  "signature": "var",
  "sockets": "var",
  "spellcheck": "var",
  "storage": "var",
  "system_indicator": "var",
  "tts_engine": "var",
  "update_url": "string",
  "web_accessible_resources": "var",
  "url_handlers": "var",
  "version": "var",
  "webview": "var",
};

/**
 * Json validator for "manifest.json" contents.
 */
class AppManifestValidator extends RootObjectSchemaValidator {
  AppManifestValidator(ErrorCollector errorCollector)
    : super(errorCollector, app_manifest_schema);
}


class SchemaValidator extends NullValidator {
  static final SchemaValidator instance = new SchemaValidator();

  void checkValue(JsonEntity entity, StringEntity propertyName) {}
}

SchemaValidator createSchemaValidator(dynamic schema, ErrorCollector errorCollector) {
  if (schema is Map) {
   return new ObjectPropertiesSchemaValidator(errorCollector, schema);
  } else if (schema is List){
   return new ArrayElementsSchemaValidator(errorCollector, schema);
  } else if (schema is String){
    switch(schema) {
      case "var":
        return SchemaValidator.instance;
      case "string":
        return new StringValueValidator(errorCollector, schema);
      case "int":
        return new IntValueValidator(errorCollector, schema);
      case "num":
        return new NumberValueValidator(errorCollector, schema);
    }
  }
  throw new Exception("Element type \"${schema}\" is invalid.");
}

class RootObjectSchemaValidator extends SchemaValidator {
  static const String message = "Top level element must be an object.";

  final ErrorCollector errorCollector;
  final Map schema;

  RootObjectSchemaValidator(this.errorCollector, this.schema);

  JsonValidator enterObject() {
    return new ObjectPropertiesSchemaValidator(errorCollector, schema);
  }

  void leaveArray(ArrayEntity entity) {
    errorCollector.addMessage(entity.span, message);
  }

  void handleRootValue(ValueEntity entity) {
    errorCollector.addMessage(entity.span, message);
  }
}

class ObjectPropertiesSchemaValidator extends SchemaValidator {
  final ErrorCollector errorCollector;
  final Map schema;

  ObjectPropertiesSchemaValidator(this.errorCollector, this.schema);

  JsonValidator propertyName(StringEntity entity) {
    var propertyType = schema[entity.text];
    if (propertyType == null) {
      String message = "Property \"${entity.text}\" is not recognized.";
      errorCollector.addMessage(entity.span, message);
      return NullValidator.instance;
    }

    SchemaValidator valueValidator = createSchemaValidator(propertyType, errorCollector);
    return new ObjectPropertyValueValidator(errorCollector, valueValidator, entity);
  }
}

class ObjectPropertyValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;
  final SchemaValidator valueValidator;
  final StringEntity propName;

  ObjectPropertyValueValidator(this.errorCollector, this.valueValidator, this.propName);

  void propertyValue(JsonEntity entity) {
    valueValidator.checkValue(entity, propName);
  }

  JsonValidator enterObject() {
    if (valueValidator is ObjectPropertiesSchemaValidator) {
      return valueValidator;
    }
    return super.enterObject();
  }

  JsonValidator enterArray() {
    if (valueValidator is ArrayElementsSchemaValidator) {
      return valueValidator;
    }
    return super.enterArray();
  }

  void leaveObject(ObjectEntity entity) {
    if (valueValidator is ArrayElementsSchemaValidator) {
      errorCollector.addMessage(entity.span, "Array expected for property \"${propName.text}\".");
    }
  }

  void leaveArray(ArrayEntity entity) {
    if (valueValidator is ObjectPropertiesSchemaValidator) {
      errorCollector.addMessage(entity.span, "Object expected for property \"${propName.text}\".");
    }
  }
}

class ArrayElementsSchemaValidator extends SchemaValidator {
  final ErrorCollector errorCollector;
  final SchemaValidator valueValidator;

  ArrayElementsSchemaValidator(ErrorCollector errorCollector, List schema)
    : this.errorCollector = errorCollector,
      this.valueValidator = createSchemaValidator(schema[0], errorCollector);

  void arrayElement(JsonEntity entity) {
    valueValidator.checkValue(entity, null);
  }

  JsonValidator enterObject() {
    if (valueValidator is ObjectPropertiesSchemaValidator) {
      return valueValidator;
    }
    return super.enterObject();
  }

  JsonValidator enterArray() {
    if (valueValidator is ArrayElementsSchemaValidator) {
      return valueValidator;
    }
    return super.enterArray();
  }

  void leaveObject(ObjectEntity entity) {
    if (valueValidator is ArrayElementsSchemaValidator) {
      errorCollector.addMessage(entity.span, "Array expected.");
    }
  }

  void leaveArray(ArrayEntity entity) {
    if (valueValidator is ObjectPropertiesSchemaValidator) {
      errorCollector.addMessage(entity.span, "Object expected.");
    }
  }
}

class StringValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;
  final String type;

  StringValueValidator(this.errorCollector, this.type);

  void checkValue(JsonEntity entity, StringEntity propertyName) {
    if (entity is! StringEntity) {
      if (propertyName == null) {
        errorCollector.addMessage(entity.span, "String value expected");
      } else {
        errorCollector.addMessage(entity.span, "String value expected for property \"${propertyName.text}\".");
      }
    }
  }
}

class NumberValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;
  final String type;

  NumberValueValidator(this.errorCollector, this.type);

  void checkValue(JsonEntity entity, StringEntity propertyName) {
    if (entity is! NumberEntity) {
      if (propertyName == null) {
        errorCollector.addMessage(entity.span, "Numeric value expected");
      } else {
        errorCollector.addMessage(entity.span, "Numeric value expected for property \"${propertyName.text}\".");
      }
    }
  }
}

class IntValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;
  final String type;

  IntValueValidator(this.errorCollector, this.type);

  void checkValue(JsonEntity entity, StringEntity propertyName) {
    if (entity is NumberEntity && entity.number is int) {
      return;
    }
    if (propertyName == null) {
      errorCollector.addMessage(entity.span, "Integer value expected");
    } else {
      errorCollector.addMessage(entity.span, "Integer value expected for property \"${propertyName.text}\".");
    }
  }
}

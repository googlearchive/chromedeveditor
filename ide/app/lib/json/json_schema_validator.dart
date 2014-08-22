// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.json.schema_validator;

import '../json/json_validator.dart';

class ErrorIds {
  static final String TOP_LEVEL_OBJECT = "";
  static final String UNKNOWN_PROPERTY_NAME = "";
  static final String ARRAY_EXPECTED = "";
  static final String OBJECT_EXPECTED = "";
  static final String STRING_EXPECTED = "";
  static final String NUMBER_EXPECTED = "";
  static final String INTEGER_EXPECTED = "";
  static final String BOOLEAN_EXPECTED = "";
}

/**
 *  Type :==
 *    "var"
 *    "int" |
 *    "num" |
 *    "string" |
 *    '[' Type ']' |
 *    '{' name ':' Type '}'
 */

class RootObjectSchemaValidator extends SchemaValidator {
  static const String message = "Top level element must be an object.";

  final ErrorCollector errorCollector;
  final Map schema;

  RootObjectSchemaValidator(this.errorCollector, this.schema);

  JsonValidator enterObject() {
    return new ObjectPropertiesSchemaValidator(errorCollector, schema);
  }

  void leaveArray(ArrayEntity entity) {
    errorCollector.addMessage(ErrorIds.TOP_LEVEL_OBJECT, entity.span, message);
  }

  void handleRootValue(ValueEntity entity) {
    errorCollector.addMessage(ErrorIds.TOP_LEVEL_OBJECT, entity.span, message);
  }
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
      case "boolean":
        return new NumberValueValidator(errorCollector, schema);
    }
  }
  throw new FormatException("Element type \"${schema}\" is invalid.");
}

void validateSchemaDefinition(String path, dynamic schema) {
  if (schema is Map) {
    schema.forEach((key, value) {
      validateSchemaDefinition(path + ".${key}", value);
    });
    return;
  }

  if (schema is List){
    if (schema.length != 1) {
      throw new FormatException("${path}: array must contain only one element");
    }
    validateSchemaDefinition(path + "[0]", schema[0]);
    return;
  }

  if (schema is String){
    switch(schema) {
      case "var":
      case "string":
      case "int":
      case "num":
      case "boolean":
        return;
    }
  }
  throw new FormatException("${path}: Element type \"${schema}\" is invalid.");
}

class ObjectPropertiesSchemaValidator extends SchemaValidator {
  final ErrorCollector errorCollector;
  final Map schema;

  ObjectPropertiesSchemaValidator(this.errorCollector, this.schema);

  JsonValidator propertyName(StringEntity entity) {
    var propertyType = schema[entity.text];
    if (propertyType == null) {
      String message = "Property \"${entity.text}\" is not recognized.";
      errorCollector.addMessage(ErrorIds.UNKNOWN_PROPERTY_NAME,  entity.span, message);
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
      errorCollector.addMessage(ErrorIds.ARRAY_EXPECTED, entity.span, "Array expected for property \"${propName.text}\".");
    }
  }

  void leaveArray(ArrayEntity entity) {
    if (valueValidator is ObjectPropertiesSchemaValidator) {
      errorCollector.addMessage(ErrorIds.OBJECT_EXPECTED, entity.span, "Object expected for property \"${propName.text}\".");
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
      errorCollector.addMessage(ErrorIds.ARRAY_EXPECTED, entity.span, "Array expected.");
    }
  }

  void leaveArray(ArrayEntity entity) {
    if (valueValidator is ObjectPropertiesSchemaValidator) {
      errorCollector.addMessage(ErrorIds.OBJECT_EXPECTED, entity.span, "Object expected.");
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
        errorCollector.addMessage(ErrorIds.STRING_EXPECTED, entity.span, "String value expected");
      } else {
        errorCollector.addMessage(ErrorIds.STRING_EXPECTED, entity.span, "String value expected for property \"${propertyName.text}\".");
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
        errorCollector.addMessage(ErrorIds.NUMBER_EXPECTED, entity.span, "Numeric value expected");
      } else {
        errorCollector.addMessage(ErrorIds.NUMBER_EXPECTED, entity.span, "Numeric value expected for property \"${propertyName.text}\".");
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
      errorCollector.addMessage(ErrorIds.INTEGER_EXPECTED, entity.span, "Integer value expected");
    } else {
      errorCollector.addMessage(ErrorIds.INTEGER_EXPECTED, entity.span, "Integer value expected for property \"${propertyName.text}\".");
    }
  }
}

class BooleanValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;
  final String type;

  BooleanValueValidator(this.errorCollector, this.type);

  void checkValue(JsonEntity entity, StringEntity propertyName) {
    if (entity is BoolEntity) {
      return;
    }
    if (propertyName == null) {
      errorCollector.addMessage(ErrorIds.BOOLEAN_EXPECTED, entity.span, "Boolean value expected");
    } else {
      errorCollector.addMessage(ErrorIds.BOOLEAN_EXPECTED, entity.span, "Boolean value expected for property \"${propertyName.text}\".");
    }
  }
}

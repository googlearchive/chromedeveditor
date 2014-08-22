// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.json.schema_validator;

import '../json/json_validator.dart';

class ErrorIds {
  static final String TOP_LEVEL_OBJECT = "TOP_LEVEL_OBJECT";
  static final String UNKNOWN_PROPERTY_NAME = "UNKNOWN_PROPERTY_NAME";
  static final String ARRAY_EXPECTED = "ARRAY_EXPECTED";
  static final String OBJECT_EXPECTED = "OBJECT_EXPECTED";
  static final String STRING_EXPECTED = "STRING_EXPECTED";
  static final String NUMBER_EXPECTED = "NUMBER_EXPECTED";
  static final String INTEGER_EXPECTED = "INTEGER_EXPECTED";
  static final String BOOLEAN_EXPECTED = "BOOLEAN_EXPECTED";
}

abstract class SchemaValidatorFactory {
  SchemaValidator createValidator(dynamic schema);
  bool validateSchemaForTesting(dynamic schema);
  SchemaValidatorFactory get parentFactory;
}

/**
 * The core factory understands the following schema:
 *
 * SchemaType :==
 *    "var"
 *    "int" |
 *    "num" |
 *    "string" |
 *    List<SchemaType> |
 *    Map<String, SchemaType>
 */
class CoreSchemaValidatorFactory implements SchemaValidatorFactory {
  final SchemaValidatorFactory parentFactory;
  final ErrorCollector errorCollector;

  CoreSchemaValidatorFactory(this.parentFactory, this.errorCollector);

  SchemaValidator createValidator(dynamic schema) {
    if (parentFactory != null) {
      var result = parentFactory.createValidator(schema);
      if (result != null) {
        return result;
      }
    }

    if (schema is Map) {
      return new ObjectPropertiesSchemaValidator(this, errorCollector, schema);
    } else if (schema is List) {
      return new ArrayElementsSchemaValidator(this, errorCollector, schema);
    } else if (schema is String) {
      switch(schema) {
        case "var":
          return SchemaValidator.instance;
        case "string":
          return new StringValueValidator(errorCollector);
        case "int":
          return new IntValueValidator(errorCollector);
        case "num":
          return new NumberValueValidator(errorCollector);
        case "boolean":
          return new BooleanValueValidator(errorCollector);
      }
    }
    throw new FormatException("Element type \"${schema}\" is invalid.");
  }

  bool validateSchemaForTesting(dynamic schema) {
    if (parentFactory != null) {
      var result = parentFactory.validateSchemaForTesting(schema);
      if (result)
        return true;
    }

    if (schema is Map) {
      var result = true;
      schema.forEach((propertyName, propertySchema) {
        if (!validateSchemaForTesting(propertySchema)) {
          result = false;
        }
      });
      return result;
    }

    if (schema is List){
      if (schema.length != 1) {
        return false;
      }
      return validateSchemaForTesting(schema[0]);
    }

    if (schema is String){
      switch(schema) {
        case "var":
        case "string":
        case "int":
        case "num":
        case "boolean":
          return true;
      }
    }

    return false;
  }

}

class RootObjectSchemaValidator extends SchemaValidator {
  static const String message = "Top level element must be an object.";

  final SchemaValidatorFactory factory;
  final ErrorCollector errorCollector;
  final Map schema;

  RootObjectSchemaValidator(this.factory, this.errorCollector, this.schema);

  JsonValidator enterObject() {
    return new ObjectPropertiesSchemaValidator(factory, errorCollector, schema);
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

class ObjectPropertiesSchemaValidator extends SchemaValidator {
  final SchemaValidatorFactory factory;
  final ErrorCollector errorCollector;
  final Map schema;

  ObjectPropertiesSchemaValidator(
      this.factory, this.errorCollector, this.schema);

  JsonValidator propertyName(StringEntity entity) {
    var propertyType = schema[entity.text];
    if (propertyType == null) {
      String message = "Property \"${entity.text}\" is not recognized.";
      errorCollector.addMessage(
          ErrorIds.UNKNOWN_PROPERTY_NAME,  entity.span, message);
      return NullValidator.instance;
    }

    SchemaValidator valueValidator = factory.createValidator(propertyType);
    return new ObjectPropertyValueValidator(
        errorCollector, valueValidator, entity);
  }
}

class ObjectPropertyValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;
  final SchemaValidator valueValidator;
  final StringEntity propName;

  ObjectPropertyValueValidator(
      this.errorCollector, this.valueValidator, this.propName);

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
      errorCollector.addMessage(
          ErrorIds.ARRAY_EXPECTED,
          entity.span,
          "Array expected for property \"${propName.text}\".");
    }
  }

  void leaveArray(ArrayEntity entity) {
    if (valueValidator is ObjectPropertiesSchemaValidator) {
      errorCollector.addMessage(
          ErrorIds.OBJECT_EXPECTED,
          entity.span,
          "Object expected for property \"${propName.text}\".");
    }
  }
}

class ArrayElementsSchemaValidator extends SchemaValidator {
  final SchemaValidatorFactory factory;
  final ErrorCollector errorCollector;
  final SchemaValidator valueValidator;

  ArrayElementsSchemaValidator(
      SchemaValidatorFactory factory,
      ErrorCollector errorCollector,
      List schema)
    : this.factory = factory,
      this.errorCollector = errorCollector,
      this.valueValidator = factory.createValidator(schema[0]);

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
      errorCollector.addMessage(
          ErrorIds.ARRAY_EXPECTED, entity.span, "Array expected.");
    }
  }

  void leaveArray(ArrayEntity entity) {
    if (valueValidator is ObjectPropertiesSchemaValidator) {
      errorCollector.addMessage(
          ErrorIds.OBJECT_EXPECTED, entity.span, "Object expected.");
    }
  }
}

class StringValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;

  StringValueValidator(this.errorCollector);

  void checkValue(JsonEntity entity, StringEntity propertyName) {
    if (entity is! StringEntity) {
      if (propertyName == null) {
        errorCollector.addMessage(
            ErrorIds.STRING_EXPECTED, entity.span, "String value expected");
      } else {
        errorCollector.addMessage(
            ErrorIds.STRING_EXPECTED,
            entity.span,
            "String value expected for property \"${propertyName.text}\".");
      }
    }
  }
}

class NumberValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;

  NumberValueValidator(this.errorCollector);

  void checkValue(JsonEntity entity, StringEntity propertyName) {
    if (entity is! NumberEntity) {
      if (propertyName == null) {
        errorCollector.addMessage(
            ErrorIds.NUMBER_EXPECTED, entity.span, "Numeric value expected");
      } else {
        errorCollector.addMessage(
            ErrorIds.NUMBER_EXPECTED,
            entity.span,
            "Numeric value expected for property \"${propertyName.text}\".");
      }
    }
  }
}

class IntValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;

  IntValueValidator(this.errorCollector);

  void checkValue(JsonEntity entity, StringEntity propertyName) {
    if (entity is NumberEntity && entity.number is int) {
      return;
    }
    if (propertyName == null) {
      errorCollector.addMessage(
          ErrorIds.INTEGER_EXPECTED, entity.span, "Integer value expected");
    } else {
      errorCollector.addMessage(
          ErrorIds.INTEGER_EXPECTED,
          entity.span,
          "Integer value expected for property \"${propertyName.text}\".");
    }
  }
}

class BooleanValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;

  BooleanValueValidator(this.errorCollector);

  void checkValue(JsonEntity entity, StringEntity propertyName) {
    if (entity is BoolEntity) {
      return;
    }
    if (propertyName == null) {
      errorCollector.addMessage(
          ErrorIds.BOOLEAN_EXPECTED, entity.span, "Boolean value expected");
    } else {
      errorCollector.addMessage(
          ErrorIds.BOOLEAN_EXPECTED,
          entity.span,
          "Boolean value expected for property \"${propertyName.text}\".");
    }
  }
}

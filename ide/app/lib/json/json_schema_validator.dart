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

/**
 * A [SchemaValidator] instance is a custom type of json validator
 * that handles validation of schema definitions.
 */
class SchemaValidator extends NullValidator {
  static final SchemaValidator instance = new SchemaValidator();

  /** Called when a value has been parsed and needs to be validated. */
  void checkValue(JsonEntity entity, [StringEntity propertyName]) {}
}

/**
 * A schema validator factory is reponsible for creating [SchemaValidator]
 * instances based on the content of a schema definition.
 */
abstract class SchemaValidatorFactory {
  /**
   * Returns a [SchemaValidator] instance corresponding to the [schema]
   * definition, or `null` if the factory does not understand [schema].
   */
  SchemaValidator createValidator(dynamic schema);

  /** Returns `true` if [schema] is a valid schema for this factory */
  bool validateSchemaForTesting(dynamic schema);
}

/**
 * The core schema factory understands a limited set of schema types and
 * forwards the to a parent factory for custom schema types.
 *
 * The factory supports the following type definition:
 *
 * SchemaType :==
 *    "boolean" |    // true and false literals only
 *    "int" |        // integer values only
 *    "num" |        // numeric values only
 *    "string" |     // string literals only
 *    "var"          // anything is valid
 *    List<SchemaType> |       // Array of types
 *    Map<String, SchemaType>  // Map of (property name, type)
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
      return new ObjectSchemaValidator(this, errorCollector, schema);
    } else if (schema is List) {
      return new ArraySchemaValidator(this, errorCollector, schema);
    } else if (schema is String) {
      switch(schema) {
        case "boolean":
          return new BooleanValueValidator(errorCollector);
        case "int":
          return new IntegerValueValidator(errorCollector);
        case "num":
          return new NumberValueValidator(errorCollector);
        case "string":
          return new StringValueValidator(errorCollector);
        case "var":
          return SchemaValidator.instance;
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
      var isValid = true;
      schema.forEach((propertyName, propertySchema) {
        if (!validateSchemaForTesting(propertySchema)) {
          isValid = false;
        }
      });
      return isValid;
    } else if (schema is List) {
      if (schema.length != 1) {
        return false;
      }
      return validateSchemaForTesting(schema[0]);
    } else if (schema is String) {
      switch(schema) {
        case "boolean":
        case "int":
        case "num":
        case "string":
        case "var":
          return true;
        default:
          return false;
      }
    } else {
      return false;
    }
  }
}

/**
 * Schema validator used when the root object of the schema is expected to be
 * a json object.
 */
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

/**
 * Schema validator that handles validation of a json object based on
 * a [Map] schema definition.
 */
class ObjectSchemaValidator extends SchemaValidator {
  final SchemaValidatorFactory factory;
  final ErrorCollector errorCollector;
  final Map schema;

  ObjectSchemaValidator(this.factory, this.errorCollector, this.schema);

  JsonValidator enterObject() {
    return new ObjectPropertiesSchemaValidator(factory, errorCollector, schema);
  }

  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is! ObjectEntity) {
      if (propertyName == null) {
        errorCollector.addMessage(
            ErrorIds.OBJECT_EXPECTED, entity.span, "Object expected.");
      } else {
        errorCollector.addMessage(
            ErrorIds.OBJECT_EXPECTED,
            entity.span,
            "Object expected for property \"${propertyName.text}\".");
      }
    }
  }
}

/**
 * Schema validator that handles validation of the properties of a json object
 * based on a [Map] schema definition.
 */
class ObjectPropertiesSchemaValidator extends SchemaValidator {
  final SchemaValidatorFactory factory;
  final ErrorCollector errorCollector;
  final Map schema;

  ObjectPropertiesSchemaValidator(this.factory, this.errorCollector, this.schema);

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

/**
 * Schema validator that handles validation of a property value of a json
 * for a given property name and [SchemaValidator] instance to validate
 * the property value.
 */
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
    return valueValidator.enterObject();
  }

  JsonValidator enterArray() {
    return valueValidator.enterArray();
  }
}

/**
 * Schema validator that handles validation of a json array based on
 * a [List] schema definition.
 */
class ArraySchemaValidator extends SchemaValidator {
  final SchemaValidatorFactory factory;
  final ErrorCollector errorCollector;
  final List schema;

  ArraySchemaValidator(this.factory, this.errorCollector, this.schema);

  JsonValidator enterArray() {
    return new ArrayElementsSchemaValidator(factory, errorCollector, schema);
  }

  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is! ArrayEntity) {
      if (propertyName == null) {
        errorCollector.addMessage(
            ErrorIds.ARRAY_EXPECTED, entity.span, "Array expected.");
      } else {
        errorCollector.addMessage(
            ErrorIds.ARRAY_EXPECTED,
            entity.span,
            "Array expected for property \"${propertyName.text}\".");
      }
    }
  }
}

/**
 * Schema validator that handles validation of the elements of a json array
 * based on a [List] schema definition.
 */
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
    return valueValidator.enterObject();
  }

  JsonValidator enterArray() {
    return valueValidator.enterArray();
  }
}

/**
 * Base class to literal value schema validator.
 */
abstract class LiteralValueSchemaValidator extends SchemaValidator {
  void leaveObject(ObjectEntity entity) {
    checkValue(entity);
  }

  void leaveArray(ArrayEntity entity) {
    checkValue(entity);
  }

  void checkValue(JsonEntity entity, [StringEntity propertyName]);
}

/**
 * Schema validator for string values.
 */
class StringValueValidator extends LiteralValueSchemaValidator {
  final ErrorCollector errorCollector;

  StringValueValidator(this.errorCollector);

  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is! StringEntity) {
      if (propertyName == null) {
        errorCollector.addMessage(
            ErrorIds.STRING_EXPECTED, entity.span, "String value expected.");
      } else {
        errorCollector.addMessage(
            ErrorIds.STRING_EXPECTED,
            entity.span,
            "String value expected for property \"${propertyName.text}\".");
      }
    }
  }
}

/**
 * Schema validator for numeric values.
 */
class NumberValueValidator extends LiteralValueSchemaValidator {
  final ErrorCollector errorCollector;

  NumberValueValidator(this.errorCollector);

  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is! NumberEntity) {
      if (propertyName == null) {
        errorCollector.addMessage(
            ErrorIds.NUMBER_EXPECTED, entity.span, "Numeric value expected.");
      } else {
        errorCollector.addMessage(
            ErrorIds.NUMBER_EXPECTED,
            entity.span,
            "Numeric value expected for property \"${propertyName.text}\".");
      }
    }
  }
}

/**
 * Schema validator for integer values.
 */
class IntegerValueValidator extends LiteralValueSchemaValidator {
  final ErrorCollector errorCollector;

  IntegerValueValidator(this.errorCollector);

  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is NumberEntity && entity.number is int) {
      return;
    }
    if (propertyName == null) {
      errorCollector.addMessage(
          ErrorIds.INTEGER_EXPECTED, entity.span, "Integer value expected.");
    } else {
      errorCollector.addMessage(
          ErrorIds.INTEGER_EXPECTED,
          entity.span,
          "Integer value expected for property \"${propertyName.text}\".");
    }
  }
}

/**
 * Schema validator for boolean values.
 */
class BooleanValueValidator extends LiteralValueSchemaValidator {
  final ErrorCollector errorCollector;

  BooleanValueValidator(this.errorCollector);

  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is BoolEntity) {
      return;
    }
    if (propertyName == null) {
      errorCollector.addMessage(
          ErrorIds.BOOLEAN_EXPECTED, entity.span, "Boolean value expected.");
    } else {
      errorCollector.addMessage(
          ErrorIds.BOOLEAN_EXPECTED,
          entity.span,
          "Boolean value expected for property \"${propertyName.text}\".");
    }
  }
}

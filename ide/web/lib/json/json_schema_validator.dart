// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.json.schema_validator;

import '../json/json_validator.dart';

class ErrorIds {
  static final String INVALID_PROPERTY_NAME = "UNKNOWN_PROPERTY_NAME";
  static final String MISSING_MANDATORY_PROPERTY = "MISSING_MANDATORY_PROPERTY";
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

  /**
   * Called when a value [entity] has been parsed and needs validation.
   * [entity] is either a simple literal, an array element or a object
   * property value, in which case the [propertyName] is passed in.
   */
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
   * [rootFactory] is the "root" factory in case of chained factories.
   */
  SchemaValidator createValidator(
      SchemaValidatorFactory rootFactory, dynamic schema);

  /** Returns `true` if [schema] is a valid schema for this factory */
  bool validateSchemaForTesting(dynamic schema);
}

typedef SchemaValidator SchemaValidatorCreator(ErrorCollector errorCollector);

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
 *    List<SchemaType> |       // Array of types (1 element only)
 *    Map<PropertySpec, SchemaType>
 *
 * PropertySpec :==
 *   MetaPropertyName  // Special properties used for validation
 *   PropertyName ||   // Simple string containing optional property name
 *   PropertyName "!"  // Mandatory property names have a "!" suffix
 *
 * MetaPropertyName :: =
 *   "<meta-open-ended>"  // Flag indicating if unlisted property names are
 *                        // allowed (true by default).
 */
class CoreSchemaValidatorFactory implements SchemaValidatorFactory {
  /**
   * Use this custom property (with a boolean value) to specify that the
   * object/dictionary can only contain properties defined in the current
   * schema object definition. Any other property name used in the validated
   * json document will result in validation errors.
   */
  static final String MetaOpenEnded = "<meta-open-ended>";
  static final Map<String, SchemaValidatorCreator> _literalValidators = {
    "boolean": (e) => new BooleanValueValidator(e),
    "int": (e) => new IntegerValueValidator(e),
    "num": (e) => new NumberValueValidator(e),
    "string": (e) => new StringValueValidator(e),
    "var": (e) => SchemaValidator.instance,
  };
  final SchemaValidatorFactory parentFactory;
  final ErrorCollector errorCollector;

  CoreSchemaValidatorFactory(this.parentFactory, this.errorCollector);

  @override
  SchemaValidator createValidator(
      SchemaValidatorFactory rootFactory, dynamic schema) {
    assert(identical(this, rootFactory));

    if (parentFactory != null) {
      SchemaValidator result =
          parentFactory.createValidator(rootFactory, schema);
      if (result != null) {
        return result;
      }
    }

    if (schema is Map) {
      return new ObjectSchemaValidator(this, errorCollector, schema);
    } else if (schema is List) {
      return new ArraySchemaValidator(this, errorCollector, schema);
    } else if (schema is String) {
      SchemaValidatorCreator creator = _literalValidators[schema];
      if (creator != null) {
        return creator(errorCollector);
      }
    }
    throw new FormatException("Element type \"${schema}\" is invalid.");
  }

  @override
  bool validateSchemaForTesting(dynamic schema) {
    if (parentFactory != null) {
      var result = parentFactory.validateSchemaForTesting(schema);
      if (result) {
        return true;
      }
    }

    if (schema is Map) {
      bool isValid = true;
      schema.forEach((String propertyName, dynamic propertySchema) {
        if (propertyName == MetaOpenEnded) {
          if (propertySchema is! bool) {
            isValid = false;
          }
        } else if (!validateSchemaForTesting(propertySchema)) {
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
      return _literalValidators.containsKey(schema);
    } else {
      return false;
    }
  }
}

/**
 * Schema validator that handles validation of a json object based on a [Map]
 * schema definition. Errors are generated if the parsed json entity is not a
 * json object.
 */
class ObjectSchemaValidator extends SchemaValidator {
  final SchemaValidatorFactory factory;
  final ErrorCollector errorCollector;
  final Map schema;
  ObjectPropertiesSchemaValidator validator;

  ObjectSchemaValidator(this.factory, this.errorCollector, this.schema) {
    validator = new ObjectPropertiesSchemaValidator(factory, errorCollector, schema);
  }

  @override
  JsonValidator enterObject() {
    return validator.enterObject();
  }

  @override
  void leaveObject(ObjectEntity entity) {
    validator.leaveObject(entity);
  }

  @override
  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is ObjectEntity) {
      return;
    }
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

/**
 * Schema validator used when the root object of the schema is expected to be
 * a json object. Errors are generated if the top level json entity is not a
 * json object.
 */
class RootObjectSchemaValidator extends ObjectSchemaValidator {
  RootObjectSchemaValidator(
      SchemaValidatorFactory factory,
      ErrorCollector errorCollector,
      Map schema)
    : super(factory, errorCollector, schema);

  @override
  void leaveArray(ArrayEntity entity) {
    checkValue(entity);
  }

  @override
  void handleRootValue(ValueEntity entity) {
    checkValue(entity);
  }
}

/**
 * Schema validator that handles validation of the properties of a json object
 * based on a [Map] schema definition. Errors are generated for object
 * properties that are not present in [schema].
 */
class ObjectPropertiesSchemaValidator extends SchemaValidator {
  final SchemaValidatorFactory factory;
  final ErrorCollector errorCollector;
  final Map<String, dynamic> schema;
  bool _isOpenEnded;
  Set<String> _mandatoryProperties;
  Set<String> _mandatoryPropertiesSeen = new Set<String>();

  ObjectPropertiesSchemaValidator(this.factory, this.errorCollector, this.schema) {
    _isOpenEnded = schema[CoreSchemaValidatorFactory.MetaOpenEnded];
    if (_isOpenEnded == null) {
      _isOpenEnded = true;
    }
    _mandatoryProperties = schema.keys
        .where((String key) => key.endsWith("!"))
        .map((String key) => key.substring(0, key.length - 1))
        .toSet();
  }

  @override
  JsonValidator propertyName(StringEntity entity) {
    String name = entity.text;
    // Keep track of mandatory properties used in this object.
    if (_mandatoryProperties.contains(name)) {
      _mandatoryPropertiesSeen.add(name);
      name += "!";
    }

    var propertyType = schema[name];
    if (propertyType == null) {
      if (!_isOpenEnded) {
        String message = "Property \"${entity.text}\" is not recognized.";
        errorCollector.addMessage(
            ErrorIds.INVALID_PROPERTY_NAME,  entity.span, message);
      }
      return NullValidator.instance;
    }

    SchemaValidator valueValidator =
        factory.createValidator(factory, propertyType);
    return new ObjectPropertyValueValidator(entity, valueValidator);
  }

  /**
   * Note: This method is a special case, in the sense that it is explictly
   * called by "ObjectSchemaValidator".
   */
  @override
  JsonValidator enterObject() {
    assert(_mandatoryPropertiesSeen.isEmpty);
    return this;
  }

  /**
   * Note: This method is a special case, in the sense that it is explictly
   * called by "ObjectSchemaValidator".
   */
  @override
  void leaveObject(ObjectEntity entity) {
    // Create an error for every mandatory property not present in the object.
    Set<String> missingProperties = _mandatoryProperties
        .difference(_mandatoryPropertiesSeen);
    missingProperties.forEach((name) {
      String message = "Object is missing mandatory property \"${name}\".";
      errorCollector.addMessage(
          ErrorIds.MISSING_MANDATORY_PROPERTY, entity.span, message);
    });
    _mandatoryPropertiesSeen.clear();
  }
}

/**
 * Schema validator that handles validation of a property value of a json
 * object for a given property name [propName] and a [SchemaValidator]
 * instance used to validate the property value.
 */
class ObjectPropertyValueValidator extends SchemaValidator {
  final SchemaValidator valueValidator;
  final StringEntity propName;

  ObjectPropertyValueValidator(this.propName, this.valueValidator);

  @override
  void propertyValue(JsonEntity entity) {
    valueValidator.checkValue(entity, propName);
  }

  @override
  JsonValidator enterObject() {
    return valueValidator.enterObject();
  }

  @override
  void leaveObject(ObjectEntity entity) {
    valueValidator.leaveObject(entity);
  }

  @override
  JsonValidator enterArray() {
    return valueValidator.enterArray();
  }

  @override
  void leaveArray(ArrayEntity entity) {
    valueValidator.leaveArray(entity);
  }
}

/**
 * Schema validator that handles validation of a json array based on
 * a [List] schema definition. [schema] must contain a single element
 * with the type of elements allowed in corresponding json array.
 * Errors are generated if the parsed json entity is not an array.
 */
class ArraySchemaValidator extends SchemaValidator {
  final SchemaValidatorFactory factory;
  final ErrorCollector errorCollector;
  final List schema;

  ArraySchemaValidator(this.factory, this.errorCollector, this.schema);

  @override
  JsonValidator enterArray() {
    SchemaValidator valueValidator =
        factory.createValidator(factory, schema[0]);
    return new ArrayElementsSchemaValidator(valueValidator);
  }

  @override
  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is ArrayEntity) {
      return;
    }
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

/**
 * Schema validator that handles validation of the elements of a json array
 * by calling [checkValue] on [valueValidator] for each element of the array.
 */
class ArrayElementsSchemaValidator extends SchemaValidator {
  final SchemaValidator valueValidator;

  ArrayElementsSchemaValidator(this.valueValidator);

  @override
  void arrayElement(JsonEntity entity) {
    valueValidator.checkValue(entity, null);
  }

  @override
  JsonValidator enterObject() {
    return valueValidator.enterObject();
  }

  @override
  void leaveObject(ObjectEntity entity) {
    valueValidator.leaveObject(entity);
  }

  @override
  JsonValidator enterArray() {
    return valueValidator.enterArray();
  }

  @override
  void leaveArray(ArrayEntity entity) {
    valueValidator.leaveArray(entity);
  }
}

/**
 * Schema validator for string values. Errors are generated if the parsed
 * json entity is not a string literal.
 */
class StringValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;

  StringValueValidator(this.errorCollector);

  @override
  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is StringEntity) {
      return;
    }
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

/**
 * Schema validator for numeric values. Errors are generated if the parsed
 * json entity is not a numeric literal.
 */
class NumberValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;

  NumberValueValidator(this.errorCollector);

  @override
  void checkValue(JsonEntity entity, [StringEntity propertyName]) {
    if (entity is NumberEntity) {
      return;
    }
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

/**
 * Schema validator for integer values. Errors are generated if the parsed
 * json entity is not an integer literal.
 */
class IntegerValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;

  IntegerValueValidator(this.errorCollector);

  @override
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
 * Schema validator for boolean values. Errors are generated if the parsed
 * json entity is not a boolean literal.
 */
class BooleanValueValidator extends SchemaValidator {
  final ErrorCollector errorCollector;

  BooleanValueValidator(this.errorCollector);

  @override
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

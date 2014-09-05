// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.json.validator;

import 'json_parser.dart';

class ErrorIds {
  static final String JSON_ERROR = "JSON_ERROR";
}

/**
 * Event based interface of a json validator. A json validator is similar to
 * a [JsonListener], except that events expose [JsonEntity] instances and that
 * new validators are used when navigating inside containers (i.e. arrays or
 * objects).
 */
abstract class JsonValidator {
  /**
   * Invoked when the json document contains a single root literal value.
   */
  void handleRootValue(ValueEntity entity);

  /**
   * Invoked when entering an array.
   *
   * Returns a validator for the elements of the array.
   */
  JsonValidator enterArray();

  /**
   * Invoked after parsing an array. Called on the validator that received the
   * corresponding [enterArray].
   */
  void leaveArray(ArrayEntity entity);

  /**
   * Invoked after parsing an array value. Called on the validator returned
   * by the corresponding [enterArray].
   */
  void arrayElement(JsonEntity entity);

  /**
   * Invoked when entering an object.
   *
   * Returns a validator for the properties of the object.
   */
  JsonValidator enterObject();

  /**
   * Invoked when leaving an object. Called on the validator that received
   * the corresponding [enterObject].
   */
  void leaveObject(ObjectEntity entity);

  /**
   * Invoked after parsing an property name inside an object. Called on the
   * validator returned by the corresponding [enterObject].
   *
   * Returns a validator for the property value.
   */
  JsonValidator propertyName(StringEntity entity);

  /**
   * Invoked after parsing a propery value inside an object. Called on the
   * validator retruned by the corresponding [propertyName].
   */
  void propertyValue(JsonEntity entity);
}

/**
 * Abstraction over an error reporting mechanism that understands error
 * spans and messages for given source text.
 */
abstract class ErrorCollector {
  void addMessage(String messageId, Span span, String message);
}

/**
 * Implements [JsonListener] and forward json validation events to
 * a [JsonValidator]. The implementation uses a stack of [JsonValidator]
 * instances and listen to the various "enterXxx"/"leaveXxx" methods of
 * [JsonListener] to keep track of the active validator and forward
 * events accordingly.
 */
class JsonValidatorListener extends JsonListener {
  final ErrorCollector _jsonErrorCollector;
  final List<ContainerEntity> _containers = new List<ContainerEntity>();
  final List<StringEntity> _keys = new List<StringEntity>();
  final List<JsonValidator> _validators = new List<JsonValidator>();
  ContainerEntity _currentContainer;
  JsonValidator _currentValidator;
  StringEntity _key;
  JsonEntity _value;

  /**
   * Creates a new listener given an [ErrorCollector] used to report json
   * syntax errors and a [JsonValidator] used as the initial validator for
   * the root json elements.
   */
  JsonValidatorListener(this._jsonErrorCollector, JsonValidator rootValidator)
      : this._currentValidator = rootValidator;

  /** Pushes the currently active container (and key, if a [Map]). */
  void pushContainer() {
    if (_currentContainer is ObjectEntity) {
      assert(_key != null);
      _keys.add(_key);
    }
    _containers.add(_currentContainer);
  }

  /** Pops the top container from the [stack], including a key if applicable. */
  void popContainer() {
    _value = _currentContainer;
    _currentContainer = _containers.removeLast();
    if (_currentContainer is ObjectEntity) {
      _key = _keys.removeLast();
    }
  }

  void pushValidator() {
    _validators.add(_currentValidator);
  }

  void popValidator() {
    _currentValidator = _validators.removeLast();
  }

  void handleString(Span span, String value) {
    _value = new StringEntity(span, value);
  }

  void handleNumber(Span span, num value) {
    _value = new NumberEntity(span, value);
  }

  void handleBool(Span span, bool value) {
    _value = new BoolEntity(span, value);
  }

  void handleNull(Span span) {
    _value = new NullEntity(span);
  }

  /**
   * Called when the opening "{" of an object is parsed.
   */
  void beginObject(int position) {
    assert(_currentValidator != null);
    pushContainer();
    pushValidator();
    _currentContainer = new ObjectEntity();
    _currentValidator = _currentValidator.enterObject();
  }

  /**
   * Called when the closing "}" of an object is parsed.
   * Invariants: current container is an [ObjectEntity].
   */
  void endObject(Span span) {
    assert(_currentValidator != null);
    assert(_currentContainer != null);
    assert(_currentContainer is ObjectEntity);
    _currentContainer.span = span;
    popValidator();
    _currentValidator.leaveObject(_currentContainer);
    popContainer();
  }

  /**
   * Called when the opening "[" of an array is parsed.
   */
  void beginArray(int position) {
    assert(_currentValidator != null);
    pushContainer();
    pushValidator();
    _currentContainer = new ArrayEntity();
    _currentValidator = _currentValidator.enterArray();
  }

  /**
   * Called when the closing "]" of an array is parsed.
   * Invariants: current container is an [ArrayEntity].
   */
  void endArray(Span span) {
    assert(_currentValidator != null);
    assert(_currentContainer != null);
    assert(_currentContainer is ArrayEntity);
    _currentContainer.span = span;
    popValidator();
    _currentValidator.leaveArray(_currentContainer);
    popContainer();
  }

  /**
   * Called when a ":" is parsed inside an object.
   * Invariants: current container is an [ObjectEntity].
   */
  void propertyName(Span span) {
    assert(_currentValidator != null);
    assert(_currentContainer != null);
    assert(_currentContainer is ObjectEntity);
    assert(_value != null);
    assert(_value is StringEntity);
    _key = _value;
    _value = null;
    pushValidator();
    _currentValidator = _currentValidator.propertyName(_key);
  }

  /**
   * Called when a "," or "}" is parsed inside an object.
   * Invariants: current container is an [ObjectEntity].
   */
  void propertyValue(Span span) {
    assert(_currentValidator != null);
    assert(_currentContainer != null);
    assert(_currentContainer is ObjectEntity);
    assert(_value != null);
    _currentValidator.propertyValue(_value);
    popValidator();
    _key = _value = null;
  }

  /**
   * Called when the "," after an array element is parsed.
   * Invariants: current container is an [ArrayEntity].
   */
  void arrayElement(Span span) {
    assert(_currentValidator != null);
    assert(_currentContainer != null);
    assert(_currentContainer is ArrayEntity);
    assert(_value != null);
    _currentValidator.arrayElement(_value);
    _value = null;
  }

  void endDocument(Span span) {
    if (_value is ValueEntity) {
      _currentValidator.handleRootValue(_value);
    }
  }

  void fail(String source, Span span, String message) {
    _jsonErrorCollector.addMessage(ErrorIds.JSON_ERROR, span, message);
  }
}

/**
 * No-op base implementation of a [JsonValidator].
 */
class NullValidator implements JsonValidator {
  static final JsonValidator instance = new NullValidator();

  void handleRootValue(ValueEntity entity) {}

  JsonValidator enterArray() { return instance; }

  void leaveArray(ArrayEntity entity) {}

  void arrayElement(JsonEntity entity) {}

  JsonValidator enterObject() { return instance; }

  void leaveObject(ObjectEntity entity) {}

  JsonValidator propertyName(StringEntity entity) { return instance; }

  void propertyValue(JsonEntity entity) {}
}


/**
 * Abstract base class of all types of json entities that are parsed
 * and exposed with a [Span].
 */
abstract class JsonEntity {
  Span span;
}

/**
 * Abstract base class for simple values.
 */
abstract class ValueEntity extends JsonEntity {
  dynamic get value;
}

/**
 * Abstract base class for containers (array and object).
 */
abstract class ContainerEntity extends JsonEntity {
}

/**
 * Entity for string values.
 */
class StringEntity extends ValueEntity {
  final String text;
  StringEntity(Span span, this.text) {
    this.span = span;
  }

  get value => this.text;
}

/**
 * Entity for `null` literal values.
 */
class NullEntity extends ValueEntity {
  NullEntity(Span span) {
    this.span = span;
  }

  get value => null;
}

/**
 * Entity for numeric values.
 */
class NumberEntity extends ValueEntity {
  final num number;
  NumberEntity(Span span, this.number) {
    this.span = span;
  }

  get value => this.number;
}

/**
 * Entity for "true" or "false" literal values.
 */
class BoolEntity extends ValueEntity {
  final bool boolValue;
  BoolEntity(Span span, this.boolValue) {
    this.span = span;
  }

  get value => this.boolValue;
}

/**
 * Entity for array values.
 */
class ArrayEntity extends ContainerEntity {
}

/**
 * Entity for object values.
 */
class ObjectEntity extends ContainerEntity {
}

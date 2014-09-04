// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Note: The parser implementation is based on the deprecated
// "package:json/json.dart" implementation. It has been modifed
// to expose source span information when parsing elements.

library spark.json.parser;

/**
 * Straightforward span representation.
 */
class Span {
  /// Start position (inclusive)
  final int start;
  /// End position (exclusive)
  final int end;
  Span(this.start, this.end) {
    assert(start >= 0);
    assert(end >= start);
  }
}

/**
 * Simple event API for json parsing.
 */
abstract class JsonListener {
  /**
   * Called when a string has been parsed in the context of a top level
   * value, property name, propery value or array element.
   */
  void handleString(Span span, String value) {}
  /**
   * Called when a number has been parsed in the context of a top level
   * value, property name, propery value or array element.
   */
  void handleNumber(Span span, num value) {}
  /**
   * Called when a boolean value "true" or "false" has been parsed in the
   * context of a top level value, property name, propery value or array
   * element.
   */
  void handleBool(Span span, bool value) {}
  /**
   * Called when a "null" has been parsed in the context of a top level
   * value, property name, propery value or array element.
   */
  void handleNull(Span span) {}
  /**
   * Called when the opening brace of an object has been parsed.
   */
  void beginObject(int position) {}
  /**
   * Called when a property name of an object has been parsed. The name
   * has been reported during the previous call to [handleString].
   */
  void propertyName(Span span) {}
  /**
   * Called when a property value of an object has been parsed. The value
   * has been reported during the previous call to any [handleXxx] method,
   * [endArray] or [endObject].
   */
  void propertyValue(Span span) {}
  /**
   * Called when the closing brace of an object has been parsed. [span]
   * is the span from the '{' to the '}'.
   */
  void endObject(Span span) {}
  /**
   * Called when the opening bracket of an array has been parsed.
   */
  void beginArray(int position) {}
  /**
   * Called when an array element has been parsed. The value has
   * been reported during the previous call to any [handleXxx] method,
   * [endArray] or [endObject].
   */
  void arrayElement(Span span) {}
  /**
   * Called when the closing bracket of an array has been parsed. [span]
   * is the span from the '[' to the ']'.
   */
  void endArray(Span span) {}
  /**
   * Called when the of document has been reached.
   */
  void endDocument(Span span) {}
  /**
   * Called when a syntax error has been detected.
   */
  void fail(String source, Span span, String message) {}
}

/**
 * Stack of container/literal positions used to keep track of their spans.
 */
class _SpanStack {
  final List<int> _containerStartPositions = <int>[];
  int _literalStartPosition;
  Span _lastSpan;

  void enterContainer(int position) {
    _literalStartPosition = null;
    _containerStartPositions.add(position);
  }

  void leaveContainer(int position) {
    assert(_containerStartPositions.length > 0);
    _literalStartPosition = null;
    _lastSpan = new Span(_containerStartPositions.removeLast(), position);
  }

  void enterLiteral(int position) {
    _literalStartPosition = position;
  }

  void leaveLiteral(int position) {
    assert(_literalStartPosition != null);
    _lastSpan = new Span(_literalStartPosition, position);
    _literalStartPosition = null;
  }

  Span getLastSpan() {
    assert(_lastSpan != null);
    return _lastSpan;
  }
}

/**
 * A simple event based parser for JSON, that invokes methods of a
 * [JsonListener] instance during parsing.
 */
class JsonParser {
  // A simple non-recursive state-based parser for JSON.
  //
  // Literal values accepted in states ARRAY_EMPTY, ARRAY_COMMA, OBJECT_COLON
  // and strings also in OBJECT_EMPTY, OBJECT_COMMA.
  //               VALUE  STRING  :  ,  }  ]        Transitions to
  // EMPTY            X      X                   -> END
  // ARRAY_EMPTY      X      X             @     -> ARRAY_VALUE / pop
  // ARRAY_VALUE                     @     @     -> ARRAY_COMMA / pop
  // ARRAY_COMMA      X      X                   -> ARRAY_VALUE
  // OBJECT_EMPTY            X          @        -> OBJECT_KEY / pop
  // OBJECT_KEY                   @              -> OBJECT_COLON
  // OBJECT_COLON     X      X                   -> OBJECT_VALUE
  // OBJECT_VALUE                    @  @        -> OBJECT_COMMA / pop
  // OBJECT_COMMA            X                   -> OBJECT_KEY
  // END
  // Starting a new array or object will push the current state. The "pop"
  // above means restoring this state and then marking it as an ended value.
  // X means generic handling, @ means special handling for just that
  // state - that is, values are handled generically, only punctuation
  // cares about the current state.
  // Values for states are chosen so bits 0 and 1 tell whether
  // a string/value is allowed, and setting bits 0 through 2 after a value
  // gets to the next state (not empty, doesn't allow a value).

  // State building-block constants.
  static const int INSIDE_ARRAY = 1;
  static const int INSIDE_OBJECT = 2;
  static const int AFTER_COLON = 3; // Always inside object.

  static const int ALLOW_STRING_MASK = 8; // Allowed if zero.
  static const int ALLOW_VALUE_MASK = 4; // Allowed if zero.
  static const int ALLOW_VALUE = 0;
  static const int STRING_ONLY = 4;
  static const int NO_VALUES = 12;

  // Objects and arrays are "empty" until their first property/element.
  static const int EMPTY = 0;
  static const int NON_EMPTY = 16;
  static const int EMPTY_MASK = 16; // Empty if zero.

  static const int VALUE_READ_BITS = NO_VALUES | NON_EMPTY;

  // Actual states.
  static const int STATE_INITIAL = EMPTY | ALLOW_VALUE;
  static const int STATE_END = NON_EMPTY | NO_VALUES;

  static const int STATE_ARRAY_EMPTY = INSIDE_ARRAY | EMPTY | ALLOW_VALUE;
  static const int STATE_ARRAY_VALUE = INSIDE_ARRAY | NON_EMPTY | NO_VALUES;
  static const int STATE_ARRAY_COMMA = INSIDE_ARRAY | NON_EMPTY | ALLOW_VALUE;

  static const int STATE_OBJECT_EMPTY = INSIDE_OBJECT | EMPTY | STRING_ONLY;
  static const int STATE_OBJECT_KEY = INSIDE_OBJECT | NON_EMPTY | NO_VALUES;
  static const int STATE_OBJECT_COLON = AFTER_COLON | NON_EMPTY | ALLOW_VALUE;
  static const int STATE_OBJECT_VALUE = AFTER_COLON | NON_EMPTY | NO_VALUES;
  static const int STATE_OBJECT_COMMA = INSIDE_OBJECT | NON_EMPTY | STRING_ONLY;

  // Character code constants.
  static const int BACKSPACE = 0x08;
  static const int TAB = 0x09;
  static const int NEWLINE = 0x0a;
  static const int CARRIAGE_RETURN = 0x0d;
  static const int FORM_FEED = 0x0c;
  static const int SPACE = 0x20;
  static const int QUOTE = 0x22;
  static const int PLUS = 0x2b;
  static const int COMMA = 0x2c;
  static const int MINUS = 0x2d;
  static const int DECIMALPOINT = 0x2e;
  static const int SLASH = 0x2f;
  static const int CHAR_0 = 0x30;
  static const int CHAR_9 = 0x39;
  static const int COLON = 0x3a;
  static const int CHAR_E = 0x45;
  static const int LBRACKET = 0x5b;
  static const int BACKSLASH = 0x5c;
  static const int RBRACKET = 0x5d;
  static const int CHAR_a = 0x61;
  static const int CHAR_b = 0x62;
  static const int CHAR_e = 0x65;
  static const int CHAR_f = 0x66;
  static const int CHAR_l = 0x6c;
  static const int CHAR_n = 0x6e;
  static const int CHAR_r = 0x72;
  static const int CHAR_s = 0x73;
  static const int CHAR_t = 0x74;
  static const int CHAR_u = 0x75;
  static const int LBRACE = 0x7b;
  static const int RBRACE = 0x7d;

  final String _source;
  final JsonListener _listener;
  JsonParser(this._source, this._listener);

  /** Parses [_source], or throws if it fails. */
  void parse() {
    final List<int> states = <int>[];
    int state = STATE_INITIAL;
    _SpanStack spans = new _SpanStack();
    int position = 0;
    int length = _source.length;
    while (position < length) {
      int char = _source.codeUnitAt(position);
      switch (char) {
        // Whitespace characters
        case SPACE:
        case CARRIAGE_RETURN:
        case NEWLINE:
        case TAB:
          position++;
          break;
        // Enter object definition
        case LBRACE:
          if ((state & ALLOW_VALUE_MASK) != 0) _fail(position);
          spans.enterContainer(position);
          _listener.beginObject(position);
          states.add(state);
          state = STATE_OBJECT_EMPTY;
          position++;
          break;
        // Enter array definition
        case LBRACKET:
          if ((state & ALLOW_VALUE_MASK) != 0) _fail(position);
          spans.enterContainer(position);
          _listener.beginArray(position);
          states.add(state);
          state = STATE_ARRAY_EMPTY;
          position++;
          break;
        // End of object
        case RBRACE:
          if (state == STATE_OBJECT_EMPTY) {
            spans.leaveContainer(position + 1);
            _listener.endObject(spans.getLastSpan());
          } else if (state == STATE_OBJECT_VALUE) {
            _listener.propertyValue(spans.getLastSpan());
            spans.leaveContainer(position + 1);
            _listener.endObject(spans.getLastSpan());
          } else {
            _fail(position);
            spans.leaveContainer(position + 1);
          }
          state = states.removeLast() | VALUE_READ_BITS;
          position++;
          break;
        // End of array
        case RBRACKET:
          if (state == STATE_ARRAY_EMPTY) {
            spans.leaveContainer(position + 1);
            _listener.endArray(spans.getLastSpan());
          } else if (state == STATE_ARRAY_VALUE) {
            _listener.arrayElement(spans.getLastSpan());
            spans.leaveContainer(position + 1);
            _listener.endArray(spans.getLastSpan());
          } else {
            _fail(position);
            spans.leaveContainer(position + 1);
          }
          state = states.removeLast() | VALUE_READ_BITS;
          position++; // Skip the bracket
          break;
        // property name separator
        case COLON:
          if (state != STATE_OBJECT_KEY) _fail(position);
          _listener.propertyName(spans.getLastSpan());
          state = STATE_OBJECT_COLON;
          position++;
          break;
        // Array element/object value separator
        case COMMA:
          if (state == STATE_OBJECT_VALUE) {
            _listener.propertyValue(spans.getLastSpan());
            state = STATE_OBJECT_COMMA;
            position++;
          } else if (state == STATE_ARRAY_VALUE) {
            _listener.arrayElement(spans.getLastSpan());
            state = STATE_ARRAY_COMMA;
            position++;
          } else {
            _fail(position);
          }
          break;
        // String literal
        case QUOTE:
          if ((state & ALLOW_STRING_MASK) != 0) _fail(position);
          spans.enterLiteral(position);
          position = _parseString(position + 1);
          spans.leaveLiteral(position);
          state |= VALUE_READ_BITS;
          break;
        // "null"
        case CHAR_n:
          if ((state & ALLOW_VALUE_MASK) != 0) _fail(position);
          spans.enterLiteral(position);
          position = _parseNull(position);
          spans.leaveLiteral(position);
          state |= VALUE_READ_BITS;
          break;
        // "false"
        case CHAR_f:
          if ((state & ALLOW_VALUE_MASK) != 0) _fail(position);
          spans.enterLiteral(position);
          position = _parseFalse(position);
          spans.leaveLiteral(position);
          state |= VALUE_READ_BITS;
          break;
        // "true"
        case CHAR_t:
          if ((state & ALLOW_VALUE_MASK) != 0) _fail(position);
          spans.enterLiteral(position);
          position = _parseTrue(position);
          spans.leaveLiteral(position);
          state |= VALUE_READ_BITS;
          break;
        // Number
        default:
          if ((state & ALLOW_VALUE_MASK) != 0) _fail(position);
          spans.enterLiteral(position);
          position = _parseNumber(char, position);
          spans.leaveLiteral(position);
          state |= VALUE_READ_BITS;
          break;
      }
    }
    if (state != STATE_END) _fail(position, "Unexpected end of file.");
    _listener.endDocument(new Span(0, position));
  }

  /**
   * Parses a "true" literal starting at [position].
   *
   * [:source[position]:] must be "t".
   */
  int _parseTrue(int position) {
    assert(_source.codeUnitAt(position) == CHAR_t);
    if (_source.length < position + 4) _fail(position, "Unexpected identifier");
    if (_source.codeUnitAt(position + 1) != CHAR_r ||
        _source.codeUnitAt(position + 2) != CHAR_u ||
        _source.codeUnitAt(position + 3) != CHAR_e) {
      _fail(position);
    }
    _listener.handleBool(new Span(position, position + 4), true);
    return position + 4;
  }

  /**
   * Parses a "false" literal starting at [position].
   *
   * [:source[position]:] must be "f".
   */
  int _parseFalse(int position) {
    assert(_source.codeUnitAt(position) == CHAR_f);
    if (_source.length < position + 5) _fail(position, "Unexpected identifier");
    if (_source.codeUnitAt(position + 1) != CHAR_a ||
        _source.codeUnitAt(position + 2) != CHAR_l ||
        _source.codeUnitAt(position + 3) != CHAR_s ||
        _source.codeUnitAt(position + 4) != CHAR_e) {
      _fail(position);
    }
    _listener.handleBool(new Span(position, position + 4), false);
    return position + 5;
  }

  /** Parses a "null" literal starting at [position].
   *
   * [:source[position]:] must be "n".
   */
  int _parseNull(int position) {
    assert(_source.codeUnitAt(position) == CHAR_n);
    if (_source.length < position + 4) _fail(position, "Unexpected identifier");
    if (_source.codeUnitAt(position + 1) != CHAR_u ||
        _source.codeUnitAt(position + 2) != CHAR_l ||
        _source.codeUnitAt(position + 3) != CHAR_l) {
      _fail(position);
    }
    _listener.handleNull(new Span(position, position + 4));
    return position + 4;
  }

  int _parseString(int position) {
    // Format: '"'([^\x00-\x1f\\\"]|'\\'[bfnrt/\\"])*'"'
    // Initial position is right after first '"'.
    int start = position;
    int char;
    do {
      if (position == _source.length) {
        _fail(start - 1, "Unterminated string");
      }
      char = _source.codeUnitAt(position);
      if (char == QUOTE) {
        _listener.handleString(
            new Span(start - 1, position + 1),
            _source.substring(start, position));
        return position + 1;
      }
      if (char < SPACE) {
        _fail(position, "Control character in string");
      }
      position++;
    } while (char != BACKSLASH);
    // Backslash escape detected. Collect character codes for rest of string.
    int firstEscape = position - 1;
    List<int> chars = <int>[];
    while (true) {
      if (position == _source.length) {
        _fail(start - 1, "Unterminated string");
      }
      char = _source.codeUnitAt(position);
      switch (char) {
        case CHAR_b:
          char = BACKSPACE;
          break;
        case CHAR_f:
          char = FORM_FEED;
          break;
        case CHAR_n:
          char = NEWLINE;
          break;
        case CHAR_r:
          char = CARRIAGE_RETURN;
          break;
        case CHAR_t:
          char = TAB;
          break;
        case SLASH:
        case BACKSLASH:
        case QUOTE:
          break;
        case CHAR_u:
          int hexStart = position - 1;
          int value = 0;
          for (int i = 0; i < 4; i++) {
            position++;
            if (position == _source.length) {
              _fail(start - 1, "Unterminated string");
            }
            char = _source.codeUnitAt(position);
            char -= 0x30;
            if (char < 0) _fail(hexStart, "Invalid unicode escape");
            if (char < 10) {
              value = value * 16 + char;
            } else {
              char = (char | 0x20) - 0x31;
              if (char < 0 || char > 5) {
                _fail(hexStart, "Invalid unicode escape");
              }
              value = value * 16 + char + 10;
            }
          }
          char = value;
          break;
        default:
          if (char < SPACE) _fail(position, "Control character in string");
          _fail(position, "Unrecognized string escape");
      }
      do {
        chars.add(char);
        position++;
        if (position == _source.length) _fail(start - 1, "Unterminated string");
        char = _source.codeUnitAt(position);
        if (char == QUOTE) {
          String result = new String.fromCharCodes(chars);
          if (start < firstEscape) {
            result = "${_source.substring(start, firstEscape)}$result";
          }
          _listener.handleString(new Span(start - 1, position + 1), result);
          return position + 1;
        }
        if (char < SPACE) {
          _fail(position, "Control character in string");
        }
      } while (char != BACKSLASH);
      position++;
    }
  }

  int _handleLiteral(start, position, isDouble) {
    String literal = _source.substring(start, position);
    // This correctly creates -0 for doubles.
    num value = (isDouble ? double.parse(literal) : int.parse(literal));
    _listener.handleNumber(new Span(start, position), value);
    return position;
  }

  int _parseNumber(int char, int position) {
    // Format:
    //  '-'?('0'|[1-9][0-9]*)('.'[0-9]+)?([eE][+-]?[0-9]+)?
    int start = position;
    int length = _source.length;
    bool isDouble = false;
    if (char == MINUS) {
      position++;
      if (position == length) _fail(position, "Missing expected digit");
      char = _source.codeUnitAt(position);
    }
    if (char < CHAR_0 || char > CHAR_9) {
      _fail(position, "Missing expected digit");
    }
    if (char == CHAR_0) {
      position++;
      if (position == length) return _handleLiteral(start, position, false);
      char = _source.codeUnitAt(position);
      if (CHAR_0 <= char && char <= CHAR_9) {
        _fail(position);
      }
    } else {
      do {
        position++;
        if (position == length) return _handleLiteral(start, position, false);
        char = _source.codeUnitAt(position);
      } while (CHAR_0 <= char && char <= CHAR_9);
    }
    if (char == DECIMALPOINT) {
      isDouble = true;
      position++;
      if (position == length) _fail(position, "Missing expected digit");
      char = _source.codeUnitAt(position);
      if (char < CHAR_0 || char > CHAR_9) _fail(position);
      do {
        position++;
        if (position == length) return _handleLiteral(start, position, true);
        char = _source.codeUnitAt(position);
      } while (CHAR_0 <= char && char <= CHAR_9);
    }
    if (char == CHAR_e || char == CHAR_E) {
      isDouble = true;
      position++;
      if (position == length) _fail(position, "Missing expected digit");
      char = _source.codeUnitAt(position);
      if (char == PLUS || char == MINUS) {
        position++;
        if (position == length) _fail(position, "Missing expected digit");
        char = _source.codeUnitAt(position);
      }
      if (char < CHAR_0 || char > CHAR_9) {
        _fail(position, "Missing expected digit");
      }
      do {
        position++;
        if (position == length) return _handleLiteral(start, position, true);
        char = _source.codeUnitAt(position);
      } while (CHAR_0 <= char && char <= CHAR_9);
    }
    return _handleLiteral(start, position, isDouble);
  }

  void _fail(int position, [String message]) {
    _failSpan(new Span(position, position + 20), message);
  }

  void _failSpan(Span span, [String message]) {
    if (message == null) message = "Unexpected character";
    _listener.fail(_source, span, message);
    // If the listener didn't throw, do it here.
    int position = span.start;
    int sliceEnd = span.end;
    String slice;
    if (sliceEnd > _source.length) {
      slice = "'${_source.substring(position)}'";
    } else {
      slice = "'${_source.substring(position, sliceEnd)}...'";
    }
    throw new FormatException("Unexpected character at $position: $slice");
  }
}

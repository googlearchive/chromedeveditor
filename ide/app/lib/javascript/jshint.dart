// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A wrapper around the jshint library.
 *
 * See (jshint)[https://github.com/jshint/jshint/].
 */
library spark.jslint;

import 'dart:js' as js;

/**
 * A class to perform linting of JavaScript code.
 */
class JsHint {
  Map<String, bool> _options = {};

  static bool get available => js.context['JSHINT'] != null;

  JsHint();

  void setOption(String optionName, bool value) {
    _options[optionName] = value;
  }

  List<JsResult> lint(String source) {
    bool result = js.context.callMethod('JSHINT',
        [source, new js.JsObject.jsify(_options)]);

    if (result) return [];

    js.JsArray errors = js.context['JSHINT']['errors'];
    return errors.where(_notNull).map(_convertError).toList();
  }

  bool _notNull(obj) => obj != null;

  JsResult _convertError(js.JsObject error) {
    String raw = error['raw'];
    String severity = 'warning';

    //if (raw == 'Missing "use strict"') return null;

    if (raw.startsWith("Unclosed ") || raw.startsWith("Unmatched ") ||
        raw.startsWith("Expected ") || raw.startsWith("Unexpected")) {
      severity = 'error';
    }

    return new JsResult(
      error['reason'],
      severity,
      error['line'],
      error['character']);
  }
}

class JsResult {
  /// The analysis message.
  final String message;

  // `error`, `warning`, or `info`.
  final String severity;

  /// The 0-based line.
  final int line;

  /// The 0-based column.
  final int column;

  JsResult(this.message, this.severity, this.line, this.column);

  String toString() => '[line ${line + 1}: ${message}]';
}

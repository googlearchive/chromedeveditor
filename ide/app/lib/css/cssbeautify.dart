// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.cssbeautify;

import 'dart:js' as js;

/**
 * Wrapper for the cssbeautify.js library.
 */
class CssBeautify {
  final bool autosemicolon;
  final bool useTabs;
  final int indentSpaceSize;

  /**
   * TODO: doc
   */
  CssBeautify({this.autosemicolon: true, this.useTabs: false,
    this.indentSpaceSize: 2}) {
    if (indentSpaceSize < 1 || indentSpaceSize > 4) {
      throw new ArgumentError('indentSpaceSize must be > 0 and <= 4');
    }
  }

  /**
   * Format the given CSS text.
   */
  String format(String text) {
    bool startedWithNewLine = text.startsWith('\n');
    var options = {'indent': _indent(), 'autosemicolon': autosemicolon};

    String result = js.context.callMethod(
        'cssbeautify', [text, new js.JsObject.jsify(options)]);

    if (startedWithNewLine && !result.startsWith('\n')) result = '\n${result}';
    if (!result.endsWith('\n')) result = '${result}\n';

    return result;
  }

  String _indent() {
    if (useTabs) return '\t';
    if (indentSpaceSize == 1) return ' ';
    if (indentSpaceSize == 2) return '  ';
    if (indentSpaceSize == 3) return '   ';
    return '    ';
  }
}

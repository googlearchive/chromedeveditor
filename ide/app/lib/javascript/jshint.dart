// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A wrapper around the jshint library.
 *
 * See (jshint)[https://github.com/jshint/jshint/].
 */
library spark.jshint;

import 'dart:js';

// JsHint options:

//asi         : if automatic semicolon insertion should be tolerated
//bitwise     : if bitwise operators should not be allowed
//boss        : if advanced usage of assignments should be allowed
//browser     : if the standard browser globals should be predefined
//camelcase   : if identifiers should be required in camel case
//couch       : if CouchDB globals should be predefined
//curly       : if curly braces around all blocks should be required
//debug       : if debugger statements should be allowed
//devel       : if logging globals should be predefined (console, alert, etc.)
//dojo        : if Dojo Toolkit globals should be predefined
//eqeqeq      : if === should be required
//eqnull      : if == null comparisons should be tolerated
//notypeof    : if should report typos in typeof comparisons
//es3         : if ES3 syntax should be allowed
//es5         : if ES5 syntax should be allowed (is now set per default)
//esnext      : if es.next specific syntax should be allowed
//moz         : if mozilla specific syntax should be allowed
//evil        : if eval should be allowed
//expr        : if ExpressionStatement should be allowed as Programs
//forin       : if for in statements must filter
//funcscope   : if only function scope should be used for scope tests
//globalstrict: if global "use strict"; should be allowed (also enables 'strict')
//immed       : if immediate invocations must be wrapped in parens
//iterator    : if the `__iterator__` property should be allowed
//jquery      : if jQuery globals should be predefined
//lastsemic   : if semicolons may be ommitted for the trailing statements inside
//              of a one-line blocks.
//laxbreak    : if line breaks should not be checked
//laxcomma    : if line breaks should not be checked around commas
//loopfunc    : if functions should be allowed to be defined within loops
//mootools    : if MooTools globals should be predefined
//multistr    : allow multiline strings
//freeze      : if modifying native object prototypes should be disallowed
//newcap      : if constructor names must be capitalized
//noarg       : if arguments.caller and arguments.callee should be disallowed
//node        : if the Node.js environment globals should be predefined
//noempty     : if empty blocks should be disallowed
//nonbsp      : if non-breaking spaces should be disallowed
//nonew       : if using `new` for side-effects should be disallowed
//nonstandard : if non-standard (but widely adopted) globals should be predefined
//phantom     : if PhantomJS symbols should be allowed
//plusplus    : if increment/decrement should not be allowed
//proto       : if the `__proto__` property should be allowed
//prototypejs : if Prototype and Scriptaculous globals should be predefined
//rhino       : if the Rhino environment globals should be predefined
//shelljs     : if ShellJS globals should be predefined
//typed       : if typed array globals should be predefined
//undef       : if variables should be declared before used
//scripturl   : if script-targeted URLs should be tolerated
//strict      : require the "use strict"; pragma
//sub         : if all forms of subscript notation are tolerated
//supernew    : if `new function () { ... };` and `new Object;` should be
//              tolerated
//validthis   : if 'this' inside a non-constructor function is valid. This is a
//              function scoped option only.
//withstmt    : if with statements should be allowed
//worker      : if Web Worker script symbols should be allowed
//wsh         : if the Windows Scripting Host environment globals should be
//              predefined
//yui         : YUI variables should be predefined
//mocha       : Mocha functions should be predefined
//noyield     : allow generators without a yield

/**
 * A class to perform linting of JavaScript code. To use, create a `JsHint`
 * instance, set zero or more options on that instance ([setOption]), and then
 * call [lint]. [JsHint] instances can be reused.
 */
class JsHint {
  Map<String, bool> _options = {};

  static bool get available => context['JSHINT'] != null;

  JsHint() {
    setOption('laxbreak');
  }

  /**
   * Set a `bool` JsHint option.
   */
  void setOption(String optionName, [bool value = true]) {
    _options[optionName] = value;
  }

  /**
   * Lint the given JavaScript source and return any analysis errors.
   */
  List<JsResult> lint(String source) {
    bool analyzesOk = context.callMethod(
        'JSHINT', [source, new JsObject.jsify(_options)]);

    if (analyzesOk) {
      return [];
    } else {
      JsArray errors = context['JSHINT']['errors'];
      return errors.where(_notNull).map(_convertError).toList();
    }
  }

  bool _notNull(obj) => obj != null;

  JsResult _convertError(JsObject error) {
    String raw = error['raw'];
    String severity = 'warning';

    if (raw.startsWith("Unclosed ") ||
        raw.startsWith("Unmatched ") ||
        raw.startsWith("Expected ") ||
        raw.startsWith("Unexpected")) {
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

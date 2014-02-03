// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.diff3;

import 'dart:html';
import 'dart:js' as js;

/**
 * Wrapper for the diff3.js library.
 */
class Diff3 {
  static js.JsObject _diff = js.context['Diff'];

  static Diff3Result diff(String our, String base, String their) {
    window.console.log(our);
    window.console.log(base);
    window.console.log(their);
    var result = _diff.callMethod("diff3_dig", [our, base, their]);
    return new Diff3Result(result['text'], result['conflict']);
  }
}

class Diff3Result {
  String text;
  bool conflict;
  Diff3Result(this.text, this.conflict);
}

// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.js_completer;

import 'dart:async';

class JsCompleter {
  Completer _completer = new Completer();

  JsCompleter();

  Function get onSuccess => (() => _completer.complete());
  Function get onSuccessWithResult => ((r) => _completer.complete(r));
  Function get onError => ((e) => _completer.completeError(e));

  Future get future => _completer.future;
}

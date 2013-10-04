// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

if (navigator.webkitStartDart) {
  navigator.webkitStartDart();
} else {
  var script = document.createElement('script');
  // Point the script to the compiled CSP compatible output for Spark.
  script.src = 'spark.dart.precompiled.js';
  document.body.appendChild(script);
}

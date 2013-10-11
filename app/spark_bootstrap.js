// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

(function() {
  if (navigator.webkitStartDart) {
    navigator.webkitStartDart();
  } else {
    var scripts = document.getElementsByTagName("script");

    for (var i = 0; i < scripts.length; ++i) {
      if (scripts[i].type == "application/dart") {
        if (scripts[i].src && scripts[i].src != '') {
          var script = document.createElement('script');
          script.src = scripts[i].src.replace(/\.dart(?=\?|$)/, '.dart.precompiled.js');
          document.currentScript = script;
          scripts[i].parentNode.replaceChild(script, scripts[i]);
        }
      }
    }
  }
})();

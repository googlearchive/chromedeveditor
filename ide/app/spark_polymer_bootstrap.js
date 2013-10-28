// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

(function() {
  if (navigator.webkitStartDart) {
    // NOTE: This is already done in polymer/boot.js, and this attempt to
    // execute it the second time breaks polymer-element instantiations.
    // This is in a transient state: boot.js is going away soon, and so it
    // the requirement to run webkitStartDart(). By Dart 1.0 both should be
    // gone. However, depending on which goes first, this might need to be
    // uncommented for a brief period.
    // TODO(sergeygs): Remove this completely after Dart 1.0.
    //navigator.webkitStartDart();
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
      } else if (scripts[i].src.indexOf('.dart.js') == scripts[i].src.length - 8) {
        var script = document.createElement('script');
        script.src = scripts[i].src.replace(/\.dart\.js$/, '.dart.precompiled.js');
        document.currentScript = script;
        scripts[i].parentNode.replaceChild(script, scripts[i]);
      }
    }
  }
})();

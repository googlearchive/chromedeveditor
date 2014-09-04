// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

chrome.app.runtime.onLaunched.addListener(function(launchData) {
  chrome.app.window.create('testing.html', {
    'id': '_mainWindow', 'bounds': {'width': 800, 'height': 600 }
  });
});

// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

chrome.app.runtime.onLaunched.addListener(function(launchData) {
  chrome.storage.local.get('windowMaximized', function(items) {
    var wasMaximized = items['windowMaximized'];

    var screenWidth = screen.availWidth;
    var screenHeight = screen.availHeight;
    var width = Math.floor(screenWidth*(7/8));
    var height = Math.floor(screenHeight*(7/8));

    // Open the main window.
    chrome.app.window.create('spark.html', {
      id: 'main_editor_window',
      bounds: { width: width, height: height },
      minWidth: 600,
      minHeight: 350
    }, function(createdWindow) {
      // Open any files passed in using the file_handlers mechanism.
	  if (launchData && launchData.items) {
	    for (i = 0; i < launchData.items.length; i++) {
	      var item = launchData.items[i];

	      // string item.type
	      // FileEntry item.fileentry

	      // TODO: handle the item.fileentry

	    }
	  }
    });
  });
});

chrome.app.window.onClosed.addListener(function() {
  var isMaximized = chrome.app.window.current().isMaximized();

  chrome.storage.local.set({'windowMaximized': isMaximized});
});

chrome.app.runtime.onRestarted.addListener(function() {
  // TODO: re-open the main window?

});

chrome.runtime.onSuspend.addListener(function() {

});

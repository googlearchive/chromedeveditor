
chrome.app.runtime.onLaunched.addListener(function(launchData) {
  chrome.storage.local.get('windowMaximized', function(items) {
    var wasMaximized = items['windowMaximized'];

    // Open the main window.
    chrome.app.window.create('spark.html', {
      'id': 'main_editor_window',
      'bounds': {'width': 1000, 'height': 700 }
      //'state': (wasMaximized ? 'maximized' : 'normal')
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

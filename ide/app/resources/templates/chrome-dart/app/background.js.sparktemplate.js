
chrome.app.runtime.onLaunched.addListener(function(launchData) {
  chrome.app.window.create('_source_name_.html', {
    'id': '_mainWindow', 'bounds': {'width': 800, 'height': 600 }
  });
});

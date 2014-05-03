/**
 * Listens for the app launching then creates the window.
 *
 * @see http://developer.chrome.com/apps/app.runtime.html
 * @see http://developer.chrome.com/apps/app.window.html
 */
chrome.app.runtime.onLaunched.addListener(function() {
  chrome.app.window.create(
    "index.html", 
    {
      id: "mainWindow",
      bounds: {
        width: 500,
        height: 300
      }
    }
  );
});

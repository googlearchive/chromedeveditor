// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Set to true when the Document is loaded IFF "test=true" is in the query
// string.
var isTest = false;

// Set to true when loading a "Release" NaCl module, false when loading a
// "Debug" NaCl module.
var isRelease = true;

// Javascript module pattern:
//   see http://en.wikipedia.org/wiki/Unobtrusive_JavaScript#Namespaces
// In essence, we define an anonymous function which is immediately called and
// returns a new object. The new object contains only the exported definitions;
// all other definitions in the anonymous function are inaccessible to external
// code.
var GitSalt = (function() {

  /**
   * Inject a script into the DOM, and call a callback when it is loaded.
   *
   * @param {string} url The url of the script to load.
   * @param {Function} onload The callback to call when the script is loaded.
   * @param {Function} onerror The callback to call if the script fails to load.
   */
  function injectScript(url, onload, onerror) {
    var scriptEl = document.createElement('script');
    scriptEl.type = 'text/javascript';
    scriptEl.src = url;
    scriptEl.onload = onload;
    if (onerror) {
      scriptEl.addEventListener('error', onerror, false);
    }
    document.head.appendChild(scriptEl);
  }

  /**
   * Run all tests for this example.
   *
   * @param {Object} moduleEl The module DOM element.
   */
  function runTests(moduleEl) {
    console.log('runTests()');
    GitSalt.tester = new Tester();

    // All NaCl SDK examples are OK if the example exits cleanly; (i.e. the
    // NaCl module returns 0 or calls exit(0)).
    //
    // Without this exception, the browser_tester thinks that the module
    // has crashed.
    GitSalt.tester.exitCleanlyIsOK();

    GitSalt.tester.addAsyncTest('loaded', function(test) {
      test.pass();
    });

    if (typeof window.addTests !== 'undefined') {
      window.addTests();
    }

    GitSalt.tester.waitFor(moduleEl);
    GitSalt.tester.run();
  }

  /**
   * Create the Native Client <embed> element as a child of the DOM element
   * named "listener".
   *
   * @param {string} name The name of the example.
   * @param {string} path Directory name where .nmf file can be found.
   */
  function createNaClModule(name, path) {
    var moduleEl = document.createElement('embed');
    moduleEl.setAttribute('name', 'nacl_module');
    moduleEl.setAttribute('id', 'nacl_module');
    moduleEl.setAttribute('width', 0);
    moduleEl.setAttribute('height', 0);
    moduleEl.setAttribute('path', path);
    moduleEl.setAttribute('src', path + '/' + name + '.nmf');

    moduleEl.setAttribute('type', "application/x-nacl");

    // The <EMBED> element is wrapped inside a <DIV>, which has both a 'load'
    // and a 'message' event listener attached.  This wrapping method is used
    // instead of attaching the event listeners directly to the <EMBED> element
    // to ensure that the listeners are active before the NaCl module 'load'
    // event fires.
    var listenerDiv = document.getElementById('git-salt-container');
    listenerDiv.appendChild(moduleEl);

    // This is code that is only used to test the SDK.
    if (isTest) {
      var loadNaClTest = function() {
        injectScript('nacltest.js', function() {
          runTests(moduleEl);
        });
      };

      // Try to load test.js for the example. Whether or not it exists, load
      // nacltest.js.
      injectScript('test.js', loadNaClTest, loadNaClTest);
    }
  }

  /**
   * Add the default "load" and "message" event listeners to the element with
   * id "listener".
   *
   * The "load" event is sent when the module is successfully loaded. The
   * "message" event is sent when the naclModule posts a message using
   * PPB_Messaging.PostMessage() (in C) or pp::Instance().PostMessage() (in
   * C++).
   */
  function attachDefaultListeners() {
    var listenerDiv = document.getElementById('git-salt-container');
    listenerDiv.addEventListener('load', moduleDidLoad, true);
    listenerDiv.addEventListener('message', handleMessage, true);
    listenerDiv.addEventListener('error', handleError, true);
    listenerDiv.addEventListener('crash', handleCrash, true);
    if (typeof window.attachListeners !== 'undefined') {
      window.attachListeners();
    }
  }

  /**
   * Called when the NaCl module fails to load.
   *
   * This event listener is registered in createNaClModule above.
   */
  function handleError(event) {
    // We can't use GitSalt.naclModule yet because the module has not been
    // loaded.
    var moduleEl = document.getElementById('nacl_module');
    updateStatus('ERROR [' + moduleEl.lastError + ']');
  }

  /**
   * Called when the Browser can not communicate with the Module
   *
   * This event listener is registered in attachDefaultListeners above.
   */
  function handleCrash(event) {
    if (GitSalt.naclModule.exitStatus == -1) {
      updateStatus('CRASHED');
    } else {
      updateStatus('EXITED [' + GitSalt.naclModule.exitStatus + ']');
    }
    if (typeof window.handleCrash !== 'undefined') {
      window.handleCrash(GitSalt.naclModule.lastError);
    }
  }

  /**
   * Called when the NaCl module is loaded.
   *
   * This event listener is registered in attachDefaultListeners above.
   */
  function moduleDidLoad() {
    GitSalt.naclModule = document.getElementById('nacl_module');
    updateStatus('RUNNING');
    saveFile();
    if (typeof window.moduleDidLoad !== 'undefined') {
      window.moduleDidLoad();
    }
  }

  /**
   * Hide the NaCl module's embed element.
   *
   * We don't want to hide by default; if we do, it is harder to determine that
   * a plugin failed to load. Instead, call this function inside the example's
   * "moduleDidLoad" function.
   *
   */
  function hideModule() {
    // Setting GitSalt.naclModule.style.display = "None" doesn't work; the
    // module will no longer be able to receive postMessages.
    GitSalt.naclModule.style.height = '0';
  }

  /**
   * Remove the NaCl module from the page.
   */
  function removeModule() {
    GitSalt.naclModule.parentNode.removeChild(GitSalt.naclModule);
    GitSalt.naclModule = null;
  }

  /**
   * Return true when |s| starts with the string |prefix|.
   *
   * @param {string} s The string to search.
   * @param {string} prefix The prefix to search for in |s|.
   */
  function startsWith(s, prefix) {
    // indexOf would search the entire string, lastIndexOf(p, 0) only checks at
    // the first index. See: http://stackoverflow.com/a/4579228
    return s.lastIndexOf(prefix, 0) === 0;
  }

  /** Maximum length of logMessageArray. */
  var kMaxLogMessageLength = 20;

  /** An array of messages to display in the element with id "log". */
  var logMessageArray = [];

  /**
   * Add a message to an element with id "log".
   *
   * This function is used by the default "log:" message handler.
   *
   * @param {string} message The message to log.
   */
  function logMessage(message) {
    logMessageArray.push(message);
    if (logMessageArray.length > kMaxLogMessageLength)
      logMessageArray.shift();
    console.log(message);
  }

  /**
   */
  var defaultMessageTypes = {
    'alert': alert,
    'log': logMessage
  };

  /**
   * Called when the NaCl module sends a message to JavaScript (via
   * PPB_Messaging.PostMessage())
   *
   * This event listener is registered in createNaClModule above.
   *
   * @param {Event} message_event A message event. message_event.data contains
   *     the data sent from the NaCl module.
   */
  function handleMessage(message_event) {
    if (typeof message_event.data === 'string') {
      for (var type in defaultMessageTypes) {
        if (defaultMessageTypes.hasOwnProperty(type)) {
          if (startsWith(message_event.data, type + ':')) {
            func = defaultMessageTypes[type];
            func(message_event.data.slice(type.length + 1));
            return;
          }
        }
      }
    }

    if (typeof window.handleMessage !== 'undefined') {
      window.handleMessage(message_event);
      return;
    }

    logMessage('Unhandled message: ' + message_event.data);
  }

  /**
   * @param {string} name The name of the example.
   * @param {string} path Directory name where .nmf file can be found.
   */
  function loadPlugin(name, path) {
    attachDefaultListeners();
    createNaClModule(name, path);
  }

  /** Saved text to display in the element with id 'statusField'. */
  var statusText = 'NO-STATUSES';

  function updateStatus(opt_message) {
    if (opt_message) {
      statusText = opt_message;
    }
    console.log(statusText);
  }

  // The symbols to export.
  return {
    /** A reference to the NaCl module, once it is loaded. */
    naclModule: null,

    attachDefaultListeners: attachDefaultListeners,
    loadPlugin: loadPlugin,
    createNaClModule: createNaClModule,
    hideModule: hideModule,
    removeModule: removeModule,
    logMessage: logMessage,
    updateStatus: updateStatus
  };
}());

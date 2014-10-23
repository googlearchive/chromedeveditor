// Copyright (c) 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/**
 *@constructor
 */
var GitSalt = function() {
  this.callbacks = new Object();
};

GitSalt.prototype.listenerDiv = null;

GitSalt.prototype.loadCb = null;

GitSalt.prototype.callbacks = {};

/**
 * Create the Native Client <embed> element as a child of the DOM element
 * named "listener".
 *
 * @param {string} name The name of the example.
 * @param {string} path Directory name where .nmf file can be found.
 */
GitSalt.prototype.createNaClModule = function(name, path) {
  var moduleEl = document.createElement('embed');
  moduleEl.setAttribute('width', 0);
  moduleEl.setAttribute('height', 0);
  moduleEl.setAttribute('path', path);
  moduleEl.setAttribute('src', path + '/' + name + '.nmf');

  moduleEl.setAttribute('type', "application/x-nacl");
  this.naclModule = moduleEl;

  // The <EMBED> element is wrapped inside a <DIV>, which has both a 'load'
  // and a 'message' event listener attached.  This wrapping method is used
  // instead of attaching the event listeners directly to the <EMBED> element
  // to ensure that the listeners are active before the NaCl module 'load'
  // event fires.
  this.listenerDiv.appendChild(moduleEl);
};

GitSalt.prototype.statusText = 'NO-STATUSES';

GitSalt.prototype.updateStatus = function(opt_message) {
  if (opt_message) {
    statusText = opt_message;
  }
  console.log(statusText);
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
GitSalt.prototype.attachDefaultListeners = function() {
  this.listenerDiv.addEventListener('load', this.moduleDidLoad.bind(this), true);
  this.listenerDiv.addEventListener('message', this.handleMessage.bind(this), true);
  this.listenerDiv.addEventListener('error', this.handleError.bind(this), true);
  this.listenerDiv.addEventListener('crash', this.handleCrash.bind(this), true);
};

/**
 * Called when the NaCl module fails to load.
 *
 * This event listener is registered in createNaClModule above.
 */
GitSalt.prototype.handleError = function(event) {
  this.updateStatus('ERROR [' + this.naclModule.lastError + ']');
};

/**
 * Called when the Browser can not communicate with the Module
 *
 * This event listener is registered in attachDefaultListeners above.
 */
GitSalt.prototype.handleCrash = function(event) {
  if (this.naclModule.exitStatus == -1) {
    this.updateStatus('CRASHED');
  } else {
    this.updateStatus('EXITED [' + this.naclModule.exitStatus + ']');
  }
  if (typeof window.handleCrash !== 'undefined') {
    window.handleCrash(this.naclModule.lastError);
  }
};

/**
 * Called when the NaCl module is loaded.
 *
 * This event listener is registered in attachDefaultListeners above.
 */
GitSalt.prototype.moduleDidLoad = function() {
  this.updateStatus('RUNNING');
  if (typeof window.moduleDidLoad !== 'undefined') {
    window.moduleDidLoad();
  }
  if (this.loadCb != null) {
    this.loadCb();
    this.loadCb = null;
  }
};

/**
 * Hide the NaCl module's embed element.
 *
 * We don't want to hide by default; if we do, it is harder to determine that
 * a plugin failed to load. Instead, call this function inside the example's
 * "moduleDidLoad" function.
 *
 */
GitSalt.prototype.hideModule = function() {
  // Setting GitSalt.naclModule.style.display = "None" doesn't work; the
  // module will no longer be able to receive postMessages.
  this.naclModule.style.height = '0';
};

/**
 * Remove the NaCl module from the page.
 */
GitSalt.prototype.removeModule = function() {
  this.naclModule.parentNode.removeChild(this.naclModule);
  this.naclModule = null;
};

/**
 * Return true when |s| starts with the string |prefix|.
 *
 * @param {string} s The string to search.
 * @param {string} prefix The prefix to search for in |s|.
 */
GitSalt.prototype.startsWith = function(s, prefix) {
  // indexOf would search the entire string, lastIndexOf(p, 0) only checks at
  // the first index. See: http://stackoverflow.com/a/4579228
  return s.lastIndexOf(prefix, 0) === 0;
};

GitSalt.prototype.logMessage = function(message) {
  console.log(message);
};

GitSalt.prototype.defaultMessageTypes = {
  'alert': alert,
  'log': this.logMessage
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
GitSalt.prototype.handleMessage = function(message_event) {
  if (typeof message_event.data === 'string') {
    for (var type in this.defaultMessageTypes) {
      if (this.defaultMessageTypes.hasOwnProperty(type)) {
        if (this.startsWith(message_event.data, type + ':')) {
          func = this.defaultMessageTypes[type];
          func(message_event.data.slice(type.length + 1));
          return;
        }
      }
    }
  }

  this.handleResponse(message_event);
};

GitSalt.prototype.handleResponse = function(response) {
   var cb = this.callbacks[response.data.regarding];
   if (cb != null) {
     cb(response.data.arg);
     this.callbacks[response.data] = null;
   }
};

/**
 * @param {string} name The name of the example.
 * @param {string} path Directory name where .nmf file can be found.
 */
GitSalt.prototype.loadPlugin = function(name, path, cb) {
  this.loadCb = cb;
  this.listenerDiv = document.createElement('div');

  var gitSaltContainer = document.getElementById('git-salt-container');
  gitSaltContainer.appendChild(this.listenerDiv);

  this.attachDefaultListeners();
  this.createNaClModule(name, path);
};

GitSalt.prototype.postMessage = function(message, cb) {
  this.callbacks[message.subject] = cb;
  this.naclModule.postMessage(message);
};

var gitSalt = new GitSalt();


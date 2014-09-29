// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// App class. Implements the windowless top part of Spark app that
// manages app's window(s).
var App = function() {
  this.ui = "spark_polymer.html";
  this.editorWin_ = null;
};

App.prototype.launch = function() {
  if (this.editorWin_) {
    this.editorWin_.destroy();
    delete this.editorWin_;
  }

  this.editorWin_ = new EditorWindow(this);
};

// EditorWindow class. Encapsulates the state of a Spark app's main window.
var EditorWindow = function(app) {
  this.app_ = app;
  this.window = null;

  chrome.app.window.create(
    this.app_.ui,
    {
      id: 'main_editor_window',
      frame: 'chrome',
      // Bounds will have effect only on the first start after app installation
      // in a given Chromium instance. After that, size & position will be
      // restored from the window id above.
      bounds: {
        width: Math.floor(screen.availWidth * (7/8)),
        height: Math.floor(screen.availHeight * (7/8))
      },
      minWidth: 600,
      minHeight: 400,
    },
    this.onCreated_.bind(this)
  );
};

// A listener called after Chrome app window has been created.
EditorWindow.prototype.onCreated_ = function(win) {
  this.window = win;
};

// Destroy the window, if any.
EditorWindow.prototype.destroy = function() {
  if (this.window) {
    this.window.close();
  }
};

// Create a new app window.
chrome.app.runtime.onLaunched.addListener(function(launchData) {
  new App().launch();
});

chrome.app.runtime.onRestarted.addListener(function() {
  // TODO: re-open the main window?
});

chrome.runtime.onSuspend.addListener(function() {
  // TODO: save any unsaved state.
});

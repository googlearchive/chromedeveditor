// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// App class. Implements the windowless top part of Spark app that
// caches/saves/restores settings, manages app's window(s), and performs UI
// ui switching when requested.
var App = function() {
  this.uis_ = [ "spark_polymer.html", "spark.html" ];
  this.DEFAULT_UI_ = 0;
  this.CAN_SWITCH_UIS_ = 0;
  this.settings = { ui: this.uis_[this.DEFAULT_UI_] };

  this.editorWin_ = null;
};

App.prototype.updateSettings = function(changedSettings) {
  for (var key in changedSettings) {
    this.settings[key] = changedSettings[key];
  }
};

App.prototype.launch = function(ui_opt) {
  if (ui_opt !== undefined) {
    this.updateSettings({ ui: ui_opt });
  }

  if (this.editorWin_) {
    this.editorWin_.destroy();
    delete this.editorWin_;
  }

  var div = document.createElement('div');
  if (div.createShadowRoot == null) {
    chrome.app.window.create(
        'cannot_launch/cannot_launch.htm', {
        frame: 'chrome',
        bounds: {
          width: 600,
          height: 220
        },
        resizable: false
    });
    return;
  }

  this.editorWin_ = new EditorWindow(this);
};

App.prototype.switchUi = function() {
  var nextSkinIdx =
      (this.uis_.indexOf(this.settings.ui) + 1) % this.uis_.length;
  this.launch(this.uis_[nextSkinIdx]);
};


// EditorWindow class. Encapsulates the state of a Spark app's main window.
var EditorWindow = function(app) {
  this.app_ = app;
  this.window = null;

  chrome.app.window.create(
    this.app_.settings.ui,
    {
      id: 'main_editor_window' + this.app_.settings.ui,
      frame: 'chrome',
      // Bounds will have effect only on the first start after app installation
      // in a given Chromium instance. After that, size & position will be
      // restored from the window id above.
      bounds: {
        width: Math.floor(screen.availWidth * (7/8)),
        height: Math.floor(screen.availHeight * (7/8))
      },
      minWidth: 900,
      minHeight: 640,
    },
    this.onCreated_.bind(this)
  );
};

// A listener called after Chrome app window has been created.
EditorWindow.prototype.onCreated_ = function(win) {
  this.window = win;
  this.window.contentWindow.addEventListener(
      'DOMContentLoaded', this.onLoad_.bind(this));
};

// A listener called after the DOM has been constructed for the content window.
EditorWindow.prototype.onLoad_ = function() {
  if (this.app_.CAN_SWITCH_UIS_) {
    chrome.contextMenus.create({
      title: "Spark: Switch UI",
      id: 'switch_ui',
      contexts: [ 'all' ]
    });
    chrome.contextMenus.onClicked.addListener(function(info) {
      if (info.menuItemId == 'switch_ui') {
        this.app_.switchUi();
      }
    }.bind(this));
  }
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

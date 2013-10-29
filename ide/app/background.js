// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// App class. Implements the windowless top part of Spark app that
// caches/saves/restores settings, manages app's window(s), and performs UI
// skin switching when requested.
var App = function() {
  this.settings = null;
  this.editorWin_ = null;
  this.skins_ = [ "spark.html", "spark_polymer.html" ];
};

App.prototype.getSettings = function(callback) {
  if (this.settings !== null) {
    callback();
  } else {
    chrome.storage.local.get(
      {
        skin: this.skins_[0]
      },
      function(settings) {
        this.settings = settings;
        callback();
      }.bind(this)
    );
  }
};

App.prototype.updateSettings = function(changedSettings) {
  for (var key in changedSettings) {
    this.settings[key] = changedSettings[key];
  }
  // NOTE: The method is asynchronous, but there's no need to wait since
  // the stored value is used only on app's startup -- the rest of the code uses
  // the cached value.
  chrome.storage.local.set(this.settings);
};

App.prototype.launch = function(skin_opt) {
  if (skin_opt) {
    this.updateSettings({ skin: skin_opt });
  }

  if (this.editorWin_) {
    this.editorWin_.destroy();
    delete this.editorWin_;
  }

  this.getSettings(function() {
    this.editorWin_ = new EditorWindow(this);
  }.bind(this));
}

App.prototype.switchUi = function() {
  var nextSkinIdx =
      (this.skins_.indexOf(this.settings.skin) + 1) % this.skins_.length;
  this.launch(this.skins_[nextSkinIdx]);
}


// EditorWindow class. Encapsulates the state of a Spark app's main window.
var EditorWindow = function(app) {
  this.app_ = app;
  this.window = null;

  chrome.app.window.create(
    this.app_.settings.skin,
    {
      id: 'main_editor_window' + this.app_.settings.skin,
      frame: 'chrome',
      // Bounds will have effect only on the first start after app installation
      // in a given Chromium instance. After that, size & position will be
      // restored from the window id above.
      bounds: {
        width: Math.floor(screen.availWidth * (7/8)),
        height: Math.floor(screen.availHeight * (7/8))
      },
      minWidth: 600,
      minHeight: 350,
    },
    this.onCreated_.bind(this)
  );
};

// A listener called after Chrome app window has been created.
EditorWindow.prototype.onCreated_ = function(win) {
  this.window = win;
  this.window.contentWindow.addEventListener(
      'DOMContentLoaded', this.onLoad_.bind(this));
}

// A listener called after the DOM has been constructed for the content window.
EditorWindow.prototype.onLoad_ = function() {
  // Find an optional link to switch between UIs and attach the parent's app
  // UI-switching listener to it.
  var uiSwitcher =
      this.window.contentWindow.document.getElementById('uiSwitcher');
  if (uiSwitcher) {
    uiSwitcher.onclick = this.app_.switchUi.bind(this.app_);
  }
}

// Destroy the window.
EditorWindow.prototype.destroy = function() {
  this.window.close();
}

// Create a new app window and restore settings/state.
chrome.app.runtime.onLaunched.addListener(function(launchData) {
  new App().launch();
});

chrome.app.runtime.onRestarted.addListener(function() {
  // TODO: re-open the main window?
});

chrome.runtime.onSuspend.addListener(function() {
  // TODO: save any unsaved state.
});

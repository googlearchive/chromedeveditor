// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

Polymer('cde-polymer-designer', {
  // NOTE: Make sure this is in-sync with ide/web/manifest.json.
  _STORAGE_PARTITION: 'persist:cde-polymer-designer',
  // NOTE: We must use the full path as viewed by a client app.
  _LOCAL_ENTRY_POINT:
      'packages/cde_polymer_designer/src/polymer_designer/index.html',
  _ONLINE_ENTRY_POINT:
      'https://www.polymer-project.org/tools/designer/',

  /**
   * Specifies whether to use the local, compiled-in copy of Polymer Designer
   * or the online one.
   *
   * @attribute attr
   * @type string
   */
  entryPoint: 'local',

  /**
   * The dynamically created <webview> element.
   */
  _webview: null,

  /**
   * Fires after the <webview> has been created, its UI tweaked and the proxy
   * script injected into it.
   *
   * @type: Promise
   */
  _webviewReady: null,
  _webviewReadyResolve: null,

  /**
   * Fires when the asynchronous code export requested from the proxy has
   * completed.
   *
   * @type: Promise<String>
   */
  _codeExported: null,
  _codeExportedResolve: null,

  /**
   * Registers an event listener to complete initialization once the
   * <webview> is up and running.
   */
  attached: function() {
    this._registerDesignerProxyListener();
  },

  /**
   * Initializes this object from an idle state:
   * - Creates a new <webview>.
   * - Inserts it into the shadow DOM.
   * - Navigates it to the Polymer Designer local or online entry point.
   *
   * @type: Promise
   */
  load: function() {
    var that = this;

    that._webviewReady = new Promise(function(resolve, reject) {
      that._webviewReadyResolve = resolve;
      // TODO(ussuri): BUG #3466.
      setTimeout(function() {
        that._webview = document.createElement('webview');
        that._webview.addEventListener(
            'contentload', that._onWebviewContentLoad.bind(that));
        that._webview.partition = that._STORAGE_PARTITION;
        that._webview.src =
            that.entryPoint == 'local' ?
            that._LOCAL_ENTRY_POINT :
            that._ONLINE_ENTRY_POINT;
        that.shadowRoot.appendChild(that._webview);
      }, 500);
    });

    return that._webviewReady;
  },

  /**
   * Returns the object to the idle state:
   * - terminates the running <webview>, if any.
   * - removes the <webview> element from the shadow DOM.
   * - Resets the [Completer]s.
   *
   * @type: void
   */
  unload: function() {
    if (this._webview != null) {
      this._webview.terminate();
      this.shadowRoot.removeChild(this._webview);
    }
    this._webview = this._webviewReady = this._webviewReadyResolve = null;
    this._codeExported = this._codeExportedResolve = null;
  },

  /**
   * Reinitializes the object from a running state.
   *
   * @type: Promise
   */
  reload: function() {
    this.unload();
    return this.load();
  },

  /**
   * Sets the internal design code inside the Polymer Designer running within
   * the <webview>. This results in PD re-rendering the design, if it can
   * parse the code. If it can't, it resets the design to an empty one.
   *
   * @type: Promise
   */
  setCode: function(code) {
    var that = this;

    // Escape all special charachters and enclose in double-quotes.
    code = JSON.stringify(code);
    // Just in case we are called too early, wait until the webview is ready.
    return that._webviewReady.then(function () {
      // TODO(ussuri): This doesn't work without a delay:
      // find some way to detect when PD is fully ready.
      return setTimeout(function() {
        // The request is received and handled by the JS proxy script injected
        // into [_webview>] by [_injectDesignerProxy].
        return that._executeScriptInWebview(
          "function() { window.postMessage({action: 'set_code', code: " +
          code +
          "}, '*'); }"
        );
      }, 500);
    });
  },

  /**
   * Extracts and returns to the caller the current design code from the
   * Polymer Designer.
   *
   * @type: Promise<String>
   */
  getCode: function() {
    var that = this;

    if (that._codeExported == null) {
      that._codeExported = new Promise(function(resolve, reject) {
        that._codeExportedResolve = resolve;
        // The request is received and handled by [_designerProxy], which
        // asynchronously returns the result via a chrome.runtime.sendMessage,
        // received and handled by [_designProxyListener], which resolves the
        // [_codeExported] promise with the code string.
        that._executeScriptInWebview(
          "function() { window.postMessage({action: 'get_code'}, '*'); }"
        );
      });
    } else {
      // There already is a pending [getCode] request: just fall through
      // to returning the same promise to the new caller.
    }

    return that._codeExported;
  },

  /**
   * Tweaks the Polymer Designer UI and inject a proxy script.
   *
   * @type: void
   */
  _onWebviewContentLoad: function(event) {
    var that = this;

    that._tweakDesignerUI();
    that._injectDesignerProxy().then(function() {
      that._webviewReadyResolve(null);
    });
  },

  /**
   * Tweaks the Polymer Designer UI by inserting some CSS into [_webview]:
   * - Adjusts font sizes.
   * - Reduces toolbar sizes.
   * - Removes some buttons we don't need.
   *
   * @type: void
   */
  _tweakDesignerUI: function() {
    // TODO(ussuri): Some of this will become unnecessary once BUG #3467 is
    // resolved.
    this._insertCssIntoWebview("\
        /* Reduce the initial font sizes */\
        html /deep/ *, html /deep/ #tabs > * {\
          font-size: 12px;\
        }\
        html /deep/ #tabs {\
          padding-top: 0;\
          padding-bottom: 0;\
        }\
        html /deep/ core-toolbar,\
        html /deep/ core-toolbar::shadow > #topBar {\
          height: 40px;\
        }\
        /* Hide some UI elements we do not need */\
        #designer::shadow > #appbar > * {\
          display: none;\
        }\
        #designer::shadow > #appbar > .design-controls {\
          display: block;\
        }\
        #designer::shadow > #appbar > .design-controls > .separator:first-child {\
          display: none;\
        }\
        /* Revert font size for the current element */\
        #designer /deep/ #selectedElement {\
          font-size: 15px;\
        }\
        /* Adjust palette elements' style */\
        #designer /deep/ .simple-item {\
          height: 30px;\
          line-height: 30px;\
          font-size: 12px;\
        }"
    );
  },

  /**
   * Registers a listener for responses sent by [_designerProxy].
   *
   * @type: void
   */
  _registerDesignerProxyListener: function() {
    chrome.runtime.onMessage.addListener(this._designerProxyListener.bind(this));
  },

  /**
   * Handles messages/responses sent from inside [_webview] by [_designerProxy].
   *
   * @type: void
   */
  _designerProxyListener: function(event) {
    // TODO(ussuri): Check the sender?
    switch (event.type) {
      case 'get_code_response':
        this._codeExportedResolve(event.code);
        // Null the promise so new [getCode] requests can work properly.
        this._codeExported = this._codeExportedResolve = null;
        break;
    }
  },

  /**
   * The proxy script injected into the scripting context ("main world") of
   * [_webview] in order to receive and handle requests on behalf of this object.
   *
   * @type: string
   */
  _designerProxy: function() {
    // This will receive events sent by the main code via window.postMessage
    // executed inside [_webview]'s DOM.
    window.addEventListener('message', function(event) {
      var designer = document.querySelector('#designer');
      switch (event.data.action) {
        case 'get_code':
          chrome.runtime.sendMessage({
              type: 'get_code_response',
              code: designer.html
          });
          break;
        case 'set_code':
          // After this, PD will detect the new design code and try to parse
          // and render it.
          designer.loadHtml(event.data.code);
          break;
      }
    });
  },

  /**
   * Injects [_designerProxy] into the scripting context ("main world") of
   * [_webview]. This is necessary in contrast to the "isolated world" in
   * order for the proxy to have access to the JS context of the Designer
   * (within "isolated world", the proxy would only see the Designer's DOM).
   *
   * @type: Promise
   */
  _injectDesignerProxy: function() {
    return this._injectScriptIntoWebviewMainWorld(this._designerProxy);
  },

  /**
   * Effectively injects and runs a given script in the [_webview]'s scripting
   * context ("main world"). This is achieved by creating a new <script> tag in
   * the [_webview]'s DOM and setting its inner HTML to the script's code.
   * Doing that will cause the script to run and be able to register event
   * listeners which will have access to various Polymer Designer's JS
   * properties.
   *
   * @type: Promise
   */
  _injectScriptIntoWebviewMainWorld: function(func) {
    var script = JSON.stringify('(' + func.toString() + ')();');

    return this._executeScriptInWebview("function() {\n\
      var scriptTag = document.createElement('script');\n\
      scriptTag.innerHTML = " + script + ";\n\
      document.body.appendChild(scriptTag);\n\
    }");
  },

  /**
   * Executes a script in [_webview]'s "isolated world", which give the script
   * access only to the webview's DOM, but not the JS context.
   *
   * @type: Promise<array of any>
   */
  _executeScriptInWebview: function(func) {
    var that = this;

    var script = '(' + func.toString() + ')();';

    return new Promise(function(resolve, reject) {
      that._webview.executeScript(
          {code: script},
          function(result) { resolve(result); }
      );
    });
  },

  /**
   * Inserts a fragment of CSS into [_webview]'s DOM.
   *
   * @type: void
   */
  _insertCssIntoWebview: function(css) {
    this._webview.insertCSS({code: css});
  }
});

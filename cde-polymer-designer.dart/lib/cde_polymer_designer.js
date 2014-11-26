// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

function PromiseCompleter() {
  this.promise = new Promise(function(resolve, reject) {
    this.resolve_ = resolve;
    this.reject_ = reject;
  }.bind(this));
}

PromiseCompleter.prototype.resolve = function(value) {
  this.resolve_(value);
};

PromiseCompleter.prototype.reject = function(value) {
  this.reject_(value);
};

PromiseCompleter.prototype.then = function(onFulfilled, onRejected) {
  this.promise.then(onFulfilled, onRejected);
};

PromiseCompleter.prototype.catch = function(onRejected) {
  this.promise.catch(onRejected);
};

Polymer('cde-polymer-designer', {
  // NOTE: Make sure this is in-sync with ide/web/manifest.json.
  STORAGE_PARTITION_: 'persist:cde-polymer-designer',
  // NOTE: We must use the full path as viewed by a client app.
  LOCAL_ENTRY_POINT_:
      'packages/cde_polymer_designer/src/polymer_designer/index.html',
  ONLINE_ENTRY_POINT_:
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
   * Initial design code requested in a call to [load].
   */
  initialCode_: '',

  /**
   * The dynamically created <webview> element.
   */
  webview_: null,

  /**
   * Resolves after the <webview> has been created, its UI tweaked and the proxy
   * script injected into it.
   *
   * @type: PromiseCompleter
   */
  webviewReadyCompleter_: null,

  /**
   * Resolves when the asynchronous code export requested from the proxy has
   * completed.
   *
   * @type: PromiseCompleter<String>
   */
  getCodeCompleter_: null,

  /**
   * Registers an event listener to complete initialization once the
   * <webview> is up and running.
   */
  ready: function() {
    this.registerDesignerProxyListener_();
  },

  /**
   * Initializes this object from an idle state:
   * - Creates a new <webview>.
   * - Inserts it into the shadow DOM.
   * - Navigates it to the Polymer Designer local or online entry point.
   *
   * @return: Promise
   */
  load: function(initialCode) {
    if (this.webviewReadyCompleter_ !== null) {
      throw "Already loaded or still loading: call unload() first";
    }

    this.initialCode_ = initialCode;

    // This will be completed in [onWebviewContentLoad_].
    this.webviewReadyCompleter_ = new PromiseCompleter();

    this.webview_ = document.createElement('webview');
    this.webview_.addEventListener(
        'contentload', this.onWebviewContentLoad_.bind(this));
    this.webview_.partition = this.STORAGE_PARTITION_;
    this.webview_.src =
        this.entryPoint === 'local' ?
        this.LOCAL_ENTRY_POINT_ :
        this.ONLINE_ENTRY_POINT_;
    this.shadowRoot.appendChild(this.webview_);

    return this.webviewReadyCompleter_.promise;
  },

  /**
   * Returns the object to the idle state:
   * - terminates the running <webview>, if any.
   * - removes the <webview> element from the shadow DOM.
   * - Resets the [Completer]s.
   *
   * @return: void
   */
  unload: function() {
    if (this.webview_ !== null) {
      this.webview_.terminate();
      this.shadowRoot.removeChild(this.webview_);
    }
    this.webview_ = null;
    this.webviewReadyCompleter_ = null;
    this.getCodeCompleter_ = null;
  },

  /**
   * Reinitializes the object from a running state.
   *
   * @return: Promise
   */
  reload: function() {
    this.unload();
    return this.load();
  },

  /**
   * Sets the internal design code inside the Designer. This results in PD
   * (re-)rendering the design, if it can parse the code. If it can't, it
   * resets the design to an empty one.
   *
   * @return: Promise
   */
  setCode: function(code) {
    // Escape all special charachters and enclose in double-quotes.
    code = JSON.stringify(code);
    // Just in case we are called too early, wait until the webview is ready.
    return this.webviewReadyCompleter_.then(function() {
      // The request is received and handled by the JS proxy script injected
      // into [webview_>] by [injectDesignerProxy_].
      return this.executeScriptInWebview_(
        "function() { window.postMessage({action: 'set_code', code: " +
        code +
        "}, '*'); }"
      );
    }.bind(this));
  },

  /**
   * Resets the internal design code to the value originally requested in [load].
   *
   * @return: Promise
   */
  revertCode: function() {
      return this.executeScriptInWebview_(
        "function() { window.postMessage({action: 'revert_code'}, '*'); }"
      );
  },

  /**
   * Extracts and returns to the caller the current design code from the
   * Polymer Designer.
   *
   * @return: Promise<String>
   */
  getCode: function() {
    if (!this.getCodeCompleter_) {
      this.getCodeCompleter_ = new PromiseCompleter();

      // The request is received and handled by [designerProxy_], which
      // asynchronously returns the result via a chrome.runtime.sendMessage,
      // received and handled by [_designProxyListener], which resolves
      // [getCodeCompleter_.promise] with the code string.
      this.executeScriptInWebview_(
        "function() { window.postMessage({action: 'get_code'}, '*'); }"
      );
    } else {
      // There already is a pending [getCode] request: just fall through
      // to returning the same promise to the new caller.
    }

    return this.getCodeCompleter_.promise;
  },

  /**
   * Tweaks the Polymer Designer UI and inject a proxy script.
   *
   * @return: void
   */
  onWebviewContentLoad_: function(event) {
    // Nudge Chrome to redo the layout of the Designer. Without this, or some
    // other trigger, the Designer never settles to fit the viewport perfectly
    // (overflows to the right). See http://stackoverflow.com/questions/3485365/.
    this.webview_.style.width = '100%';
    this.tweakDesignerUI_();
    this.injectDesignerProxy_().then(function() {
      this.webviewReadyCompleter_.resolve();
    }.bind(this));
  },

  /**
   * Tweaks the Polymer Designer UI by inserting some CSS into [webview_]:
   * - Adjusts font sizes.
   * - Reduces toolbar sizes.
   * - Removes some buttons we don't need.
   *
   * @return: void
   */
  tweakDesignerUI_: function() {
    // TODO(ussuri): Some of this will become unnecessary once BUG #3467 is
    // resolved.
    this.insertCssIntoWebview_(
        // Reduce the initial font sizes.
        "#designer /deep/ *," +
        "#designer /deep/ #tabs > * {" +
        "  font-size: 13px;" +
        "}" +
        // Adjust tabs' height and color.
        "#designer /deep/ #inspector::shadow > #tabs," +
        "#designer /deep/ .paletteTree > #tabs {" +
        "  padding-top: 0;" +
        "  padding-bottom: 0;" +
        "  background-color: #fafafa;" +
        "}" +
        // Skinnier splitter.
        "#designer /deep/ core-splitter {" +
        "  height: 8px;" +
        "  background-color: #fafafa;" +
        "}" +
        // Adjust toolbars' height.
        "#designer /deep/ core-toolbar," +
        "#designer /deep/ #topBar," +
        "#designer /deep/ .designTools {" +
        "  height: 50px;" +
        "  background-color: #fafafa;" +
        "}" +
        // Make buttons' smaller and round.
        "#designer /deep/ core-icon-button {" +
        "  height: 38px;" +
        "  width: 38px;" +
        "  border-radius: 50%;" +
        "  box-shadow: none;" +
        "}" +
        "#designer /deep/ core-icon-button:hover {" +
        "  background-color: #eee;" +
        "}" +
        // Hide some UI elements we do not need.
        "#designer::shadow > #appbar > * {" +
        "  display: none;" +
        "}" +
        "#designer::shadow > #appbar > .design-controls {" +
        "  display: block;" +
        "}" +
        "#designer::shadow > #appbar > .design-controls > .separator:first-child {" +
        "  display: none;" +
        "}" +
        // Revert font size for the current element.
        "#designer /deep/ #selectedElement {" +
        "  font-size: 15px;" +
        "}" +
        // Adjust palette elements' style.
        "#designer /deep/ .simple-item {" +
        "  height: 30px;" +
        "  line-height: 30px;" +
        "  font-size: 13px;" +
        "}" +
        // Override palette's opacity from 0.9. This is an empirically found
        // way to mask BUG #3634.
        // TODO(ussuri): This is possibly related to BUG #3466.
        "#designer /deep/ #palette::shadow #list {" +
        "  opacity: 1;" +
        "}"
    );
  },

  /**
   * Registers a listener for responses sent by [designerProxy_].
   *
   * @return: void
   */
  registerDesignerProxyListener_: function() {
    chrome.runtime.onMessage.addListener(this.designerProxyListener_.bind(this));
  },

  /**
   * Handles messages/responses sent from inside [webview_] by [designerProxy_].
   *
   * @return: void
   */
  designerProxyListener_: function(event) {
    // TODO(ussuri): Check the sender?
    switch (event.type) {
      case 'get_code_response':
        this.getCodeCompleter_.resolve(event.code + '\n');
        // Null the promise so new [getCode] requests can work properly.
        this.getCodeCompleter_ = null;
        break;
      default:
        throw "Unsupported message from proxy";
    }
  },

  /**
   * The proxy script injected into the scripting context ("main world") of
   * [webview_] in order to receive and handle requests on behalf of this object.
   *
   * @return: string
   */
  designerProxy_: function(initialCode) {
    var designer = document.querySelector('#designer');

    // `designer-ready` is fired when the contained designer-frame becomes
    // ready, but before the designer-element loads the elements from the
    // palette (specified in [metadata]) and possibly some design from the user.
    // Handle it in the capture phase to get ahead of designer-element's handler.
    designer.$.frame.contentWindow.addEventListener('designer-ready',
        function(event) {
      // Prest the design code to be loaded by the Designer while the event is
      // on the way to it. Setting [firstLoad] is a required hack.
      designer.pendingHtml = initialCode;
      designer.firstLoad = false;
    }, /*useCapture=*/true);

    // This will receive events sent by the main code via window.postMessage
    // executed inside [webview_]'s DOM.
    window.addEventListener('message', function(event) {
      switch (event.data.action) {
        case 'get_code':
          chrome.runtime.sendMessage({
              type: 'get_code_response',
              code: designer.html
          });
          break;
        case 'set_code':
          // PD will try to parse and render the new design code. It will
          // throw an internal error and clear out the design if the code
          // doesn't match the expected format: there should be a
          // <polymer-element> tag at the top level.
          designer.loadHtml(event.data.code);
          break;
        case 'revert_code':
          designer.loadHtml(initialCode);
          break;
        default:
          throw "Unsupported request from client";
      }
    });
  },

  /**
   * Injects [designerProxy_] into the scripting context ("main world") of
   * [webview_]. This is necessary in contrast to the "isolated world" in
   * order for the proxy to have access to the JS context of the Designer
   * (within "isolated world", the proxy would only see the Designer's DOM).
   *
   * @return: Promise
   */
  injectDesignerProxy_: function() {
    return this.injectScriptIntoWebviewMainWorld_(
        this.designerProxy_, this.initialCode_);
  },

  /**
   * Effectively injects and runs a given script in the [webview_]'s scripting
   * context ("main world"). This is achieved by creating a new <script> tag in
   * the [webview_]'s DOM and setting its inner HTML to the script's code.
   * Doing that will cause the script to run and be able to register event
   * listeners which will have access to various Polymer Designer's JS
   * properties.
   *
   * @return: Promise
   */
  injectScriptIntoWebviewMainWorld_: function(func, args) {
    // NOTE: Double-stringifying of [args] is intentional.
    var script = JSON.stringify(
        '(' + func.toString() + ')(' + JSON.stringify(args) + ');'
    );
    return this.executeScriptInWebview_(
        "function() {\n" +
        "  var scriptTag = document.createElement('script');\n" +
        "  scriptTag.innerHTML = " + script + ";\n" +
        "  document.body.appendChild(scriptTag);\n" +
        "}"
    );
  },

  /**
   * Executes a script in [webview_]'s "isolated world", which gives the script
   * access only to the webview's DOM, but not the JS context.
   *
   * @return: Promise<array of any>
   */
  executeScriptInWebview_: function(func) {
    var script = '(' + func.toString() + ')();';
    var completer = new PromiseCompleter();
    this.webview_.executeScript(
        {code: script},
        function(result) { completer.resolve(result); }
    );
    return completer.promise;
  },

  /**
   * Inserts a fragment of CSS into [webview_]'s DOM.
   *
   * @return: void
   */
  insertCssIntoWebview_: function(css) {
    this.webview_.insertCSS({code: css});
  }
});

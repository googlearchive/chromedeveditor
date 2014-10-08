// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library cde_polymer_designer;

import 'dart:async';
import 'dart:html';
import 'dart:js' as js;
import 'dart:convert' show JSON;

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:polymer/polymer.dart';

/**
 * This Polymer element is a wrapper around the top-level entry point of
 * Polymer Designer.
 *
 * It runs either a local copy or the online origin of the Designer inside
 * a webview, tweaking its UI to match the requirements of CDE. To be able to
 * communicate with the Designer inside a webview, it injects a proxy script
 * into the webview's "main world" (as opposed to the "isolated world"). The
 * Dart side then posts messages to the proxy by executing window.postMessage
 * in the webview's "isolated world"; the proxy receives requests in its
 * on-message listener and responds back via chrome.runtime.sendMessage(),
 * received by the Dart side in a chrome.runtime.onMessage listener.
 *
 * The webview with Polymer Designer can be started and terminated multiple
 * times.
 *
 * The primary useful functionality to a client is [setCode] to intialize
 * the Designer with some existing design and [getCode] to extract a new design
 * back after the user has modified it.
 */
@CustomTag('cde-polymer-designer')
class CdePolymerDesigner extends PolymerElement {
  // NOTE: Make sure this is in-sync with ide/web/manifest.json.
  static const _STORAGE_PARTITION = 'cde-polymer-designer';
  // NOTE: We must use the full path as viewed by a client app.
  static const String _LOCAL_ENTRY_POINT =
      'packages/cde_polymer_designer/src/polymer_designer/index.html';
  static const String _ONLINE_ENTRY_POINT =
      'https://www.polymer-project.org/tools/designer/';

  @published String entryPoint = 'local';

  /// The dynamically created <webview> element.
  Element _webviewElt;
  /// A JS proxy object around [_webviewElt].
  js.JsObject _webview;
  /// Fires after the <webview> has been created, its UI tweaked and the proxy
  /// script injected into it.
  Completer _webviewReady;
  /// Fires when the asynchronous code export requested from the proxy has
  /// completed.
  Completer<String> _codeExported;

  CdePolymerDesigner.created() : super.created();

  @override
  void attached() {
    super.attached();

    assert(['local', 'inline'].contains(entryPoint));

    _registerDesignerProxyListener();
  }

  /**
   * Initializes this object from an idle state:
   * - Creates a new <webview>.
   * - Inserts it into the shadow DOM.
   * - Navigates it to the Polymer Designer local or online entry point.
   * - Registers an event listener to complete initialization once the
   * <webview> is up and running.
   */
  Future load() {
    _webviewReady = new Completer();

    // TODO(ussuri): BUG #3466.
    new Timer(new Duration(milliseconds: 500), () {
      _webviewElt = new Element.tag('webview');

      _webview = new js.JsObject.fromBrowserObject(_webviewElt);
      _webview.callMethod(
          'addEventListener', ['contentload', _onWebviewContentLoad]);
      _webview['partition'] = _STORAGE_PARTITION;
      _webview['src'] =
          entryPoint == 'local'  ? _LOCAL_ENTRY_POINT : _ONLINE_ENTRY_POINT;

      shadowRoot.append(_webviewElt);
    });

    // TODO(ussuri): Try enabling once BUG #3467 is resolved.
    // _webviewReady.future.then((_) {
    //   _webview.callMethod('setZoom', [0.8]);
    // });

    return _webviewReady.future;
  }

  /**
   * Reinitializes the object from a running state.
   */
  Future reload() {
    unload();
    return load();
  }

  /**
   * Returns the object to the idle state:
   * - terminates the running <webview>, if any.
   * - removes the <webview> element from the shadow DOM.
   * - Resets the [Completer]s.
   */
  void unload() {
    if (_webview != null) {
      _webview.callMethod('terminate');
    }
    if (_webviewElt != null) {
      _webviewElt.remove();
    }
    _webview = _webviewElt = _webviewReady = _codeExported = null;
  }

  /**
   * Sets the internal design code inside the Polymer Designer running within
   * the <webview>. This results in PD re-rendering the design, if it can
   * parse the code. If it can't, it resets the design to an empty one.
   */
  Future setCode(String code) {
    // Escape all special charachters and enclose in double-quotes.
    code = JSON.encode(code);
    // Just in case we are called too early, wait until the webview is ready.
    return _webviewReady.future.then((_) {
      // TODO(ussuri): This doesn't work without a delay:
      // find some way to detect when PD is fully ready.
      return new Timer(new Duration(milliseconds: 500), () {
        // The request is received and handled by the JS proxy script injected
        // into [_webview>] by [_injectDesignerProxy].
        return _executeScriptInWebview(r'''
            window.postMessage(
                {action: 'import_code', code: ''' + code + r'''}, '*');
        ''');
      });
    });
  }

  /**
   * Extracts and returns to the caller the current design code from the
   * Polymer Designer.
   */
  Future<String> getCode() {
    if (_codeExported == null) {
      _codeExported = new Completer<String>();
      // Just in case we are called too early, wait until the webview is ready.
      _webviewReady.future.then((_) {
        // The request is received and handled by [_designerProxy], which
        // asynchronously returns the result via a chrome.runtime.sendMessage,
        // received and handled by [_designProxyListener], which completes the
        // [_codeExported] completer with the code string.
        _executeScriptInWebview(r'''
            window.postMessage({action: 'export_code'}, '*');
        ''');
      });
    } else {
      // There already is a pending [getCode] request: just fall through
      // to returning the same future to the new caller.
    }
    return _codeExported.future;
  }

  /**
   * Tweaks the Polymer Designer UI and inject a proxy script.
   */
  void _onWebviewContentLoad(_) {
    _tweakDesignerUI();
    _injectDesignerProxy().then((_) => _webviewReady.complete());
  }

  /**
   * Tweaks the Polymer Designer UI by inserting some CSS into [_webview]:
   * - Reduces font sizes.
   * - Reduces toolbar sizes.
   * - Removes some buttons we don't need.
   */
  void _tweakDesignerUI() {
    // TODO(ussuri): Some of this will become unnecessary once BUG #3467 is
    // resolved.
    _insertCssIntoWebview(r'''
        /* Reduce the initial font sizes */
        html /deep/ *, html /deep/ #tabs > * {
          font-size: 13px;
        }
        html /deep/ #tabs {
          padding-top: 0;
          padding-bottom: 0;
        }
        html /deep/ core-toolbar,
        html /deep/ core-toolbar::shadow > #topBar {
          height: 40px;
        }
        /* Hide some UI elements we don't need */
        #designer::shadow > #appbar > * {
          display: none;
        }
        #designer::shadow > #appbar > .design-controls {
          display: block;
        }
        #designer::shadow > #appbar > .design-controls > .separator:first-child {
          display: none;
        }
    ''');
  }

  /**
   * Handles responses sent from inside [_webview] by [_designerProxy].
   */
  void _designerProxyListener(chrome.OnMessageEvent event) {
    // TODO(ussuri): Check the sender?
    if (event.message['type'] == 'export_code_response') {
      _codeExported.complete("${event.message['code']}");
      // Null the completer so new [getCode] requests can work properly.
      _codeExported = null;
    }
  }

  /**
   * Registers a listener for responses sent by [_designerProxy].
   */
  void _registerDesignerProxyListener() {
    chrome.runtime.onMessage.listen(_designerProxyListener);
  }

  /**
   * The proxy script injected into the scripting context ("main world") of
   * [_webview] in order to receive and handle requests on behalf of this object.
   */
  static const String _designerProxy = r'''
      // This will receive events sent by the main code via window.postMessage
      // executed inside [_webview]'s DOM.
      window.addEventListener("message", function(event) {
        var designer = document.querySelector('#designer');
        var action = event.data['action'];
        if (action === 'export_code') {
          chrome.runtime.sendMessage(
              {type: 'export_code_response', code: designer.html});
        } else if (action === 'import_code') {
          // After this, PD will detect the new design code and try to parse
          // and render it.
          designer.loadHtml(event.data['code']);
        }
      });
  ''';

  /**
   * Injects [_designerProxy] into the scripting context ("main world") of
   * [_webview]. This is necessary in contrast to the "isolated world" in
   * order for the proxy to have access to the JS context of the Designer
   * (within "isolated world", the proxy would only see the Designer's DOM).
   */
  Future _injectDesignerProxy() {
    // TODO(ussuri): Check the sender?
    return _injectScriptIntoWebviewMainWorld(_designerProxy);
  }

  /**
   * Effectively injects and runs a given script in the [_webview]'s scripting
   * context ("main world"). This is achieved by creating a new <script> tag in
   * the [_webview]'s DOM and setting its inner HTML to the script's code.
   * Doing that will cause the script to run and be able to register event
   * listeners which will have access to various Polymer Designer's JS
   * properties.
   */
  Future _injectScriptIntoWebviewMainWorld(String script) {
    // Escape all special charachters and enclose in double-quotes.
    script = JSON.encode('(function() { $script; })()');
    return _executeScriptInWebview(r'''
        (function() {
          var scriptTag = document.createElement('script');
          scriptTag.innerHTML = ''' + script + r''';
          document.body.appendChild(scriptTag);
        })();
    ''');
  }

  /**
   * Executes a script in [_webview]'s "isolated world", which give the script
   * access only to the webview's DOM, but not the JS context.
   */
  Future<dynamic> _executeScriptInWebview(String script) {
    final js.JsObject jsScript = new js.JsObject.jsify({'code': script});
    final completer = new Completer();
    _webview.callMethod('executeScript',
        [jsScript, ([result]) => completer.complete(result)]);
    return completer.future;
  }

  /**
   * Inserts a fragment of CSS into [_webview]'s DOM.
   */
  void _insertCssIntoWebview(String css) {
    final js.JsObject jsCss = new js.JsObject.jsify({'code': css});
    _webview.callMethod('insertCSS', [jsCss]);
  }
}

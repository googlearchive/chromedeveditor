// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library cde_polymer_designer;

import 'dart:async';
import 'dart:html';
import 'dart:js' as js;

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:polymer/polymer.dart';

@CustomTag('cde-polymer-designer')
class CdePolymerDesigner extends PolymerElement {
  // Must use the full path as viewed by a client app.
  static const String _LOCAL_ENTRY_POINT =
      'packages/cde_polymer_designer/src/polymer_designer/index.html';
  static const String _ONLINE_ENTRY_POINT =
      'https://www.polymer-project.org/tools/designer/';
  static const _STORAGE_PARTITION = 'cde-polymer-designer';

  @published String entryPoint = 'local';

  Element _webviewElt;
  js.JsObject _webview;
  Completer _webviewReady;
  Completer<String> _codeExported;

  CdePolymerDesigner.created() : super.created();

  @override
  void attached() {
    super.attached();
    assert(['local', 'inline'].contains(entryPoint));

    _registerDesignerProxyListener();
  }

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

  Future reload() {
    unload();
    return load();
  }

  void unload() {
    if (_webview != null) {
      _webview.callMethod('terminate');
    }
    if (_webviewElt != null) {
      _webviewElt.remove();
    }
    _webview = _webviewElt = _webviewReady = _codeExported = null;
  }

  Future setCode(String code) {
    code = code.replaceAll('"', r'\"').replaceAll('\n', r'\n');
    return _webviewReady.future.then((_) {
      // TODO(ussuri): This doesn't work without a delay:
      // find some way to detect when PD and proxy/listener are fully ready.
      return new Timer(new Duration(milliseconds: 500), () {
        return _executeScriptInWebview('''
            window.postMessage({action: 'import_code', code: '$code'}, '*');
        ''');
      });
    });
  }

  Future<String> getCode() {
    _codeExported = new Completer<String>();
    _webviewReady.future.then((_) {
      _executeScriptInWebview('''
          window.postMessage({action: 'export_code'}, '*');
      ''');
    });
    return _codeExported.future;
  }

  void _onWebviewContentLoad(_) {
    _tweakDesignerUI();
    _injectDesignerProxy().then((_) => _webviewReady.complete());
  }

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

  void _registerDesignerProxyListener() {
    chrome.runtime.onMessage.listen((chrome.OnMessageEvent event) {
      // TODO(ussuri): Check the sender?
      if (event.message['type'] == 'export_code_response') {
        _codeExported.complete("${event.message['code']}");
      }
    });
  }

  Future _injectDesignerProxy() {
    // TODO(ussuri): Check the sender?
    return _injectScriptIntoWebviewMainWorld(r'''
        window.addEventListener("message", function(event) {
          var designer = document.querySelector('#designer');
          var action = event.data['action'];
          if (action === 'export_code') {
            chrome.runtime.sendMessage(
                {type: 'export_code_response', code: designer.html});
          } else if (action === 'import_code') {
            designer.loadHtml(event.data['code']);
          }
        });
    ''');
  }

  Future _injectScriptIntoWebviewMainWorld(String script) {
    script = script.replaceAll('"', r'\"')
                   .replaceAll("'", r"\'")
                   .replaceAll('\n', r'\n');
    return _executeScriptInWebview(r'''
        (function() {
          var scriptTag = document.createElement('script');
          scriptTag.innerHTML = '(function() { ''' + script + r'''; })()';
          document.body.appendChild(scriptTag);
        })();
    ''');
  }

  Future<dynamic> _executeScriptInWebview(String script) {
    final js.JsObject jsScript = new js.JsObject.jsify({'code': script});
    final completer = new Completer();
    _webview.callMethod('executeScript',
        [jsScript, ([result]) => completer.complete(result)]);
    return completer.future;
  }

  void _insertCssIntoWebview(String css) {
    final js.JsObject jsCss = new js.JsObject.jsify({'code': css});
    _webview.callMethod('insertCSS', [jsCss]);
  }
}

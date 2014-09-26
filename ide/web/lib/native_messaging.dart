// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Native Messaging services
 */
library spark.native_messaging;

import 'dart:convert';
import 'dart:js';

import 'utils.dart';

class NativeMassagingManager {

  static const HOST_NAME = 'com.google.cde.host';
  static const KEY_ACTION = 'action';
  static const KEY_PATH = 'path';
  static const KEY_URL = 'url';

  JsObject _port;
  Notifier _notifier;

  /**
   * Sends a message to the native host, the message is in JSON format.
   */
  void _sendNativeMessage(String message) {
    _port.callMethod('postMessage', [message]);
  }

  /**
   * function for receiving message
   */
  void _onNativeMessage(request, sender) {
    String message = context['JSON'].callMethod('stringify',[request]);
    Map map = JSON.decode(message);
    if (map.containsKey("error")) {
      _notifier.showMessage("Dartium launch", map["error"]);
    }
  }

  void _onDisconnected(sender) {
    _port = null;
  }

  /**
   * Connect to host and add listeners. Once connected, all communications to the host
   * is done through the port of connection.
   */
  void _connect() {
    JsObject runtime = context['chrome']['runtime'];
    _port = runtime.callMethod('connectNative', [HOST_NAME]);

    var jsOnMessageEvent = _port['onMessage'];
    JsObject dartOnMessageEvent = (jsOnMessageEvent is JsObject ?
        jsOnMessageEvent : new JsObject.fromBrowserObject(jsOnMessageEvent));
    dartOnMessageEvent.callMethod('addListener', [_onNativeMessage]);

    jsOnMessageEvent = _port['onDisconnect'];
    dartOnMessageEvent = (jsOnMessageEvent is JsObject ?
          jsOnMessageEvent : new JsObject.fromBrowserObject(jsOnMessageEvent));
    dartOnMessageEvent.callMethod('addListener', [_onDisconnected]);
  }

  void launchDartium(Notifier notifier, String path, String url) {
    if (_port == null) {
      _connect();
    }
    _notifier = notifier;
    Map<String,String> map = new Map();
    map[KEY_ACTION] = 'dartium';
    map[KEY_PATH] = path;
    map[KEY_URL] = url;
    _sendNativeMessage(JSON.encode(map));
  }
}

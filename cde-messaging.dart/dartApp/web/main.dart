// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:html';
import 'dart:js';

void main() {
  querySelector("#connect-button").onClick.listen(connect);
  querySelector("#send-message-button").onClick.listen(sendNativeMessage);
  updateUiState();
}

JsObject port;

 void _appendMessage(text) {
   querySelector("#response").text += text;
}

void updateUiState() {
  querySelector("#connect-button").style.display = port != null ? 'none' : 'block';
  querySelector("#input_text").style.display = port != null ? 'block' : 'none';
  querySelector("#send-message-button").style.display = port != null ? 'block' : 'none';
}

void sendNativeMessage(MouseEvent event) {
  InputElement element = querySelector("#input_text");
  String message = '{"action":${element.value}}';
  port.callMethod('postMessage', [message]);
  _appendMessage('Sent message:  $message');
}

void onNativeMessage(request, sender) {
  String s = context['JSON'].callMethod('stringify',[request]);
  querySelector("#response").text += 'Received message: $s';
}

void onDisconnected(sender) {
  _appendMessage('Failed to connect');
  port = null;
  updateUiState();
}

void connect(MouseEvent event) {
  var hostName = "com.google.chrome.example.py";
  _appendMessage("Connecting to native messaging host" + hostName);
  JsObject runtime = context['chrome']['runtime'];
  port = runtime.callMethod('connectNative', [hostName]);

  var jsOnMessageEvent = port['onMessage'];
  JsObject dartOnMessageEvent = (jsOnMessageEvent is JsObject ?
      jsOnMessageEvent : new JsObject.fromBrowserObject(jsOnMessageEvent));
  dartOnMessageEvent.callMethod('addListener', [onNativeMessage]);

  jsOnMessageEvent = port['onDisconnect'];
  dartOnMessageEvent = (jsOnMessageEvent is JsObject ?
        jsOnMessageEvent : new JsObject.fromBrowserObject(jsOnMessageEvent));
  dartOnMessageEvent.callMethod('addListener', [onDisconnected]);
  updateUiState();
}



// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to communicate with usb devices.
 */
library spark.usb;

import 'dart:async';
import 'dart:js' as js;

/**
 * Utility class to query new features in the USB api. These should eventually
 * be generated in the chrome_apps/usb.dart package.
 */
class UsbUtil {
  static final _context = js.context['chrome']['usb'];

  static Future<List> getDevices() {
    Completer completer = new Completer();

    Function cb = (result) {
      completer.complete(result);
    };

    var options = new js.JsObject.jsify({});
    _context.callMethod("getDevices", [options, cb]);

    return completer.future;
  }

  static Future<List> getUserSelectedDevices() {
    Completer completer = new Completer();

    Function cb = (result) {
      completer.complete(result);
    };

    var options = new js.JsObject.jsify({
      'filters': [
        new js.JsObject.jsify({
          // filter to get adb devices.
          'interfaceClass': 0xff,
          'interfaceSubclass': 0x42,
          'interfaceProtocol': 0x01
        })
      ]
    });

    try {
      _context.callMethod("getUserSelectedDevices", [options, cb]);
    } catch (e) {
      // user cancelled the operation.
      completer.complete();
    }

    return completer.future;
  }
}

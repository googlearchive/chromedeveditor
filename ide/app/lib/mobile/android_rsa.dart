// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to manage Android RSA key generation and signature.
 */
library spark.android_rsa;

import 'dart:async';
import 'dart:js' as js;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show CryptoUtils;

/**
 * Here's the possible errors that the methods of AndroidRSA can return.
 *
 * invalid_parameters
 * When the number of parameters is not correct.
 *
 * invalid_parameters_types:
 * When a parameter has an invalid type.
 *
 * unknown_command:
 * The command is unknown.
 *
 * unexpected:
 * Unexpected error: generally happens a memory error happens
 *
 * invalid_key:
 * Invalid private key.
 *
 * empty_input
 * Invalid or empty input.
 */

class AndroidRSA {
  // Javascript object to wrap.
  static js.JsObject jsAndroidRSA = js.context['AndroidRSA'];

  /**
   * This method will sign the given data using the given private key.
   * It will return the signature on success.
   */
  static Future<Uint8List> sign(String key, Uint8List data) {
    Completer completer = new Completer();
    Function callback = (signature) {
      Uint8List result =
          new Uint8List.fromList(CryptoUtils.base64StringToBytes(signature));
      completer.complete(result);
    };
    Function errorHandler = (error) {
      completer.completeError(error);
    };
    String b64Data = CryptoUtils.bytesToBase64(data.toList());
    jsAndroidRSA.callMethod('sign', [key, b64Data, callback, errorHandler]);
    return completer.future;
  }

  /**
   * This method will generate a private key.
   */
  static Future<String> generateKey() {
    Completer completer = new Completer();
    Function callback = (key) {
      completer.complete(key);
    };
    Function errorHandler = ([error]) {
      completer.completeError(error);
    };
    jsAndroidRSA.callMethod('generateKey', [callback, errorHandler]);
    return completer.future;
  }

  /**
   * This method return the public key corresponding to the private key in
   * a format used in the ADB protocol.
   */
  static Future<String> getPublicKey(String key) {
    Completer completer = new Completer();
    Function callback = (publicKey) {
      completer.complete(publicKey);
    };
    Function errorHandler = ([error]) {
      completer.completeError(error);
    };
    jsAndroidRSA.callMethod('getPublicKey', [key, callback, errorHandler]);
    return completer.future;
  }

  /**
   * This method will seed the pseudo random number generator with some
   * unpredictable data.
   */
  static Future randomSeed(Uint8List unpredictableData) {
    Completer completer = new Completer();
    Function callback = () {
      completer.complete();
    };
    Function errorHandler = ([error]) {
      completer.completeError(error);
    };
    String b64Data = CryptoUtils.bytesToBase64(unpredictableData.toList());
    jsAndroidRSA.callMethod('randomSeed', [b64Data, callback, errorHandler]);
    return completer.future;
  }
}

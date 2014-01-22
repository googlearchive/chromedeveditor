// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.utils;

import 'dart:async';
import 'dart:core';
import 'dart:html';
import 'dart:js';
import 'dart:typed_data';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:crypto/crypto.dart' as crypto;

/**
 * Convertes [sha] string to sha bytes.
 */
Uint8List shaToBytes(String sha) {
  List<int> bytes = [];
  for (var i = 0; i < sha.length; i+=2) {
    bytes.add(int.parse('0x' + sha[i] + sha[i+1]));
  }
  return new Uint8List.fromList(bytes);
}

/**
 * Converts [shaBytes] to HEX string.
 */
String shaBytesToString(Uint8List shaBytes) {
  String sha = "";
  shaBytes.forEach((int byte) {
    String shaPart = byte.toRadixString(16);
    if (shaPart.length == 1) shaPart = '0' + shaPart;
    sha += shaPart;
  });
  return sha;
}

Future<String> getShaForEntry(chrome.ChromeFileEntry entry, String type) {
  Completer completer = new Completer();
  entry.readBytes().then((chrome.ArrayBuffer content) {
    List<dynamic> blobParts = [];

    Uint8List data = new Uint8List.fromList(content.getBytes());
    int size = data.length;

    String header = '${type} ${size}' ;
    blobParts.add(header);
    blobParts.add(new Uint8List.fromList([0]));
    blobParts.add(data);

    var reader = new JsObject(context['FileReader']);

    reader['onloadend'] = (var event) {
      var result = reader['result'];
      crypto.SHA1 sha1 = new crypto.SHA1();
      Uint8List resultList;

      if (result is JsObject) {
        var arrBuf = new chrome.ArrayBuffer.fromProxy(result);
        resultList = new Uint8List.fromList(arrBuf.getBytes());
      } else if (result is ByteBuffer) {
        resultList = new Uint8List.view(result);
      } else if (result is Uint8List) {
        resultList = result;
      } else {
        // TODO: Check expected types here.
        throw "Unexpected result type.";
      }

      Uint8List data = new Uint8List.fromList(resultList);
      sha1.add(data);
      Uint8List digest = new Uint8List.fromList(sha1.close());
      completer.complete(shaBytesToString(digest));
    };

    reader['onerror'] = (var domError) {
      completer.completeError(domError);
    };

    reader.callMethod('readAsArrayBuffer', [new Blob(blobParts)]);
  });
  return completer.future;
}

/**
 * An empty function.
 */
void nopFunction() => null;

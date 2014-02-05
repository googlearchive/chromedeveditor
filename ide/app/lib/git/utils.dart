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

import 'file_operations.dart';

/**
 * Convertes [sha] string to sha bytes.
 */
Uint8List shaToBytes(String sha) {
  List<int> bytes = [];
  for (var i = 0; i < sha.length; i += 2) {
    bytes.add(int.parse('0x' + sha[i] + sha[i+1]));
  }
  return new Uint8List.fromList(bytes);
}

/**
 * Converts [shaBytes] to HEX string.
 */
String shaBytesToString(List shaBytes) {
  String sha = "";
  shaBytes.forEach((int byte) {
    String shaPart = byte.toRadixString(16);
    if (shaPart.length == 1) shaPart = '0' + shaPart;
    sha += shaPart;
  });
  return sha;
}

Future<String> getShaForEntry(chrome.ChromeFileEntry entry, String type) {
  return entry.readBytes().then((chrome.ArrayBuffer content) => _getShaForData(
      content, type));
}

Future<String> getShaForString(String data, String type) {
  return _getShaForData(data, type);
}

Future<String> _getShaForData(dynamic content, String type) {
  Completer completer = new Completer();
  List<dynamic> blobParts = [];

  int size = 0;
  dynamic data = content;
  if (content is Uint8List) {
    size = content.length;
  } else if (content is Blob) {
    size = content.size;
  } else if (content is String) {
    size = content.length;
  } else if (content is chrome.ArrayBuffer) {
    size = content.getBytes().length;
    data = new Uint8List.fromList(content.getBytes());
  } else {
    // TODO: Check expected types here.
    throw "Unexpected content type.";
  }

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

  return completer.future;
}

/**
 * Return sha for the given data.
 */

dynamic getSha(dynamic data, [bool asBytes]) {
  crypto.SHA1 sha1 = new crypto.SHA1();
  sha1.add(data);
  Uint8List sha = sha1.close();
  if (asBytes) {
    return sha;
  } else {
    return shaBytesToString(sha);
  }
}


/**
 * Clears the given working directory.
 */
Future cleanWorkingDir(chrome.DirectoryEntry root) {
  return FileOps.listFiles(root).then((List<chrome.DirectoryEntry> entries) {
    return Future.forEach(entries, (chrome.Entry entry) {
      if (entry.isDirectory) {
        chrome.DirectoryEntry dirEntry = entry;
        // Do not remove the .git directory.
        if (entry.name == '.git') {
          return null;
        }
        return dirEntry.removeRecursively();
      } else {
        return entry.remove();
      }
    });
  });
}

/**
 * Returns the current time as a string in git internal time format.
 *
 * It is <unix timestamp> <time zone offset>, where <unix timestamp> is the
 * number of seconds since the UNIX epoch. <time zone offset> is a positive
 * or negative offset from UTC. For example CET (which is 2 hours ahead UTC)
 * is +0200.
 */
String getCurrentTimeAsString() {
  DateTime now = new DateTime.now();
  String dateString =
      (now.millisecondsSinceEpoch / 1000).floor().toString();
  int offset = (now.timeZoneOffset.inHours).floor();
  int absOffset = offset.abs().floor();
  String offsetStr = ' ' + (offset < 0 ? '-' : '+');
  offsetStr += (absOffset < 10 ? '0' : '') + '${absOffset}00';
  dateString += offsetStr;
  return dateString;
}

/**
 * An empty function.
 */
void nopFunction() => null;

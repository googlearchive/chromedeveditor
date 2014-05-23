// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.utils;

import 'dart:async';
import 'dart:core';
import 'dart:typed_data';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:logging/logging.dart';

import 'fast_sha.dart';
import 'file_operations.dart';

Logger logger = new Logger('spark.git');

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
String shaBytesToString(List<int> sha) {
  StringBuffer buf = new StringBuffer();
  int len = sha.length;
  for (int i = 0; i < len; i++) {
    String s = sha[i].toRadixString(16);
    if (s.length == 1) buf.write('0');
    buf.write(s);
  }
  return buf.toString();
}

Future<String> getShaForEntry(chrome.ChromeFileEntry entry, String type) {
  return entry.readBytes().then((chrome.ArrayBuffer content) {
    return getShaStringForData(content.getBytes(), type);
  });
}

String getShaForString(String data, String type) {
  return getShaStringForData(data.codeUnits, type);
}

String getShaStringForData(List<int> content, String type) {
  FastSha sha1 = new FastSha();
  sha1.add('${type} ${content.length}'.codeUnits);
  sha1.add([0]);
  sha1.add(content);
  return shaBytesToString(sha1.close());
}

/**
 * Return sha for the given data.
 */
List<int> getShaAsBytes(List<int> data) {
  FastSha sha1 = new FastSha();
  sha1.add(data);
  return sha1.close();
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

/**
 * This class defines a cancellable object.
 * A caller must call check function to find out if the operation has been
 * cancelled. The check function calls the performCancel handler if operation
 * is cancelled.
 */
abstract class Cancel {

  bool _cancel = false;
  String _errorCode;
  bool canIgnore;

  get cancel => _cancel;
  set cancel(bool value) => _cancel = value;
  Cancel([this._cancel]);

  bool check() {
    if (_cancel) {
      performCancel();
      return false;
    } else {
      return true;
    }
  }

  void performCancel();
}

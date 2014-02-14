// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to allow access to the Dart SDK. Specifically, this class exposes
 * the source code for the dart: libraries fro the `dart-sdk/lib` directory.
 * Having the SDK source is necessary for:
 *
 * * dart2js to compile against (otherwise it won't know anything about say
 *    dart:core String)
 * * the analyzer to analyze against, so we can get warnings about incorrect
 *    API usage
 * * the user to navigate to when doing things like exploring the Dart apis
 */
library spark.sdk;

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data' as typed_data;

import 'package:chrome/chrome_app.dart' as chrome;

/**
 * Return the contents of the file at the given path. The path is relative to
 * the Chrome app's directory.
 */
Future<List<int>> _getContentsBinary(String path) {
  String url = chrome.runtime.getURL(path);

  return html.HttpRequest.request(url, responseType: 'arraybuffer').then((request) {
    typed_data.ByteBuffer buffer = request.response;
    return new typed_data.Uint8List.view(buffer);
  });
}

/**
 * This class represents the Dart SDK as build into Spark. It allows you to
 * query the SDK version and to get the contents of the included Dart libraries.
 */
class DartSdk extends SdkDirectory {
  String _version;
  List<int> _contents;
  SdkDirectory _libDirectory;

  /**
   * Create a return a [DartSdk]. Generally, an application will only have one
   * of these object's instantiated. They are however relatively lightweight
   * objects.
   */
  static Future<DartSdk> createSdk() {
    return _getContentsBinary('sdk/dart-sdk.bin').then((List<int> contents) {
      return new DartSdk._withContents(contents);
    }).catchError((e) {
      return new DartSdk._fromVersion('');
    });
  }

  String get version => _version;

  DartSdk get sdk => this;

  DartSdk._withContents(this._contents): super._(null, 'sdk') {
    _parseArchive();
  }

  DartSdk._fromVersion(this._version): super._(null, 'sdk') {
    _libDirectory = _getCreateDir('lib');
  }

  /**
   * Return the `sdk/lib` directory.
   */
  SdkDirectory get libDirectory => _libDirectory;

  /**
   * Return whether the Dart SDK is present.
   */
  bool get available => libDirectory != null;

  /**
   * Return the content for the file at the given path.
   */
  String getSourceForPath(String path) {
    List<String> paths = path.split('/');

    SdkDirectory dir = libDirectory;

    for (String p in paths.sublist(0, paths.length - 1)) {
      SdkEntity child = dir.getChild(p);

      if (child is SdkDirectory) {
        dir = child;
      } else {
        return null;
      }
    }

    SdkFile file = dir.getChild(paths.last);
    return file != null ? file.getContents() : null;
  }

  void _parseArchive() {
    _libDirectory = _getCreateDir('lib');

    _ByteReader reader = new _ByteReader(_contents);

    _version = reader.readUtf();
    int fileCount = reader.readInt();

    List<_ArchiveEntry> entries = [];

    for (int i = 0; i < fileCount; i++) {
      entries.add(new _ArchiveEntry(reader.readUtf(), reader.readInt()));
    }

    int fileContentStart = reader.pos;

    for (_ArchiveEntry entry in entries) {
      _libDirectory._createFile(entry.path, fileContentStart, entry.length);
      fileContentStart += entry.length;
    }
  }

  List<int> _getFileContents(int offset, int len) =>
      _contents.sublist(offset, offset + len);
}

/**
 * An abstract SDK entity; the parent class of [SdkFile] and [SdkDirectory].
 */
abstract class SdkEntity {
  /**
   * The full path of this entity (`sdk/lib/core/string.dart`).
   */
  final String path;

  /**
   * The parent of this entity.
   */
  final SdkDirectory parent;

  DartSdk get sdk => parent.sdk;

  SdkEntity._(this.parent, this.path);

  /**
   * The name of this entity (`string.dart`).
   */
  String get name {
    int index = path.lastIndexOf('/');
    return index == -1 ? path : path.substring(index + 1);
  }

  String toString() => name;
}

/**
 * An SDK file.
 */
class SdkFile extends SdkEntity {
  int _offset;
  int _length;

  SdkFile._(SdkDirectory parent, String path, this._offset, this._length):
    super._(parent, path);

  /**
   * Return the contents of this file.
   */
  String getContents() =>
      UTF8.decoder.convert(sdk._getFileContents(_offset, _length));
}

/**
 * An SDK directory entry.
 */
class SdkDirectory extends SdkEntity {
  List<SdkEntity> _children = [];

  SdkDirectory._(SdkDirectory parent, String path): super._(parent, path);

  /**
   * Return the given named child of this directory.
   */
  SdkEntity getChild(String name) {
    return _children.firstWhere((c) => c.name == name, orElse: () => null);
  }

  /**
   * Return the children of this directory.
   */
  List<SdkEntity> getChildren() => _children;

  SdkDirectory _getCreateDir(String name) {
    SdkDirectory dir = getChild(name);

    if (dir == null) {
      dir = new SdkDirectory._(this, name);
      _children.add(dir);
    }

    return dir;
  }

  SdkFile _createFile(String path, int offset, int length) {
    List<String> paths = path.split('/');

    SdkDirectory dir = this;

    for (String p in paths.sublist(0, paths.length - 1)) {
      dir = dir._getCreateDir(p);
    }

    SdkFile file = new SdkFile._(dir, paths.last, offset, length);
    dir._children.add(file);
    return file;
  }
}

class _ArchiveEntry {
  final String path;
  final int length;

  _ArchiveEntry(this.path, this.length);

  String toString() => '${path} ${length}';
}

/**
 * A class to simplify reading data from a byte array.
 */
class _ByteReader {
  List<int> _contents;
  int _pos = 0;

  _ByteReader(this._contents);

  int get pos => _pos;

  String readUtf() {
    int len = 0;

    // Assert that we don't read past the end of the archive - all utf strings
    // should be null-terminated.
    // TODO(devoncarew): Track down why this assert is failing.
    //assert(_contents.isNotEmpty && _contents.last == 0);

    while (_contents[_pos + len] != 0) {
      len++;
    }

    String str = UTF8.decoder.convert(_contents.sublist(_pos, _pos + len));
    _pos += len + 1;
    return str;
  }

  int readInt() {
    String str = readUtf();
    return str == null ? null : int.parse(str);
  }
}

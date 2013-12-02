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

import 'package:chrome_gen/chrome_app.dart' as chrome;

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
   * This temporary method will exists only as long as it takes to figure out a
   * good sync/async story with running the analyzer.
   */
  String getSourceForPath(String path) {
    List<String> paths = path.split('/');

    SdkDirectory dir = libDirectory;

    for (String p in paths.sublist(0, paths.length - 1)) {
      dir = dir._getCreateDir(p);

      if (dir == null) {
        return null;
      }
    }

    SdkFile file = dir.getChild(paths.last);
    return file != null ? file.getContents() : null;
  }

  void _parseArchive() {
    _libDirectory = _getCreateDir('lib');

    int pos = 0;
    int len = _utfLen(_contents, pos);
    _version = _readUtf(_contents, pos, len);
    pos += len + 1;
    int fileCount = _readInt(_contents, pos);
    pos += 4;

    List<_ArchiveEntry> entries = [];

    for (int i = 0; i < fileCount; i++) {
      len = _utfLen(_contents, pos);
      String path = _readUtf(_contents, pos, len);
      pos += len + 1;
      int fileLen = _readInt(_contents, pos);
      pos += 4;

      entries.add(new _ArchiveEntry(path, fileLen));
    }

    int fileContentStart =  pos;

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

int _readInt(List<int> _contents, int pos) {
  return _contents[pos] << 24 |
      _contents[pos + 1] << 16 |
      _contents[pos + 2] << 8 |
      _contents[pos + 3];
}

String _readUtf(List<int> _contents, int pos, int len) {
  return UTF8.decoder.convert(_contents.sublist(pos, pos + len));
}

int _utfLen(List<int> _contents, int pos) {
  int len = 0;

  while (_contents[pos + len] != 0) {
    len++;
  }

  return len;
}


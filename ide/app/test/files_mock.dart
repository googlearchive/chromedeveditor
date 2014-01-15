// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to mock out a DOM file system.
 */
library spark.files_mock;

import 'dart:async';
import 'dart:html';

import 'package:chrome/chrome_app.dart';
import 'package:mime/mime.dart' as mime;
import 'package:path/path.dart' as path;

export 'package:chrome/chrome_app.dart'
  show FileEntry, DirectoryEntry, ChromeFileEntry;

/**
 * A mutable, memory resident file system.
 */
class MockFileSystem implements FileSystem {
  final String name;
  _MockDirectoryEntry _root;

  MockFileSystem([this.name]) {
    _root = new _RootDirectoryEntry(this, 'root');
  }

  DirectoryEntry get root => _root;

  // Utility methods.

  FileEntry createFile(String filePath, {String contents}) {
    if (filePath.startsWith('/')) {
      filePath = filePath.substring(1);
    }

    String dirPath = path.dirname(filePath);
    String fileName = path.basename(filePath);

    if (dirPath == '.') {
      return _root._createFile(filePath, contents: contents);
    } else {
      _MockDirectoryEntry dir = createDirectory(dirPath);
      return dir._createFile(fileName, contents: contents);
    }
  }

  void removeFile(String filePath) {
    if (filePath.startsWith('/')) {
      filePath = filePath.substring(1);
    }

    String dirPath = path.dirname(filePath);
    String fileName = path.basename(filePath);

    if (dirPath == '.') {
      _root._removeFile(filePath);
    } else {
      _MockDirectoryEntry dir = getEntry(dirPath);
      if (dir is! DirectoryEntry) {
        return;
      }
      dir._removeFile(fileName);
    }
  }

  DirectoryEntry createDirectory(String filePath) {
    if (filePath.startsWith('/')) {
      filePath = filePath.substring(1);
    }

    String dirPath = path.dirname(filePath);
    String fileName = path.basename(filePath);

    if (dirPath == '.') {
      return _root._createDirectory(filePath);
    } else {
      _MockDirectoryEntry dir = createDirectory(dirPath);
      return dir._createDirectory(fileName);
    }
  }

  Entry getEntry(String path) {
    _MockEntry entry = _root;

    for (String name in path.split('/')) {
      entry = entry._getChild(name);

      if (entry == null) return null;
    }

    return entry;
  }
}

abstract class _MockEntry implements Entry {
  final String name;

  _MockDirectoryEntry _parent;
  DateTime _modificationTime = new DateTime.now();

  _MockEntry(this._parent, this.name);

  FileSystem get filesystem => _parent.filesystem;

  String get fullPath => _isRoot ? '/${name}' : '${_parent.fullPath}/${name}';

  // TODO:
  Future<Entry> copyTo(DirectoryEntry parent, {String name}) {
    throw new UnimplementedError('Entry.copyTo()');
  }

  Future<Metadata> getMetadata() => new Future.value(new _MockMetadata(this));

  Future<Entry> getParent() => new Future.value(_isRoot ? this : _parent);

  // TODO:
  Future<Entry> moveTo(DirectoryEntry parent, {String name}) {
    throw new UnimplementedError('Entry.moveTo()');
  }

  String toUrl() => 'mock:/${fullPath}';

  bool get _isRoot => filesystem.root == this;

  Entry _getChild(String name);

  _touch() => _modificationTime = new DateTime.now();

  String get _path => _parent == null ? '/${name}' : '${_parent._path}/${name}';

  int get _size;
}

class _MockFileEntry extends _MockEntry implements FileEntry, ChromeFileEntry {
  String _contents;
  List<int> _byteContents;

  _MockFileEntry(DirectoryEntry parent, String name): super(parent, name);

  bool get isDirectory => false;
  bool get isFile => true;

  Future remove() => _parent._remove(this);

  // TODO:
  Future<FileWriter> createWriter() {
    throw new UnimplementedError('FileEntry.createWriter()');
  }

  Future<File> file() => new Future.value(new _MockFile(this));

  // ChromeFileEntry specific methods

  Future<ArrayBuffer> readBytes() {
    if (_byteContents != null) {
      return new Future.value(new ArrayBuffer.fromBytes(_byteContents));
    } else if (_contents != null) {
      return new Future.value(new ArrayBuffer.fromString(_contents));
    } else {
      return new Future.value(new ArrayBuffer());
    }
  }

  Future<String> readText() {
    if (_contents != null) {
      return new Future.value(_contents);
    } else if (_byteContents != null) {
      return new Future.value(new String.fromCharCodes(_byteContents));
    } else {
      return new Future.value('');
    }
  }

  Future writeBytes(ArrayBuffer data) {
    _byteContents = data.getBytes();
    _contents = null;
    _touch();
    return new Future.value();
  }

  Future writeText(String text) {
    _contents = text;
    _byteContents = null;
    _touch();
    return new Future.value();
  }

  Entry _getChild(String name) => null;

  int get _size {
    if (_contents != null) return _contents.length;
    if (_byteContents != null) return _byteContents.length;
    return 0;
  }

  dynamic get jsProxy => null;
  dynamic toJs() => null;
}

class _MockDirectoryEntry extends _MockEntry implements DirectoryEntry {
  List<Entry> _children = [];

  _MockDirectoryEntry(DirectoryEntry parent, String name): super(parent, name);

  bool get isDirectory => true;
  bool get isFile => false;

  Future remove() {
    if (_isRoot && _children.isEmpty) {
      return new Future.error('illegal state');
    } else {
      return _parent._remove(this);
    }
  }

  Future _remove(Entry e) {
    _children.remove(e);
    _touch();
    return new Future.value();
  }

  Future<Entry> createDirectory(String path, {bool exclusive: false}) {
    if (_getChild(path) != null && exclusive) {
      return new Future.error('directory already exists');
    } else {
      return new Future.value(_createDirectory(path));
    }
  }

  Future<Entry> createFile(String path, {bool exclusive: false}) {
    if (_getChild(path) != null && exclusive) {
      return new Future.error('file already exists');
    } else {
      return new Future.value(_createFile(path));
    }
  }

  DirectoryReader createReader() => new _MockDirectoryReader(this);

  Future<Entry> getDirectory(String path) {
    Entry entry = _getChild(path);

    if (entry is! DirectoryEntry) {
      return new Future.error("directory doesn't exist");
    } else {
      return new Future.value(_createFile(path));
    }
  }

  Future<Entry> getFile(String path) {

    List<String> pathParts = path.split('/');
    Entry entry = _getChild(pathParts[0]);
    int i = 1;

    while (entry != null && entry.isDirectory && i < pathParts.length) {
      entry = (entry as _MockDirectoryEntry)._getChild(pathParts[i++]);
    }

    if (entry is! FileEntry) {
      return new Future.error("file doesn't exist");
    } else {
      return new Future.value(entry);
    }
  }

  Future removeRecursively() => _parent._remove(this);

  FileEntry _createFile(String name, {String contents}) {
    _MockFileEntry entry = _getChild(name);
    if (entry != null) return entry;

    _touch();

    entry = new _MockFileEntry(this, name);
    _children.add(entry);
    if (contents != null) {
      entry._contents = contents;
    }
    return entry;
  }

  DirectoryEntry _createDirectory(String name) {
    _MockDirectoryEntry entry = _getChild(name);
    if (entry != null) return entry;

    _touch();

    entry = new _MockDirectoryEntry(this, name);
    _children.add(entry);
    return entry;
  }

  Future<Entry> _removeFile(String name) {
    _MockFileEntry entry = _getChild(name);
    if (entry == null) {
      return new Future.value();
    }

    return _remove(entry);
  }

  Entry _getChild(String name) {
    for (Entry entry in _children) {
      if (entry.name == name) return entry;
    }

    return null;
  }

  int get _size => 0;
}

class _RootDirectoryEntry extends _MockDirectoryEntry {
  final FileSystem filesystem;

  _RootDirectoryEntry(this.filesystem, String name): super(null, name);
}

class _MockDirectoryReader implements DirectoryReader {
  _MockDirectoryEntry dir;

  _MockDirectoryReader(this.dir);

  Future<List<Entry>> readEntries() => new Future.value(dir._children);
}

class _MockMetadata implements Metadata {
  final _MockEntry entry;

  _MockMetadata(this.entry);

  DateTime get modificationTime => entry._modificationTime;

  int get size => entry._size;
}

abstract class _MockBlob implements Blob {
  int get size;
  Blob slice([int start, int end, String contentType]);
  String get type;
}

class _MockFile extends _MockBlob implements File {
  final _MockEntry entry;

  _MockFile(this.entry);

  DateTime get lastModifiedDate => entry._modificationTime;

  String get name => entry.name;

  String get relativePath => entry._path;

  int get size => entry._size;

  // TODO:
  Blob slice([int start, int end, String contentType]) {
    throw new UnimplementedError('Blob.slice()');
  }

  String get type {
    String _type = mime.lookupMimeType(name);
    return _type == null ? '' : _type;
  }
}

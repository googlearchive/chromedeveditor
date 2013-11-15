// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to mock out a DOM file system.
 */
library spark.files_mock;

import 'dart:async';

import 'package:chrome_gen/chrome_app.dart';

import '../lib/utils.dart';

export 'package:chrome_gen/chrome_app.dart'
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

  FileEntry createFile(String path, {String contents}) {
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    String dirPath = dirName(path);
    String fileName = baseName(path);

    if (dirPath == null) {
      return _root._createFile(path, contents: contents);
    } else {
      _MockDirectoryEntry dir = createDirectory(dirPath);
      return dir._createFile(fileName, contents: contents);
    }
  }

  DirectoryEntry createDirectory(String path) {
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    String dirPath = dirName(path);
    String fileName = baseName(path);

    if (dirPath == null) {
      return _root._createDirectory(path);
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

  _MockEntry(this._parent, this.name);

  FileSystem get filesystem => _parent.filesystem;

  String get fullPath => _isRoot ? '/${name}' : '${_parent.fullPath}/${name}';

  // TODO:
  Future<Entry> copyTo(DirectoryEntry parent, {String name}) {
    throw new UnimplementedError('Entry.copyTo()');
  }

  // TODO:
  Future<Metadata> getMetadata() {
    throw new UnimplementedError('Entry.getMetadata()');
  }

  Future<Entry> getParent() => new Future.value(_isRoot ? this : _parent);

  // TODO:
  Future<Entry> moveTo(DirectoryEntry parent, {String name}) {
    throw new UnimplementedError('Entry.moveTo()');
  }

  String toUrl() => 'mock:/${fullPath}';

  bool get _isRoot => filesystem.root == this;

  Entry _getChild(String name);
}

class _MockFileEntry extends _MockEntry implements FileEntry, ChromeFileEntry {
  String _contents;

  _MockFileEntry(DirectoryEntry parent, String name): super(parent, name);

  bool get isDirectory => false;
  bool get isFile => true;

  Future remove() => _parent._remove(this);

  // TODO:
  Future<FileWriter> createWriter() {
    throw new UnimplementedError('FileEntry.createWriter()');
  }

  // TDOO:
  Future<File> file() {
    throw new UnimplementedError('FileEntry.file()');
  }

  // ChromeFileEntry specific methods

  // TDOO:
  Future<ArrayBuffer> readBytes() {
    throw new UnimplementedError('FileEntry.readBytes()');
  }

  Future<String> readText() {
    return _contents == null ? new Future.value('') : new Future.value(_contents);
  }

  // TDOO:
  Future writeBytes(ArrayBuffer data) {
    throw new UnimplementedError('FileEntry.writeBytes()');
  }

  // TDOO:
  Future writeText(String text) {
    throw new UnimplementedError('FileEntry.writeText()');
  }

  Entry _getChild(String name) => null;

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
    return new Future.value();
  }

  // TDOO:
  Future<Entry> createDirectory(String path, {bool exclusive: false}) {
    throw new UnimplementedError('DirectoryEntry.createDirectory()');
  }

  // TDOO:
  Future<Entry> createFile(String path, {bool exclusive: false}) {
    throw new UnimplementedError('DirectoryEntry.createFile()');
  }

  // TDOO:
  DirectoryReader createReader() => new _MockDirectoryReader(this);

  // TDOO:
  Future<Entry> getDirectory(String path) {
    throw new UnimplementedError('DirectoryEntry.getDirectory()');
  }

  // TDOO:
  Future<Entry> getFile(String path) {
    throw new UnimplementedError('DirectoryEntry.getFile()');
  }

  // TDOO:
  Future removeRecursively() {
    throw new UnimplementedError('DirectoryEntry.removeRecursively()');
  }

  FileEntry _createFile(String name, {String contents}) {
    _MockFileEntry entry = _getChild(name);
    if (entry != null) return entry;

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

    entry = new _MockDirectoryEntry(this, name);
    _children.add(entry);
    return entry;
  }

  Entry _getChild(String name) {
    for (Entry entry in _children) {
      if (entry.name == name) return entry;
    }

    return null;
  }
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

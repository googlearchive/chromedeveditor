// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A resource workspace implementation.
 */
library spark.workspace;

import 'dart:async';

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;

import 'preferences.dart';

/**
 * The Workspace is a top-level entity that can contain files and projects. The
 * files that it contains are loose files; they do not have parent folders.
 */
class Workspace implements Container {
  Container _parent = null;
  chrome_gen.Entry _entry = null;

  List<Resource> _children = [];
  PreferenceStore _store;

  // TODO: perhaps move to returning a constructed Workspace via a static
  // method that returns a Future? see PicoServer

  Workspace(PreferenceStore preferenceStore) {
    this._store = preferenceStore;
  }

  String get name => null;

  Container get parent => null;

  Future<Resource> link(chrome_gen.Entry entity) {

    if (entity.isFile) {
      var resource = new File(this, entity);
      _children.add(resource);
      return new Future.value(resource);
    } else {
      var project = new Project(this, entity);
      _children.add(project);
      return _gatherChildren(project);
    }
  }

  void unlink(Resource resource) {
    // TODO: remove resource from list of children
  }

  List<Resource> getChildren() {
   return _children;
  }

  List<File> getFiles() {
    List list = [];
    for (var child in _children) {
      if (child is File) list.add(child);
    }
    return list;
  }

  List<Project> getProjects() {
    List list = [];
    for (var child in _children) {
      if (child is Project) list.add(child);
    }
    return list;
  }

  Project get project => null;

  Future save() {
    // TODO: save workspace information - maybe in preferences?

    return new Future.value();
  }

  Future<Resource> _gatherChildren(Container container) {
    chrome_gen.DirectoryEntry dir = container._entry;
    List futures = [];

    return dir.createReader().readEntries().then((entries) {
      for (chrome_gen.Entry ent in entries) {
        if (ent.isFile) {
          var file = new File(container, ent);
          container._children.add(file);
        } else {
          var folder = new Folder(container, ent);
          container._children.add(folder);
          futures.add(_gatherChildren(folder));
        }
      }
      return Future.wait(futures).then((_) => container);
    });
  }
}

abstract class Container extends Resource {
  List<Resource> _children = [];

  Container(Container parent, chrome_gen.Entry entry) : super(parent, entry);

  List<Resource> getChildren() => _children;
}

abstract class Resource {
  Container _parent;
  chrome_gen.Entry _entry;

  Resource(this._parent, this._entry);

  String get name => _entry.name;

  Container get parent => _parent;

  /**
   * Returns the containing [Project]. This can return null for loose files and
   * for the workspace.
   */
  Project get project => parent == null ? null : parent.project;
}

class Folder extends Container {
  Folder(Container parent, chrome_gen.Entry entry) : super(parent, entry);
}

class File extends Resource {
  File(Container parent, chrome_gen.Entry entry) : super(parent, entry);

  Future<String> getContents() => (_entry as chrome_gen.ChromeFileEntry).readText();

  Future setContents(String contents) => (_entry as chrome_gen.ChromeFileEntry).writeText(contents);
}

class Project extends Folder {
  Project(Container parent, chrome_gen.Entry entry) : super(parent, entry);

  Project get project => this;
}

// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A resource workspace implementation.
 */
library spark.workspace;

import 'dart:async';

import 'package:chrome/app.dart' as chrome;

import 'preferences.dart';

/**
 * The Workspace is a top-level entity that can contain files and projects. The
 * files that it contains are loose files; they do not have parent folders.
 */
class Workspace implements Container {
  Container _parent = null;
  chrome.Entry _entry = null;

  List<Resource> _children = [];
  PreferenceStore _store;

  Workspace(PreferenceStore preferenceStore) {
    this._store = preferenceStore;
  }

  String get name => null;

  Container get parent => null;

  Workspace initialize() {
    // TODO: initialize workspace with saved info from previous session
  }

  Resource link(chrome.Entry entity) {
    // TODO: create a resource for the entry and add it to list of children
  }

  void unlink(Resource resource) {
    // TODO: remove resource from list of children
  }

  List<Resource> getChildren() {
   return _children;
  }

  List<Project> getProjects() {
    // TODO: return list of projects in the workspace
  }

  List<File> getFiles() {
    // TODO: return list of loose files in the workspace
  }

  Project get project => null;

  void save() {
    // TODO: save workspace information - maybe in preferences?
  }
}

abstract class Container extends Resource {
  List<Resource> _children;

  Container(Container parent, chrome.Entry entry) : super(parent, entry);

  List<Resource> getChildren() => _children;
}

abstract class Resource {
  Container _parent;
  chrome.Entry _entry;

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
  Folder(Container parent, chrome.Entry entry) : super(parent, entry);
}

class File extends Resource {
  File(Container parent, chrome.Entry entry) : super(parent, entry);

  Future<String> getContents() {
    // TODO: read from entry
  }

  Future setContents(String contents) {
    // TODO: set contents of entry
  }
}

class Project extends Folder {
  Project(Container parent, chrome.Entry entry) : super(parent, entry);

  Project get project => this;
}

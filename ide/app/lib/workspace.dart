// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A resource workspace implementation.
 */
library spark.workspace;

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;
import 'package:logging/logging.dart';

import 'preferences.dart';

/**
 * The Workspace is a top-level entity that can contain files and projects. The
 * files that it contains are loose files; they do not have parent folders.
 */
class Workspace implements Container {

  Logger workspaceLogger = new Logger('spark.workspace');
  Container _parent = null;
  chrome_gen.Entry _entry = null;
  bool _syncable = false;

  List<Resource> _children = [];
  PreferenceStore _store;

  StreamController<ResourceChangeEvent> _streamController =
      new StreamController.broadcast();

  // TODO: perhaps move to returning a constructed Workspace via a static
  // method that returns a Future? see PicoServer
  Workspace(PreferenceStore preferenceStore) {
    this._store = preferenceStore;
  }

  String get name => null;

  Container get parent => null;

  Future<Resource> link(chrome_gen.Entry entity, bool syncable) {

    if (entity.isFile) {
      var resource = new File(this, entity, syncable);
      _children.add(resource);
      _streamController.add(new ResourceChangeEvent(resource, ResourceEventType.ADD));
      return new Future.value(resource);
    } else {
      var project = new Project(this, entity, syncable);
      _children.add(project);
      _streamController.add(new ResourceChangeEvent(project, ResourceEventType.ADD));
      return _gatherChildren(project, syncable);
    }
  }

  void unlink(Resource resource) {
    // TODO: remove resource from list of children and fire event
  }

  List<Resource> getChildren() =>_children;

  List<File> getFiles() => _children.where((c) => c is File).toList();

  List<Project> getProjects() => _children.where((c) => c is Project).toList();

  Stream<ResourceChangeEvent> get onResourceChange => _streamController.stream;

  Project get project => null;

  // read the workspace data from storage and restore entries
  Future restore() {
    return _store.getValue('workspace').then((s) {
      if (s == null) return null;

      try {
        List<String> ids = JSON.decode(s);
        return Future.forEach(ids, (id) {
          return chrome_gen.fileSystem.restoreEntry(id)
              .then((entry) => link(entry, false))
              .catchError((_) => null);
        });
      } catch (e) {
        workspaceLogger.log(Level.INFO, 'Exception in workspace restore', e);
        return new Future.error(e);
      }
    });
  }

  // store info for workspace children
  Future save() {
    List list = [];
    _children.forEach((c) {
      if (!c._syncable) list.add(chrome_gen.fileSystem.retainEntry(c._entry));
    });

    return _store.setValue('workspace', JSON.encode(list));
  }

  Future<Resource> _gatherChildren(Container container, bool syncable) {
    chrome_gen.DirectoryEntry dir = container._entry;
    List futures = [];

    return dir.createReader().readEntries().then((entries) {
      for (chrome_gen.Entry ent in entries) {
        if (ent.isFile) {
          var file = new File(container, ent, syncable);
          container._children.add(file);
        } else {
          var folder = new Folder(container, ent, syncable);
          container._children.add(folder);
          futures.add(_gatherChildren(folder, syncable));
        }
      }
      return Future.wait(futures).then((_) => container);
    });
  }
}

abstract class Container extends Resource {
  List<Resource> _children = [];

  Container(Container parent, chrome_gen.Entry entry, bool syncable) : super(parent, entry, syncable);

  List<Resource> getChildren() => _children;
}

abstract class Resource {
  Container _parent;
  chrome_gen.Entry _entry;
  bool _syncable;

  Resource(this._parent, this._entry, this._syncable);

  String get name => _entry.name;

  Container get parent => _parent;

  /**
   * Returns the containing [Project]. This can return null for loose files and
   * for the workspace.
   */
  Project get project => parent == null ? null : parent.project;
}

class Folder extends Container {
  Folder(Container parent, chrome_gen.Entry entry, bool syncable) : super(parent, entry, syncable);
}

class File extends Resource {
  File(Container parent, chrome_gen.Entry entry, bool syncable) : super(parent, entry, syncable);

  Future<String> getContents() => (_entry as chrome_gen.ChromeFileEntry).readText();

  // TODO: fire change event
  Future setContents(String contents) => (_entry as chrome_gen.ChromeFileEntry).writeText(contents);
}

class Project extends Folder {
  Project(Container parent, chrome_gen.Entry entry, bool syncable) : super(parent, entry, syncable);

  Project get project => this;
}

class ResourceEventType {
  final String name;

  const ResourceEventType._(this.name);

  /**
   * Event type indicates resource has been added to workspace.
   */
  static const ResourceEventType ADD = const ResourceEventType._('ADD');

  /**
   * Event type indicates resource has been removed from workspace.
   */
  static const ResourceEventType DELETE = const ResourceEventType._('DELETE');

  /**
   * Event type indicates resource has changed.
   */
  static const ResourceEventType CHANGE = const ResourceEventType._('CHANGE');

  String toString() => name;
}

/**
 * Used to indicate changes to the Workspace.
 */
class ResourceChangeEvent {
  final ResourceEventType type;
  final Resource resource;

  ResourceChangeEvent(this.resource, this.type);
}

// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A resource workspace implementation.
 */
library spark.workspace;

import 'dart:async';
import 'dart:convert' show JSON;

import 'package:chrome_gen/chrome_app.dart' as chrome;
import 'package:logging/logging.dart';

import 'preferences.dart';

/**
 * The Workspace is a top-level entity that can contain files and projects. The
 * files that it contains are loose files; they do not have parent folders.
 */
class Workspace implements Container {

  Logger _logger = new Logger('spark.workspace');
  Container _parent = null;
  chrome.Entry _entry = null;
  bool _syncable = false;

  List<Resource> _children = [];
  PreferenceStore _store;
  Completer<Workspace> _whenAvailable = new Completer();

  StreamController<ResourceChangeEvent> _controller =
      new StreamController.broadcast();

  // TODO: perhaps move to returning a constructed Workspace via a static
  // method that returns a Future? see PicoServer
  Workspace([this._store]);

  Future<Workspace> whenAvailable() => _whenAvailable.future;

  String get name => null;
  String get path => '';
  bool get isTopLevel => false;
  String persistToToken() => path;

  Future delete() => null;

  Container get parent => null;
  Project get project => null;
  Workspace get workspace => this;

  Future<Resource> link(chrome.Entry entity, {bool syncable: false}) {
    return _link(entity, syncable: syncable, fireEvent: true);
  }

  Future<Resource> _link(chrome.Entry entity, {bool syncable: false, bool fireEvent: true}) {
    if (entity.isFile) {
      var resource = new File(this, entity, syncable);
      _children.add(resource);
      if (fireEvent) {
        _controller.add(new ResourceChangeEvent(resource, ResourceEventType.ADD));
      }
      return new Future.value(resource);
    } else {
      var project = new Project(this, entity, syncable);
      _children.add(project);
      return _gatherChildren(project, syncable).then((container) {
        if (fireEvent) {
          _controller.add(new ResourceChangeEvent(container, ResourceEventType.ADD));
        }
        return container;
      });
    }
  }

  Future unlink(Resource resource) {
    if (!_children.contains(resource)) {
      throw new ArgumentError('${resource} is not a top level entity');
    }
    _removeChild(resource);
    return new Future.value();
  }

  /**
   * Moves all the [Resource] resources in the [List] to the given [Container] container.
   * Fires a [ResourceChangeEvent] event of type change [ResourceEventType.CHANGE]
   * after the moves are completed.
   */
  Future moveTo(List<Resource> resources, Container container) {
    var syncable = container._syncable;
    List futures = [];
    resources.forEach((resource) => futures.add(_moveTo(resource, container, syncable)));
    return Future.wait(futures).then((_) {
      _controller.add(new ResourceChangeEvent(container.project, ResourceEventType.CHANGE));
      return new Future.value();
    });
  }

  // Removes the given resource from parent, moves to the specifed container, and
  // adds it to the container's children.
  // syncable indicated whether the entry is in the sync file sytem.
  Future _moveTo(Resource resource, Container container, bool syncable) {
    chrome.Entry entry = resource._entry;
    return entry.moveTo(container._entry).then((newEntry) {
      resource.close(fireEvent: false);
      if (newEntry.isFile) {
        var file = new File(container, (newEntry as chrome.ChromeFileEntry), syncable);
        container._children.add(file);
        return new Future.value();
      } else {
        var folder = new Folder(container, newEntry, syncable);
        container._children.add(folder);
        return (_gatherChildren(folder, syncable));
      }
    });
  }

  Resource getChild(String name) {
    for (Resource resource in getChildren()) {
      if (resource.name == name) {
        return resource;
      }
    }
    return null;
  }

  Resource getChildPath(String childPath) {
    int index = childPath.indexOf('/');
    if (index == -1) {
      return getChild(childPath);
    } else {
      Resource child = getChild(childPath.substring(0, index));
      if (child is Container) {
        return child.getChildPath(childPath.substring(index + 1));
      } else {
        return null;
      }
    }
  }

  List<Resource> getChildren() =>_children;

  List<File> getFiles() => _children.where((c) => c is File).toList();

  List<Project> getProjects() => _children.where((c) => c is Project).toList();

  Stream<ResourceChangeEvent> get onResourceChange => _controller.stream;

  void _fireEvent(ResourceChangeEvent event) => _controller.add(event);

  // read the workspace data from storage and restore entries
  Future restore() {
    _store.getValue('workspace').then((s) {
      if (s == null) return null;

      try {
        List<String> ids = JSON.decode(s);
        Future.forEach(ids, (id) {
          return chrome.fileSystem.restoreEntry(id)
              .then((entry) => _link(entry, fireEvent: false))
              .catchError((_) => null);
        }).then((_) => _whenAvailable.complete(this));
      } catch (e) {
        _logger.log(Level.INFO, 'Exception in workspace restore', e);
        _whenAvailable.complete(this);
      }
    });

    return whenAvailable();
  }

  // store info for workspace children
  Future save() {
    List list = [];
    _children.forEach((c) {
      if (!c._syncable) list.add(chrome.fileSystem.retainEntry(c._entry));
    });

    return _store.setValue('workspace', JSON.encode(list));
  }

  Resource restoreResource(String token) {
    if (token == '') return this;
    if (!token.startsWith('/')) return null;

    return getChildPath(token.substring(1));
  }

  Future<Resource> _gatherChildren(Container container, bool syncable) {
    chrome.DirectoryEntry dir = container._entry;
    List futures = [];

    return dir.createReader().readEntries().then((entries) {
      for (chrome.Entry ent in entries) {
        if (ent.isFile) {
          var file = new File(container, ent, syncable);
          container._children.add(file);
        } else {
          // We don't want to show .git folders to the user.
          if (ent.name == '.git') {
            continue;
          }
          var folder = new Folder(container, ent, syncable);
          container._children.add(folder);
          futures.add(_gatherChildren(folder, syncable));
        }
      }
      return Future.wait(futures).then((_) => container);
    });
  }

 void _removeChild(Resource resource, {bool fireEvent: true}) {
   _children.remove(resource);
   if (fireEvent) _fireEvent(new ResourceChangeEvent(resource, ResourceEventType.DELETE));
  }

 Future close({bool fireEvent: true}) => new Future.value();

}

abstract class Container extends Resource {
  List<Resource> _children = [];

  Container(Container parent, chrome.Entry entry, bool syncable) : super(parent, entry, syncable);

  Resource getChild(String name) {
    for (Resource resource in getChildren()) {
      if (resource.name == name) {
        return resource;
      }
    }

    return null;
  }

  Resource getChildPath(String childPath) {
    int index = childPath.indexOf('/');
    if (index == -1) {
      return getChild(childPath);
    } else {
      Resource child = getChild(childPath.substring(0, index));
      if (child is Container) {
        return child.getChildPath(childPath.substring(index + 1));
      } else {
        return null;
      }
    }
  }

  void _fireEvent(ResourceChangeEvent event) => _parent._fireEvent(event);

  void _removeChild(Resource resource, {bool fireEvent: true}) {
    _children.remove(resource);
    if (fireEvent) _fireEvent(new ResourceChangeEvent(resource, ResourceEventType.DELETE));
  }

  List<Resource> getChildren() => _children;

}

abstract class Resource {
  Container _parent;
  chrome.Entry _entry;
  bool _syncable;

  Resource(this._parent, this._entry, this._syncable);

  String get name => _entry.name;

  /**
   * Return the path to this element from the workspace. Paths are not
   * guarenteed to be unique.
   */
  String get path => '${parent.path}/${name}';

  bool get isTopLevel => _parent is Workspace;

  /**
   * Return a token that can be later used to deserialize this [Resource]. This
   * is an opaque token.
   */
  String persistToToken() => path;

  Container get parent => _parent;

  Future delete() {
    if (_entry.isFile) return _entry.remove().then((_) => _parent._removeChild(this));

    return (_entry as chrome.DirectoryEntry).removeRecursively().then((_) => _parent._removeChild(this));
  }

  Future close({bool fireEvent: true}) {
    _parent._removeChild(this, fireEvent: fireEvent);
    return new Future.value();
  }

  /**
   * Returns the containing [Project]. This can return null for loose files and
   * for the workspace.
   */
  Project get project => parent is Project ? parent : parent.project;

  Workspace get workspace => parent.workspace;

  String toString() => '${this.runtimeType} ${name}';
}

class Folder extends Container {
  Folder(Container parent, chrome.Entry entry, bool syncable):
    super(parent, entry, syncable);

  /**
   * Creates a new [File] with the given name
   */
  Future<File> createNewFile(String name) {
    return (_entry as chrome.DirectoryEntry).createFile(name).then((entry) {
      File file = new File(this, entry, _syncable);
      _children.add(file);
      _fireEvent(new ResourceChangeEvent(file, ResourceEventType.ADD));
      return file;
    });
  }

}

class File extends Resource {
  File(Container parent, chrome.Entry entry, bool syncable):
    super(parent, entry, syncable);

  Future<String> getContents() => (_entry as chrome.ChromeFileEntry).readText();

  Future<chrome.ArrayBuffer> getBytes() => (_entry as chrome.ChromeFileEntry).readBytes();

  Future setContents(String contents) {
    (_entry as chrome.ChromeFileEntry).writeText(contents).then((_) {
      workspace._fireEvent(new ResourceChangeEvent(this, ResourceEventType.CHANGE));
    });
  }
}

class Project extends Folder {
  Project(Container parent, chrome.Entry entry, bool syncable):
    super(parent, entry, syncable);

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

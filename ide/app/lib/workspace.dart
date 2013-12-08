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
 * files that it contains are loose files; they do not have parent projects.
 */
class Workspace implements Container {
  Logger _logger = new Logger('spark.workspace');
  Container _parent = null;

  chrome.Entry get _entry => null;
  set _entry(chrome.Entry value) => null;
  chrome.Entry get entry => null;

  bool get _syncable => false;

  List<Resource> _children = [];
  PreferenceStore _store;
  Completer<Workspace> _whenAvailable = new Completer();

  StreamController<ResourceChangeEvent> _controller =
      new StreamController.broadcast();

  Workspace([this._store]);

  Future<Workspace> whenAvailable() => _whenAvailable.future;

  String get name => null;
  String get path => '';
  bool get isTopLevel => false;
  String persistToToken() => path;

  Future delete() => new Future.value();
  Future rename(String name) => new Future.value();

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

  void unlink(Resource resource) {
    if (!_children.contains(resource)) {
      throw new ArgumentError('${resource} is not a top level entity');
    }
    _removeChild(resource);
  }

  // TODO: this should fire adds and deletes, not change events
  /**
   * Moves all the [Resource] resources in the [List] to the given [Container]
   * container. Fires a [ResourceChangeEvent] event of type change
   * [ResourceEventType.CHANGE] after the moves are completed.
   */
  Future moveTo(List<Resource> resources, Container container) {
    List futures = resources.map((r) => _moveTo(r, container, container._syncable));
    return Future.wait(futures).then((_) {
      _controller.add(new ResourceChangeEvent(container, ResourceEventType.CHANGE));
    });
  }

  /**
   * Removes the given resource from parent, moves to the specifed container,
   * and adds it to the container's children. [syncable] indicates whether the
   * entry is in the sync file sytem.
   */
  Future _moveTo(Resource resource, Container container, bool syncable) {
    return resource.entry.moveTo(container.entry).then((chrome.Entry newEntry) {
      resource.parent._removeChild(resource, fireEvent: false);

      if (newEntry.isFile) {
        var file = new File(container, newEntry, syncable);
        container._children.add(file);
        return new Future.value();
      } else {
        var folder = new Folder(container, newEntry, syncable);
        container._children.add(folder);
        return _gatherChildren(folder, syncable);
      }
    });
  }

  Resource getChild(String name) {
    return getChildren().firstWhere((c) => c.name == name, orElse: () => null);
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

  List<Resource> getChildren() => _children;

  List<File> getFiles() => _children.where((c) => c is File).toList();

  List<Project> getProjects() => _children.where((c) => c is Project).toList();

  Stream<ResourceChangeEvent> get onResourceChange => _controller.stream;

  void _fireEvent(ResourceChangeEvent event) => _controller.add(event);

  /**
   * Read the workspace data from storage and restore entries.
   */
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

  /**
   * Store info for workspace children.
   */
  Future save() {
    List<String> entries = _children.where((c) => c._syncable).map(
        (c) => chrome.fileSystem.retainEntry(c.entry)).toList();

    return _store.setValue('workspace', JSON.encode(entries));
  }

  Resource restoreResource(String token) {
    if (token == '') return this;
    if (!token.startsWith('/')) return null;

    return getChildPath(token.substring(1));
  }

  Future<Resource> _gatherChildren(Container container, bool syncable) {
    chrome.DirectoryEntry dir = container.entry;
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
   if (fireEvent) {
     _fireEvent(new ResourceChangeEvent(resource, ResourceEventType.DELETE));
   }
  }
}

abstract class Container extends Resource {
  List<Resource> _children = [];

  Container(Container parent, chrome.Entry entry, bool syncable):
    super(parent, entry, syncable);

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

  void _removeChild(Resource resource, {bool fireEvent: true}) {
    _children.remove(resource);
    if (fireEvent) {
      _fireEvent(new ResourceChangeEvent(resource, ResourceEventType.DELETE));
    }
  }

  List<Resource> getChildren() => _children;
}

abstract class Resource {
  Container _parent;
  chrome.Entry _entry;
  final bool _syncable;

  Resource(this._parent, this._entry, this._syncable);

  String get name => _entry.name;

  chrome.Entry get entry => _entry;

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

  void _fireEvent(ResourceChangeEvent event) => _parent._fireEvent(event);

  Future delete();

  // TODO: This should instead fire a delete and add event. From the POV of
  // analysis, this is a new file, not changed content.
  Future rename(String name) {
    return entry.moveTo(_parent._entry, name: name).then((chrome.Entry e) {
      _entry = e;
      _fireEvent(new ResourceChangeEvent(_parent, ResourceEventType.CHANGE));
    });
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
    return _dirEntry.createFile(name).then((entry) {
      File file = new File(this, entry, _syncable);
      _children.add(file);
      _fireEvent(new ResourceChangeEvent(file, ResourceEventType.ADD));
      return file;
    });
  }

  Future delete() {
    return _dirEntry.removeRecursively().then((_) => _parent._removeChild(this));
  }

  chrome.DirectoryEntry get _dirEntry => entry;
}

class File extends Resource {
  File(Container parent, chrome.Entry entry, bool syncable):
    super(parent, entry, syncable);

  Future<String> getContents() => _fileEntry.readText();

  Future<chrome.ArrayBuffer> getBytes() => _fileEntry.readBytes();

  Future setContents(String contents) {
    return _fileEntry.writeText(contents).then((_) {
      workspace._fireEvent(new ResourceChangeEvent(this,
          ResourceEventType.CHANGE));
    });
  }

  Future delete() {
    return _fileEntry.remove().then((_) => _parent._removeChild(this));
  }

  Future setBytes(List<int> data) {
    chrome.ArrayBuffer bytes = new chrome.ArrayBuffer.fromBytes(data);
    return _fileEntry.writeBytes(bytes).then((_) {
      workspace._fireEvent(new ResourceChangeEvent(this,
          ResourceEventType.CHANGE));
    });
  }

  chrome.ChromeFileEntry get _fileEntry => entry;
}

/**
 * The top-level container resource for the workspace. Only [File]s and
 * [Projects]s can be immediate child elements of a [Workspace].
 */
class Project extends Folder {
  Project(Container parent, chrome.Entry entry, bool syncable):
    super(parent, entry, syncable);

  Project get project => this;
}

/**
 * An enum of the valid [ResourceChangeEvent] types.
 */
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

  String toString() => '${type}: ${resource}';
}

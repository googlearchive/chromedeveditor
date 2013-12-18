// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A resource workspace implementation.
 */
library spark.workspace;

import 'dart:async';
import 'dart:collection';
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

  List<Resource> _localChildren = [];
  List<Resource> _syncChildren = [];
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

  /**
   * Adds a chrome entry and its children to the workspace.
   * [syncable] indicates whether the entry is in the sync file sytem.
   */
  Future<Resource> link(chrome.Entry entity, {bool syncable: false}) {
    return _link(entity, syncable: syncable, fireEvent: true);
  }

  Future<Resource> _link(chrome.Entry entity, {bool syncable: false, bool fireEvent: true}) {
    if (entity.isFile) {
      var resource = new File(this, entity);
      if (syncable) {
        _syncChildren.add(resource);
      } else {
        _localChildren.add(resource);
      }
      if (fireEvent) {
        _controller.add(
            new ResourceChangeEvent.fromSingle(new ChangeDelta(resource, ResourceEventType.ADD)));
      }
      return new Future.value(resource);
    } else {
      var project = new Project(this, entity);
      if (syncable) {
        _syncChildren.add(project);
      } else {
        _localChildren.add(project);
      }
      return _gatherChildren(project).then((container) {
        if (fireEvent) {
          _controller.add(
              new ResourceChangeEvent.fromSingle(new ChangeDelta(container, ResourceEventType.ADD)));
        }
        return container;
      });
    }
  }

  void unlink(Resource resource) {
    if (!_localChildren.contains(resource) && !_syncChildren.contains(resource)) {
      throw new ArgumentError('${resource} is not a top level entity');
    }
    _removeChild(resource);
  }

  /**
   * Moves all the [Resource] resources in the [List] to the given [Container]
   * container. Fires a list of [ResourceChangeEvent] events with deletes and
   * adds for the resources after the moves are completed.
   */
  Future moveTo(List<Resource> resources, Container container) {
    List futures = resources.map((r) => _moveTo(r, container));
    return Future.wait(futures).then((events) {
      List<ChangeDelta> list = [];
      resources.forEach((r) => list.add(new ChangeDelta(r, ResourceEventType.DELETE)));
      list.addAll(events);
      _controller.add(new ResourceChangeEvent.fromList(list));
    });
  }

  /**
   * Removes the given resource from parent, moves to the specifed container,
   * and adds it to the container's children.
   */
  Future _moveTo(Resource resource, Container container) {
    return resource.entry.moveTo(container.entry).then((chrome.Entry newEntry) {
      resource.parent._removeChild(resource, fireEvent: false);

      if (newEntry.isFile) {
        var file = new File(container, newEntry);
        container._localChildren.add(file);
        return new Future.value(new ChangeDelta(file, ResourceEventType.ADD));
      } else {
        var folder = new Folder(container, newEntry);
        container._localChildren.add(folder);
        return _gatherChildren(folder).then((_) => new ChangeDelta(folder, ResourceEventType.ADD));
      }
    });
  }

  bool isSyncResource(Resource resource) => _syncChildren.contains(resource);

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

  List<Resource> getChildren() => _localChildren;

  List<File> getFiles() => _localChildren.where((c) => c is File).toList();

  List<Project> getProjects() => _localChildren.where((c) => c is Project).toList();

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
    List<String> entries = _localChildren.map(
        (c) => chrome.fileSystem.retainEntry(c.entry)).toList();

    return _store.setValue('workspace', JSON.encode(entries));
  }

  Resource restoreResource(String token) {
    if (token == '') return this;
    if (!token.startsWith('/')) return null;

    return getChildPath(token.substring(1));
  }

  Future<Resource> _gatherChildren(Container container) {
    chrome.DirectoryEntry dir = container.entry;
    List futures = [];

    return dir.createReader().readEntries().then((entries) {
      for (chrome.Entry ent in entries) {
        if (ent.isFile) {
          var file = new File(container, ent);
          container._localChildren.add(file);
        } else {
          // We don't want to show .git folders to the user.
          if (ent.name == '.git') {
            continue;
          }
          var folder = new Folder(container, ent);
          container._localChildren.add(folder);
          futures.add(_gatherChildren(folder));
        }
      }
      return Future.wait(futures).then((_) => container);
    });
  }

  /**
   * Updates the content of the workspace with what's on the filesystem.
   */
  Future _reloadContents() {
    List futures = [];
    for(Project resource in getChildren()) {
      if (resource is Project) {
        // We use a temporary project to fill the children...
        Project tmpProject =
            new Project(this, resource.entry);
        Future future =
            _gatherChildren(tmpProject).then((container) {
          // Then, we are able to replace the children in one atomic operation.
          // It helps make the UI more stable visually.
          // TODO(dvh): indentity of objects needs to be preserved.
          resource._localChildren = tmpProject._localChildren;
          tmpProject._localChildren = [];
          _controller.add(new ResourceChangeEvent.fromSingle(
                new ChangeDelta(resource, ResourceEventType.CHANGE)));
          return container;
        });
        futures.add(future);
      }
    }
    return Future.wait(futures);
  }

  /**
   * This method checks if the layout of files on the filesystem has changed
   * and will update the content of the workspace if needed.
   */
  Future refresh() {
    Set<String> existing = new Set();
    _fillSetWithResource(existing, this);
    Set<String> current = new Set();
    List futures = [];
    for(Resource resource in getChildren()) {
      futures.add(_gatherPaths(current, resource.entry));
    }
    return Future.wait(futures).then((e) {
      Set<String> union = new Set();
      union.addAll(current);
      union.addAll(existing);
      // We compare the list of paths.
      if (union.length != current.length ||
          current.length != existing.length) {
        return _reloadContents();
      } else {
        return new Future.value();
      }
    });
  }

  /**
   * Collect the list of paths (and subpaths for the given entry) as strings
   * in a Set.
   */
  Future _gatherPaths(Set<String> paths, chrome.Entry entry) {
    paths.add(entry.fullPath);
    if (entry is chrome.DirectoryEntry) {
      return entry.createReader().readEntries().then((entries) {
        List futures = [];
        for (chrome.Entry ent in entries) {
          if (ent.name == '.git') {
            continue;
          }
          futures.add(_gatherPaths(paths, ent));
        }
        return Future.wait(futures);
      });
    } else {
      return new Future.value();
    }
  }

  /**
   * Collect the list of paths (and subpaths for the given resource) as strings
   * in a Set.
   */
  void _fillSetWithResource(Set<String> paths, Resource resource) {
    if (resource is! Workspace) {
      paths.add(resource.path);
    }
    if (resource is Container) {
      resource.getChildren().forEach((Resource child) {
        _fillSetWithResource(paths, child);
      });
    }
  }

  void _removeChild(Resource resource, {bool fireEvent: true}) {
    if (_localChildren.contains(resource)) {
      _localChildren.remove(resource);
    } else {
      _syncChildren.remove(resource);
    }
   if (fireEvent) {
     _fireEvent(new ResourceChangeEvent.fromSingle(
         new ChangeDelta(resource, ResourceEventType.DELETE)));
   }
  }
}

abstract class Container extends Resource {
  List<Resource> _localChildren = [];

  Container(Container parent, chrome.Entry entry):
    super(parent, entry);

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
    _localChildren.remove(resource);
    if (fireEvent) {
      _fireEvent(new ResourceChangeEvent.fromSingle(
          new ChangeDelta(resource, ResourceEventType.DELETE)));
    }
  }

  List<Resource> getChildren() => _localChildren;
}

abstract class Resource {
  Container _parent;
  chrome.Entry _entry;

  Resource(this._parent, this._entry);

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

  Future rename(String name) {
    return entry.moveTo(_parent._entry, name: name).then((chrome.Entry e) {
      List<ChangeDelta> list = [];
      list.add(new ChangeDelta(this, ResourceEventType.DELETE));
      _entry = e;
      list.add(new ChangeDelta(this, ResourceEventType.ADD));
      _fireEvent(new ResourceChangeEvent.fromList(list));
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
  Folder(Container parent, chrome.Entry entry):
    super(parent, entry);

  /**
   * Creates a new [File] with the given name
   */
  Future<File> createNewFile(String name) {
    return _dirEntry.createFile(name).then((entry) {
      File file = new File(this, entry);
      _localChildren.add(file);
      _fireEvent(new ResourceChangeEvent.fromSingle(
          new ChangeDelta(file, ResourceEventType.ADD)));
      return file;
    });
  }

  Future<Folder> createNewFolder(String name) {
    return _dirEntry.createDirectory(name).then((entry) {
      Folder folder = new Folder(this, entry);
      _localChildren.add(folder);
      _fireEvent(new ResourceChangeEvent.fromSingle(
          new ChangeDelta(folder, ResourceEventType.ADD)));
      return folder;
    });
  }

  Future delete() {
    return _dirEntry.removeRecursively().then((_) => _parent._removeChild(this));
  }

  chrome.DirectoryEntry get _dirEntry => entry;
}

class File extends Resource {
  File(Container parent, chrome.Entry entry):
    super(parent, entry);

  Future<String> getContents() => _fileEntry.readText();

  Future<chrome.ArrayBuffer> getBytes() => _fileEntry.readBytes();

  Future setContents(String contents) {
    return _fileEntry.writeText(contents).then((_) {
      workspace._fireEvent(new ResourceChangeEvent.fromSingle(
          new ChangeDelta(this, ResourceEventType.CHANGE)));
    });
  }

  Future delete() {
    return _fileEntry.remove().then((_) => _parent._removeChild(this));
  }

  Future setBytes(List<int> data) {
    chrome.ArrayBuffer bytes = new chrome.ArrayBuffer.fromBytes(data);
    return _fileEntry.writeBytes(bytes).then((_) {
      workspace._fireEvent(new ResourceChangeEvent.fromSingle(
          new ChangeDelta(this, ResourceEventType.CHANGE)));
    });
  }

  chrome.ChromeFileEntry get _fileEntry => entry;
}

/**
 * The top-level container resource for the workspace. Only [File]s and
 * [Projects]s can be immediate child elements of a [Workspace].
 */
class Project extends Folder {
  Project(Container parent, chrome.Entry entry):
    super(parent, entry);

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
  final List<ChangeDelta> changes;

  factory ResourceChangeEvent.fromSingle(ChangeDelta delta) {
   return new ResourceChangeEvent._([delta]);
  }

  factory ResourceChangeEvent.fromList(List<ChangeDelta> deltas) {
    return new ResourceChangeEvent._(deltas.toList());
  }

  ResourceChangeEvent._(List<ChangeDelta> delta): changes = new UnmodifiableListView(delta);
}

/**
 * Indicates a change on a particular resource
 */
class ChangeDelta {
  final Resource resource;
  final ResourceEventType type;

  ChangeDelta(this.resource, this.type);

  String toString() => '${type}: ${resource}';
}

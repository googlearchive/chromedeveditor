// A resource workspace implementation.

library spark.workspace;

import 'preferences.dart';

import 'package:chrome/app.dart' as chrome;

/**
 * The Workspave is a top-level entity that can contain files and folders.
 * The files that it contains are loose files; they do not have parent folders.
 * The folders it contains are all top-level folders/projects.
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

  Folder get topLevelFolder => null;

  void save(){
    // TODO: save workspace information - maybe in preferences?
  }
}

abstract class Container extends Resource {
  List<Resource> _children;

  Container(Container parent, chrome.Entry entry) : super(parent, entry);

  List<Resource> getChildren() {
      return _children;
  }
}

abstract class Resource {
  Container _parent;
  chrome.Entry _entry;

  Resource(this._parent, this._entry);

  String get name => _entry.name;

  Container get parent => _parent;

  /**
   * Returns the top-level folder. This can return null for loose files.
   */
  Folder get topLevelFolder {}

}


class Folder extends Container {

  Folder(Container parent, chrome.Entry entry) : super(parent, entry);

  bool get isTopLevel => parent is Workspace;

}


class File extends Resource {

  File(Container parent, chrome.Entry entry) : super(parent, entry);

}


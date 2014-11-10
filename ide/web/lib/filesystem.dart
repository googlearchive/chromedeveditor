// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.filesystem;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

import 'dependency.dart';
import 'files_mock.dart';
import 'preferences.dart';
import 'spark_flags.dart';
import 'utils.dart';
import 'workspace.dart' as ws;

FileSystemAccess _fileSystemAccess;

/**
 * Sets the used FileSystemAccess class, allowing overriding versions of the
 * filesystem
 */
void setMockFilesystemAccess() {
  assert(_fileSystemAccess == null || _fileSystemAccess.root == null);
  _fileSystemAccess = new MockFileSystemAccess();
}

/**
 * Returns the current FilesystemAccess
 */
FileSystemAccess get fileSystemAccess {
  if (_fileSystemAccess == null) {
    _fileSystemAccess = new FileSystemAccess._();
  }

  return _fileSystemAccess;
}

/**
 * Restores the ProjectLocationManager and returns a future with its value.
 */
Future<ProjectLocationManager> restoreManager([PreferenceStore localPrefs]) {
  if (localPrefs == null) {
    localPrefs = Dependencies.dependency[PreferenceStore];
  }

  return localPrefs.getValue('projectFolder').then((String folderToken) {
    return fileSystemAccess.restoreManager(localPrefs, folderToken);
  });
}

/**
 * Provides abstracted access to all filesystem functions.
 */
class FileSystemAccess {
  ProjectLocationManager _locationManager;

  /**
   * The ProjectLocationManager (default location to create new projects) if one
   * has been chosen.
   */
  ProjectLocationManager get locationManager => _locationManager;

  LocationResult _location;

  ws.WorkspaceRoot _root;

  /**
   * The root where all projects are held
   */
  ws.WorkspaceRoot get root {
    if (_root == null) {
      if (_location != null) {
        _root = getRootFor(_location);
      }
    }

    return _root;
  }

  FileSystemAccess._();

  /**
   * Returns the full display path for an entry.
   */
  Future<String> getDisplayPath(chrome.Entry entry) {
    return chrome.fileSystem.getDisplayPath(entry);
  }

  /**
   * Restores the ProjectLocationManager and returns a future with its value,
   * based on a folder token.
   */
  Future<ProjectLocationManager> restoreManager(PreferenceStore prefs,
      String folderToken) {
    return ProjectLocationManager.restoreManager(prefs, folderToken)
        .then((ProjectLocationManager manager) {
      _locationManager = manager;
      return manager;
    });
  }

  /**
   * Creates a root for the given LocationResult.
   */
  ws.WorkspaceRoot getRootFor(LocationResult location) {
    if (location.isSync) {
      return new ws.SyncFolderRoot(location.entry);
    } else {
      return new ws.FolderChildRoot(location.parent, location.entry);
    }
  }

  /**
   * Returns the default location to create new projects in. For Chrome OS, this
   * will be the sync filesystem. This method can return `null` if the user
   * cancels the folder selection dialog.
   */
  Future<LocationResult> getProjectLocation([bool chooseIfNone = true]) =>
      locationManager.getProjectLocation(chooseIfNone);

  /**
   * This will create a new folder in default project location. It will attempt
   * to use the given [defaultName], but will disambiguate it if necessary. For
   * example, if `defaultName` already exists, the created folder might be named
   * something like `defaultName-1` instead.
   */
  Future<LocationResult> createNewFolder(String name) => locationManager.createNewFolder(name);

  /**
   * Opens a pop up and asks the user to change the root directory. Internally,
   * the stored value is changed here.
   */
  Future<LocationResult> chooseNewProjectLocation(bool showFileSystemDialog) =>
      locationManager.chooseNewProjectLocation(showFileSystemDialog);
}

class MockFileSystemAccess extends FileSystemAccess {
  MockProjectLocationManager _locationManager;
  MockProjectLocationManager get locationManager => _locationManager;

  WorkspaceRoot _root;
  WorkspaceRoot get root {
    if (_root == null) {
      _root = new MockWorkspaceRoot(_location.entry);
    }

    return _root;
  }

  MockFileSystemAccess() : super._() {
    MockFileSystem fs = new MockFileSystem();
    DirectoryEntry rootParent = fs.createDirectory("rootParent");

    rootParent.createDirectory("root").then((DirectoryEntry root) {
      _location = new LocationResult(rootParent, root, false);
    });
  }

  Future<String> getDisplayPath(chrome.Entry entry) {
    return new Future.value(entry.fullPath);
  }

  Future<ProjectLocationManager> restoreManager(
      PreferenceStore prefs, String folderToken) {
    return MockProjectLocationManager.restoreManager(prefs).then(
        (ProjectLocationManager manager) {
      _locationManager = manager;
      return manager;
    });
  }

  ws.WorkspaceRoot getRootFor(LocationResult location) {
    return new MockWorkspaceRoot(location.entry);
  }
}

/**
 * Used to manage the default location to create new projects.
 *
 * This class also abstracts a bit other the differences between Chrome OS and
 * Windows/Mac/linux.
 */
class ProjectLocationManager {
  final PreferenceStore prefs;
  LocationResult _projectLocation;

  /**
   * Create a ProjectLocationManager asynchronously, restoring the default
   * project location from the given preferences.
   */
  static Future<ProjectLocationManager> restoreManager(
      PreferenceStore prefs, String folderToken) {

    // If there is nothing to restore, create a new ProjectLocationManager.
    if (folderToken == null) {
      return new Future.value(new ProjectLocationManager._(prefs));
    }

    return chrome.fileSystem.restoreEntry(folderToken).then((chrome.Entry entry) {
      return _initFlagsFromProjectLocation(entry).then((_) {
        return new Future.value(new ProjectLocationManager._(
            prefs, new LocationResult(entry, entry, false)));
      });
    }).catchError((e) {
      return new Future.value(new ProjectLocationManager._(prefs));
    });
  }

  /**
   * Try to read and set the highest precedence developer flags from
   * "<project_location>/.spark.json".
   */
  static Future _initFlagsFromProjectLocation(chrome.DirectoryEntry projDir) {
    return projDir.getFile('.spark.json').then(
        (chrome.ChromeFileEntry flagsFile) {
      return SparkFlags.initFromFile(flagsFile.readText());
    }).catchError((_) {
      // Ignore missing file.
      return new Future.value();
    });
  }

  ProjectLocationManager._(this.prefs, [this._projectLocation]);

  /**
   * Returns the default location to create new projects in. For Chrome OS, this
   * will be the sync filesystem. This method can return `null` if the user
   * cancels the folder selection dialog.
   */
  Future<LocationResult> getProjectLocation([bool chooseIfNone = true]) {
    if (_projectLocation != null) {
      // Check if the saved location exists. If so, return it. Otherwise, get a
      // new location.
      return _projectLocation.exists().then((bool value) {
        if (value) {
          return _projectLocation;
        } else {
          _projectLocation = null;
          return getProjectLocation();
        }
      });
    }

    // On Chrome OS, use the sync filesystem.
    // TODO(grv): Enable syncfs once the api is more stable.
    /*if (PlatformInfo.isCros && _spark.workspace.syncFsIsAvailable) {
      return chrome.syncFileSystem.requestFileSystem().then((fs) {
        var entry = fs.root;
        return new LocationResult(entry, entry, true);
      });
    }*/

    if (chooseIfNone) {
      // Show a dialog with explaination about what this folder is for.
      return chooseNewProjectLocation(true);
    } else {
      return new Future.value(null);
    }
  }

  /**
   * Opens a pop up and asks the user to change the root directory. Internally,
   * the stored value is changed here.
   */
  Future<LocationResult> chooseNewProjectLocation(bool showFileSystemDialog) {
    // Show a dialog with explaination about what this folder is for.
    if (showFileSystemDialog) {
      return _showRequestFileSystemDialog().then((bool accepted) {
        if (!accepted) {
          return null;
        }
        return _selectFolderDialog();
      });
    } else {
      return _selectFolderDialog();
    }
  }

  Future<LocationResult> _selectFolderDialog() {
    // Display a dialog asking the user to choose a default project folder.
    return _selectFolder(suggestedName: 'projects').then((entry) {
      if (entry == null) return null;

      _projectLocation = new LocationResult(entry, entry, false);
      prefs.setValue('projectFolder', chrome.fileSystem.retainEntry(entry));
      return _projectLocation;
    });
  }

  Future<bool> _showRequestFileSystemDialog() {
    Notifier notifier = Dependencies.dependency[Notifier];

    return notifier.askUserOkCancel(
        'Please choose a folder to store your Chrome Dev Editor projects.',
        okButtonLabel: 'Choose Folder',
        title: 'Choose top-level workspace folder');
  }

  /**
   * This will create a new folder in default project location. It will attempt
   * to use the given [defaultName], but will disambiguate it if necessary. For
   * example, if `defaultName` already exists, the created folder might be named
   * something like `defaultName-1` instead.
   */
  Future<LocationResult> createNewFolder(String defaultName) {
    return getProjectLocation().then((LocationResult root) {
      return root == null ? null : _create(root, defaultName, 1);
    });
  }

  Future<LocationResult> _create(
      LocationResult location, String baseName, int count) {
    String name = count == 1 ? baseName : '${baseName}-${count}';

    return location.parent.createDirectory(name, exclusive: true).then((dir) {
      return new LocationResult(location.parent, dir, location.isSync);
    }).catchError((_) {
      if (count > 50) {
        throw "Error creating project '${baseName}.'";
      } else {
        return _create(location, baseName, count + 1);
      }
    });
  }
}

class LocationResult {
  /**
   * The parent Entry. This can be useful for persistng the info across
   * sessions.
   */
  final chrome.DirectoryEntry parent;

  /**
   * The created location.
   */
  final chrome.DirectoryEntry entry;

  /**
   * Whether the entry was created in the sync filesystem.
   */
  final bool isSync;

  LocationResult(this.parent, this.entry, this.isSync);

  /**
   * The name of the created entry.
   */
  String get name => entry.name;

  Future<bool> exists() {
    if (isSync) return new Future.value(true);

    return entry.getMetadata().then((_) {
      return true;
    }).catchError((e) {
      return false;
    });
  }
}

class MockProjectLocationManager extends ProjectLocationManager {
  LocationResult _projectLocation;

  MockProjectLocationManager(PreferenceStore prefs) : super._(prefs);

  static Future<ProjectLocationManager> restoreManager(PreferenceStore prefs) {
    return new Future.value(new MockProjectLocationManager(prefs));
  }

  Future setupRoot() {
    if (_projectLocation != null) {
      return new Future.value(_projectLocation);
    }

    MockFileSystem fs = new MockFileSystem();
    DirectoryEntry rootParent = fs.createDirectory("rootParent");
    return rootParent.createDirectory("root").then((DirectoryEntry root) {
      _projectLocation = new LocationResult(rootParent, root, false);
    });
  }

  Future<LocationResult> getProjectLocation([bool chooseIfNone = true]) {
    if (_projectLocation == null) {
      return super.getProjectLocation(chooseIfNone);
    } else {
      return new Future.value(_projectLocation);
    }
  }

  Future<LocationResult> createNewFolder(String name) {
    return _projectLocation.entry.createDirectory(name, exclusive: true).then((dir) {
      return new LocationResult(_projectLocation.entry, dir, false);
    }).catchError((_) {
      throw "Error creating project '${name}.'";
    });
  }
}

/**
 * Allows a user to select a folder on disk. Returns the selected folder
 * entry. Returns `null` in case the user cancels the action.
 */
Future<chrome.DirectoryEntry> _selectFolder({String suggestedName}) {
  Completer completer = new Completer();
  chrome.ChooseEntryOptions options = new chrome.ChooseEntryOptions(
      type: chrome.ChooseEntryType.OPEN_DIRECTORY);
  if (suggestedName != null) options.suggestedName = suggestedName;
  chrome.fileSystem.chooseEntry(options).then((chrome.ChooseEntryResult res) {
    completer.complete(res.entry);
  }).catchError((e) => completer.complete(null));
  return completer.future;
}


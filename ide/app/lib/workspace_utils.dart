// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.workspace_utils;

import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart' as archive;
import 'package:chrome/chrome_app.dart' as chrome;

import 'dependency.dart';
import 'package_mgmt/pub.dart';
import 'workspace.dart';

import 'preferences.dart' as preferences;


Future archiveContainer(Container container, [bool addZipManifest = false]) {
  archive.Archive arch = new archive.Archive();
  return getDeploymentTime(container.project.name).then((String depTime) {
    return _recursiveArchiveModifiedFiles(arch, container,
        depTime, addZipManifest ? 'www/' : '').then((_) {
      String zipAssetManifestString =
          _buildAssetManifestOfModified(container, depTime);
        if (addZipManifest) {
          arch.addFile(new archive.ArchiveFile('zipassetmanifest.json',
              zipAssetManifestString.codeUnits.length,
              zipAssetManifestString.codeUnits));
        }
        return new archive.ZipEncoder().encode(arch);
    });
  });
}

String buildAssetManifest(Container container) {
  return _buildZipAssetManifest(container);
}

/**
 * Return (or create) the child file of the given folder.
 */
Future<File> getCreateFile(Folder parent, String filename) {
  File file = parent.getChild(filename);

  if (file == null) {
    return parent.createNewFile(filename);
  } else {
    return new Future.value(file);
  }
}

/**
 * Copy the given `source` Resource into the `target` Container. The
 */
Future copyResource(Resource source, Folder target) {
  source.workspace.pauseResourceEvents();

  try {
    return _copyResource(source, target).whenComplete(() {
      source.workspace.resumeResourceEvents();
    });
  } catch (e) {
    source.workspace.resumeResourceEvents();
    rethrow;
  }
}

Future _copyResource(Resource source, Folder target) {
  if (source is File) {
    return _copyFile(source, target);
  } else {
    return _copyContainer(source, target);
  }
}

Future _copyFile(File source, Folder target) {
  Resource child = target.getChild(source.name);

  if (child == null) {
    return target.createNewFile(source.name).then((File file) {
      return _copyContents(source, file);
    });
  } else if (!child.isFile) {
    return child.delete().then((_) {
      return target.createNewFile(source.name).then((File file) {
        return _copyContents(source, file);
      });
    });
  } else if (source.timestamp > (child as File).timestamp) {
    return _copyContents(source, child);
  } else {
    return new Future.value();
  }
}

Future _copyContainer(Container source, Folder target) {
  Resource child = target.getChild(source.name);

  return new Future.value().then((_) {
    if (child != null && child.isFile) {
      return child.delete();
    } else if (child == null) {
      return target.createNewFolder(source.name).then((Folder f) {
        child = f;
      });
    }
  }).then((_) {
    return Future.forEach(source.getChildren(), (Resource r) {
      return _copyResource(r, child);
    });
  });
}

Future _copyContents(File source, File dest) {
  return source.getBytes().then((chrome.ArrayBuffer data) {
    return dest.setBytesArrayBuffer(data);
  });
}

/**
 * Returns whether the given target file is up to date with respect to the
 * source file(s). An optional filter will cause only files that match the
 * filter to be checked.
 *
 * Returns `true` if targetFile is not older then any source file.
 */
bool isUpToDate(File targetFile, Resource sourceFiles, [Function filter]) {
  if (targetFile == null) return false;

  int timestamp = targetFile.timestamp;

  Iterable files = sourceFiles.traverse(includeDerived: false).where((Resource resource) {
    if (resource is File) {
      return filter == null ? true : filter(resource);
    } else {
      return false;
    }
  });

  for (File file in files) {
    if (timestamp < file.timestamp) {
      return false;
    }
  }

  return true;
}

/**
 * Given a file and a relative path from it, resolve the target file. Can return
 * `null`.
 */
Resource resolvePath(File file, String path) {
  if (file.parent == null) return null;

  // Check for a `package` reference.
  if (pubProperties.isPackageRef(path)) {
    PubManager pubManager = Dependencies.dependency[PubManager];

    if (pubManager != null) {
      var resolver = pubManager.getResolverFor(file.project);
      File resolvedFile = resolver.resolveRefToFile(path);
      if (resolvedFile != null) return resolvedFile;
    }
  }

  return _resolvePaths(file.parent, path.split('/'));
}

Resource _resolvePaths(Container container, Iterable<String> pathElements) {
  if (pathElements.isEmpty || container == null) return null;

  String element = pathElements.first;

  if (pathElements.length == 1) {
    return container.getChild(element);
  }

  if (element == '..') {
    return _resolvePaths(container.parent, pathElements.skip(1));
  } else {
    return _resolvePaths(container.getChild(element), pathElements.skip(1));
  }
}

String _buildZipAssetManifest(Container container) {
  Iterable<Resource> children = container.traverse().skip(1);
  int rootIndex = container.path.length + 1;
  Map<String, Map<String, String>> zipAssetManifest = {};
  for (Resource element in children) {
    if (element.isFile) {
      String path = element.path.substring(rootIndex);
      zipAssetManifest["www/$path"] = {"path": "www/$path", "etag": "0"};
    }
  }
  return JSON.encode(zipAssetManifest);
}

String _buildAssetManifestOfModified(Container container, String depTime) {
  Iterable<Resource> children = container.traverse().skip(1);
  int rootIndex = container.path.length + 1;
  Map<String, Map<String, String>> zipAssetManifest = {};
  for (Resource element in children) {
    if (element.isFile) {
      if (_isChangedSinceDeployment(element, depTime)) {
          String path = element.path.substring(rootIndex);
          zipAssetManifest["www/$path"] = {"path": "www/$path", "etag": "0"};
      }
    }
  }

  return JSON.encode(zipAssetManifest);
}

bool _isChangedSinceDeployment(File file, String depTime) {
  if (depTime != null) {
    if (file.timestamp < int.parse(depTime)) {
      return false;
    } else {
      return true;
    }
  } else {
    return true;
  }
}

/**
 * This method reads the last deployment time from the local storage
 * and returns it.
 */
Future<String> getDeploymentTime(String projName) {
  return preferences.localStore.getValue("deployment-time").then((String mapTime) {
    if (projName == null) return "0";
    Map<String, String> depTime = JSON.decode(mapTime);
    return depTime[projName];
  }).catchError((_) {
    return "0";
  });
}

/**
 * This method sets the deployment time for a project.
 * The deployment time is saved in the local storage in order to be accessible
 * across sessions.
 */
Future setDeploymentTime(String projName, int time) {
  return preferences.localStore.getValue("deployment-time").then((String mapTime) {
    Map<String, String> depTime = JSON.decode(mapTime);
    depTime[projName]=time.toString();
    return preferences.localStore.setValue("deployment-time", JSON.encode(depTime)).
        then((_) {
      return null;
    });
  }).catchError((_) {
    Map<String, String> depTime = {};
    depTime[projName]=time.toString();
    return preferences.localStore.setValue("deployment-time", JSON.encode(depTime)).
        then((_) {
      return null;
    });
  });
}

Future _recursiveArchiveModifiedFiles(archive.Archive arch, Container parent,
    String depTime, [String prefix = '']) {
  List<Future> futures = [];

  for (Resource child in parent.getChildren()) {
    if (child is File) {
      if (_isChangedSinceDeployment(child, depTime)) {
        futures.add(child.getBytes().then((buf) {
          List<int> data = buf.getBytes();
          arch.addFile(new archive.ArchiveFile('${prefix}${child.name}',
              data.length, data));
        }));
      }
    } else if (child is Folder) {
      futures.add(_recursiveArchiveModifiedFiles(arch, child, depTime, '${prefix}${child.name}/'));
    }
  }

  return Future.wait(futures);
}

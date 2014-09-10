// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.treediff;

import 'dart:async';

import '../object.dart';
import '../objectstore.dart';

class DiffEntryType {
  static const String ADDED = "ADDED";
  static const String REMOVED = "REMOVED";
  static const String MODIFIED = "MODIFIED";
}

class DiffEntry {
  final TreeEntry oldEntry;
  final TreeEntry newEntry;
  final String type;
  String path;

  /// String representation of the diff between the two versions of file.
  String diff;

  DiffEntry(this.oldEntry, this.newEntry, this.type,  [String path]) {

    if (path == null) {
      this.path = oldEntry == null ? newEntry.name : oldEntry.name;
    } else {
      this.path = path;
    }
  }
}

class TreeDiffResult {
  final Map<String, DiffEntry> entries = {};

  List<DiffEntry> getAddedEntries() => _getEntriesForType(DiffEntryType.ADDED);
  List<DiffEntry> getRemovedEntries() => _getEntriesForType(DiffEntryType.REMOVED);
  List<DiffEntry> getModifiedEntries() => _getEntriesForType(DiffEntryType.MODIFIED);

  List<DiffEntry> _getEntriesForType(String type)
      => entries.values.where((entry) => entry.type == type).toList();

  void addEntry(DiffEntry diffEntry) {
    entries[diffEntry.path] = diffEntry;
  }

  void removeEntry(DiffEntry diffEntry) {
     entries.remove(diffEntry.path);
  }

  void addAll(List<DiffEntry> diffEntries) {
    diffEntries.forEach((diffEntry) {
      entries[diffEntry.path] = diffEntry;
    });
  }

  void removeAll(List<DiffEntry> diffEntries) {
    diffEntries.forEach((diffEntry) {
      entries.remove(diffEntry.path);
    });
  }

  void clear() => entries.clear();
}

/**
 * Implements tree diffs.
 *
 * TODO(grv): add unittests.
 */
class TreeDiff {

  static TreeDiffResult diffTree(TreeObject oldTree, TreeObject newTree) {
    oldTree.sortEntries();
    newTree.sortEntries();

    List<TreeEntry> oldEntries = oldTree.entries;
    List<TreeEntry> newEntries = newTree.entries;

    int oldIdx = 0;
    int newIdx = 0;

    TreeDiffResult treeDiff = new TreeDiffResult();

    while (true) {
      TreeEntry newEntry = newIdx < newEntries.length ? newEntries[newIdx]
          : null;
      TreeEntry oldEntry = oldIdx < oldEntries.length ? oldEntries[oldIdx]
          : null;

      if (newEntry == null) {
        if (oldEntry == null ) {
          break;
        }
        treeDiff.addEntry(new DiffEntry(oldEntry, null, DiffEntryType.REMOVED));
        oldIdx++;
      } else if (oldEntry == null) {
        treeDiff.addEntry(new DiffEntry(null, newEntry, DiffEntryType.ADDED));
        newIdx++;
      } else if (newEntry.name.compareTo(oldEntry.name) < 0) {
        treeDiff.addEntry(new DiffEntry(null, newEntry, DiffEntryType.ADDED));
        newIdx++;
      } else if (newEntry.name.compareTo(oldEntry.name) > 0) {
        treeDiff.addEntry(new DiffEntry(oldEntry, null, DiffEntryType.REMOVED));
        oldIdx++;
      } else {
        if (newEntry.sha != oldEntry.sha) {
          if (newEntry.isBlob != oldEntry.isBlob) {
            treeDiff.addEntry(
                new DiffEntry(oldEntry, null, DiffEntryType.REMOVED));
            treeDiff.addEntry(
                new DiffEntry(null, newEntry, DiffEntryType.ADDED));
          } else {
            treeDiff.addEntry(
                new DiffEntry(oldEntry, newEntry, DiffEntryType.MODIFIED));
          }
        }
        oldIdx++;
        newIdx++;
      }
    }
    return treeDiff;
  }

  /**
   * Diffs given tree objects [oldTree], [newTree] recursively and returns
   * the diff files as [TreeDiffResult].
   */
  static Future<TreeDiffResult> diffTreeRecursive(
      ObjectStore store, TreeObject oldTree, TreeObject newTree) {

    TreeDiffResult diff = diffTree(oldTree, newTree);
    List<TreeEntry> treeEntries =
        diff.getAddedEntries().map((entry) => entry.newEntry).toList();

    return _expandDiffEntries(store, treeEntries, DiffEntryType.ADDED).then(
        (diffEntries) {
      diff.removeAll(diff.getAddedEntries());
      diff.addAll(diffEntries);
    }).then((_) {
      List<TreeEntry> treeEntries =
          diff.getRemovedEntries().map((entry) => entry.oldEntry).toList();

      return _expandDiffEntries(store, treeEntries, DiffEntryType.REMOVED).then(
          (diffEntries) {
        diff.removeAll(diff.getRemovedEntries());
        diff.addAll(diffEntries);
      }).then((_) {
        List<DiffEntry> diffEntries = diff.getModifiedEntries();
        return Future.forEach(diffEntries, ((DiffEntry diffEntry) {

          if (!diffEntry.newEntry.isBlob) {
            return store.retrieveObjectList([diffEntry.oldEntry.sha,
                diffEntry.newEntry.sha], "Tree").then((List<TreeObject> trees) {
              diff.removeEntry(diffEntry);

              return diffTreeRecursive(store, trees[0], trees[1]).then((childDiffs) {
                childDiffs.entries.forEach((path, childEntry) {
                  childEntry.path = diffEntry.path + '/' + childEntry.path;
                  diff.addEntry(childEntry);;
                });
              });
            });
          }
        })).then((_) => diff);
      });
    });
  }

  /**
   * Expands a directory [treeSha] recursively.
   */
  static Future<List<DiffEntry>> _expandDiffEntry(
      ObjectStore store, String treeSha, String type) {

    List<DiffEntry> diffEntries = [];
    return store.retrieveObjectList([treeSha], "Tree").then(
        (List<TreeObject> trees) {
      return Future.forEach(trees[0].entries, (TreeEntry entry) {
        if (entry.isBlob) {
          if (type == DiffEntryType.ADDED) {
            diffEntries.add(new DiffEntry(null, entry, type));
          } else {
            diffEntries.add(new DiffEntry(entry, null, type));
          }
        } else {
          return _expandDiffEntry(store, entry.sha, type).then((childEntries) {
            childEntries.forEach((childDiffEntry) {
              childDiffEntry.path = entry.name + '/' + childDiffEntry.path;
              diffEntries.add(childDiffEntry);
            });
          });
        }
      }).then((_) {
        return diffEntries;
      });
    });
  }

  /**
   * Expands given [treeEntries] into files.
   */
  static Future<List<DiffEntry>> _expandDiffEntries(
      ObjectStore store, List<TreeEntry> diffEntries, String type) {
    List<DiffEntry> diffEntries = [];
    return Future.forEach(diffEntries, (DiffEntry diffEntry) {
      if (diffEntry.newEntry.isBlob) {
        diffEntries.add(diffEntry);
        return new Future.value();
      }
      return _expandDiffEntry(store, diffEntry.newEntry.sha, type).then((entries) {
        entries.forEach((entry) {
          entry.path = diffEntry.newEntry.name + '/' + entry.path;
          diffEntries.add(entry);
        });
      });
    }).then((_) => diffEntries);
  }
}

// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.diff;

import '../object.dart';

class DiffEntryType {
  static const String ADDED = "ADDED";
  static const String REMOVED = "REMOVED";
  static const String MODIFIED = "MODIFIED";
}

class DiffEntry {
  TreeEntry oldEntry;
  TreeEntry newEntry;
  String path;

  // String representation of the diff between the two versions of file.
  String diff;
  String type;
  DiffEntry(this.oldEntry, this.newEntry, this.type,  [String path, this.diff]) {
    if (path == null) {
      path = oldEntry == null ? newEntry.name : oldEntry.name;
    } else {
      this.path = path;
    }
  }
}

class TreeDiffResult {
  List<DiffEntry> diffEntries = [];

  List<DiffEntry> getAddedEntries() => _getEntriesForType(DiffEntryType.ADDED);
  List<DiffEntry> getRemovedEntries() => _getEntriesForType(DiffEntryType.REMOVED);
  List<DiffEntry> getModifiedEntries() => _getEntriesForType(DiffEntryType.MODIFIED);

  List<DiffEntry> _getEntriesForType(String type)
   => diffEntries.where((diffEntry) => diffEntry.type == type).toList();
  TreeDiffResult addEntry(DiffEntry diffEntry) {
    diffEntries.add(diffEntry);
    return this;
  }
}

/**
 * Implements tree diffs.
 *
 * TODO(grv): add unittests.
 */
class Diff {

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
}

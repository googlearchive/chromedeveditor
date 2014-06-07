// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.diff;

import 'dart:async';
import 'dart:typed_data';

import '../diff3.dart';
import '../object.dart';
import '../object_utils.dart';
import '../objectstore.dart';
import '../utils.dart';

class MergeItem {
  TreeEntry ours;
  TreeEntry base;
  TreeEntry theirs;
  String conflictText;
  bool isConflict;

  MergeItem(this.ours, this.base, this.theirs, [this.isConflict = false]);
}

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
  DiffEntry(this.oldEntry, this.newEntry, this.type,  [this.path, this.diff]);
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
 */
class Diff {

  static bool shasEqual(List<int> sha1, List<int> sha2) {
    for (var i = 0; i < sha1.length; ++i) {
      if (sha1[i] != sha2[i]) return false;
    }
    return true;
  }

  static dynamic _diff3(blob1, blob2, blob3) {
    return new Uint8List(0);
  }

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

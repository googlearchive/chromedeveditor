// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.merge;

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

class TreeDiffResult {
  List<TreeEntry> adds;
  List<TreeEntry> removes;
  List merges;
  TreeDiffResult(this.adds, this.removes, this.merges);
}

/**
 * Implements tree diffs and merging of git trees.
 */
class Merge {

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

    List removes = [];
    List adds = [];
    List merges = [];

    while (true) {
      TreeEntry newEntry = newIdx < newEntries.length ? newEntries[newIdx]
          : null;
      TreeEntry oldEntry = oldIdx < oldEntries.length ? oldEntries[oldIdx]
          : null;

      if (newEntry == null) {
        if (oldEntry == null ) {
          break;
        }
        removes.add(oldEntry);
        oldIdx++;
      } else if (oldEntry == null) {
        adds.add(newEntry);
        newIdx++;
      } else if (newEntry.name.compareTo(oldEntry.name) < 0) {
        adds.add(newEntry);
        newIdx++;
      } else if (newEntry.name.compareTo(oldEntry.name) > 0) {
        removes.add(oldEntry);
        oldIdx++;
      } else {
        if (newEntry.sha != oldEntry.sha) {
          if (newEntry.isBlob != oldEntry.isBlob) {
            removes.add(oldEntry);
            adds.add(newEntry);
          } else {
            merges.add({'new': newEntry, 'old':oldEntry});
          }
        }
        oldIdx++;
        newIdx++;
      }
    }
    return new TreeDiffResult(adds, removes, merges);
  }

  static Future<String> mergeTrees(ObjectStore store, TreeObject ourTree,
      TreeObject baseTree, TreeObject theirTree) {
    List<TreeEntry> finalTree = [];
    List merges = [];
    var next = null;
    List indices = [0,0,0];
    List<MergeItem> conflicts = [];

    // base tree can be null if we're merging a sub tree from ours and theirs
    // with the same name but it didn't exist in base.
    if (baseTree == null) {
      baseTree = new TreeObject();
      baseTree.entries = [];
    }

    ourTree.sortEntries();
    theirTree.sortEntries();
    baseTree.sortEntries();

    List<List<TreeEntry>> allTrees = [ourTree.entries, baseTree.entries,
        theirTree.entries];

    while (true) {
      TreeEntry next = null;
      int nextX = 0;
      for (int i = 0; i < allTrees.length; ++i) {
        List treeEntries = allTrees[i];
        TreeEntry top = (indices[i] < treeEntries.length) ?
            treeEntries[indices[i]] : null;

        if (next == null || (top != null && top.name.compareTo(next.name) < 0)) {
          next = top;
          nextX = i;
        }
      }

      if (next == null) break;

      switch (nextX) {
        case 0:
          TreeEntry theirEntry = allTrees[2][indices[2]];
          TreeEntry baseEntry = allTrees[1][indices[1]];
          if (theirEntry.name == next.name) {
            if (!shasEqual(theirEntry.shaBytes, next.shaBytes)) {
              if (baseEntry.name != next.name) {
                baseEntry = new TreeEntry(null, null, false);
                if (next.isBlob) {
                  conflicts.add( new MergeItem(next, null, theirEntry, true));
                  break;
                }
              }
              if (next.isBlob == theirEntry.isBlob && (baseEntry.isBlob
                  == next.isBlob)) {
                if (shasEqual(next.shaBytes, baseEntry.shaBytes)) {
                  finalTree.add(theirEntry);
                } else if (shasEqual(baseEntry.shaBytes, theirEntry.shaBytes)){
                  finalTree.add(next);
                } else {
                  merges.add(new MergeItem(next, baseEntry, theirEntry));
                }
              } else {
                conflicts.add(new MergeItem(next, baseEntry, theirEntry,
                    true));
              }
            } else {
              finalTree.add(next);
            }
          } else if(baseEntry.name == next.name) {
            if (!shasEqual(baseEntry.shaBytes, next.shaBytes)) {
              // deleted from theirs but changed in ours. Delete/modfify
              // conflict.
              conflicts.add(new MergeItem(next, baseEntry, null, true));
            }
          } else {
            finalTree.add(next);
          }
          break;

        case 1:
          TreeEntry theirEntry = allTrees[2][indices[2]];
          if (next.name == theirEntry.name && !shasEqual(next.shaBytes,
              theirEntry.shaBytes)) {
            // deleted from ours but changed in theirs. Delete/modify conflict.
            conflicts.add(new MergeItem(null, next, theirEntry, true));
          }
          break;

        case 2:
          finalTree.add(next);
          break;
      }

      for (int i = 0; i < allTrees.length; ++i) {
        List treeEntries = allTrees[i];
        if (indices[i] < treeEntries.length && treeEntries[indices[i]].name
            == next.name) {
          indices[i]++;
        }
      }
    }

    if (conflicts.length > 0) {
      // TODO(grv): Deal with conflicts.
      throw "unable to merge. Conflicts.";
    }

    return Future.forEach(merges, (MergeItem item) {
      List<String> shas = [item.ours.sha, item.base.sha, item.theirs.sha];
        if (item.ours.isBlob) {
          return store.retrieveObjectBlobsAsString(shas).then(
              (List<LooseObject> blobs) {
            Diff3Result diffResult = Diff3.diff(blobs[0].data,
                blobs[1].data, blobs[2].data);
            if (diffResult.conflict) {
              item.conflictText = diffResult.text;
              conflicts.add(item);
              return conflicts;
            } else {
              return store.writeRawObject('blob', diffResult.text).then(
                  (String sha) {
                item.ours.shaBytes = shaToBytes(sha);
                finalTree.add(item.ours);
                return [];
              });
            }
          });
        } else {
          return store.retrieveObjectList(shas, ObjectTypes.TREE_STR).then(
              (List<TreeObject> trees) {
            return mergeTrees(store, trees[0], trees[1], trees[2]).then(
                (String mergedSha) {
              item.ours.shaBytes = shaToBytes(mergedSha);
              finalTree.add(item.ours);
              return null;
            }, onError: (List<MergeItem> newConflicts) {
              conflicts.addAll(newConflicts);
              return [];
            });
          });
        }
    }).then((_) {
      if (conflicts.isEmpty) {
        return store.writeTree(finalTree);
      } else {
        return new Future.error(conflicts);
      }
    });
  }
}

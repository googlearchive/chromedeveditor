// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.merge;

import 'dart:async';
import 'dart:typed_data';

import 'package:chrome/chrome_app.dart' as chrome;

import 'checkout.dart';
import 'commit.dart';
import 'constants.dart';
import 'index.dart';
import '../diff3.dart';
import '../exception.dart';
import '../file_operations.dart';
import '../object.dart';
import '../object_utils.dart';
import '../objectstore.dart';
import '../options.dart';
import '../permissions.dart';
import '../utils.dart';

class MergeItem {
  TreeEntry ours;
  TreeEntry base;
  TreeEntry theirs;
  String conflictText;
  bool isConflict;

  MergeItem(this.ours, this.base, this.theirs, [this.isConflict = false]);
}

class MergeEntryType {
  static const String ADD = "ADD";
  static const String REMOVE = "REMOVE";
  static const String MODIFIED = "MODIFIED";
  static const String UNMERGED = "UNMERGED";
}

class MergeTreeEntry {
  TreeEntry entry;
  String path;
  String type;
  String message;
  bool conflict = false;

  get sha => entry.sha;

  get name => entry.name;

  get isBlob => entry.isBlob;

  MergeTreeEntry(this.entry, this.path, this.type, {this.message, this.conflict});
}

class MergeTreeDiff {
  List<MergeTreeEntry> entries = [];

  List<MergeTreeEntry> getConflicts() {
    return entries.where((entry) => entry.conflict);
  }

  bool isCleanMerge() => getConflicts().isEmpty;

  List<MergeTreeEntry> adds() => entries.where((entry) =>
      entry.type == MergeEntryType.ADD);

  List<MergeTreeEntry> removes() => entries.where((entry) =>
      entry.type == MergeEntryType.REMOVE);

  List<MergeTreeEntry> modified() => entries.where((entry) =>
      entry.type == MergeEntryType.MODIFIED);

  List<MergeTreeEntry> unmerged() => entries.where((entry) =>
      entry.type == MergeEntryType.UNMERGED);
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

  static Future<MergeTreeDiff> mergeTrees(ObjectStore store, TreeObject ourTree,
      TreeObject baseTree, TreeObject theirTree, String rootPath) {
    MergeTreeDiff finalTree = new MergeTreeDiff();
    List merges = [];
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
          TreeEntry theirEntry = TreeEntry.dummyEntry(false);
          TreeEntry baseEntry = TreeEntry.dummyEntry(false);

          if (indices[2] < allTrees[2].length) {
            theirEntry = allTrees[2][indices[2]];
          }

          if (indices[1] < allTrees[1].length) {
            baseEntry = allTrees[1][indices[1]];
          }

          if (theirEntry.name == next.name) {
            if (!shasEqual(theirEntry.shaBytes, next.shaBytes)) {
              if (baseEntry.name != next.name) {
                // The file does not exist in the  baseEntry. Create a dummy entry.
                baseEntry = TreeEntry.dummyEntry(false);
                if (next.isBlob) {
                  // TODO conflict not supported.
                  conflicts.add(new MergeItem(next, null, theirEntry, true));
                  break;
                }
              }
              if (next.isBlob == theirEntry.isBlob && (baseEntry.isBlob
                  == next.isBlob)) {
                if (shasEqual(next.shaBytes, baseEntry.shaBytes)) {
                  if (next.isBlob) {
                    finalTree.entries.add(new MergeTreeEntry(
                        theirEntry, rootPath +'/' +  theirEntry.name, MergeEntryType.MODIFIED));
                  } else {
                    merges.add(new MergeItem(next, baseEntry, theirEntry));
                  }
                } else if (shasEqual(baseEntry.shaBytes, theirEntry.shaBytes)){
                } else {
                  merges.add(new MergeItem(next, baseEntry, theirEntry));
                }
              } else {
                // TODO conflict not supported.
                conflicts.add(new MergeItem(next, baseEntry, theirEntry,
                    true));
              }
            }
          } else if(baseEntry.name == next.name) {
            if (!shasEqual(baseEntry.shaBytes, next.shaBytes)) {
              // deleted from theirs but changed in ours. Delete/modfify
              // conflict.
              finalTree.entries.add(new MergeTreeEntry(
                  next, rootPath +'/' +  next.name, MergeEntryType.UNMERGED, conflict: true));
              ///conflicts.add(new MergeItem(next, baseEntry, null, true));
            } else {
              finalTree.entries.add(new MergeTreeEntry(next, rootPath +'/' +  next.name,
                  MergeEntryType.REMOVE));
            }
          }
          break;

        case 1:
          TreeEntry theirEntry = TreeEntry.dummyEntry(false);

          if (indices[2] < allTrees[2].length) {
            theirEntry = allTrees[2][indices[2]];
          };

          if (next.name == theirEntry.name && !shasEqual(next.shaBytes,
              theirEntry.shaBytes)) {
            // deleted from ours but changed in theirs. Delete/modify conflict.
           // conflicts.add(new MergeItem(null, next, theirEntry, true));
            finalTree.entries.add(new MergeTreeEntry(theirEntry,
                rootPath +'/' + theirEntry.name, MergeEntryType.UNMERGED, conflict: true));
          }
          break;

        case 2:

          finalTree.entries.add(new MergeTreeEntry(next, rootPath +'/' +  next.name,
              MergeEntryType.ADD));
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
            return store.writeRawObject('blob', diffResult.text).then(
                             (String sha) {
              item.ours.shaBytes = shaToBytes(sha);
              if (diffResult.conflict) {
                finalTree.entries.add(
                    new MergeTreeEntry(item.ours, rootPath + '/' + item.ours.name,
                        MergeEntryType.UNMERGED, conflict: true));
              } else {
                finalTree.entries.add(
                    new MergeTreeEntry(item.ours, rootPath + '/' + item.ours.name,
                        MergeEntryType.MODIFIED));
              }
              return;
            });
          });
        } else {
          return store.retrieveObjectList(shas, ObjectTypes.TREE_STR).then(
              (List<TreeObject> trees) {
            return mergeTrees(store, trees[0], trees[1], trees[2],
                rootPath + '/' + item.ours.name).then((MergeTreeDiff mergedTree) {
              finalTree.entries.addAll(mergedTree.entries);
            });
          });
        }
    }).then((_) {
      return finalTree;
    });
  }

  /**
   * Identify if the given branch is a local or remote branch and return the
   * headSha value. This will not do an automatic fetch thus return the local
   * headSha of the remote branch.
   */
  static Future<String> _getSourceBranchSha(ObjectStore store,
      String sourceBranchName) {
    if (sourceBranchName.startsWith('origin/')) {
      sourceBranchName = sourceBranchName.split('/').last;
      return store.getRemoteHeadForRef(sourceBranchName);
    } else {
      String refName = 'refs/heads/${sourceBranchName}';
      return store.getHeadForRef(refName);
    }
  }

  static Future merge(GitOptions options, String sourceBranchName) {
    ObjectStore store = options.store;
    return store.getHeadRef().then((headRefName) {
      return store.getHeadForRef(headRefName).then((localSha) {
        return _getSourceBranchSha(store, sourceBranchName).then(
            (String sourceSha) {
          if (localSha == sourceSha) {
            return new Future.error(
              new GitException(GitErrorConstants.GIT_BRANCH_UP_TO_DATE));
          }

          return store.getCommonAncestor([sourceSha, localSha]).then((commonSha) {
            if (commonSha == sourceSha) {
              return new Future.error(
                  new GitException(GitErrorConstants.GIT_BRANCH_UP_TO_DATE));
            } else if (commonSha == localSha) {
              // The current branch has not diverged and the branch to be merged
              // is already ahead. Move the local head to the new branch.
              return Checkout.checkout(options, sourceSha).then((_) {
                return FileOps.createFileWithContent(options.root,
                    '.git/${headRefName}', sourceSha + '\n', 'Text').then((_) {
                  return store.writeConfig().then((_) => sourceSha);
                });
              });
            } else {
              String commitMsg =
                  "Merge branch ${options.branchName} into ${sourceBranchName}";
              return _merge(options, localSha, sourceSha, commonSha, commitMsg);
            }
          });
        });
      });
    });
  }

  static Future _merge(GitOptions options,
                String localSha,
                String sourceSha,
                String commonSha,
                String commitMsg) {

    ObjectStore store = options.store;
    List shas = [localSha, commonSha, sourceSha];
    return store.getHeadRef().then((String headRefName) {
      return store.getTreesFromCommits(shas).then((trees) {
        return Merge.mergeTrees(store, trees[0], trees[1], trees[2],
            store.root.fullPath).then((MergeTreeDiff mergedTree) {

          return store.getCurrentBranch().then((branch) {
            options.branchName = branch;
            options.commitMessage = commitMsg;
            // Create a merge commit by default.

            if (mergedTree.isCleanMerge()) {
              return _checkoutMergedTree(store, mergedTree).then((_) {
                return Commit.createCommitFromWorkingTree(options, [sourceSha, localSha],
                    headRefName);
              });
            } else {
              return _checkoutMergedTree(store, mergedTree).then((_) {
                return new Future.error("Unable to auto-merge. Resolve the conflicts and merge manually.");
              });
            }
          });
        }).catchError((e) {
          return new Future.error(
              new GitException(GitErrorConstants.GIT_MERGE_ERROR));
        });
      });
    });
  }

  static Future<chrome.Entry> _checkoutEntry(
      ObjectStore store, MergeTreeEntry entry, bool updateIndex) {
    String path = entry.path.substring(store.root.fullPath.length + 1);
    return ObjectUtils.expandBlob(store.root, store, path, entry.entry.sha,
        Permissions.FILE_NON_EXECUTABLE, updateIndex);
  }

  static Future _checkoutMergedTree(ObjectStore store, MergeTreeDiff tree) {
    return Future.forEach(tree.adds(), (MergeTreeEntry entry) {
      return _checkoutEntry(store, entry, false).then((chrome.Entry entry) {
        FileStatus status = FileStatus.createFromEntry(entry);
         status.type = FileStatusType.MODIFIED;
         store.index.updateIndexForEntry(entry, status);
      });
    }).then((_) {
      return Future.forEach(tree.removes(), (MergeTreeEntry entry) {
        try {
          return store.root.getFile(entry.path).then((fileEntry) =>
              fileEntry.remove().catchError((e) => true));
        } catch(e) {
          return new Future.value();
        }
      }).then((_) {
        return Future.forEach(tree.modified(), (MergeTreeEntry entry) {
          return _checkoutEntry(store, entry, false);
        }).then((_) {
          return Future.forEach(tree.unmerged(), (MergeTreeEntry entry) {
            return _checkoutEntry(store, entry, false);
          }).then((_) {
            return store.index.updateIndex().then((_) {
              return Future.forEach(tree.unmerged(), (MergeTreeEntry entry) {
                 store.index.updateStatusAsUnmerged(entry.path);
              });
            });
          });
        });
      });
    });
  }
}

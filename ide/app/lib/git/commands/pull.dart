// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.pull;

import 'dart:async';
import 'dart:typed_data';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:crypto/crypto.dart' as crypto;

import '../file_operations.dart';
import '../http_fetcher.dart';
import '../object.dart';
import '../object_utils.dart';
import '../objectstore.dart';
import '../options.dart';
import '../pack.dart';
import '../pack_index.dart';
import '../upload_pack_parser.dart';
import '../utils.dart';
import 'status.dart';
import 'merge.dart';

/**
 * A git pull command implmentation.
 *
 * TODO add unittests.
 */
class Pull {

  GitOptions options;
  chrome.DirectoryEntry root;
  ObjectStore store;
  Function progress;


  Pull(this.options){
    root = options.root;
    store = options.store;
    progress = options.progressCallback;

    if (progress == null) progress = nopFunction;
  }

   Future pull() {
    String username = options.username;
    String password = options.password;

    Function fetchProgress;
    // TODO add fetchProgress chunker.

    return Status.isWorkingTreeClean(store).then((_) {
      String url = store.config.url;

      HttpFetcher fetcher = new HttpFetcher(store, 'origin', url, username,
          password);

      // get current branch.
      return FileOps.readFile(root, '.git/HEAD', 'Text').then(
          (String headStr) {

        // get rid of the initial 'ref: ' and newline at end.
        String headRefName = headStr.substring(5).trim();
        return fetcher.fetchUploadRefs().then((List<GitRef> refs) {
          GitRef branchRef = refs.firstWhere((GitRef ref) =>
              ref.name == headRefName);

          if (branchRef != null) {
            // see if we know about the branch's head commit. If so we're up to
            // date. If not, request from remote.
            return store.retrieveRawObject(branchRef.sha, 'ArrayBuffer').then(
                (_) {
              // Branch is uptodate
              // TODO throw PULL_UP_TO_DATE;
              throw "pull up to date.";
            }, onError: (e) {
              return _handleMerge(branchRef, branchRef, fetcher);
            });
          } else {
            //TODO better error handling.
            throw "Remote branch not found";
          }
        });
      }, onError: (e) {
        // TODO throw branch not found error.
        throw "branch not found.";
      });
    });
  }

  static Future _applyDiffTree(chrome.DirectoryEntry dir,
      TreeDiffResult  treeDiff, ObjectStore store) {
    return Future.forEach(treeDiff.removes, (TreeEntry treeEntry) {
      if (treeEntry.isBlob) {
        return dir.getFile(treeEntry.name).then((chrome.FileEntry entry) {
          return entry.remove();
        });
      } else {
        return dir.getDirectory(treeEntry.name).then(
            (chrome.DirectoryEntry entry) {
          return entry.removeRecursively();
        });
      }
    }).then((_) {
      return Future.forEach(treeDiff.adds, (TreeEntry treeEntry) {
        if (treeEntry.isBlob) {
          return ObjectUtils.expandBlob(dir, store, treeEntry.name,
              shaBytesToString(treeEntry.sha));
        } else {
          return dir.createDirectory(treeEntry.name).then(
              (chrome.DirectoryEntry dirEntry) {
            return ObjectUtils.expandTree(dirEntry, store,
                shaBytesToString(treeEntry.sha));
          });
        }
      }).then((_) {
        return Future.forEach(treeDiff.merges, (mergeEntry) {
          if (mergeEntry['new'].isBlob) {
            return ObjectUtils.expandBlob(dir, store, mergeEntry['new'].name,
                shaBytesToString(mergeEntry['new'].sha));
          } else {
            return store.retrieveObjectList([mergeEntry['old'].sha,
                mergeEntry['new'].sha], ObjectTypes.TREE_STR).then(
                (List<TreeObject> trees) {
              TreeDiffResult treeDiff2 = Merge.diffTree(trees[0], trees[1]);
              return dir.createDirectory(mergeEntry['new'].name).then(
                  (chrome.DirectoryEntry dirEntry) {
                return _applyDiffTree(dirEntry, treeDiff2, store);
              });
            });
          }
        });
      });
    });
  }

  Future _updateWorkingTree(chrome.DirectoryEntry dir, ObjectStore store,
      TreeObject fromTree, TreeObject toTree) {
    return _applyDiffTree(dir, Merge.diffTree(fromTree, toTree), store);
  }

  /**
   * Create pack and packIndex file. Returns objects directory.
   */
  Future<chrome.DirectoryEntry> _createPackFiles(String packName,
      ByteBuffer packBuffer, ByteBuffer packIdxBuffer) {
    return FileOps.createDirectoryRecursive(root, '.git/objects').then(
        (chrome.DirectoryEntry objectsDir) {
      return FileOps.createFileWithContent(root, 'pack/${packName}.pack',
          packBuffer, 'ArrayBuffer').then((_) {
        return FileOps.createFileWithContent(root, 'pack/${packName}.idx',
            packIdxBuffer, 'ArrayBuffer').then((_) {
          return new Future.value(objectsDir);
        });
      });
    });
  }

  Future _createAndUpdateRef(GitRef branchRef, GitRef wantRef) {
    return FileOps.createFileWithContent(root, '.git/${wantRef.name}',
        wantRef.sha, 'Text').then((_) {
      store.getTreesFromCommits([wantRef.localHead, wantRef.sha]).then(
          (List<TreeObject> trees) {
        return _updateWorkingTree(root, store, trees[0], trees[1]).then((_) {
          store.config.remoteHeads[branchRef.name] = branchRef.sha;
          return store.writeConfig();
        });
      });
    });
  }

  Future _handleMerge(GitRef branchRef, GitRef wantRef, HttpFetcher fetcher) {

    // Get the sha from the ref name.
    return store.getHeadForRef(branchRef.name).then((String sha) {
      branchRef.localHead = sha;
      return store.getCommitGraph([sha], 32).then((CommitGraph graph) {
        List<String> haveRefs = graph.commits.map((CommitObject commit)
            => commit.treeSha);
        return fetcher.fetchRef([wantRef.sha], haveRefs, store.config.shallow,
            null, graph.nextLevel, null, progress).then((PackParseResult result) {
          // fast forward merge.
          if (result.common.indexOf(wantRef.localHead) != null) {

            Uint8List packSha = result.data.sublist(result.data.length - 20);
            Uint8List packIdxData = PackIndex.writePackIndex(result.objects,
                packSha);
            // Get a veiw of the sorted shas.
            Uint8List sortedShas = packIdxData.sublist(4 + 4 + (256 * 4),
                result.objects.length * 20);

            crypto.SHA1 sha1 = new crypto.SHA1();
            sha1.add(sortedShas);
            String packNameSha = shaBytesToString(sha1.close());

            String packName = 'pack-${packNameSha}';
            return _createPackFiles(packName, result.data.buffer,
                packIdxData.buffer).then((objectsDir) {
              store.objectDir = objectsDir;
              PackIndex packIdx = new PackIndex(packIdxData.buffer);
              store.packs.add(new PackEntry(new Pack(result.data, store), packIdx));
              return _createAndUpdateRef(branchRef, wantRef);
            });
          } else {
            // non-fast-forward merge.
            //TODO support non-fast-forward merges.
            throw "non fast forward merge.";
          }
        });
      });
    });
  }
}

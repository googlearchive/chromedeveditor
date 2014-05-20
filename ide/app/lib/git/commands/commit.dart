// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.commit;

import 'dart:async';
import 'dart:typed_data';
import 'package:chrome/chrome_app.dart' as chrome;

import 'constants.dart';
import 'index.dart';
import 'status.dart';
import '../file_operations.dart';
import '../exception.dart';
import '../object.dart';
import '../object_utils.dart';
import '../objectstore.dart';
import '../options.dart';
import '../utils.dart';

/**
 * This class implments the git commit command.
 */
class Commit {

  /**
   * Walks over all the files in the working tree. Returns sha of the
   * working tree.
   */
  static Future<String> walkFiles(chrome.DirectoryEntry root,
      ObjectStore store) {

    return FileOps.listFiles(root).then((List<chrome.ChromeFileEntry> entries) {
      if (entries.isEmpty) {
        return null;
      }

      List<TreeEntry> treeEntries = [];

      return Future.forEach(entries, (chrome.Entry entry) {
        if (entry.name == '.git') {
          return null;
        }

        if (entry.isDirectory) {
          return walkFiles(entry as chrome.DirectoryEntry, store).then((String sha) {
            if (sha != null) {
              treeEntries.add(new TreeEntry(entry.name, shaToBytes(sha), false));
            }
          });
        } else {
          chrome.ChromeFileEntry fileEntry = entry;

          return Status.getFileStatus(store, entry).then((FileStatus status) {
            if (status.type != FileStatusType.UNTRACKED) {
              store.index.updateIndexForEntry(status);
              status = store.index.getStatusForEntry(entry);

              if (status.type == FileStatusType.STAGED ||
                  status.type == FileStatusType.MODIFIED) {
                return fileEntry.readBytes().then((chrome.ArrayBuffer buf) {
                  return store.writeRawObject(
                      'blob', new Uint8List.fromList(buf.getBytes()));
                }).then((String sha) {
                  treeEntries.add(new TreeEntry(entry.name, shaToBytes(sha), true));
                });
              } else if (status.type == FileStatusType.COMMITTED){
                treeEntries.add(
                    new TreeEntry(entry.name, shaToBytes(status.sha), true));
              }
            }
          });
        }
      }).then((_) {
        treeEntries.sort((TreeEntry a, TreeEntry b) {
          String aName = a.isBlob ? a.name : (a.name + '/');
          String bName = b.isBlob ? b.name : (b.name + '/');
          return aName.compareTo(bName);
        });
        return store.writeTree(treeEntries);
      });
    });
  }

  static Future checkTreeChanged(ObjectStore store, String parent,
      String sha) {
    if (parent != null && parent.isEmpty) {
      return null;
    } else {
      return store.retrieveObject(parent, ObjectTypes.COMMIT_STR).then(
          (CommitObject parentCommit) {
        String oldTree = parentCommit.treeSha;
        if (oldTree == sha) {
          throw new GitException(GitErrorConstants.GIT_COMMIT_NO_CHANGES);
        } else {
          return null;
        }
      }, onError: (e) {
        throw new GitException(GitErrorConstants.GIT_OBJECT_STORE_CORRUPTED);
      });
    }
  }

  /**
   * Creates a commit of all the changed files int the working tree with
   * [options.commitMessage] as commit message.
   */
  static Future commit(GitOptions options) {
    chrome.DirectoryEntry dir = options.root;
    ObjectStore store = options.store;

    return store.getHeadRef().then((String headRefName) {
      return store.getHeadForRef(headRefName).then((String parent) {
        return _createCommitFromWorkingTree(options, parent, headRefName);
      }, onError: (e) {
        return _createCommitFromWorkingTree(options, null, headRefName);
      });
    });
  }

  static Future createCommit(GitOptions options, String parent, String treeSha,
      String refName) {
    ObjectStore store = options.store;

    return checkTreeChanged(store, parent, treeSha).then((_) {
      String dateString = getCurrentTimeAsString();
      StringBuffer commitContent = new StringBuffer();
      commitContent.write('tree ${treeSha}\n');
      if (parent != null && parent.length > 0) {
        commitContent.write('parent ${parent}');
        if (parent[parent.length -1] != '\n') {
          commitContent.write('\n');
        }
      }

      String name = options.name == null ? "" : options.name;
      String email = options.email == null ? "" : options.email;
      String commitMsg = options.commitMessage == null ? ""
          : options.commitMessage;
      commitContent.write('author ${name} <${email}> ${dateString}\n');
      commitContent.write('committer ${name} <${email}> ${dateString}');
      commitContent.write('\n\n${commitMsg}\n');

      return store.writeRawObject(ObjectTypes.COMMIT_STR,
          commitContent.toString()).then((String commitSha) {
        return FileOps.createFileWithContent(options.root, '.git/${refName}',
            commitSha + '\n', 'Text').then((_) {
          return store.writeConfig().then((_) => commitSha);
        });
      });
    });
  }

  static Future _createCommitFromWorkingTree(GitOptions options, String parent,
      String refName) {
    ObjectStore store = options.store;

    return walkFiles(options.root, store).then((String sha) {
      // update the index.
      return store.index.onCommit().then((_) {
        return createCommit(options, parent, sha, refName);
      });
    });
  }
}

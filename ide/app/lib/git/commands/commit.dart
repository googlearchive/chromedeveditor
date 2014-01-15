// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.commit;

import 'dart:async';
import 'dart:typed_data';

import 'package:chrome/chrome_app.dart' as chrome;

import '../file_operations.dart';
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

    return FileOps.listFiles(root).then((List<chrome.DirectoryEntry> entries) {
      if (entries.isEmpty) {
        return null;
      }

      List<TreeEntry> treeEntries = [];

      return Future.forEach(entries, (chrome.DirectoryEntry entry) {
        if (entry.name == '.git') {
          return null;
        }

        if (entry.isDirectory) {
          return walkFiles(entry, store).then((String sha) {
            if (sha != null) {
              treeEntries.add(new TreeEntry(entry.name, shaToBytes(sha),
                  false));
            }
          });
        } else {
          return (entry as chrome.ChromeFileEntry).readBytes().then(
              (chrome.ArrayBuffer buf) {
                return store.writeRawObject('blob', new Uint8List.fromList(
                    buf.getBytes()));
              }).then((String sha) {
                treeEntries.add(
                    new TreeEntry(entry.name, shaToBytes(sha), true));
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
    if (parent.isEmpty) {
      return null;
    } else {
      return store.retrieveObject(parent, ObjectTypes.COMMIT).then(
          (CommitObject parentCommit) {
        String oldTree = parentCommit.treeSha;
        if (oldTree == sha) {
          // TODO throw COMMITS_NO_CHANGES error.
          throw "commits_no_changes";
        } else {
          return null;
        }
      }, onError: (e) {
        // TODO throw error object_store_corrupted.
        throw "object_store_corrupted";
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

  static Future _createCommitFromWorkingTree(GitOptions options, String parent,
      String refName) {
    chrome.DirectoryEntry dir = options.root;
    ObjectStore store = options.store;
    String name = options.name;
    String email = options.email;
    String commitMsg = options.commitMessage;

    return walkFiles(dir, store).then((String sha) {
      return checkTreeChanged(store, parent, sha).then((_) {
        DateTime now = new DateTime.now();
        String dateString =
            (now.millisecondsSinceEpoch / 1000).floor().toString();
        int offset = (now.timeZoneOffset.inHours).floor();
        int absOffset = offset.abs().floor();
        String offsetStr = ' ' + (offset < 0 ? '-' : '+');
        offsetStr += (absOffset < 10 ? '0' : '') + '${absOffset}00';
        dateString += offsetStr;
        StringBuffer commitContent = new StringBuffer();
        commitContent.write('tree ${sha}\n');
        if (parent != null && parent.length > 0) {
          commitContent.write('parent ${parent}');
          if (parent[parent.length -1] != '\n') {
            commitContent.write('\n');
          }
        }

        commitContent.write('author ${name} ');
        commitContent.write(' <$email> ');
        commitContent.write(dateString);
        commitContent.write('\n');
        commitContent.write('committer ${name}');
        commitContent.write(' <${email}> ');
        commitContent.write(dateString);
        commitContent.write('\n\n${commitMsg}\n');

        return store.writeRawObject(
            ObjectTypes.COMMIT, commitContent.toString()).then(
                (String commitSha) {
          return FileOps.createFileWithContent(dir, '.git/${refName}',
              commitSha + '\n', 'Text').then((_) {
                return store.updateLastChange(null).then((_) => commitSha);
          });
        });
      });
    });
  }
}

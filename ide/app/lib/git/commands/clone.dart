// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.clone;

import 'dart:async';
import 'dart:typed_data';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:crypto/crypto.dart' as crypto;

import '../file_operations.dart';
import '../http_fetcher.dart';
import '../objectstore.dart';
import '../object_utils.dart';
import '../options.dart';
import '../pack.dart';
import '../pack_index.dart';
import '../upload_pack_parser.dart';
import '../utils.dart';

/**
 * This class implements the git clone command.
 */
class Clone {

  GitOptions _options;

  Clone(this._options) {
    if (_options.branchName == null) _options.branchName = 'master';
    if (_options.progressCallback == null) {
      _options.progressCallback = nopFunction;
    }
  }

  Future clone() {

    HttpFetcher fetcher = new HttpFetcher(_options.store, "origin",
        _options.repoUrl, _options.username, _options.password);

    return _checkDirectory(_options.root, _options.store, nopFunction).then((_) {
      return  _options.root.createDirectory(".git").then(
          (chrome.DirectoryEntry gitDir) {
        return fetcher.fetchUploadRefs().then((List<GitRef> refs) {
          if (refs.isEmpty) {
            return _createInitialConfig(null, null);
          }

          GitRef remoteHeadRef, localHeadRef;
          String remoteHead;

          refs.forEach((GitRef ref) {
            if (ref.name == "HEAD") {
              remoteHead = ref.sha;
            } else if (ref.name == "refs/heads/" + _options.branchName) {
              localHeadRef = ref;
            } else if (ref.name.indexOf("refs/heads/") == 0) {
              if (ref.sha == remoteHead) {
                remoteHeadRef = ref;
              }
            }
          });

          if (localHeadRef == null) {
            if (_options.branchName == null) {
              //REMOTE_BRANCH_NOT_FOUND;
              return null;
            } else {
              localHeadRef = remoteHeadRef;
            }
          }
          return _processClone(gitDir, localHeadRef, fetcher);
        });
      });
    });
  }

  Future _createCurrentTreeFromPack(chrome.DirectoryEntry dir, ObjectStore store,
      String headSha) {
    return store.retrieveObject(headSha, ObjectTypes.COMMIT_STR).then((commit) {
          return ObjectUtils.expandTree(dir, store, commit.treeSha);
    });
  }

  // TODO error handling.
  Future _checkDirectory(chrome.DirectoryEntry dir, ObjectStore store, ferror) {

    return FileOps.listFiles(dir).then((entries) {
      if (entries.length == 0) {
        throw "CLONE_DIR_NOT_INTIALIZED";
      } else if (entries.length != 1 || entries.first.isFile
          || entries.first.name != '.git') {
        throw "CLONE_DIR_NOT_EMPTY";
      } else {
        return FileOps.listFiles(store.objectDir).then((entries) {
          if (entries.length > 1) {
            throw "CLONE_GIT_DIR_IN_USE";
          } else if (entries.length == 1) {
            if (entries.first.name == "pack") {
              return store.objectDir.getDirectory('pack').then(
                  (chrome.DirectoryEntry packDir) {
                return FileOps.listFiles(packDir).then((entries) {
                  if (entries.length > 0) {
                    throw "CLONE_GIT_DIR_IN_USE";
                  } else {
                    return null;
                  }
                }, onError: (e) {
                  ferror();
                  throw e;
                });
              }, onError: (e) {
                ferror();
                throw e;
              });
            }
          }
        }, onError: (e) {
          ferror();
          throw e;
        });
      }
    }, onError: (e) {
      ferror();
      throw e;
    });
  }

  Future _createInitialConfig(String shallow, GitRef localHeadRef) {
    GitConfig config = new GitConfig();
    config.url = _options.repoUrl;
    config.time = new DateTime.now();

    if (_options.depth > 0 && shallow != null) {
      config.shallow = shallow;
    }

    if (localHeadRef != null) {
      config.remoteHeads[localHeadRef.name]= localHeadRef.sha;
    }
    return _options.store.setConfig(config);
  }

  Future _createPackFiles(chrome.DirectoryEntry objectsDir, String packName,
      Uint8List packData, Uint8List packIdxData) {
    return FileOps.createFileWithContent(objectsDir, 'pack/${packName}.pack',
        packData, "blob").then((_) {
          return FileOps.createFileWithContent(objectsDir,
              'pack/${packName}.idx', packIdxData, "blob");
        });
  }

  Future _processClone(chrome.DirectoryEntry gitDir, GitRef localHeadRef,
      HttpFetcher fetcher) {
    return FileOps.createFileWithContent(gitDir, "HEAD",
        "ref: ${localHeadRef.name}\n", "Text").then((_) {
      return FileOps.createFileWithContent(gitDir, localHeadRef.name,
          localHeadRef.sha, "Text").then((_) {
        return fetcher.fetchRef([localHeadRef.sha], null, null, _options.depth,
            null, nopFunction, nopFunction).then((PackParseResult result) {
          Uint8List packData = result.data;
          List<int> packSha = packData.sublist(packData.length - 20);
          Uint8List packIdxData = PackIndex.writePackIndex(result.objects,
              packSha);
          // get a view of the sorted shas.
          int offset = 4 + 4 + (256 * 4);
          Uint8List sortedShas = packIdxData.sublist(offset,
              offset + result.objects.length * 20);
          crypto.SHA1 sha1 = new crypto.SHA1();
          sha1.add(sortedShas);
          String packNameSha = shaBytesToString(sha1.close());

          String packName = 'pack-${packNameSha}';
          return gitDir.createDirectory('objects').then(
              (chrome.DirectoryEntry objectsDir) {
            return _createPackFiles(objectsDir, packName, packData,
                packIdxData).then((_) {
              PackIndex packIdx = new PackIndex(packIdxData.buffer);
              Pack pack = new Pack(packData, _options.store);
              _options.store.loadWith(objectsDir, [new PackEntry(pack,
                  packIdx)]);
              //TODO add progress
              //progress({pct: 95, msg: "Building file tree from pack. Be patient..."});
              return _createCurrentTreeFromPack(_options.root, _options.store,
                  localHeadRef.sha);
            });
          });
        });
      });
    });
  }
}

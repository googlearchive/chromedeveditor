// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.commands.clone;

import 'dart:async';
import 'dart:typed_data';
import 'dart:html';

import 'package:chrome_gen/chrome_app.dart' as chrome;
import 'package:crypto/crypto.dart' as crypto;

import '../file_operations.dart';
import '../git_http_fetcher.dart';
import '../git_object.dart';
import '../git_objectstore.dart';
import '../git_object_utils.dart';
import '../git_pack.dart';
import '../git_pack_index.dart';
import '../git_upload_pack_parser.dart';
import '../git_utils.dart';

class GitOptions {
  chrome.DirectoryEntry root;
  ObjectStore store;
  String url;
  int depth;
  String branch;
  String username;
  String password;

  // progress function.
  var progress;

}

nopFunction() {}

class Clone {

  GitOptions _options;

  Future _createCurrentTreeFromPack(chrome.DirectoryEntry dir, ObjectStore store,
      String headSha) {
    return store.retrieveObject(headSha, ObjectTypes.COMMIT).then(
        (CommitObject commit) {
          window.console.log(commit);
          window.console.log(commit.toString());
          return ObjectUtils.expandTree(dir, store, commit.treeSha);
    });
  }

  // TODO error handling.
  Future _checkDirectory(chrome.DirectoryEntry dir, ObjectStore store, ferror) {

    return FileOps.listFiles(dir).then((entries) {
      if (entries.length == 0) {
        throw "error";
        //error({type: errutils.CLONE_DIR_NOT_INTIALIZED, msg: errutils.CLONE_DIR_NOT_INTIALIZED_MSG});
      } else if (entries.length != 1 || entries[0].isFile
          || entries[0].name != '.git') {
        throw "error";
        //error({type: errutils.CLONE_DIR_NOT_EMPTY, msg: errutils.CLONE_DIR_NOT_EMPTY_MSG});
      } else {
        return FileOps.listFiles(store.objectDir).then((entries) {
          if (entries.length > 1) {
            throw "";
            //error({type: errutils.CLONE_GIT_DIR_IN_USE, msg: errutils.CLONE_GIT_DIR_IN_USE_MSG});
          } else if (entries.length == 1) {
            if (entries[0].name == "pack") {
              return store.objectDir.getDirectory('pack').then(
                  (chrome.DirectoryEntry packDir) {
                return FileOps.listFiles(packDir).then((entries) {
                  if (entries.length > 0) {
                    throw "";
                    //error({type: errutils.CLONE_GIT_DIR_IN_USE, msg: errutils.CLONE_GIT_DIR_IN_USE_MSG});
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

  Future _createInitialConfig(bool shallow, GitRef localHeadRef) {
    GitConfig config = new GitConfig();
    config.url = _options.url;
    config.time = new DateTime.now();

    if (_options.depth && shallow) {
      config.shallow = shallow;
    }

    if (localHeadRef != null) {
      config.remoteHeads[localHeadRef.name]= localHeadRef.sha;
    }
    return _options.store.setConfig(config);
  }

  Clone(this._options) {
    if (_options.branch == null) _options.branch = 'master';
    if (_options.progress == null) {
      _options.progress = nopFunction();
    }
  }

  Future _createPackFiles(chrome.DirectoryEntry objectsDir, String packName,
      Uint8List packData, Uint8List packIdxData) {
    return FileOps.createFileWithContent(objectsDir, 'pack/${packName}.pack',
        packData, "blob").then((_) {
          return FileOps.createFileWithContent(objectsDir,
              'pack/${packName}.idx', packIdxData, "blob");
        });
  }

  Future _something(chrome.DirectoryEntry gitDir, GitRef localHeadRef,
      HttpFetcher fetcher) {
    return FileOps.createFileWithContent(gitDir, "HEAD",
        "ref: ${localHeadRef.name}\n", "Text").then((_) {
      return FileOps.createFileWithContent(gitDir, localHeadRef.name,
          localHeadRef.sha, "Text").then((_) {
        return fetcher.fetchRef([localHeadRef], null, null, _options.depth,
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

  Future clone() {

    HttpFetcher fetcher = new HttpFetcher(_options.store, "origin",
        _options.url, _options.username, _options.password);

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
            } else if (ref.name == "refs/heads/" + _options.branch) {
              localHeadRef = ref;
            } else if (ref.name.indexOf("refs/heads/") == 0) {
              if (ref.sha == remoteHead) {
                remoteHeadRef = ref;
              }
            }
          });

          if (localHeadRef == null) {
            if (_options.branch == null) {
              //error({type: errutils.REMOTE_BRANCH_NOT_FOUND, msg: errutils.REMOTE_BRANCH_NOT_FOUND_MSG});
              return null;
            } else {
              localHeadRef = remoteHeadRef;
            }
          }
          return _something(gitDir, localHeadRef, fetcher);
        });
      });
    });
  }
}
// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.objectstore;

import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:html';
import 'dart:js';
import 'dart:typed_data';

import 'package:chrome_gen/chrome_app.dart' as chrome;
import 'package:crypto/crypto.dart' as crypto;

import 'file_operations.dart';
import 'git_object.dart';
import 'git_pack.dart';
import 'git_pack_index.dart';
import 'git_utils.dart';

import 'zlib.dart';

/**
 * An objectstore for git objects.
 * TODO(grv): Add unittests, add better docs.
 **/

class GitRef {
  String sha;
  String name;

  GitRef(String sha, String name) {
    this.name = name;
    this.sha = sha;
  }
}

class PackEntry {
  Pack pack;
  PackIndex packIdx;

  PackEntry(this.pack, this.packIdx);
}

class ObjectStore {

  static final GIT_FOLDER_PATH = '.git/';
  static final OBJECT_FOLDER_PATH = 'objects';
  static final HEAD_PATH = 'HEAD';
  static final HEAD_MASTER_REF_PATH = 'refs/head/master';
  static final HEAD_MASTER_SHA = '0000000000000000000000000000000000000000';

  // The root directory of the git checkout the objectstore represents.
  chrome.DirectoryEntry _rootDir;

  // The root directory of the objects the objectstore represnts.
  chrome.DirectoryEntry _objectDir;

  // Git directory path.
  String gitPath = '.git/';

  List<PackEntry> _packs = [];

  ObjectStore(chrome.DirectoryEntry root) {
    _rootDir = root;
  }

  loadWith(chrome.DirectoryEntry objectDir, List<PackEntry> packs) {
    _objectDir = objectDir;
    _packs = packs;
  }

  Future load() {
    return _rootDir.createDirectory(gitPath + OBJECT_FOLDER_PATH).then((
        chrome.DirectoryEntry objectsDir) {
      _objectDir = objectsDir;

      return objectsDir.createDirectory('pack', exclusive: true).then((
          chrome.DirectoryEntry packDir) {
        return FileOps.listFiles(packDir).then((List<chrome.Entry> entries) {
          Iterable<chrome.Entry> packEntries = entries.where((e) => e.name.endsWith('.pack'));

          return Future.forEach(packEntries, (chrome.Entry entry) {
            _readPackEntry(packDir, entry);
          });
        });
      });
    });
  }

  Future<chrome.FileEntry> createNewRef(String refName, String sha) {
    String path = GIT_FOLDER_PATH + refName;
    String content = sha + '\n';
    return FileOps.createFileWithContent(_rootDir, path, content, "Text");
  }

  Future<chrome.FileEntry> setHeadRef(String refName, String sha) {
    String content = 'ref: ${refName}\n';
    return FileOps.createFileWithContent(_rootDir, gitPath + HEAD_PATH,
        content, "Text");
  }

  Future<String> getHeadRef() {
    return _rootDir.getFile(gitPath + HEAD_PATH).then((chrome.ChromeFileEntry entry) {
      entry.readText().then((String content) {
        Completer completer = new Completer();
        // get rid of the initial 'ref: ' plus newline at end.
        String headRefname = content.substring(5).trim();
        completer.complete(headRefname);
      });
    });
  }

  Future<String> getHeadSha() {
    return getHeadRef().then((String headRefName)
        => _getHeadForRef(headRefName));
  }

  Future<String> getAllHeads() {
    return _rootDir.getDirectory('.git/refs/heads').then((
        chrome.DirectoryEntry dir) {
      return FileOps.listFiles(dir).then((List<chrome.Entry> entries) {
        List<String> branches;
        Completer completer = new Completer();
        entries.forEach((chrome.Entry entry) {
          branches.add(entry.name);
        });
        completer.complete(branches);
      });
    });
  }

  Future<String> _getHeadForRef(String headRefName) {
    return FileOps.readFile(_rootDir, GIT_FOLDER_PATH + headRefName, "Text")
      .then((String content) => content.substring(0, 40));
  }

  Future _readPackEntry(chrome.DirectoryEntry packDir,
      chrome.ChromeFileEntry entry) {
    return entry.readBytes().then((chrome.ArrayBuffer packData) {
      return FileOps.readFile(packDir, entry.name.substring(0,
          entry.name.lastIndexOf('.pack')) + '.idx', 'ArrayBuffer').then(
          (chrome.ArrayBuffer idxData) {
            Pack pack = new Pack(new Uint8List.fromList(
                packData.getBytes()), this);

            PackIndex packIdx = new PackIndex(new Uint8List.fromList(
                idxData.getBytes()).buffer);
            _packs.add(new PackEntry(pack, packIdx));
            return new Future.value();
      });
    });
  }

  Future<chrome.FileEntry> _findLooseObject(String sha) {
    return _objectDir.getFile(sha.substring(0, 2) + '/' + sha.substring(2));
  }

  Future _findPackedObject(Uint8List shaBytes) {
    Completer completer = new Completer();

    _packs.forEach((PackEntry packEntry) {
      int offset = packEntry.packIdx.getObjectOffset(shaBytes);

    });
    for (var i = 0; i < _packs.length; ++i) {
      int offset = _packs[i].packIdx.getObjectOffset(shaBytes);

      if (offset != -1) {
        //completer.complete(offset, _packs[i].pack);
      }
    }

    //TODO complete with error.
    return completer.future;
  }

  Future _retrieveObject(String sha, String objType) {
    String dataType = "ArrayBuffer";
    if (objType == "Commit") {
      dataType = "Text";
    }

    Completer completer = new Completer();
    retrieveRawObject(sha, dataType).then((LooseObject object) {
      completer.complete(GitObject.make(sha, objType, object.data));
    });

    return completer.future;
  }

  Future retrieveRawObject(dynamic sha, String dataType) {
    Uint8List shaBytes;
    if (sha is Uint8List) {
      shaBytes = sha;
      sha = shaBytesToString(shaBytes);
    } else {
      shaBytes = shaToBytes(sha);
    }

    Completer completer = new Completer();

    return this._findLooseObject(sha).then((chrome.ChromeFileEntry entry) {
      return entry.readBytes().then((chrome.ArrayBuffer buffer) {
        chrome.ArrayBuffer inflated = Zlib.inflate(
            new Uint8List.fromList(buffer.getBytes()), 0).buffer;

        if (dataType == 'Raw' || dataType == 'ArrayBuffer') {
          // TODO do trim buffer and return completer ;
          var buff;
          completer.complete(new LooseObject(buff));
        } else {
          return FileOps.readBlob(new Blob(inflated.getBytes())).then((String data) {
            completer.complete(new LooseObject(data));
          });
        }
      });
    }, onError:(e){
      this._findPackedObject(shaBytes).then((x) {
        dataType = dataType == 'Raw' ? 'ArrayBuffer' : dataType;
        //TODO do something with pack
        //pack.matchAndExpandObjectAtOffset(offset, dataType, function(object){
          //callback(object);
        //});
      }, onError: (e) {
        throw "Can't find object with SHA " + sha;
      });
    });
  }


  Future _getCommitGraph(List<String> headShas, int limit) {
    List<CommitObject> commits = [];
    Map<String, bool> seen = {};


    Future walkLevel(List<String> shas) {
      List<String> nextLevel;

      return Future.forEach(shas, (String sha) {
        Completer completer = new Completer();
        if (seen[sha]) {
          completer.complete();
          return completer.future;
        }

        seen[sha] = true;

        return _retrieveObject(sha, 'Commit').then((CommitObject commitObj) {
          nextLevel.addAll(commitObj.parents);
          int i = commits.length - 1;
          for (; i >= 0; i--) {
            if (commits[i].author.timestamp > commitObj.author.timestamp) {
              commits.insert(i + 1, commitObj);
              break;
            }
          }
          if (i < 0) {
            commits.insert(0, commitObj);
          }

          completer.complete();
          return completer.future;
      }).then((_) {

        if (commits.length >= limit || nextLevel.length == 0) {
          return new Future.value();
        } else {
          return walkLevel(nextLevel);
        }
      });
      });
    }
    return walkLevel(headShas).then((_) => commits);
  }

  Future_getCommitsForPush(List<GitRef> baseRefs, Map<String, String> remoteHeads) {
    // special case of empty remote.
    if (baseRefs.length == 1 && baseRefs[0].sha == HEAD_MASTER_SHA) {
      baseRefs[0].name = HEAD_MASTER_REF_PATH;
    }

    // find the remote branch corresponding to the local one.
    GitRef remoteRef, headRef;
    getHeadRef().then((String headRefName) {
      remoteRef = baseRefs.firstWhere((GitRef ref) => ref.name == headRefName);
      Map<String, bool> remoteShas;
      // Didn't find a remote branch for the local branch.
      if (remoteHeads.isNotEmpty) {
        remoteRef.name = 'headRef';
        remoteRef.sha = HEAD_MASTER_SHA;

        remoteHeads.forEach((String headName, String sha) {
        remoteShas[sha] = true;
        });
      }

      nonFastForward() {
        //TODO throw some error.
      }

      Future checkRemoteHead() {

        Completer completer = new Completer();

        // Check if the remote head exists in the local repo.
        if (remoteRef.sha != HEAD_MASTER_SHA) {
          return _retrieveObject(remoteRef.sha, 'Commit').then((obj) => obj,
              onError: (e) {
            //TODO support non-fast forward.
            nonFastForward();
            completer.completeError(e);
          });
        }
        completer.complete();
        return completer.future;
      }


      checkRemoteHead().then((_) {

        return _getHeadForRef(headRefName).then((String sha) {

          if (sha == remoteRef.sha) {

          // no changes to push.
            return new Future.value();
          }

          //remoteRef.head = sha;
          remoteRef.sha = sha;

         //TODO handle case of new branch with no commits.

          // At present local merge commits are not supported. Thus, look for
          // non-brancing list of ancestors of the current commit.
          var commits = [];
          Future getNextCommit(String sha) {

            //TODO return retrieveObject result
            return _retrieveObject(sha, 'Commit').then((CommitObject commitObj) {
              var rawObj;
              Completer completer = new Completer();
              commits.add({"commit": commitObj, "raw": rawObj});
              if (commitObj.parents.length > 1) {
                // this means a local merge commit.
                nonFastForward();
                completer.completeError("");
              } else if(commitObj.parents.length == 0 ||
                commitObj.parents[0] == remoteRef.sha || remoteShas[commitObj.parents[0]]) {
                // callback commits, remoteRef;
                completer.complete();
              } else {
                return getNextCommit(commitObj.parents[0]);
              }

              return completer.future;

            }, onError: (e) {
              nonFastForward();
            });
          }
          return getNextCommit(sha);
        }, onError: (e) {

        // no commits to push.

        });
      });
    });
    return;
  }

  Future _retrieveObjectBlobsAsString(List<String> shas) {
    List blobs;
    return Future.forEach(shas, (String sha) {
      retrieveRawObject(sha, 'Text').then((blob) => blobs.add(blob));
    }).then((_) => blobs);
  }

  Future _retrieveObjectList(List<String> shas, String objType) {
    List objects = [];
    return Future.forEach(shas, (sha) {
      return _retrieveObject(sha, objType).then((object) => objects.add(object));
    }).then((e) => objects);
  }

  Future init() {
    _rootDir.getDirectory('.git').then((chrome.DirectoryEntry gitDir) {
      return load();
    }, onError: (e) {
      // handle error
    });
  }

  Future _init() {
    return _rootDir.createDirectory(gitPath + OBJECT_FOLDER_PATH).then((chrome.DirectoryEntry objectDir) {
      _objectDir = objectDir;
      return FileOps.createFileWithContent(objectDir, gitPath +HEAD_PATH,
          'ref: refs/heads/master\n', 'Text').then((entry) => entry, onError: (e) {
            // throw file error
          });
    }, onError: (e) {
      // throw file error;
    });
  }

  Future _getTreeFromCommitSha(String sha) {
    return _retrieveObject(sha, 'Commit').then((CommitObject commit) {
      _retrieveObject(commit.treeSha, 'Tree').then((rawObject) => rawObject);
    });
  }

  Future _getTreesWithCommits(List<String> shas) {
    List trees = [];

    return Future.forEach(shas, (sha) {
      return _getTreeFromCommitSha(sha).then((tree) => trees.add(tree));
    }).then((_) => trees);
  }

  Future writeRawObject(String type, content) {

    Completer completer = new Completer();
    List<dynamic> blobParts = [];

    int size = 0;
    if (content is Uint8List) {
      size = content.length;
    } else if (content is Blob) {
     size = content.size;
    }

    String header = 'type ${size}' ;

    blobParts.add(header);
    blobParts.add(new Uint8List.fromList([0]));
    blobParts.add(content);

    var reader = new JsObject(context['FileReader']);

    reader['onloadend'] = (var event) {
      chrome.ArrayBuffer buffer = reader['result'];
      crypto.SHA1 sha1 = new crypto.SHA1();
      Uint8List data = new Uint8List.fromList(buffer.getBytes());
      sha1.add(data);
      List<int> digest = sha1.close();
      return _findPackedObject(digest).then((_) {
        completer.complete(digest);
      }, onError: (e) {
        return _storeInFile(shaBytesToString(digest), data);
      });
    };

    reader['onerror'] = (var domError) {
      completer.completeError(domError);
    };

    reader.callMethod('readAsArrayBuffer', [new Blob(blobParts)]);
    return completer.future;
  }

  Future _storeInFile(String digest, Uint8List store) {
    String subDirName = digest.substring(0,2);
    String objectFileName = digest.substring(2);

    return _objectDir.createDirectory(subDirName).then(
        (chrome.DirectoryEntry dirEntry) {
      return dirEntry.createDirectory(objectFileName).then(
          (chrome.FileEntry fileEntry) {
        fileEntry.file().then((File file) {
          Completer completer = new Completer();
          if (file.size == 0) {
            chrome.ArrayBuffer content = Zlib.deflate(store).buffer;
            fileEntry.createWriter().then((fileWriter) {
              fileWriter.write(new Blob([content]));
              completer.complete(digest);
            }, onError: (e) {

            });
          } else {
            completer.complete(digest);
          }
          completer.future;
        }, onError: (e) {

        });
      }, onError: (e) {

      });
    }, onError: (e) {

    });
  }

  Future _writeTree(List treeEntries) {
    List blobParts = [];
    treeEntries.forEach((tree) {
      blobParts.add(tree.isBlob ? '100644 ' : '40000 ' + tree.name);
      blobParts.add(new Uint8List.fromList([0]));
      blobParts.add(tree.sha);
    });

    return writeRawObject('tree', new Blob(blobParts));
  }

  Future getConfig() {
    return FileOps.readFile(_rootDir, '.git/config.json', 'Text').then(
        (String configStr) => JSON.decode(configStr), onError: (e) {
      //TODO handle errors.
    });
  }

  Future setConfig(config) {
    String configStr = JSON.encode(config);
    return FileOps.createFileWithContent(_rootDir, '.git/config.json', configStr, 'Text');
  }

  Future updateLastChange(config) {
    doUpdate(config) {
      config.time = new DateTime.now();
      return setConfig(config);
    }
    if (config) {
      return doUpdate(config);
    }
    return this.getConfig().then((config) => doUpdate(config));
  }
}
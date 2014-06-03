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

import 'package:chrome/chrome_app.dart' as chrome;

import 'config.dart';
import 'constants.dart';
import 'exception.dart';
import 'fast_sha.dart';
import 'file_operations.dart';
import 'commands/index.dart';
import 'object.dart';
import 'object_utils.dart';
import 'pack.dart';
import 'pack_index.dart';
import 'utils.dart';

import 'zlib.dart';

/**
 * An objectstore for git objects.
 *
 * TODO(grv): Add unittests, add better docs.
 */
class GitRef {
  String sha;
  String name;
  String type;
  String head;
  String localHead;
  dynamic remote;

  GitRef(this.sha, this.name, [this.type, this.remote]);

  String getPktLine() => '${sha} ${head} ${name}';

  String toString() => getPktLine();
}

class PackEntry {
  Pack pack;
  PackIndex packIdx;

  PackEntry(this.pack, this.packIdx);
}

class CommitPushEntry {
  List<CommitObject> commits = [];
  GitRef ref;

  CommitPushEntry(this.commits, this.ref);
}

class FindPackedObjectResult {
  Pack pack;
  int offset;
  FindPackedObjectResult(this.pack, this.offset);
}

class CommitGraph {
  List<CommitObject> commits;
  List<String> nextLevel;
  CommitGraph(this.commits, this.nextLevel);
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
  chrome.DirectoryEntry objectDir;

  // Git directory path.
  String gitPath = '.git/';

  List<PackEntry> packs = [];

  Config config;

  Index index;

  chrome.DirectoryEntry get root => _rootDir;

  ObjectStore(chrome.DirectoryEntry root) {
    _rootDir = root;
    index = new Index(this);
    config = new Config();
  }

  loadWith(chrome.DirectoryEntry objectDir, List<PackEntry> packs) {
    this.objectDir = objectDir;
    this.packs = packs;
  }

  Future load() {
    return _rootDir.getDirectory(GIT_FOLDER_PATH).then((gitDir) {
      return gitDir.getDirectory(OBJECT_FOLDER_PATH).then((objectsDir) {

        objectDir = objectsDir;
        return objectsDir.getDirectory('pack').then((
            chrome.DirectoryEntry packDir) {
          return FileOps.listFiles(packDir).then((List<chrome.Entry> entries) {
            Iterable<chrome.Entry> packEntries = entries.where((e)
                => e.name.endsWith('.pack'));

            return Future.forEach(packEntries, (chrome.Entry entry) {
              return _readPackEntry(packDir, entry);
            }).then((_) {
              return _initHelper();
            });
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
    return _rootDir.getFile(gitPath + HEAD_PATH).then((chrome.FileEntry entry) {
      return FileOps.readBytes(entry).then((List<int> data) {
        // Get rid of the initial 'ref: ' plus newline at end.
        String content = UTF8.decode(data);
        return content.substring(5).trim();
      });
    });
  }

  Future<String> getHeadSha() {
    return getHeadRef().then((String headRefName)
        => getHeadForRef(headRefName));
  }

  Future<List<String>> getLocalHeads() {
    return _rootDir.getDirectory('.git/refs/heads').then((
        chrome.DirectoryEntry dir) {
      return FileOps.listFiles(dir).then((List<chrome.Entry> entries) {
        return entries.map((entry) => entry.name).toList();
      });
    });
  }

  Future<List<String>> getRemoteHeads() {
    return _rootDir.getDirectory('.git/refs/remotes/origin').then((
        chrome.DirectoryEntry dir) {
      return FileOps.listFiles(dir).then((List<chrome.Entry> entries) {
        return entries.map((entry) => entry.name).toList();
      });
    });
  }

  Future<String> getHeadForRef(String headRefName) {
    return FileOps.readFileText(_rootDir, gitPath + headRefName).then((content) {
      return content.substring(0, 40);
    });
  }

  Future<String> getRemoteHeadForRef(String headRefName) {
    String path = gitPath + REFS_REMOTE_HEADS + headRefName.split('/').last;
    return FileOps.readFileText(_rootDir, path).then((String content) {
      return content.substring(0, 40);
    });
  }

  Future<List<String>> getLocalBranches() => getLocalHeads();

  Future<List<String>> getRemoteBranches() => getRemoteHeads();

  /**
   * Returns the name of the current branches.
   */
  Future<String> getCurrentBranch() {
    return getHeadRef().then((ref) {
      return ref.substring('refs/heads/'.length);
    });
  }

  Future _readPackEntry(chrome.DirectoryEntry packDir, chrome.FileEntry entry) {
    return FileOps.readBytes(entry).then((List<int> packData) {
      String path = entry.name.substring(0, entry.name.lastIndexOf('.pack')) +
          '.idx';
      return FileOps.readFileBytes(packDir, path).then((List<int> indexData) {
        Pack pack = new Pack(packData, this);
        PackIndex packIdx = new PackIndex(indexData);
        packs.add(new PackEntry(pack, packIdx));
        return new Future.value();
      });
    });
  }

  Future<chrome.Entry> _findLooseObject(String sha) {
    return objectDir.getFile(sha.substring(0, 2) + '/' + sha.substring(2));
  }

  FindPackedObjectResult findPackedObject(List<int> shaBytes) {
    for (var i = 0; i < packs.length; ++i) {
      int offset = packs[i].packIdx.getObjectOffset(shaBytes);

      if (offset != -1) {
        return new FindPackedObjectResult(packs[i].pack, offset);
      }
    }
    // TODO More specific error.
    return throw("Not found.");
  }

  Future<GitObject> retrieveObject(String sha, String objType) {
    String dataType = (objType == ObjectTypes.COMMIT_STR ? "Text"
        : "ArrayBuffer");
    return retrieveRawObject(sha, dataType).then((object) {
      if (objType == 'Raw') {
        return object;
      } else if (object is LooseObject) {
        return GitObject.make(sha, objType, object.data, object);
      } else {
        return GitObject.make(sha, objType, object.data);
      }
    });
  }

  Future<GitObject> retrieveRawObject(dynamic sha, String dataType) {
    Uint8List shaBytes;
    if (sha is Uint8List) {
      shaBytes = sha;
      sha = shaBytesToString(shaBytes);
    } else {
      shaBytes = shaToBytes(sha);
    }

    return this._findLooseObject(sha).then((chrome.ChromeFileEntry entry) {
      return entry.readBytes().then((chrome.ArrayBuffer buffer) {
        chrome.ArrayBuffer inflated = new chrome.ArrayBuffer.fromBytes(
            Zlib.inflate(new Uint8List.fromList(buffer.getBytes())).data);
        if (dataType == 'Raw' || dataType == 'ArrayBuffer') {
          // TODO do trim buffer and return completer ;
          var buff;
          return new LooseObject(inflated);
        } else {
          return FileOps.readBlob(new Blob(
              [new Uint8List.fromList(inflated.getBytes())]), 'Text').then(
              (data) => new LooseObject(data));
        }
      });
    }, onError:(e) {
      try {
        FindPackedObjectResult obj = this.findPackedObject(shaBytes);
        dataType = dataType == 'Raw' ? 'ArrayBuffer' : dataType;
        return obj.pack.matchAndExpandObjectAtOffset(obj.offset, dataType).then(
            (PackedObject packed) {
          if (dataType == 'Text') {
            return FileOps.readBlob(new Blob([packed.data]), 'Text').then(
                (String data) {
              packed.data = data;
              return packed;
            });
          } else {
            return packed;
          }
        });
      } catch (e) {
        throw "Can't find object with SHA " + sha;
      }
    });
  }


  Future<CommitGraph> getCommitGraph(List<String> headShas, [int limit]) {
    List<CommitObject> commits = [];
    Map<String, bool> seen = {};


    Future<CommitGraph> walkLevel(List<String> shas) {
      List<String> nextLevel = [];

      return Future.forEach(shas, (String sha) {
        Completer completer = new Completer();
        if (seen[sha] != null) return null;

        seen[sha] = true;

        return retrieveObject(sha, ObjectTypes.COMMIT_STR).then(
            (CommitObject commitObj) {
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

          return null;
        }).catchError((e) => null);
      }).then((_) {
        if ((limit != null && commits.length >= limit) ||
            nextLevel.length == 0) {
          return new Future.value(new CommitGraph(commits, nextLevel));
        } else {
          return walkLevel(nextLevel);
        }
      });
    }
    return walkLevel(headShas).then((_) => new CommitGraph(commits, []));
  }

  /**
   * Returns the lowest common ancestor for the given [headShas].
   */
  Future<String> getCommonAncestor(List<String> headShas) {
    List<CommitObject> commits = [];
    Map<String, List> seen = {};

    List nodes = [];
    headShas.forEach((headSha) {
      nodes.add({"sha": headSha, "head" : headSha});
    });

    String ancestor;
    Future<String> walkLevel(List nodes) {
    List<Map> nextLevel = [];
      return Future.forEach(nodes, (Map node) {
        // Already found the lowest common ancestor.
        if (ancestor != null) {
          return null;
        }

        String sha = node["sha"];
        if (seen[sha] != null) {
          if (!seen[sha].any((String head) => node["head"] == head)) {
            seen[sha].add(node["head"]);
            if (seen[sha].length == headShas.length) {
              ancestor = sha;
            }
          }
          return null;
        }

        seen[sha] = [node["head"]];

        return retrieveObject(sha, ObjectTypes.COMMIT_STR).then(
            (CommitObject commitObj) {
          commitObj.parents.forEach((String parent) {
            nextLevel.add({"sha" : parent, "head" : node["head"]});
          });
        }).catchError((e) => null);
      }).then((_) {
        if (nextLevel.length == 0) {
          if (ancestor == null) {
            throw "error in finding common ancestor.";
          } else {
            return ancestor;
          }
        } else {
          if (ancestor != null) {
            return ancestor;
          }
          return walkLevel(nextLevel);
        }
      });
    }
    return walkLevel(nodes);
  }

  // TODO (grv) : Support non fast forward push.
  void _nonFastForwardPush() {
    throw new GitException(GitErrorConstants.GIT_PUSH_NON_FAST_FORWARD);
    //TODO throw some error.
  }

  Future _checkRemoteHead(GitRef remoteRef) {
    // Check if the remote head exists in the local repo.
    if (remoteRef.sha != HEAD_MASTER_SHA) {
      return retrieveObject(remoteRef.sha, ObjectTypes.COMMIT_STR).then((r) => r,
        onError: (e) {
          _nonFastForwardPush();
      });
    }
    return new Future.value();
  }


  Future<CommitPushEntry> getCommitsForPush(List<GitRef> baseRefs,
      Map<String, String> remoteHeads) {
    // special case of empty remote.
    if (baseRefs.length == 1 && baseRefs.first.sha == HEAD_MASTER_SHA) {
      baseRefs[0].name = HEAD_MASTER_REF_PATH;
    }

    // find the remote branch corresponding to the local one.
    GitRef remoteRef, headRef;
    return getHeadRef().then((String headRefName) {
      remoteRef = baseRefs.firstWhere(
          (GitRef ref) => ref.name == headRefName, orElse: () => null);
      Map<String, bool> remoteShas = {};
      // Didn't find a remote branch for the local branch.
      if (remoteRef == null) {
        remoteRef = new GitRef(HEAD_MASTER_SHA, headRefName);
        remoteHeads.forEach((String headName, String sha) {
          remoteShas[sha] = true;
        });
      }
      return _checkRemoteHead(remoteRef).then((_) {
        return getHeadForRef(headRefName).then((String sha) {
          if (sha == remoteRef.sha) {
          // no changes to push.
            return new Future.value();
          }

          remoteRef.head = sha;

         //TODO handle case of new branch with no commits.

          // At present local merge commits are not supported. Thus, look for
          // non-brancing list of ancestors of the current commit.
          return _getCommits(remoteRef, remoteShas, sha);

        }, onError: (e) {
          throw new GitException(GitErrorConstants.GIT_BRANCH_NOT_FOUND);
        });
      });
    });
  }

  Future<CommitPushEntry> _getCommits(GitRef remoteRef,
      Map<String, bool> remoteShas, String sha) {
    var commits = [];
    Future<CommitPushEntry> getNextCommit(String sha) {

      return retrieveObject(sha, ObjectTypes.COMMIT_STR).then((
          CommitObject commitObj) {

        Completer completer = new Completer();
        commits.add(commitObj);

        if (commitObj.parents.length > 1) {
          // this means a local merge commit.
          _nonFastForwardPush();
          completer.completeError("");
        } else if (commitObj.parents.length == 0
            || commitObj.parents.first == remoteRef.sha
            || remoteShas[commitObj.parents[0]] == true) {
          completer.complete(new CommitPushEntry(commits, remoteRef));
        } else {
          return getNextCommit(commitObj.parents.first);
        }

        return completer.future;

      }, onError: (e) {
        _nonFastForwardPush();
      });
    }
    return getNextCommit(sha);
  }

  Future<List<LooseObject>> retrieveObjectBlobsAsString(List<String> shas) {
    List<LooseObject> blobs = [];
    return Future.forEach(shas, (String sha) {
      return retrieveRawObject(sha, 'Text').then((blob) => blobs.add(blob));
    }).then((_) => blobs);
  }

  Future retrieveObjectList(List<String> shas, String objType) {
    List objects = [];
    return Future.forEach(shas, (sha) {
      return retrieveObject(sha, objType).then((object) => objects.add(object));
    }).then((e) => objects);
  }

  Future init() {
    return _rootDir.getDirectory('.git').then((chrome.DirectoryEntry gitDir) {
      return load();
    }, onError: (FileError e) {
      return _init();
      // TODO(grv) : error handling.
      /*if (e.code == FileError.NOT_FOUND_ERR) {
        return _init();
      } else {
        throw e;
      }*/
    });
  }

  Future _init() {
    return FileOps.createDirectoryRecursive(_rootDir,
        gitPath + OBJECT_FOLDER_PATH).then((chrome.DirectoryEntry objectDir) {
      this.objectDir = objectDir;
      return FileOps.createFileWithContent(_rootDir, gitPath + HEAD_PATH,
          'ref: refs/heads/master\n', 'Text').then((entry)  {
            return _initHelper();
          }, onError: (e) {
            print(e);
            throw e;
          });
    }, onError: (e) {
      throw e;
    });
  }

  Future _initHelper() {
    return index.init().then((_) {
      return readConfig().then((Config config) {
        this.config = config;
        return new Future.value();
      });
    });
  }

  Future<TreeObject> _getTreeFromCommitSha(String sha) {
    return retrieveObject(sha, ObjectTypes.COMMIT_STR).then(
        (CommitObject commit) {
     return  retrieveObject(commit.treeSha, ObjectTypes.TREE_STR).then(
         (rawObject) => rawObject);
    });
  }

  Future<List<TreeObject>> getTreesFromCommits(List<String> shas) {
    List<TreeObject> trees = [];

    return Future.forEach(shas, (String sha) {
      return _getTreeFromCommitSha(sha).then((TreeObject tree) => trees.add(
          tree));
    }).then((_) => trees);
  }

  Future<String> writeRawObject(String type, content) {
    Completer completer = new Completer();
    List<dynamic> blobParts = [];

    int size = 0;
    if (content is Uint8List) {
      size = content.length;
    } else if (content is Blob) {
      size = content.size;
    } else if (content is String) {
      size = content.length;
    } else {
      // TODO: Check expected types here.
      throw "Unexpected content type.";
    }

    String header = '${type} ${size}' ;
    blobParts.add(header);
    blobParts.add(new Uint8List.fromList([0]));
    blobParts.add(content);

    var reader = new JsObject(context['FileReader']);

    reader['onloadend'] = (var event) {
      var result = reader['result'];
      FastSha sha1 = new FastSha();
      Uint8List resultList;

      if (result is JsObject) {
        var arrBuf = new chrome.ArrayBuffer.fromProxy(result);
        resultList = new Uint8List.fromList(arrBuf.getBytes());
      } else if (result is ByteBuffer) {
        resultList = new Uint8List.view(result);
      } else if (result is Uint8List) {
        resultList = result;
      } else {
        // TODO: Check expected types here.
        throw "Unexpected result type.";
      }

      sha1.add(resultList);
      Uint8List digest = new Uint8List.fromList(sha1.close());

      try {
        FindPackedObjectResult obj = findPackedObject(digest);
        completer.complete(shaBytesToString(digest));
      } catch (e) {
        _storeInFile(shaBytesToString(digest), resultList).then((str) {
          completer.complete(str);
        });
      }
    };

    reader['onerror'] = (var domError) {
      completer.completeError(domError);
    };

    reader.callMethod('readAsArrayBuffer', [new Blob(blobParts)]);
    return completer.future;
  }

  Future<String> _storeInFile(String digest, Uint8List store) {
    String subDirName = digest.substring(0,2);
    String objectFileName = digest.substring(2);

    return objectDir.createDirectory(subDirName).then(
        (chrome.DirectoryEntry dirEntry) {
      return dirEntry.createFile(objectFileName).then(
          (chrome.ChromeFileEntry fileEntry) {
        return fileEntry.file().then((File file) {

          Future<String> writeContent() {
            chrome.ArrayBuffer content = new chrome.ArrayBuffer.fromBytes(
                Zlib.deflate(store).data);
            // TODO: Use fileEntry.createWriter() once implemented in ChromeGen.
            return fileEntry.writeBytes(content).then((_) {
              return digest;
            });
          }

          return writeContent();
        }, onError: (e) {

        });
      }, onError: (e) {

      });
    }, onError: (e) {

    });
  }

  /**
   * Writes a given tree onto disk, and returns the treeSha.
   */
  Future<String> writeTree(List treeEntries) {
    List blobParts = [];
    treeEntries.forEach((TreeEntry tree) {
      blobParts.add((tree.isBlob ? '100644 ' : '40000 ') + tree.name);
      blobParts.add(new Uint8List.fromList([0]));
      blobParts.add(tree.shaBytes);
    });

    return writeRawObject(ObjectTypes.TREE_STR, new Blob(blobParts));
  }

  Future<Config> readConfig() {
    return FileOps.readFileText(_rootDir, '.git/config.json').then(
        (String configStr) => new Config(configStr),
        // TODO: handle errors / build default GitConfig.
        onError: (e) => this.config);
  }

  Future<Entry> writeConfig() {
    String configStr = config.toJson();
    return FileOps.createFileWithContent(_rootDir, '.git/config.json',
        configStr, 'Text');
  }
}

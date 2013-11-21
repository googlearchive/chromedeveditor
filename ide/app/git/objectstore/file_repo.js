var FileObjectStore = (function() {

  String.prototype.endsWith = function(suffix){
    return this.lastIndexOf(suffix) == (this.length - suffix.length);
  }

  var fileObjectStore = function(rootDir) {
     this.dir = rootDir;
     this.packs = [];
  }

  fileObjectStore.prototype = {
    haveRefs: function(){
      return [];
    },
    load : function(callback){
      var rootDir = this.dir;
      var thiz = this;
      var fe = this.fileError;

      rootDir.getDirectory('.git/objects', {create:true}, function(objectsDir){
        thiz.objectsDir = objectsDir;
        objectsDir.getDirectory('pack', {create:true}, function(packDir){
          var packEntries = [];
          var reader = packDir.createReader();
          var readEntries = function(){
            reader.readEntries(function(entries){
              if (entries.length){
                for (var i = 0; i < entries.length; i++){
                  if (entries[i].name.endsWith('.pack'))
                    packEntries.push(entries[i]);
                }
                readEntries();
              }
              else{
                if (packEntries.length){
                  var counter = {x : 0};
                  packEntries.forEach(function(entry, i){
                    fileutils.readFile(packDir, entry.name, "ArrayBuffer", function(packData){
                      var nameRoot = entry.name.substring(0, entry.name.lastIndexOf('.pack'));
                      fileutils.readFile(packDir, nameRoot + '.idx', 'ArrayBuffer', function(idxData){
                        thiz.packs.push({pack: new Packer(packData, thiz), idx: new PackIndex(idxData)});
                        counter.x += 1;
                        if (counter.x == packEntries.length){
                          callback();
                        }
                      }, fe);
                    }, fe);
                  });
                }
                else{
                  callback();
                }
              }
            }, fe);
          }
          readEntries();
        }, fe);
      }, fe);
    },
    loadWith : function(objectsDir, packs){
      this.objectsDir = objectsDir;
      this.packs = packs;
    },
    _getCommitGraph : function(headShas, limit, callback){
      var commits = [];
      var thiz = this;
      var seen = {};

      var walkLevel = function(shas, callback){
        var nextLevel = [];
        shas.asyncEach(function(sha, callback){
          if (seen[sha]){
            callback();
            return;
          }
          else{
            seen[sha] = true;
          }
          // it's possible for this to fail since we support shallow clones
          thiz._retrieveObject(sha, 'Commit', function(obj){
            nextLevel = nextLevel.concat(obj.parents);
            var i = commits.length - 1
            for (; i >= 0; i--){
              if (commits[i].author.timestamp > obj.author.timestamp){
                commits.splice(i + 1, 0, obj);
                break;
              }
            }
            if (i < 0){
              commits.unshift(obj);
            }
            callback();
          }, callback);
        }, function(){
          if (commits.length >= limit || nextLevel.length == 0){
            /*var shas = [];
            for (var i = 0; i < commits.length; i++){
              shas.push(commit.sha);
            }*/
            callback(commits, nextLevel);
          }
          else{
            walkLevel(nextLevel, callback);
          }
        });
      }
      walkLevel(headShas, callback);
    },
    _getCommitsForPush : function(baseRefs, remoteHeads, callback, error){

      // special case of empty remote.
      if (baseRefs.length == 1 && baseRefs[0].sha == "0000000000000000000000000000000000000000"){
        baseRefs[0].name = 'refs/heads/master';
      }

      var self = this;
      // find the remote branch corresponding to our local one.
      var remoteRef, headRef;
      this.getHeadRef(function(refName){
        headRef = refName;
        for (var i = 0; i < baseRefs.length; i++){
          if (baseRefs[i].name == headRef){
            remoteRef = baseRefs[i];
            break;
          }
        }

        // Didn't find a remote branch for our local so base the commits we
        // need to push on what we already know about the remote
        var newBranch = !remoteRef;
        var remoteShas = {};
        if (newBranch){
          remoteRef = {
            sha: "0000000000000000000000000000000000000000",
            name: headRef
          }
          for (var remoteHead in remoteHeads){
            var remoteSha = remoteHeads[remoteHead];
            remoteShas[remoteSha] = true;
          }
        }

        var nonFastForward = function(){
          error({type: errutils.PUSH_NON_FAST_FORWARD, msg: errutils.PUSH_NON_FAST_FORWARD_MSG});
        }

        var checkRemoteHead = function(success){
          // See if the remote head exists in our repo.
          if (remoteRef.sha != "0000000000000000000000000000000000000000"){
            self._retrieveObject(remoteRef.sha, 'Commit', success, nonFastForward);
          }
          else{
            success();
          }
        }


        checkRemoteHead(function(){
          self._getHeadForRef(headRef, function(sha){

            if (sha == remoteRef.sha){
              error({type: errutils.PUSH_NO_CHANGES, msg: errutils.PUSH_NO_CHANGES_MSG});
              return;
            }

            remoteRef.head = sha;

            // case of new branch with no new commits
            if (newBranch && remoteShas[sha]){
              callback([], remoteRef);
              return;
            }

            // we don't support local merge commits so finding commits to push should be a
            // matter of looking at a non-branching list of ancestors of the current commit.
            var commits = [];
            var getNextCommit = function(sha){
              self._retrieveObject(sha, 'Commit', function(commit, rawObj){
                commits.push({commit: commit, raw: rawObj});
                if (commit.parents.length > 1){
                  // this would mean a local merge commit. It shouldn't happen,
                  // therefore we've strayed into somewhere we shouldn't be.
                  nonFastForward();
                }
                else if (commit.parents.length == 0 || commit.parents[0] == remoteRef.sha || remoteShas[commit.parents[0]]){
                  callback(commits, remoteRef);
                }
                else{
                  getNextCommit(commit.parents[0]);
                }
              }, nonFastForward);
            }
            getNextCommit(sha);
          },
          function(e){
            // No commits yet
            if (e.code == FileError.NOT_FOUND_ERR){
              error({type: errutils.COMMIT_NO_CHANGES, msg: errutils.COMMIT_NO_CHANGES_MSG});
            }
            else{
              self.fileError(e);
            }
          });
        });

      });

    },
    createNewRef : function(refName, sha, success){
      fileutils.mkfile(this.dir, '.git/' + refName, sha + '\n', success, this.fileError);
    },
    setHeadRef : function(refName, callback){
      fileutils.mkfile(this.dir, '.git/HEAD', 'ref: ' + refName + '\n', callback, this.fileError);
    },
    getHeadRef : function(callback){
      fileutils.readFile(this.dir, '.git/HEAD', 'Text', function(headStr){
        // get rid of the initial 'ref: ' plus newline at end
        var headRefName = headStr.substring(5).trim();
        callback(headRefName);
      },this.fileError);
    },
    getHeadSha : function(callback){
      var self = this;
      this.getHeadRef(function(ref){
        self._getHeadForRef(ref, callback, self.fileError);
      });
    },
    getAllHeads : function(callback){
      var fe = this.fileError;
      this.dir.getDirectory('.git/refs/heads', {create: false}, function(de){
        fileutils.ls(de, function(entries){
          var branches = [];
          entries.forEach(function(entry){
            branches.push(entry.name);
          });
          callback(branches);
        }, fe);
      },
      function(e){
        if (e.code == FileError.NOT_FOUND_ERR){
          callback([]);
        }
        else{
          fe(e);
        }
      });
    },
    _getHeadForRef : function(name, callback, onerror){
      fileutils.readFile(this.dir, '.git/' + name, 'Text', function(data){callback(data.substring(0, 40));}, onerror) ;
    },

    _findLooseObject : function(sha, success, error){
      this.objectsDir.getFile(sha.substring(0,2) + '/' + sha.substring(2), {create:false}, function(fileEntry){
        success(fileEntry);
      },
      function(e){
        error(e);
      });
    },
    _findPackedObject : function(sha, success, error){
      for (var i = 0; i < this.packs.length; i++){
        var offset = this.packs[i].idx.getObjectOffset(sha);
        if (offset != -1){
          success(offset, this.packs[i].pack);
          return;
        }
      }
      error();
    },
    _retrieveRawObject : function(sha, dataType, callback, error){
       var shaBytes;
       if (sha instanceof Uint8Array){
         shaBytes = sha;
         sha = utils.convertBytesToSha(shaBytes);
       }
       else{
         shaBytes = utils.convertShaToBytes(sha);
       }



       var thiz = this;
       this._findLooseObject(sha, function(fileEntry){
         fileutils.readFileEntry(fileEntry, 'ArrayBuffer', function(buf){
           var inflated = utils.inflate(new Uint8Array(buf));
           if (dataType == 'Raw' || dataType == 'ArrayBuffer'){
             var buffer = utils.trimBuffer(inflated);
             callback(new GitObjects.RawLooseObject(buffer));
           }
           else{
             fileutils.readBlob(new Blob([inflated]), dataType, function(data){
              callback(new GitObjects.RawLooseObject(data));
            });
           }
         });
       }, function(e){
           thiz._findPackedObject(shaBytes, function(offset, pack){
             dataType = dataType == 'Raw' ? 'ArrayBuffer' : dataType;
             pack.matchAndExpandObjectAtOffset(offset, dataType, function(object){
              callback(object);
            });
         }, function(){
           if (error) error.call(thiz);
           else throw(Error("Can't find object with SHA " + sha));
         });
       });
    },
    _retrieveBlobsAsStrings : function(shas, callback){
      var blobs =new Array(shas.length),
        self = this;

      shas.asyncEach(function(sha, done, i){
        self._retrieveRawObject(sha, 'Text', function(object){
          blobs[i] = new GitObjects.Blob(sha, object.data);
          done();
         });
      },
      function(){
        callback(blobs);
      });
    },
    _retrieveObjectList : function(shas, objType, callback){
      var objects = new Array(shas.length),
        self = this;

      shas.asyncEach(function(sha, done, i){
        self._retrieveObject(sha, objType, function(obj){
          objects[i] = obj;
          done();
        });
      },
      function(){
        callback(objects);
      });
    },
    _retrieveObject : function(sha, objType, callback, error){
       var dataType = "ArrayBuffer";
       if (objType == "Commit"){
         dataType = "Text";
       }

       this._retrieveRawObject(sha, dataType, function(object){
         callback(new GitObjects[objType](sha, object.data), object);
       }, error);
    },

    init : function(success, error){
      var root = this.dir;
      var self = this;
      this.error = error;
      this.fileError = errutils.fileErrorFunc(error);

      root.getDirectory('.git', {create:false}, function(gitDir){
        self.load(success);
      },
      function(e){
        if (e.code == FileError.NOT_FOUND_ERR){
          self._init(success);
        }
        else{
          self.fileError(e);
        }
      });
    },

    _init : function(success){
      var root = this.dir;
      var self = this;
      fileutils.mkdirs(root, '.git/objects', function(objectsDir){
        self.objectsDir = objectsDir;
        fileutils.mkfile(root, '.git/HEAD', 'ref: refs/heads/master\n', success, self.fileError);
      }, this.fileError);

    },

    _getTreesFromCommits : function(shas, callback){
      var trees = [],
        shaIndex = 0,
        self = this;

      var fillTrees = function(){
        self._getTreeFromCommitSha(shas[shaIndex++], function(tree){
          trees.push(tree);
          if (shaIndex >= shas.length){
            callback(trees);
          }
          else{
            fillTrees();
          }
        });
      }
      fillTrees();
    },
    _getTreeFromCommitSha : function(sha, callback){
      var self = this;
      this._retrieveObject(sha, 'Commit', function(commit){
        self._retrieveObject(commit.tree, 'Tree', callback);
      });
    },
    writeRawObject : function(type, content, callback){
      var bb = [];//new BlobBuilder();
      var size = content.byteLength || content.length || content.size || 0;
      var header = type + ' ' + String(size) ;

      //var store = header + content;

      bb.push(header);
      bb.push(new Uint8Array([0]));
      bb.push(content);
      var thiz = this;
      var fr = new FileReader();
      fr.onloadend = function(e){
        var buf = fr.result;
        var store = new Uint8Array(buf);
        var digest = Crypto.SHA1(store);
        thiz._findPackedObject(utils.convertShaToBytes(digest), function(){callback(digest);}, function(){
          thiz._storeInFile(digest, store, callback);
        });
      }

      fr.readAsArrayBuffer(new Blob(bb));
    },

    _storeInFile : function(digest, store, callback){
      var subDirName = digest.substr(0,2);
      var objectFileName = digest.substr(2);

      this.objectsDir.getDirectory(subDirName, {create:true}, function(dirEntry){
        dirEntry.getFile(objectFileName, {create:true}, function(fileEntry){
          fileEntry.file(function(file){
             if(!file.size){
               var content = utils.deflate(store);
               fileEntry.createWriter(function(fileWriter){
                 fileWriter.write(new Blob([content]));;
                 callback(digest);
               }, utils.errorHandler);
             }
             else{
               callback(digest);
             }
          }, utils.errorHandler);

        }, utils.errorHandler);

      }, utils.errorHandler);
    },

    _writeTree : function(treeEntries, success){
      var bb = [];//new BlobBuilder();
      for (var i = 0; i < treeEntries.length; i++){
        bb.push((treeEntries[i].isBlob ? '100644 ' : '40000 ') + treeEntries[i].name);
        bb.push(new Uint8Array([0]));
        bb.push(treeEntries[i].sha);
      }
      this.writeRawObject('tree', new Blob(bb), function(sha){
        success(sha);
      });
    },

    getConfig : function(success){
      var fe = this.fileError;

      fileutils.readFile(this.dir, '.git/config.json', 'Text', function(configStr){
        success(JSON.parse(configStr));
      }, function(e){
        if (e.code == FileError.NOT_FOUND_ERR){
          success({});
        }
        else{
          fe(e);
        }
      });
    },
    setConfig : function(config, success){
      var configStr = JSON.stringify(config);
      fileutils.mkfile(this.dir, '.git/config.json', configStr, success, this.fileError);
    },

    updateLastChange : function(config, success){
      var dir = this.dir,
        setConfig = this.setConfig.bind(this);
        fe = this.fileError;

      var doUpdate = function(config){
        config.time = new Date();
        setConfig(config, success);
      }
      if (config){
        doUpdate(config);
      }
      else{
        this.getConfig(doUpdate);
      }
    }

  }

  return fileObjectStore;
})();

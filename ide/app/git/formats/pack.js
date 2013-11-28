var Packer = (function() {

  String.prototype.rjust = function(width, padding) {
    padding = padding || " ";
    padding = padding.substr(0, 1);
    if (this.length < width)
      return padding.repeat(width - this.length) + this;
    else
      return this.toString();
  }
  String.prototype.repeat = function(num) {
    for (var i = 0, buf = ""; i < num; i++) buf += this;
    return buf;
  }

  var Pack = function(binary, store) {
    //var binaryString = Git.toBinaryString(binary)
    var data;
    if (binary.constructor == String)
      data = new Uint8Array(utils.stringToBytes(binary)); //new BinaryFile(binaryString)
    else
      data = new Uint8Array(binary); //new BinaryFile(binaryString)
    var offset = 0
    var objects = null

    //var lastObjectData = null;
    //var chainCache = {};
    this.getData = function() {
      return data;
    }

    //if (typeof require === "undefined") {
    var myDebug = function(obj) {
      console.log(obj)
    }
    //}
    //else {
    //  var myDebug = require('util').debug
    //}

    var peek = function(length) {
      return data.subarray(offset, offset + length)
    }

    var rest = function() {
      return data.subarray(offset)
    }

    var advance = function(length) {
      offset += length
    }

    var matchPrefix = function() {
      if (utils.bytesToString(peek(4)) === "PACK") {
        advance(4)
      } else {
        throw (Error("couldn't match PACK"))
      }
    }

    var matchVersion = function(expectedVersion) {
      var actualVersion = peek(4)[3]
      advance(4)
      if (actualVersion !== expectedVersion) {
        throw ("expected packfile version " + expectedVersion + ", but got " + actualVersion)
      }
    }

    var matchNumberOfObjects = function() {
      var num = 0
      _(peek(4)).each(function(b) {
        num = num << 8
        num += b
      })
      advance(4);
      return num;
    }

    var PackedTypes = {
      COMMIT: 1,
      TREE: 2,
      BLOB: 3,
      TAG: 4,
      OFS_DELTA: 6,
      REF_DELTA: 7
    }
    var typeArray = [null, "commit", "tree", "blob", "tag", null, "ofs_delta", "ref_delta"];
    var getTypeStr = function(type) {
      return typeArray[type];
    }

    var matchObjectHeader = function() {
      var objectStartOffset = offset;
      var headByte = data[offset++];
      var type = (0x70 & headByte) >>> 4;
      var needMore = (0x80 & headByte) > 0;

      var size = headByte & 0xf;
      var bitsToShift = 4;

      while (needMore) {
        headByte = data[offset++];
        needMore = (0x80 & headByte) > 0;
        size = size | ((headByte & 0x7f) << bitsToShift);
        bitsToShift += 7;
      }

      return {
        size: size,
        type: type,
        offset: objectStartOffset
      }

    }

    var objectHash = function(type, content) {
      var contentData = new Uint8Array(content);
      var data = utils.stringToBytes(getTypeStr(type) + " " + contentData.byteLength + "\0");
      var buf = new ArrayBuffer(data.length + contentData.byteLength);
      var fullContent = new Uint8Array(buf);
      fullContent.set(data);
      fullContent.set(contentData, data.length);
      // return new SHA1(data).hexdigest()
      return Crypto.SHA1(fullContent, {
        asBytes: true
      });
    }

    var findDeltaBaseOffset = function(header) {
      var offsetBytes = []
      var hintAndOffsetBits = peek(1)[0].toString(2).rjust(8, "0")
      var needMore = (hintAndOffsetBits[0] == "1")

      offsetBytes.push(hintAndOffsetBits.slice(1, 8))
      advance(1)

      while (needMore) {
        hintAndOffsetBits = peek(1)[0].toString(2).rjust(8, "0")
        needMore = (hintAndOffsetBits[0] == "1")
        offsetBytes.push(hintAndOffsetBits.slice(1, 8))
        advance(1)
      }

      var longOffsetString = _(offsetBytes).reduce(function(memo, byteString) {
        return memo + byteString
      }, "")

      var offsetDelta = parseInt(longOffsetString, 2)
      var n = 1
      _(offsetBytes.length - 1).times(function() {
        offsetDelta += Math.pow(2, 7 * n)
        n += 1
      })
      var desiredOffset = header.offset - offsetDelta
      return desiredOffset;
    }


    var expandDeltifiedObject = function(object, callback) {

      var doExpand = function(baseObject, deltaObject) {
        deltaObject.type = baseObject.type;
        deltaObject.data = applyDelta(new Uint8Array(baseObject.data), new Uint8Array(deltaObject.data));
        deltaObject.sha = objectHash(deltaObject.type, deltaObject.data);
        return deltaObject;
      }

      if (object.type == PackedTypes.OFS_DELTA) {
        var baseObject = matchObjectAtOffset(object.desiredOffset);
        switch (baseObject.type) {
          case PackedTypes.OFS_DELTA:
          case PackedTypes.REF_DELTA:
            expandDeltifiedObject(baseObject, function(expandedObject) {
              var newObject = doExpand(expandedObject, object);
              callback(newObject);
            });
            break;
          default:
            var newObject = doExpand(baseObject, object);
            callback(newObject);
        }

      } else {
        store._retrieveRawObject(object.baseSha, 'ArrayBuffer', function(baseObject) {
          baseObject.sha = object.baseSha;
          var newObject = doExpand(baseObject, object);
          callback(newObject);
        });
      }
    }
    var uncompressObject = function(objOffset, uncompressedLength) {
      var deflated = data.subarray(objOffset);
      var out = utils.inflate(deflated, uncompressedLength);

      return {
        buf: utils.trimBuffer(out),
        compressedLength: out.compressedLength
      };
    }

    var matchObjectData = function(header) {

      var object = {
        offset: header.offset,
        //dataOffset: dataOffset,
        //crc: crc32.crc(data.subarray(header.offset, offset)),
        type: header.type,
        //sha: objectHash(header.type, buf),
        // data: objData.buf
      }
      switch (header.type) {
        case PackedTypes.OFS_DELTA:
          object.desiredOffset = findDeltaBaseOffset(header);
          break;
        case PackedTypes.REF_DELTA:
          var shaBytes = peek(20)
          advance(20)
          object.baseSha = _(shaBytes).map(function(b) {
            return b.toString(16).rjust(2, "0")
          }).join("")
          break;
        default:
          break;

      }
      var objData = uncompressObject(offset, header.size);
      object.data = objData.buf;

      //var checksum = adler32(buf)
      advance(objData.compressedLength);
      //matchBytes(intToBytes(checksum, 4))

      return object;
    }

    var matchObjectAtOffset = function(startOffset) {
      offset = startOffset
      var header = matchObjectHeader()
      return matchObjectData(header);
    }

    // slightly different code path from the original parser used for building the index
    // I'm doing it seperately because I needed to solve a call stack overflow caused by
    // synchronouse execution of callbacks for the case of non deltified objects in the
    // pack.
    var matchAndExpandObjectAtOffset = function(startOffset, dataType, callback) {
      //var reverseMap = [null, "commit", "tree", "blob"]

      var object = matchObjectAtOffset(startOffset);

      var convertToDataType = function(object) {
        //object.type = reverseMap[object.type];
        if (dataType != 'ArrayBuffer') {
          var reader = new FileReader();

          reader.onloadend = function() {
            var buf = reader.result;
            object.data = buf;
            callback(object);
          }
          reader['readAs' + dataType](new Blob([object.data]));
        }
        else{
          callback(object);
        }
      }
      switch (object.type) {
        case PackedTypes.OFS_DELTA:
        case PackedTypes.REF_DELTA:
          expandDeltifiedObject(object, function(expandedObject){
            convertToDataType(expandedObject);
          });
          break;
        default:
          convertToDataType(object);
          break;
      }
    };
    this.matchAndExpandObjectAtOffset = matchAndExpandObjectAtOffset;

    var stripOffsetsFromObjects = function() {
      _(objects).each(function(object) {
        delete object.offset
      })
    }

    var objectAtOffset = function(offset) {
      return _(objects).detect(function(obj) {
        return obj.offset == offset
      })
    }

    this.matchObjectAtOffset = matchObjectAtOffset;

    this.parseAll = function(success, progress) {
      try {
        var numObjects;
        var i;
        var deferredObjects = [];
        objects = [];


        matchPrefix()
        matchVersion(2)
        numObjects = matchNumberOfObjects();

        if (progress){
          var tracker = 0;
          var lastPercent = 0;
          var trackProgress = function(){
            var pct = (++tracker/numObjects) * 100
            if (pct - lastPercent >= 1){
              progress({pct: pct, msg: "Unpacking " + tracker + '/' + numObjects + " objects"});
            }
          }
        }
        else{
          var trackProgress = function(){};
        }
        trackProgress();
        for (i = 0; i < numObjects; i++) {
          var object = matchObjectAtOffset(offset);

          object.crc = crc32.crc(data.subarray(object.offset, offset));

          // hold on to the data for delta style objects.
          switch (object.type) {
            case PackedTypes.OFS_DELTA:
            case PackedTypes.REF_DELTA:
              {
                deferredObjects.push(object);
                break;
              }
            default:
              object.sha = objectHash(object.type, object.data);
              delete object.data;
              trackProgress();
              break;
          }
          objects.push(object);
        }

        deferredObjects.asyncEach(function(obj, done) {
          expandDeltifiedObject(obj, function(obj){
            delete obj.data;
            trackProgress();
            done();
          });
        },
          success);

      } catch (e) {
        //console.log("Error caught in pack file parsing data") // + Git.stringToBytes(data.getRawData()))
        throw (e)
      }
      return this
    }

    this.getObjects = function() {
      return objects
    }

    // this.getObjectAtOffset = getObjectAtOffset
  }

  Pack.buildPack = function(commits, repo, callback) {
    var visited = {};
    var counter = {
      x: 0,
      numObjects: 0
    };
    var packed = []; //new BlobBuilder();

    var map = {
      "commit": 1,
      "tree": 2,
      "blob": 3
    };

    var packTypeSizeBits = function(type, size) {
      var typeBits = type;//map[type];
      var shifter = size;
      var bytes = [];
      var idx = 0;

      bytes[idx] = typeBits << 4 | (shifter & 0xf);
      shifter = shifter >>> 4;

      while (shifter != 0) {
        bytes[idx] = bytes[idx] | 0x80;
        bytes[++idx] = shifter & 0x7f;
        shifter = shifter >>> 7;
      }
      return new Uint8Array(bytes);
    }

    var packIt = function(object) {
      var compressed;
      var size;
      var type = object.type;

      if (object.compressedData) {
        size = object.size;
        // clone the data since it may be sub view of a larger buffer;
        compressed = new Uint8Array(compressedData).buffer;
      } else {
        var buf = object.data;
        var data;
        if (buf instanceof ArrayBuffer) {
          data = new Uint8Array(buf);
        } else if (buf instanceof Uint8Array) {
          data = buf;
        } else {
          // assume it's a string
          data = utils.stringToBytes(buf);
        }

        compressed = utils.deflate(data);
        size = data.length;
      }
      packed.push(packTypeSizeBits(type, size));
      packed.push(compressed);
      counter.numObjects++;
    }

    var finishPack = function() {
      var packedObjects = []; //new BlobBuilder();

      var buf = new ArrayBuffer(12);
      var dv = new DataView(buf);

      // 'PACK'
      dv.setUint32(0, 0x5041434b, false);
      // version
      dv.setUint32(4, 2, false);
      //number of packed objects
      dv.setUint32(8, counter.numObjects, false);

      //finalPack.append(buf);
      //finalPack.append(packedObjects);
      packedObjects.push(dv);
      //packed.reverse();
      for (var i = 0; i < packed.length; i++) {
        packedObjects.push(packed[i]);
      }
      //packed.getBlob();
      fileutils.readBlob(new Blob(packedObjects), 'ArrayBuffer', function(dataBuf) {
        packed = null;
        var dataBufArray = new Uint8Array(dataBuf);
        var sha = Crypto.SHA1(dataBufArray, {
          asBytes: true
        });

        var finalPack = []; //new BlobBuilder();
        finalPack.push(dataBufArray);
        finalPack.push(new Uint8Array(sha));

        fileutils.readBlob(new Blob(finalPack), 'ArrayBuffer', callback);
      });

    }

    var walkTree = function(treeSha, callback) {
      if (visited[treeSha]) {
        callback();
        return;
      } else {
        visited[treeSha] = true;
      }

      var packTree = function(){
        repo._retrieveObject(treeSha, 'Tree', function(tree, rawObj) {
          var childCount = {
            x: 0
          };
          var handleCallback = function() {
            childCount.x++;
            if (childCount.x == tree.entries.length) {
              packIt(rawObj);
              callback();
            }
          }

          for (var i = 0; i < tree.entries.length; i++) {
            var nextSha = utils.convertBytesToSha(tree.entries[i].sha);
            if (tree.entries[i].isBlob) {
              if (visited[nextSha]) {
                handleCallback();
              } else {
                visited[nextSha] = true;
                repo._findPackedObject(tree.entries[i].sha, handleCallback, function(){
                  repo._retrieveRawObject(nextSha, 'Raw', function(object) {
                    packIt(object);
                    handleCallback();
                  });
                });
              }
            } else {
              walkTree(nextSha, function() {
                handleCallback();
              });
            }
          }
        });
      }
      var shaBytes = utils.convertShaToBytes(treeSha);
      // assumes that if it's packed, the remote knows about the object since all stored packs came from the remote.
      repo._findPackedObject(shaBytes, callback, packTree);
    }

    if (commits.length == 0){
      finishPack();
    }
    else{
      commits.forEach(function(commitObj) {
        //repo._retrieveObject(commitShas[i], 'Commit', function(commit, rawObj){
        var commit = commitObj.commit;
        packIt(commitObj.raw);
        walkTree(commit.tree, function() {
          if (++counter.x == commits.length) {
            finishPack();
          }
        });
        //});
      });
    }

  }
  return Pack;
})();

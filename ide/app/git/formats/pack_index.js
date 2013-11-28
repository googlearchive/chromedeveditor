
var PackIndex = (function() {
  // This object partially parses the data contained in a pack-*.idx file, and provides
  // access to the offsets of the objects the packfile and the crc checksums of the objects.
  PackIdx = function(buf) {
    var data = new DataView(buf);
    this.data = data;
    // load the index into memory
    var magicNum = data.getUint32(0, false);
    var versionNum = data.getUint32(4, false);

    if (magicNum != 0xff744f63 || versionNum != 2){
      throw(Error("Bad pack index header. Only version 2 is supported"))
    }

    var byteOffset = 8
    //this.fanOffset = byteOffset;

    var numObjects = data.getUint32(byteOffset + (255 * 4), false);

    // skip past fanout table
    var fanTableLen = 256 * 4;
    byteOffset += fanTableLen;
    var shaTableLen = numObjects * 20;
    this.shaList = new Uint8Array(buf, byteOffset, shaTableLen);

    // skip past shas and the CRC vals
    byteOffset += shaTableLen + (numObjects * 4);

    this.offsetsOffset = byteOffset;
    this.numObjects = numObjects;
  }

  PackIdx.prototype = {
    _compareShas : function(sha1, sha2){
       // assume the first byte has been matched in the fan out table
      for (var i = 1; i < 20; i++){
        if (sha1[i] != sha2[i]){
          return sha1[i] - sha2[i];
        }
      }
      return 0;
    },
    _getShaAtIndex : function(index){
      var byteOffset = index * 20;
      return this.shaList.subarray(byteOffset, byteOffset + 20);
    },
    getObjectOffset : function(sha){
      var fanIndex = sha[0];

      var sliceStart = fanIndex > 0 ? (this.data.getUint32(8 + ((fanIndex - 1) * 4), false)) : 0;
      var sliceEnd = this.data.getUint32(8 + (fanIndex * 4), false);

      if (sliceEnd - sliceStart == 0){
        return -1;
      }

      var index;
      while (sliceEnd - sliceStart  > 1){
        var split = sliceStart + Math.floor(((sliceEnd - sliceStart)/2));

        var mid = this._getShaAtIndex(split);

        var compare = this._compareShas(sha, mid);
        if (compare == 0){
          index = split;
          break;
        }
        else if (compare < 0){
          sliceEnd = split;
        }
        else{
          sliceStart = split + 1;
        }
      }
      // if we've exited the loop without a match, sliceStart should hold the index or it's not here.
      if (!index){
        if (sliceStart < this.numObjects && this._compareShas(sha, this._getShaAtIndex(sliceStart)) == 0){
          index = sliceStart;
        }
        else{
          return -1;
        }
      }

      var objOffset = this.data.getUint32(this.offsetsOffset + (index * 4), false);
      return objOffset;

    }
  }
  /*
  * = Version 2 pack-*.idx files support packs larger than 4 GiB, and
  *  have some other reorganizations.  They have the format:
  *
  *  - A 4-byte magic number '\377tOc' which is an unreasonable
  *  fanout[0] value.
  *
  *  - A 4-byte version number (= 2)
  *
  *  - A 256-entry fan-out table just like v1.
  *
  *  - A table of sorted 20-byte SHA1 object names.  These are
  *  packed together without offset values to reduce the cache
  *  footprint of the binary search for a specific object name.
  *
  *  - A table of 4-byte CRC32 values of the packed object data.
  *  This is new in v2 so compressed data can be copied directly
  *  from pack to pack during repacking without undetected
  *  data corruption.
  *
  *  - A table of 4-byte offset values (in network byte order).
  *  These are usually 31-bit pack file offsets, but large
  *  offsets are encoded as an index into the next table with
  *  the msbit set.
  *
  *  - A table of 8-byte offset entries (empty for pack files less
  *  than 2 GiB).  Pack files are organized with heavily used
  *  objects toward the front, so most object references should
  *  not need to refer to this table.
  *
  *  - The same trailer as a v1 pack file:
  *
  *  A copy of the 20-byte SHA1 checksum at the end of
  *  corresponding packfile.
  *
  *  20-byte SHA1-checksum of all of the above.
  */
  PackIdx.writePackIdx = function(objects, packSha){
    var size = 4 + 4 + (256 * 4) + (objects.length * 20) + (objects.length * 4)  + (objects.length * 4) + (20 * 2);
    var buf = new ArrayBuffer(size);

    objects.sort(function(obj1, obj2){
      for (var i = 0; i < 20; i++){
        if (obj1.sha[i] != obj2.sha[i]){
          return obj1.sha[i] - obj2.sha[i];
        }
      }
      return 0; // shouldn't happen but just in case
    });

    var data = new DataView(buf);

    // magic number
    data.setUint32(0, 0xff744f63, false);

    //version number
    data.setUint32(4, 2, false);

    // fan table
    var byteOffset = 8, current = 0;

    for (var i = 0; i < objects.length; i++){
      var next = objects[i].sha[0];
      if (next != current){

        for (var j = current; j < next; j++){
          data.setUint32(byteOffset + (j * 4), i, false);
        }
      }
      current = next;
    }
    for (var j = current; j < 256; j++){
      data.setUint32(byteOffset + (j * 4), objects.length, false);
    }

    // list of shas
    byteOffset += (256 * 4);

    for (var i = 0; i < objects.length; i++){
      for (var j = 0; j < 20; j++){
        data.setUint8(byteOffset++, objects[i].sha[j]);
      }
    }

    // list of crcs
    for (var i = 0; i < objects.length; i++){
      data.setUint32(byteOffset, objects[i].crc, false);
      byteOffset += 4;
    }

    // list of offsets. Note that I'm not going to bother with large offsets. You shouldn't be loading a packfile >2GB inside a web browser anyway.
    for (var i = 0; i < objects.length; i++){
      data.setUint32(byteOffset, objects[i].offset, false);
      byteOffset += 4;
    }

    // the pack file sha
    for (var i = 0; i < 20; i++){
      data.setUint8(byteOffset++, packSha[i]);
    }

    // sha for all of the above
    var indexSha = Crypto.SHA1(new Uint8Array(buf, 0, byteOffset), {asBytes:true});
    for (var i = 0; i < 20; i++){
      data.setUint8(byteOffset++, indexSha[i]);
    }
    return buf;
  }

  return PackIdx;
})();

// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.pack;

import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:math';
import 'dart:typed_data';

import 'package:crc32/crc32.dart' as crc;
import 'package:crypto/crypto.dart' as crypto;
import 'package:utf/utf.dart';

import 'git_objectstore.dart';
import 'zlib.dart';

/**
 * Encapsulates a git pack object.
 */
class PackObject {
  List<int> sha;
  String baseSha;
  int crc;
  int offset;
  int type;
  int desiredOffset;
  ByteBuffer data;
}

class PackedTypes {
  static const COMMIT = 1;
  static const TREE = 2;
  static const BLOB = 3;
  static const TAG = 4;
  static const OFS_DELTA = 6;
  static const REF_DELTA = 7;
  
  static String getTypeString(int type) {
    switch(type) {
      case COMMIT:
        return "commit";
        break;
      case TREE:
        return "tree";
        break;
      case BLOB:
        return "blob";
        break;
      case TAG:
        return "tag";
        break;
      case OFS_DELTA:
        return "ofs_delta";
        break;
      case REF_DELTA:
        return "ref_delta";
        break;
      default:
        throw "unsupported pack type.";
        break;
    }
  }
}

/**
 * Encapsulates a pack object header.
 */
class PackObjectHeader {
  int size;
  int type;
  int offset;

  PackObjectHeader(int size, int type, int offset) {
    this.size = size;
    this.type = type;
    this.offset = offset;
  }
}

/**
 * This class encapsulates logic to parse, create and build git pack objects.
 * TODO(grv) : add unittests.
 */
class Pack {

  Uint8List data;
  int _offset = 0;
  ObjectStore _store;
  List<PackObject> objects = [];

  Pack(Uint8List data, ObjectStore store) {
    this.data = data;
    //this._store = store;
  }

  Uint8List _peek(int length) => data.sublist(_offset, _offset + length);

  Uint8List _rest() => data.sublist(_offset);

  void _advance(int length) {
    _offset += length;
  }

  void _matchPrefix() {
    if (UTF8.decode(_peek(4)) == 'PACK') {
      _advance(4);
    } else {
      // TODO(grv) : throw custom error.
      throw "Couldn't match PACK";
    }
  }

  /**
   * Parses and returns number of git objects from a pack object.
   */
  int _matchNumberOfObjects() {
    int num = 0;
    _peek(4).forEach((byte) {
      num = (num << 8);
      num += byte;
    });
    _advance(4);
    return num;
  }

  PackObjectHeader _getObjectHeader() {
    int objectStartoffset = _offset;
    int headByte = data[_offset++];
    int type = (0x70 & headByte) >> 4;
    bool needMore = (0x80 & headByte) > 0;

    int size = (headByte & 0xf);
    int bitsToShift = 4;

    while (needMore) {
      headByte = data[_offset++];
      needMore = (0x80 & headByte) > 0;
      size |= ((headByte & 0x7f) << bitsToShift);
      bitsToShift += 7;
    }

    return new PackObjectHeader(size, type, objectStartoffset);
  }

  /**
   * Returns a SHA1 hash of given byete stream.
   */
  List<int> getObjectHash(int type, ByteBuffer content) {
    Uint8List contentData = new Uint8List.view(content);
    List<int> header = encodeUtf8(PackedTypes.getTypeString(type)
        + "${contentData.elementSizeInBytes}\0");
    Uint8List fullContent = 
        new Uint8List(header.length + contentData.length);
    
    fullContent.setAll(0, header);
    fullContent.setAll(header.length, contentData);

    crypto.SHA1 sha1 = new crypto.SHA1();
    sha1.newInstance().add(fullContent);
    return sha1.close();
  }


  String _padString(String str, int width, String padding) {
    String result = str;
    for (int i = 0; i < width - str.length; ++i) {
      result = "${padding}${result}";
    }
    return result;
  }

  void _matchVersion(int expectedVersion) {
    int version = _peek(4)[3];
    _advance(4);
    if (version != expectedVersion) {
      // TODO(grv) : throw custom exception.
      String msg =
          "expected packfile version ${expectedVersion} but got ${version}";
          throw msg;
    }
  }

  int findDeltaBaseOffset(PackObjectHeader header) {
    List<String> offsetBytes = [];
    bool needMore = false;

    do {
      String hintAndOffsetBits = _padString(
          _peek(1)[0].toRadixString(2), 8, '0');
      needMore = (hintAndOffsetBits[0] == '1');
      offsetBytes.add(hintAndOffsetBits.substring(1, 8));
      _advance(1);
    } while(needMore);

    String longOffsetString = offsetBytes.reduce((String memo,
        String el) => memo + el);


    int offsetDelta = int.parse(longOffsetString, radix: 2);

    for (int i = 1; i < offsetBytes.length; ++i) {
      offsetDelta += pow(2, 7 * i);
    }

    return header.offset - offsetDelta;
  }


  ByteBuffer applyDelta(Uint8List baseObjBytes, Uint8List deltaObjBytes) {
    // TODO(grv) : implement.
    throw "to be implemented.";

  }

  Future expandDeltifiedObject(PackObject object) {
    Completer completer = new Completer();

    PackObject doExpand(PackObject baseObj, PackObject deltaObj) {
      deltaObj.type = baseObj.type;
      deltaObj.data = applyDelta(new Uint8List.view(baseObj.data),
          new Uint8List.view(deltaObj.data));
      deltaObj.sha = getObjectHash(deltaObj.type, deltaObj.data);
      return deltaObj;
    }

    if (object.type == PackedTypes.OFS_DELTA) {
      PackObject baseObj = _matchObjectAtOffset(object.desiredOffset);
      switch (baseObj.type){
        case PackedTypes.OFS_DELTA:
        case PackedTypes.REF_DELTA:
          return expandDeltifiedObject(baseObj).then((
              PackObject expandedObject) => doExpand(expandedObject, object));
        default:
          completer.complete(doExpand(baseObj, object));
      }
    } else {
      // TODO(grv) : desing object class.
      /*_store.retrieveRawObject(object.baseSha, 'ArrayBuffer').then((baseObj) {
        completer.complete(doExpand(baseObj, object));
      });*/
    }
    return completer.future;
  }

  ZlibResult _uncompressObject(int objOffset, int uncompressedLength) =>
      Zlib.inflate(data.sublist(objOffset), uncompressedLength);

  PackObject _matchObjectData(PackObjectHeader header) {

    PackObject object = new PackObject();

    object.offset = header.offset;
    object.type = header.type;

    switch (header.type) {
      case PackedTypes.OFS_DELTA:
        object.desiredOffset = findDeltaBaseOffset(header);
        break;
      case PackedTypes.REF_DELTA:
        Uint8List shaBytes = _peek(20);
        _advance(20);
        object.baseSha = shaBytes.map((int byte) {
          _padString(byte.toRadixString(16), 2, '0');
        }).join('');
        break;
      default:
        break;
    }

    ZlibResult objData = _uncompressObject(_offset, header.size);
    object.data = new Uint8List.fromList(objData.buffer.getBytes()).buffer;

    _advance(objData.expectedLength);
    return object;
  }

  PackObject _matchObjectAtOffset(int startOffset) {
    _offset = startOffset;
    return _matchObjectData(_getObjectHeader());
  }

  // TODO(grv) : add progress.
  Future parseAll() {
    Completer completer = new Completer();

    try {
      int numObjects;
      List<PackObject> deferredObjects = [];

      _matchPrefix();
      _matchVersion(2);
      numObjects = _matchNumberOfObjects();

      for (int i = 0; i < numObjects; ++i) {
        PackObject object = _matchObjectAtOffset(_offset);
        object.crc = crc.CRC32.compute(data.sublist(object.offset, _offset));


        // hold on to the data for delta style objects.
        switch (object.type) {
          case PackedTypes.OFS_DELTA:
          case PackedTypes.REF_DELTA:
            deferredObjects.add(object);
            break;
          default:
            object.sha = getObjectHash(object.type, object.data);
            object.data = null;
            // TODO(grv) : add progress.
            break;
        }
        objects.add(object);
      }

      return Future.forEach(deferredObjects, (PackObject obj) {
        return expandDeltifiedObject(obj).then((PackObject deltifiedObj) {
          deltifiedObj.data = null;
          // TODO(grv) : add progress.
        });
      });
    } catch (e) {
      // TODO(grv) : throw custom error.
      throw e;
    }
    return completer.future;
  }

  Future buildPack(commits, repo) {
   // TODO(grv) : implement

    throw "to be implemented";
  }

}
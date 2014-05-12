// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library git.pack.index;

import 'dart:core';
import 'dart:typed_data';

import 'fast_sha.dart';
import 'object.dart';

/**
 * This class partially parses the data contained in a pack-*.idx file, and
 *  provides access to the offsets of the objects the packfile and the crc
 *  checksums of the objects.
 *
 * = Version 2 pack-*.idx files support packs larger than 4 GiB, and
 *  have some other reorganizations.  They have the format:
 *
 *  - A 4-byte magic number '\377tOc' which is an unreasonable
 *    fanout[0] value.
 *
 *  - A 4-byte version number (= 2)
 *
 *  - A 256-entry fan-out table just like v1.
 *
 *  - A table of sorted 20-byte SHA1 object names.  These are
 *    packed together without offset values to reduce the cache
 *    footprint of the binary search for a specific object name.
 *
 *  - A table of 4-byte CRC32 values of the packed object data.
 *    This is new in v2 so compressed data can be copied directly
 *    from pack to pack during repacking without undetected
 *    data corruption.
 *
 *  - A table of 4-byte offset values (in network byte order).
 *    These are usually 31-bit pack file offsets, but large
 *    offsets are encoded as an index into the next table with
 *    the msbit set.
 *
 *  - A table of 8-byte offset entries (empty for pack files less
 *    than 2 GiB).  Pack files are organized with heavily used
 *    objects toward the front, so most object references should
 *    not need to refer to this table.
 *
 *  - The same trailer as a v1 pack file:
 *
 *    A copy of the 20-byte SHA1 checksum at the end of
 *    corresponding packfile.
 *
 *    20-byte SHA1-checksum of all of the above.
 */
class PackIndex {
  static final int PACK_IDX_SIGNATURE = 0xff744f63;
  static final int PACK_VERSION = 2;
  static final int FAN_TABLE_LENGTH = 256 * 4;

  ByteData _byteData;
  Uint8List _shaList;
  int _numObjects;
  int _offsetsOffset;

  PackIndex(List<int> data) {
    ByteBuffer buffer;

    if (data is Uint8List) {
      buffer = data.buffer;
    } else {
      buffer = new Uint8List.fromList(data).buffer;
    }

    _byteData = new ByteData.view(buffer);

    // load the index into memory
    int signature = _byteData.getUint32(0);
    int version = _byteData.getUint32(4);

    if (signature != PACK_IDX_SIGNATURE || version != PACK_VERSION) {
      // TODO: Throw a better error.
      throw "Bad pack index header. Only version 2 is supported.";
    }

    int byteOffset = 8;
    int numObjects = _byteData.getUint32(byteOffset + (255 * 4));

    // skip past fanout table.
    byteOffset += FAN_TABLE_LENGTH;
    int shaTableLen = numObjects * 20;
    _shaList = new Uint8List.view(buffer, byteOffset, shaTableLen);

    // skip past shas and the CRC vals.
    byteOffset += shaTableLen + (numObjects * 4);

    _offsetsOffset = byteOffset;
    _numObjects = numObjects;
  }

  int _compareShas(List<int> sha1, List<int> sha2) {
    // assume first byte has been matched in the fan out table.
    for (var i =1; i < 20; ++i) {
      if (sha1[i] != sha2[i]) {
        return sha1[i] - sha2[i];
      }
    }
    return 0;
  }

  Uint8List _getShaAtIndex(int index) {
    int byteOffset = index * 20;
    return _shaList.sublist(byteOffset, byteOffset + 20);
  }

  int getObjectOffset(List<int> sha) {
    int fanIndex = sha[0];

    int sliceStart = fanIndex > 0 ? (_byteData.getUint32(8 +
        (fanIndex - 1) * 4)) : 0;
    int sliceEnd = _byteData.getUint32(8 + (fanIndex * 4));

    if (sliceEnd - sliceStart == 0) {
      return -1;
    }

    int index;
    while (sliceEnd >= sliceStart) {

      int split = sliceStart + ((sliceEnd - sliceStart) / 2).floor();

      List<int> mid = _getShaAtIndex(split);

      int compare = _compareShas(sha, mid);

      if (compare == 0) {
        index = split;
        break;
      } else if (compare < 0) {
        sliceEnd = split - 1;
      } else {
        sliceStart = split + 1;
      }
    }

    if (index == null) {
      return -1;
    }

    return _byteData.getUint32(_offsetsOffset + (index * 4));
  }

  /**
   * Creates a pack file index and returns the bytestream.
   */
  static Uint8List writePackIndex(List<PackedObject> objects, List<int> packSha) {
    int size = 4 + 4 + (256 * 4) + (objects.length * 20) + (objects.length * 4)
        + (objects.length * 4) + (20 * 2);

    Uint8List byteList = new Uint8List(size);

    objects.sort((obj1, obj2) {
      for (int i = 0; i < 20; ++i) {
        if (obj1.shaBytes[i] != obj2.shaBytes[i]) {
          return obj1.shaBytes[i] - obj2.shaBytes[i];
        }
      }
      // Should never reach here.
      return 0;
    });

    ByteData data = new ByteData.view(byteList.buffer);

    data.setUint32(0, PACK_IDX_SIGNATURE);
    data.setUint32(4, PACK_VERSION);

    // fan table
    int byteOffset = 8;
    int current = 0;

    for (int i = 0; i < objects.length; ++i) {
      int next = objects[i].shaBytes[0];
      if (next != current) {
        for (int j = current; j < next; ++j) {
          data.setUint32(byteOffset + (j * 4), i);
        }
      }
      current = next;
    }
    for (int j = current; j < 256; ++j) {
      data.setUint32(byteOffset + (j * 4), objects.length);
    }

    byteOffset += (256 * 4);

    // Write list of shas.
    objects.forEach((PackedObject obj) {
      for (int j = 0; j < 20; ++j) {
        data.setUint8(byteOffset++, obj.shaBytes[j]);
      }
    });

    // Write list of crcs.
    objects.forEach((PackedObject obj) {
      data.setUint32(byteOffset, obj.crc);
      byteOffset +=4;
    });

    // Write list of offsets. Only upto 32 bit long offsets are supported.
    // TODO(grv) : add support for longer offsets(maybe).
    objects.forEach((PackedObject obj) {
      data.setUint32(byteOffset, obj.offset);
      byteOffset += 4;
    });

    // Write pack file sha.
    for (int i = 0; i < 20; ++i) {
      data.setUint8(byteOffset++, packSha[i]);
    }

    // Write sha for all of the above.
    FastSha sha1 = new FastSha();
    sha1.add(byteList.sublist(0, byteOffset).toList());
    List<int> indexSha = sha1.close();

    indexSha.forEach((int byte) {
      data.setUint8(byteOffset, byte);
    });

    return byteList;
  }
}

// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library fast_sha;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

// Constants.
const _MASK_8 = 0xff;
const _MASK_32 = 0xffffffff;
const _BITS_PER_BYTE = 8;
const _BYTES_PER_WORD = 4;

// Helper functions used by more than one hasher.

// Rotate left limiting to unsigned 32-bit values.
int _rotl32(int val, int shift) {
  var mod_shift = shift & 31;

  return ((val << mod_shift) & _MASK_32) | ((val & _MASK_32) >> (32 -
      mod_shift));
}

/**
 * An optimized implementation of the SHA1 message digest algorithm.
 */
class FastSha implements Hash {
  final Uint32List _currentChunk = new Uint32List(16);
  final Uint32List _w = new Uint32List(80);

  int _lengthInBytes = 0;
  List<int> _pendingData = [];

  int _h0;
  int _h1;
  int _h2;
  int _h3;
  int _h4;
  bool _digestCalled = false;

  // Construct a SHA1 hasher object.
  FastSha() {
    _h0 = 0x67452301;
    _h1 = 0xEFCDAB89;
    _h2 = 0x98BADCFE;
    _h3 = 0x10325476;
    _h4 = 0xC3D2E1F0;
  }

  // Update the hasher with more data.
  void add(List<int> data) {
    if (_digestCalled) {
      throw new StateError(
          'Hash update method called after digest was retrieved');
    }
    _lengthInBytes += data.length;
    _pendingData.addAll(data);
    _iterate();
  }

  // Finish the hash computation and return the digest string.
  List<int> close() {
    if (_digestCalled) {
      return _resultAsBytes();
    }
    _digestCalled = true;
    _finalizeData();
    _iterate();
    assert(_pendingData.length == 0);
    return _resultAsBytes();
  }

  Hash newInstance() => new FastSha();

  // Returns the block size of the hash in bytes.
  int get blockSize => 16 * _BYTES_PER_WORD;

  // Compute one iteration of the SHA1 algorithm with a chunk of
  // 16 32-bit pieces.
  void _updateHash(Uint32List m) {
    //assert(m.length == 16);

    var a = _h0;
    var b = _h1;
    var c = _h2;
    var d = _h3;
    var e = _h4;

    for (var i = 0; i < 80; i++) {
      if (i < 16) {
        _w[i] = m[i];
      } else {
        var n = _w[i - 3] ^ _w[i - 8] ^ _w[i - 14] ^ _w[i - 16];
        _w[i] = _rotl32(n, 1);
      }
      var t = _add32(_add32(_rotl32(a, 5), e), _w[i]);
      if (i < 20) {
        t = _add32(_add32(t, (b & c) | (~b & d)), 0x5A827999);
      } else if (i < 40) {
        t = _add32(_add32(t, (b ^ c ^ d)), 0x6ED9EBA1);
      } else if (i < 60) {
        t = _add32(_add32(t, (b & c) | (b & d) | (c & d)), 0x8F1BBCDC);
      } else {
        t = _add32(_add32(t, b ^ c ^ d), 0xCA62C1D6);
      }

      e = d;
      d = c;
      c = _rotl32(b, 30);
      b = a;
      a = t & _MASK_32;
    }

    _h0 = _add32(a, _h0);
    _h1 = _add32(b, _h1);
    _h2 = _add32(c, _h2);
    _h3 = _add32(d, _h3);
    _h4 = _add32(e, _h4);
  }

  int _add32(x, y) => (x + y) & _MASK_32;
  int _roundUp(val, n) => (val + n - 1) & -n;

  // Compute the final result as a list of bytes from the hash words.
  List<int> _resultAsBytes() {
    var result = [];
    result.addAll(_wordToBytes(_h0));
    result.addAll(_wordToBytes(_h1));
    result.addAll(_wordToBytes(_h2));
    result.addAll(_wordToBytes(_h3));
    result.addAll(_wordToBytes(_h4));
    return result;
  }

  // Converts a list of bytes to a chunk of 32-bit words.
  void _bytesToChunk(List<int> data, int dataIndex) {
    //assert((data.length - dataIndex) >= (16 * _BYTES_PER_WORD));

    for (var wordIndex = 0; wordIndex < 16; wordIndex++) {
      var w3 = data[dataIndex];
      var w2 = data[dataIndex + 1];
      var w1 = data[dataIndex + 2];
      var w0 = data[dataIndex + 3];
      dataIndex += 4;
      var word = (w3 & _MASK_8) << 24;
      word |= (w2 & _MASK_8) << 16;
      word |= (w1 & _MASK_8) << 8;
      word |= (w0 & _MASK_8);
      _currentChunk[wordIndex] = word;
    }
  }

  Uint8List _cvtBytes = new Uint8List(_BYTES_PER_WORD);

  // Convert a 32-bit word to four bytes.
  Uint8List _wordToBytes(int word) {
    _cvtBytes[0] = (word >> 24) & _MASK_8;
    _cvtBytes[1] = (word >> 16) & _MASK_8;
    _cvtBytes[2] = (word >> 8) & _MASK_8;
    _cvtBytes[3] = word & _MASK_8;
    return _cvtBytes;
  }

  // Iterate through data updating the hash computation for each
  // chunk.
  void _iterate() {
    var len = _pendingData.length;
    var chunkSizeInBytes = 16 * _BYTES_PER_WORD;
    if (len >= chunkSizeInBytes) {
      var index = 0;
      for ( ; (len - index) >= chunkSizeInBytes; index += chunkSizeInBytes) {
        _bytesToChunk(_pendingData, index);
        _updateHash(_currentChunk);
      }
      if (len - index > 0) {
        _pendingData = _pendingData.sublist(index, len);
      } else {
        _pendingData = [];
      }
    }
  }

  // Finalize the data. Add a 1 bit to the end of the message. Expand with
  // 0 bits and add the length of the message.
  void _finalizeData() {
    _pendingData.add(0x80);
    var contentsLength = _lengthInBytes + 9;
    var chunkSizeInBytes = 16 * _BYTES_PER_WORD;
    var finalizedLength = _roundUp(contentsLength, chunkSizeInBytes);
    var zeroPadding = finalizedLength - contentsLength;
    for (var i = 0; i < zeroPadding; i++) {
      _pendingData.add(0);
    }
    var lengthInBits = _lengthInBytes * _BITS_PER_BYTE;
    //assert(lengthInBits < pow(2, 32));
    _pendingData.addAll(_wordToBytes(0));
    _pendingData.addAll(_wordToBytes(lengthInBits & _MASK_32));
  }
}

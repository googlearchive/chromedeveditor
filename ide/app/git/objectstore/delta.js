var applyDelta = (function() {
  var matchLength = function(stream) {
    var data = stream.data
    var offset = stream.offset
    var result = 0
    var currentShift = 0
    var _byte = 128
    var maskedByte, shiftedByte

    while ((_byte & 128) != 0) {
      _byte = data[offset]
      offset += 1
      maskedByte = _byte & 0x7f
      shiftedByte = maskedByte << currentShift
      result += shiftedByte
      currentShift += 7
    }
    stream.offset = offset
    return result
  }

  return function(baseData, delta) {
    //var baseData = Git.stringToBytes(baseDataString)
    var stream = {
      data: delta,
      offset: 0,
      length: delta.length
    }
    var bb = [];
    var baseLength = matchLength(stream)
    if (baseLength != baseData.length) {
      throw (Error("Delta Error: base length not equal to length of given base data"))
    }

    var resultLength = matchLength(stream)
    var resultData = new Uint8Array(resultLength);
    var resultOffset = 0;

    var copyOffset
    var copyLength
    var opcode
    var copyFromResult
    while (stream.offset < stream.length) {
      opcode = stream.data[stream.offset]
      stream.offset += 1
      copyOffset = 0
      copyLength = 0
      if (opcode == 0) {
        throw (Error("Don't know what to do with a delta opcode 0"))
      } else if ((opcode & 0x80) != 0) {
        var value
        var shift = 0
        _(4).times(function() {
          if ((opcode & 0x01) != 0) {
            value = stream.data[stream.offset]
            stream.offset += 1
            copyOffset += (value << shift)
          }
          opcode >>= 1
          shift += 8
        })
        shift = 0
        _(2).times(function() {
          if ((opcode & 0x01) != 0) {
            value = stream.data[stream.offset]
            stream.offset += 1
            copyLength += (value << shift)
          }
          opcode >>= 1
          shift += 8
        })
        if (copyLength == 0) {
          copyLength = (1 << 16)
        }

        // TODO: check if this is a version 2 packfile and apply copyFromResult if so
        copyFromResult = (opcode & 0x01)
        var subarray = baseData.subarray(copyOffset, copyOffset + copyLength);
        resultData.set(subarray, resultOffset);
        resultOffset += subarray.length;

      } else if ((opcode & 0x80) == 0) {
        var subarray = stream.data.subarray(stream.offset, stream.offset + opcode);
        resultData.set(subarray, resultOffset);
        resultOffset += subarray.length;
        stream.offset += opcode
      }
    }
    return resultData.buffer;
  }
}());

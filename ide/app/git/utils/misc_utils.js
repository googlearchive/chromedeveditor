var utils = {

  // Print an error either to the console if in node, or to div#jsgit-errors
  // if in the client.
  handleError: function(message) {
  if (jsGitInNode) {
    console.log(message)
  }
  else {
    $('#jsgit-errors').append(message)
  }
  },

  // Turn an array of bytes into a String
  bytesToString: function(bytes) {
  var result = "";
  var i;
  for (i = 0; i < bytes.length; i++) {
    result = result.concat(String.fromCharCode(bytes[i]));
  }
  return result;
  },

  stringToBytes: function(string) {
  var bytes = [];
  var i;
  for(i = 0; i < string.length; i++) {
    bytes.push(string.charCodeAt(i) & 0xff);
  }
  return bytes;
  },

  toBinaryString: function(binary) {
  if (Array.isArray(binary)) {
    return Git.bytesToString(binary)
  }
  else {
    return binary
  }
  },

  // returns the next pkt-line
  nextPktLine: function(data) {
  var length = parseInt(data.substring(0, 4), 16);
  return data.substring(4, length);
  },

  // zlib files contain a two byte header. (RFC 1950)
  stripZlibHeader: function(zlib) {
  return zlib.subarray(2)
  },

  escapeHTML: function(s) {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
  },
  convertShaToBytes: function(sha){
    var bytes = new Uint8Array(sha.length/2);
    for (var i = 0; i < sha.length; i+=2)
    {
      bytes[i/2] = parseInt('0x' + sha.substr(i, 2));
    }
    return bytes;
  },
  convertBytesToSha : function(bytes){
    var shaChars = [];
    for (var i = 0; i < bytes.length; i++){
      var next = (bytes[i] < 16 ? '0' : '') + bytes[i].toString(16);
      shaChars.push(next);
    }
    return shaChars.join('');
  },
  compareShas : function(sha1, sha2){
    for (var i = 1; i < 20; i++){
      if (sha1[i] != sha2[i]){
        return sha1[i] - sha2[i];
      }
    }
    return 0;
  },
  inflate: function(data, expectedLength){
    var options;
    if (expectedLength){
      options = {bufferSize: expectedLength};
    }
    var inflate = new Zlib.Inflate(data, options);
    inflate.verify = true;
    var out = inflate.decompress();
    out.compressedLength = inflate.ip;
    return out;
  },
  deflate: function(data){
    var deflate = new Zlib.Deflate(data);
    var out = deflate.compress();
    return out;
  },
  trimBuffer: function(data){
    var buffer = data.buffer;
    if (data.byteOffset != 0 || data.byteLength != data.buffer.byteLength){
      buffer = data.buffer.slice(data.byteOffset, data.byteLength + data.byteOffset);
    }
    return buffer;
  }
};

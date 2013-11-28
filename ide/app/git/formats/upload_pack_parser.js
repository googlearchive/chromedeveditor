var UploadPackParser = (function() {
  var parse = function(arraybuffer, repo, success, progress) {
    var data = new Uint8Array(arraybuffer); //new BinaryFile(binaryString);
    var offset = 0;
    var remoteLines = null;
    var objects = null;

    var peek = function(length) {
      return data.subarray(offset, offset + length);
    };

    var advance = function(length) {
      offset += length;
    };

    var getPktLineStr = function(pktLine){
      return utils.bytesToString(data.subarray(pktLine.start, pktLine.end));
    }

    // A pkt-line is defined in http://git-scm.com/gitserver.txt
    var nextPktLine = function(isShallow) {
      var pktLine = null;
      var length;
      length = parseInt(utils.bytesToString(peek(4)), 16);
      advance(4);
      if (length == 0) {
        if (isShallow) {
          return nextPktLine()
        }
      } else {
        pktLine = {start: offset, end: offset + length - 4};//peek(length - 4);
        advance(length - 4);
      }
      return pktLine;
    };

    //console.log("Parsing upload pack of  " + arraybuffer.byteLength + " bytes")
    var startTime = new Date()
    var pktLine = nextPktLine()
    var packFileParser
    var remoteLine = ""
    //var packData = ""
    var gotAckOrNak = false
    var ackRegex = /ACK ([0-9a-fA-F]{40}) common/;
    var common = [];

    var pktLineStr = getPktLineStr(pktLine);//utils.bytesToString(data.slice(pktLine.start, pktLine.end));
    var shallow;
    while (pktLineStr.slice(0, 7) === "shallow") {
      pktLine = nextPktLine(true);
      shallow = pktLineStr.substring(8);
      pktLineStr = getPktLineStr(pktLine);
    }

    while (pktLineStr === "NAK\n" ||
      pktLineStr.slice(0, 3) === "ACK") {
      var matches = ackRegex.exec(pktLineStr);
      if (matches) {
        common.push(matches[1]);
      }
      pktLine = nextPktLine();
      pktLineStr = getPktLineStr(pktLine);
      gotAckOrNak = true;
    }

    if (!gotAckOrNak) {
      throw (Error("got neither ACK nor NAK in upload pack response"))
    }
    var packDataLines = [];
    while (pktLine !== null) {
      var pktLineType = data[pktLine.start];
      // sideband format. "2" indicates progress messages, "1" pack data
      switch (pktLineType){
        case 2:
          break;
        case 1:
          //packData += utils.bytesToString(pktLine.slice(1))
          packDataLines.push(data.subarray(pktLine.start + 1, pktLine.end));
          break;
        case 3:
          throw (Error("fatal error in packet line"))
          break;
      }
      pktLine = nextPktLine()
    }

    // create a blob from the packdata lines then read it as an arraybuffer
    var packDataBlob = new Blob(packDataLines);
    var reader = new FileReader();
    reader.onloadend = function(e){
      var packData = reader.result;
      packFileParser = new Packer(packData, repo);

      packFileParser.parseAll(function() {
        objects = packFileParser.getObjects()

         // console.log("took " + (new Date().getTime() - startTime.getTime()) + "ms")
        success(objects, packFileParser.getData(), common, shallow);
      }, progress);
    }
    reader.readAsArrayBuffer(packDataBlob);
  };
  return {
    parse: parse
  };
})();

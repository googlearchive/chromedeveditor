#!/path to dart

// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

void main()
{
  try {
    stdin.listen((data) {
      Map jsonObj = _transformInput(data);
      if (jsonObj != null) {
        _sendMessage(JSON.encode(jsonObj));
        if (jsonObj.containsKey("action")) {
          String str = jsonObj["action"];
          if (str == "dartium") {
            _runDartium();
          }
        }
      }
    },
    onError: (e) => _sendMessage('{"onError":"${e.toString()}"}'));
  } catch (e) {
    _sendMessage('{"exception":"${e.toString()}"}');
  }
}

void _runDartium() {
  List list = ["-a", "/path to dartium"];
  Process.run("open", list).then((ProcessResult results) {
  //   exit(0);
  });
}

void _sendMessage(String msg) {
  int len = msg.length;
  stdout.writeCharCode((len>>0) & 0xFF);
  stdout.writeCharCode((len>>8) & 0xFF);
  stdout.writeCharCode((len>>16) & 0xFF);
  stdout.writeCharCode((len>>24) & 0xFF);
  stdout.write(msg);
}

Map _transformInput(List<int> data) {
  Map jsonObj;
  int len = _fromBytesToInt32(data.sublist(0,4));
  if (len > 0) {
    String source = UTF8.decode(data.sublist(4));
    jsonObj = JSON.decode(source);
  }
  return jsonObj;
}

int _fromBytesToInt32(List<int> list) {
  final uint8List = new Uint8List(4)
    ..[3] = list[3]
    ..[2] = list[2]
    ..[1] = list[1]
    ..[0] = list[0];
  ByteData newBufferView = new ByteData.view(uint8List.buffer, 0);
  return newBufferView.getInt32(0);
}

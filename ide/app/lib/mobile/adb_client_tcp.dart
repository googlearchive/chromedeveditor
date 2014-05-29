// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to communicate with a running ADB server.
 *
 * Documentation for the ADB server protocol:
 * - https://github.com/jcs/adb/blob/master/SERVICES.TXT
 * - https://github.com/mozilla/libadb.js/blob/master/android-tools/adb-bin/OVERVIEW.TXT
 */
library spark.adb_client_tcp;

import 'dart:async';

import 'adb_client.dart';
import '../tcp.dart';
import '../utils.dart';

const int _ADB_PORT = 5037;

// TODO: install app

// TODO: determine if an app is installed

// TODO: start app

// Start browser and launch url
// adb shell am start -n com.android.chrome/com.google.android.apps.chrome.Main
//   -d http://192.168.1.236:3030
//
// Start content shell and launch url
// adb shell am start -n org.chromium.content_shell_apk/.ContentShellActivity
//   -d http://www.cheese.com

/**
 * An class to wrapper around talking to an ADB TCP server. This is an instance
 * of an ADB server that is already running on the host machine. Spark would
 * talk to the adb server, and that server would talk to the target device (over
 * USB). To use:
 *
 *     AdbClientTcp.createClient().then((AdbClientTcp client) {
 *       print(client.version);
 *       client.getDevices().then(...);
 *     });
 */
class AdbClientTcp {
  final int port;
  final String version;

  static Future<AdbClientTcp> createClient([int port = _ADB_PORT]) {
    return TcpClient.createClient(LOCAL_HOST, port).then((TcpClient client) {
      client.writeString(_packMessage('host:version'));
      return AdbResponse._parseFrom(client, true, true);
    }).then((AdbResponse response) {
      return new AdbClientTcp._(port, response.payloadAsString);
    });
  }

  AdbClientTcp._(this.port, this.version);

  /**
   * Returns all the connected ADB devices.
   */
  Future<List<AdbDevice>> getDevices() {
    return _sendCommand('host:devices').then((AdbResponse response) {
      if (!response.isOkay()) {
        throw 'Invalid response to device list request: ${response.getError()}';
      }

      // Each line of the response is a device description.
      String devStr = response.payloadAsString.trimRight();

      if (devStr.isEmpty) return [];

      return devStr.split('\n').map((str) {
        List<String> info = str.split('\t');
        return new AdbDevice(info[0], info[1]);
      }).toList();
    });
  }

  /**
   * Return a list of all the installed packages.
   */
  Future<List<AdbPackage>> getInstalledPackages({AdbDevice device,
      bool showSystemPackages: false}) {
    // adb shell pm list packages -f [-3]
    String system = showSystemPackages ? '' : ' -3';
    String command = 'pm list packages -f${system}';

    return _sendShellCommand(command, device: device).then((AdbResponse response) {
      if (!response.isOkay()) {
        throw 'Invalid response to package list request: ${response.getError()}';
      }

      // Response is a list of installed packages:
      //   package:/system/app/NetworkLocation.apk=com.google.android.location
      //   package:/system/app/Launcher2.apk=com.android.launcher

      List<AdbPackage> packages = response.payloadAsString.split('\n').map((str) {
        if (!str.startsWith('package:')) return null;

        // Remove the 'package:' prefix.
        str = str.substring('package:'.length);

        List<String> info = str.split('=');
        return new AdbPackage(info[1], info[0]);
      }).toList();

      return packages;
    });
  }

  Future<AdbResponse> startActivity(AdbApplication application,
      {AdbDevice device, List<String> args}) {
    String argString = args == null ? '' : ' ' + args.join(' ');
    String command = 'am start -n ${application.getLaunchString()}${argString}';
    return _sendShellCommand(command, device: device);
  }

  /**
   * Setup port forwarding from the local port to the remote port on the given
   * device.
   */
  Future forwardTcp(int localPort, int remoteDevicePort, {AdbDevice device}) {
    // host-serial:05a02bac:forward:tcp:2424;tcp:2424
    String target = device == null ? 'host-usb' : 'host-serial:${device.id}';
    String command = '${target}:forward:tcp:${localPort};tcp:${remoteDevicePort}';
    return _sendCommand(command, expectPayload: false);
  }

  Future<AdbResponse> _sendCommand(String command, {bool expectPayload: true}) {
    return TcpClient.createClient(LOCAL_HOST, port).then((TcpClient client) {
      client.writeString(_packMessage(command));
      return AdbResponse._parseFrom(client, expectPayload, true);
    });
  }

  Future<AdbResponse> _sendShellCommand(String command, {AdbDevice device}) {
    TcpClient client;
    StreamReader reader;

    return TcpClient.createClient(LOCAL_HOST, port).then((c) {
      client = c;
      reader = new StreamReader(client.stream);

      if (device == null) {
        client.writeString(_packMessage('host:transport-usb'));
      } else {
        client.writeString(_packMessage('host:transport:${device.id}'));
      }

      return AdbResponse._parse(reader, expectResponse: false);
    }).then((_) {
      client.writeString(_packMessage('shell:${command}'));
      return AdbResponse._parse(reader, parseStream: true);
    });
  }

  String toString() => 'AdbClientTcp on port ${port}, version ${version}';
}

/**
 * One of 'OKAY' or 'FAIL'.
 */
class AdbResponse {
  final String status;
  List<int> _data;

  static Future<AdbResponse> _parseFrom(TcpClient client, bool expectPayload,
      bool dispose) {
    AdbResponse response;

    StreamReader reader = new StreamReader(client.stream);

    return reader.read(4).then((List<int> data) {
      String str = new String.fromCharCodes(data);
      response = new AdbResponse._(str);

      if (response.isOkay() && !expectPayload) {
        return response;
      } else {
        return reader.read(4).then((List<int> data) {
          String str = new String.fromCharCodes(data);
          int len = int.parse(str, radix: 16);
          return reader.read(len);
        }).then((List<int> data) {
          response._data = data;
          return response;
        });
      }
    }).whenComplete(() {
      if (dispose) client.dispose();
    });
  }

  static Future<AdbResponse> _parse(StreamReader reader,
      {bool expectResponse: true, bool parseStream: false}) {
    AdbResponse response;

    return reader.read(4).then((List<int> data) {
      String str = new String.fromCharCodes(data);
      response = new AdbResponse._(str);

      if (response.isOkay() && !expectResponse) {
        return response;
      } else if (!response.isOkay() || !parseStream) {
        return reader.read(4).then((List<int> data) {
          String str = new String.fromCharCodes(data);
          int len = int.parse(str, radix: 16);
          return reader.read(len);
        }).then((List<int> data) {
          response._data = data;
          if (response.isFail()) throw response;
          return response;
        });
      } else {
        // parseStream == true
        return reader.readRemaining().then((List<int> data) {
          response._data = data;
          return response;
        });
      }
    });
  }

  AdbResponse._(this.status);

  bool isFail() => status == 'FAIL';
  String getError() => payloadAsString;

  bool isOkay() => status == 'OKAY';

  bool get hasPayload => _data != null;
  List<int> get payload => _data;
  String get payloadAsString => new String.fromCharCodes(_data);

  String toString() {
    if (isFail()) {
      return 'AdbResponse: ${status} ${getError()}';
    } else {
      return 'AdbResponse: ${status}';
    }
  }
}

String _packMessage(String message) {
  String length = message.length.toRadixString(16);
  String padding = '0000'.substring(length.length);
  return '${padding}${length}${message}';
}

// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to deploy a chrome app to an Android device.
 */
library spark.deploy;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:logging/logging.dart';

import 'adb.dart';
import 'adb_client_tcp.dart';
import '../jobs.dart';
import '../preferences.dart';
import '../tcp.dart';
import '../workspace.dart';
import '../workspace_utils.dart';

Logger _logger = new Logger('spark.deploy');

class DeviceInfo {
  final int vendorId;
  final int productId;
  /// This field is currently for debugging purposes only.
  /// It can be later used for more informative progress and error messages.
  final String description;

  DeviceInfo(this.vendorId, this.productId, this.description);
}

/**
 * A class to encapsulate deploying an application to a mobile device.
 */
class MobileDeploy {
  static bool isAvailable() => chrome.usb.available;

  final Container appContainer;
  final PreferenceStore _prefs;

  List<DeviceInfo> _knownDevices = [];

  MobileDeploy(this.appContainer, this._prefs) {
    if (appContainer == null) {
      throw new ArgumentError('must provide an app to push');
    }

    final List permissions = chrome.runtime.getManifest()['permissions'];

    for (final p in permissions) {
      if (p is Map && (p as Map).containsKey('usbDevices')) {
        final List usbDevices = (p as Map)['usbDevices'];
        for (final Map<String, dynamic> d in usbDevices) {
          _knownDevices.add(
              new DeviceInfo(d['vendorId'], d['productId'], d['description']));
        }
      }
    }
  }

  /**
   * Packages (a subdirectory of) the current project, and sends it via HTTP to
   * a remote host.
   *
   * It expects the target host, and a [ProgressMonitor] for 10 units of work.
   * All files under the project will be added to a (slightly broken, see
   * below) CRX file, and sent via HTTP POST to the target host, using the /push
   * protocol described [here](https://github.com/MobileChromeApps/harness-push).
   *
   *     MobileDeploy.pushToHost('192.168.1.121', monitor);
   *
   * Returns a Future for the push operation.
   *
   * Important Note: The CRX file that gets created and pushed is not correctly
   * signed and does not include the application's key. Since the target of a
   * push is intended to be a tool like the
   * [App Dev Tool](https://github.com/MobileChromeApps/chrome-app-harness)
   * on Android, and that tool doesn't care about the CRX metadata, this is not
   * a problem.
   */
  Future pushToHost(String target, ProgressMonitor monitor) {
    monitor.start('Deploying…', 10);

    _logger.info('deploying application to ip host');

    return _sendHttpPush(target, monitor);
  }

  /**
   * Push the application via ADB. We try connecting to a local ADB server
   * first. If that fails, then we try pushing via a USB connection.
   */
  Future pushAdb(ProgressMonitor monitor) {
    monitor.start('Deploying…', 10);

    // Try to find a local ADB server. If we fail, try to use USB.
    return AdbClientTcp.createClient().then((AdbClientTcp client) {
      _logger.info('deploying application via adb server');

      return _pushToAdbServer(client, monitor);
    }, onError: (_) {
      _logger.info('deploying application via ADB over USB');

      // No server found, so use our own USB code.
      return _pushViaUSB(monitor);
    });
  }

  List<int> _buildHttpRequest(String target, String path, {List<int> payload}) {
    List<int> httpRequest = [];

    // Build the HTTP request headers.
    String header =
        'POST /$path HTTP/1.1\r\n'
        'User-Agent: Spark IDE\r\n'
        'Host: ${target}:2424\r\n';
    List<int> body = [];

    if (payload != null) {
      body.addAll(payload);
    }
    httpRequest.addAll(header.codeUnits);
    httpRequest.addAll('Content-length: ${body.length}\r\n\r\n'.codeUnits);
    httpRequest.addAll(body);

    return httpRequest;
  }

  List<int> _buildPushRequest(String target, List<int> archivedData) {
    return _buildHttpRequest(target,
        "zippush?appId=${appContainer.project.name}&appType=chrome",
        payload: archivedData);
  }

  List<int> _buildLaunchRequest(String target) {
    return _buildHttpRequest(target,
        "launch?appId=${appContainer.project.name}");
  }

  Future _sendHttpPush(String target, ProgressMonitor monitor) {
    List<int> httpRequest;
    return archiveContainer(appContainer, true).then((List<int> archivedData) {
      monitor.worked(3);
      // TODO(ericarnold): Turn the request into a class
      _sendRequestTcp(target, _buildPushRequest(target, archivedData),
          monitor, keepOpen: true).then((TcpClient client) {
        /*%TRACE3*/ print("(4> 6/16/14): laycnh!"); // TRACE%
            return _sendRequestTcp(target,
                _buildPushRequest(target, archivedData), monitor,
                client:client);
          });
    });
  }

  Future<TcpClient> _sendRequestTcp(String target, List<int> httpRequest,
                         ProgressMonitor monitor,
                         {TcpClient client: null, keepOpen: false}) {
    Future _createClient() {
      if (client == null) {
        return TcpClient.createClient(target, 2424).then((TcpClient _client) {
          client = _client;
        });
      } else {
        return new Future.value();
      }
    }

    Future _closeClient() {
      if (client != null && !keepOpen) client.dispose();
      return new Future.value(client);
    }

    // Temporary solution for testing reusing client
    if (client != null) {
      client.write(httpRequest);
      return null;
    }

    return _createClient().then((_) {
      /*%TRACE3*/ print("(4> 6/16/14): _createClient!"); // TRACE%
      client.write(httpRequest);
      return client.stream.timeout(new Duration(minutes: 1)).first;
    }).then((List<int> responseBytes) {
      String response = new String.fromCharCodes(responseBytes);
      List<String> lines = response.split('\n');
      if (lines == null || lines.isEmpty) {
        return new Future.error('Bad response from push server');
      }

      if (lines.first.contains('200')) {
        monitor.worked(2);
        return true;
      } else {
        return new Future.error(lines.first);
      }
    }).then((_) => _closeClient())
    .catchError((error) => _closeClient().then((_) => throw error));
  }

  // Safe to call multiple times. It will open the device if it has not been opened yet.
  Future<AndroidDevice> _fetchAndroidDevice() {
    AndroidDevice device = new AndroidDevice(_prefs);

    Future doOpen(int index) {
      if (_knownDevices.length == 0) {
        return new Future.error('No known mobile devices.');
      }
      if (index >= _knownDevices.length) {
        return new Future.error('No known mobile device connected.\n'
            'Please ensure that you have a mobile device connected.');
      }

      DeviceInfo di = _knownDevices[index];
      return device.open(di.vendorId, di.productId).catchError((e) {
        if ((e == 'no-device') || (e == 'no-connection')) {
          // No matching device found, try again.
          return doOpen(index + 1);
        } else {
          return new Future.error('Connection to the Android device failed.\n'
              'Please check whether "Developer Options" and "USB debugging" is enabled on your device.\n'
              'Enable Developer Options by going in Settings > System > About phone and press 7 times on Build number.\n'
              '"Developer options" should now appear in Settings > System > Developer options. '
              'You can now enable "USB debugging" in that menu.');
        }
      });
    }

    return doOpen(0).then((_) {
      return device.connect(new SystemIdentity()).catchError((e) {
        device.dispose();
        throw e;
      });
    }).then((_) => device);
  }

  Future _pushToAdbServer(AdbClientTcp client, ProgressMonitor monitor) {
    // Start ADT on the device.
    //return client.startActivity(AdbApplication.CHROME_ADT);

    // Setup port forwarding to 2424 on the device.
    return client.forwardTcp(2424, 2424).then((_) {
      // TODO: a SocketException, code == -100 here often means that the App Dev
      // Tool is not running on the device.
      // Push the app binary to port 2424.
      return _sendHttpPush('127.0.0.1', monitor);
    });
  }

  Future _pushViaUSB(ProgressMonitor monitor) {
    List<int> httpRequest;
    AndroidDevice _device;

    // Build the archive.
    return archiveContainer(appContainer, true).then((List<int> archivedData) {
      monitor.worked(3);
      httpRequest = _buildHttpRequest('localhost', archivedData);
      monitor.worked(4);

      // Send this payload to the USB code.
      return _fetchAndroidDevice();
    }).then((deviceResult) {
      _device = deviceResult;

      return _device.sendHttpRequest(httpRequest, 2424).timeout(
          new Duration(minutes: 5), onTimeout: () {
            return new Future.error(
                'Push timed out: Total time exceeds 5 minutes');
          });
    }).then((msg) {
      monitor.worked(3);
      String resp = new String.fromCharCodes(msg);
      List<String> lines = resp.split('\r\n');
      Iterable<String> header = lines.takeWhile((l) => l.isNotEmpty);
      String body = lines.skip(header.length + 1).join('<br>\n');

      if (header.first.indexOf('200') < 0) {
        // Error! Fail with the error line.
        return new Future.error(
            '${header.first.substring(header.first.indexOf(' ') + 1)}: $body');
      } else {
        return body;
      }
    }).whenComplete(() {
      if (_device != null) _device.dispose();
    });
  }
}

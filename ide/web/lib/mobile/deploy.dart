// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to deploy a chrome app to an Android device.
 */
library spark.deploy;

import 'dart:async';
import 'dart:convert';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:chrome_net/tcp.dart';
import 'package:logging/logging.dart';

import 'adb.dart';
import 'adb_client_tcp.dart';
import '../apps/app_utils.dart';
import '../dependency.dart';
import '../jobs.dart';
import '../preferences.dart';
import '../spark_flags.dart';
import '../utils.dart';
import '../workspace.dart';
import '../workspace_utils.dart';

Logger _logger = new Logger('spark.deploy');
PreferenceStore get _localPrefs => localStore;

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
  static const int DEPLOY_PORT = 2424;
  static bool isAvailable() => chrome.usb.available;

  final Container appContainer;
  final PreferenceStore _prefs;

  List<DeviceInfo> _knownDevices = [];

  MobileDeploy(this.appContainer, this._prefs) {
    if (appContainer == null) {
      throw new ArgumentError('must provide an app to push');
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
    monitor.start('Deploying…', maxWork: 10);

    _logger.info('deploying application to ip host');
    HttpDeployer dep = new HttpDeployer(appContainer, _prefs, target);
    return dep.deploy(monitor);
  }

  /**
   * Push the application via ADB. We try connecting to a local ADB server
   * first. If that fails, then we try pushing via a USB connection.
   */
  Future pushAdb(ProgressMonitor monitor,{int productId: -1, int vendorId: -1}) {
    monitor.start('Deploying…', maxWork: 10);

    // Try to find a local ADB server. If we fail, try to use USB.
    return AdbClientTcp.createClient().then((AdbClientTcp client) {
      _logger.info('deploying application via adb server');
      return _pushToAdbServer(client, monitor);
    }, onError: (_) {
      _logger.info('deploying application via ADB over USB');

      // No server found, so use our own USB code.
      if (SparkFlags.enableNewUsbApi) {
        DeviceInfo info = new DeviceInfo(vendorId, productId, '');
        return _pushViaUSB(monitor, info);
      } else {
        return _pushViaUSB(monitor);
      }
    });
  }

  Future _pushToAdbServer(AdbClientTcp client, ProgressMonitor monitor) {
    // Start ADT on the device.
    // TODO: a SocketException, code == -100 here often means that the App Dev
    // Tool is not running on the device.
    // Setup port forwarding to DEPLOY_PORT on the device.
    return client.forwardTcp(DEPLOY_PORT, DEPLOY_PORT).then((_) {
      // Push the app binary on DEPLOY_PORT.
      ADBDeployer dep = new ADBDeployer(appContainer, _prefs);
      return dep.deploy(monitor);
    });
  }

  Future _pushViaUSB(ProgressMonitor monitor, [DeviceInfo info]) {
    USBDeployer dep = new USBDeployer(appContainer, _prefs);
    if (info != null) {
      dep.addToKnownDevices(info);
    }
    return dep.init().then((_) {
      return dep.deploy(monitor);
    });
  }
}

abstract class AbstractDeployer {
  static const int DEPLOY_PORT = 2424;
  static Duration REGULAR_REQUEST_TIMEOUT = new Duration(seconds: 2);
  static Duration PUSH_REQUEST_TIMEOUT = new Duration(seconds: 60);

  final Container appContainer;
  final PreferenceStore _prefs;

  List<String> fileToAdd = [];
  List<DeviceInfo> _knownDevices = [];

  AbstractDeployer(this.appContainer, this._prefs) {
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
   * Builds a request to given `target` at given `path` and with given `payload`
   * (body content).
   */
  List<int> _buildHttpRequest(String httpMethod, String target, String path, {List<int> payload}) {
    List<int> httpRequest = [];

    // Build the HTTP request headers.
    String header =
        '$httpMethod /$path HTTP/1.1\r\n'
        'User-Agent: Chrome Dev Editor\r\n'
        'Host: ${target}:$DEPLOY_PORT\r\n';
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
    return _buildHttpRequest("POST" ,target,
        "zippush?appId=${appContainer.project.name}&appType=chrome&movetype=file",
        payload: archivedData);
  }

  List<int> _buildDeleteRequest(String target, List<int> archivedData) {
    return _buildHttpRequest("POST" ,target,
        "deletefiles?appId=${appContainer.project.name}",
        payload: archivedData);
  }


  List<int> _buildLaunchRequest(String target) {
    return _buildHttpRequest("POST" ,target, "launch?appId=${appContainer.project.name}");
  }

  List<int> _buildAssetManifestRequest(String target) {
    return _buildHttpRequest("GET" ,target,
        "assetmanifest?appId=${appContainer.project.name}");
  }

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

  Future _expectHttpOkResponse(List<int> msg) {
    String response = new String.fromCharCodes(msg);
    List<String> lines = response.split('\r\n');
    Iterable<String> header = lines.takeWhile((l) => l.isNotEmpty);

    if (header.isEmpty) return new Future.error('Unexpected error during deploy.');

    String body = lines.skip(header.length + 1).join('<br>\n');

    if (!header.first.contains('200')) {
      // Error! Fail with the error line.
      return new Future.error(
          '${header.first.substring(header.first.indexOf(' ') + 1)}: $body');
    } else {
      return new Future.value(body);
    }
  }

  /// This method sends the command to the device and it's
  /// implementation depends on the deployment choice
  Future<List<int>> _pushRequestToDevice(List<int> httpRequest, Duration timeout);

  /// Get the deployment target URL
  String _getTarget();

  Future _setTimeout(Future httpPushFuture) {
    return httpPushFuture.timeout(new Duration(seconds: 60), onTimeout: () {
      return new Future.error('Push timed out: Total time exceeds 60 seconds');
    });
  }

  void _updateContainerEtag(String response) {
    Map<String, String> etagResponse = JSON.decode(response);
    setEtag(appContainer, etagResponse['assetManifestEtag']);
  }

  Future _deleteObsoleteFiles(String result) {
    List<String> fileToDelete = [];

    Map<String, Map<String, String>> assetManifestOnDevice = JSON.decode(result);
    if (assetManifestOnDevice['assetManifest'] != null) {
      Map<String, Map<String, String>> assetManifestLocal =
          JSON.decode(buildAssetManifest(appContainer));
      if (getEtag(appContainer) != assetManifestOnDevice['assetManifestEtag']) {
        setDeploymentTime(appContainer, 0);
      }
      assetManifestOnDevice['assetManifest'].keys.forEach((key) {
        if ((key.startsWith("www/"))
            && (!assetManifestLocal.containsKey(key))) {
          fileToDelete.add(key);
        }
      });

      assetManifestLocal.keys.forEach((key) {
        if ((key.startsWith("www/")) &&
            (!assetManifestOnDevice['assetManifest'].containsKey(key))) {
          fileToAdd.add(key);
        }
      });

      if (fileToDelete.isNotEmpty) {
        Map<String, List<String>> toDeleteMap = {};
        toDeleteMap["paths"] = fileToDelete;
        String command = JSON.encode(toDeleteMap);
        List<int> httpRequest = _buildDeleteRequest(_getTarget(), command.codeUnits);
        return _setTimeout(_pushRequestToDevice(httpRequest, REGULAR_REQUEST_TIMEOUT));
      }
      return new Future.value();
    } else {
      return new Future.value(setDeploymentTime(appContainer, 0));
    }
  }

  /// when the deployment is done this function is called to ensure
  /// that the used resources are disposed
  void _doWhenComplete();

  /// Implements the deployement flow
  Future deploy(ProgressMonitor monitor) {
    List<int> httpRequest;

    httpRequest = _buildAssetManifestRequest(_getTarget());
    return _setTimeout(_pushRequestToDevice(httpRequest, REGULAR_REQUEST_TIMEOUT))
      .then((msg) {
        return _expectHttpOkResponse(msg);
    }).then((String result) {
        return _deleteObsoleteFiles(result);
    }).then((msg) {
      if (msg != null) {
        monitor.worked(2);
        return _expectHttpOkResponse(msg);
      }
    }).then((_) {
      return archiveModifiedFilesInContainer(appContainer, true, fileToAdd)
        .then((List<int> archivedData) {
          monitor.worked(3);
          httpRequest = _buildPushRequest(_getTarget(), archivedData);
          return _setTimeout(_pushRequestToDevice(httpRequest, PUSH_REQUEST_TIMEOUT));
     }).then((msg) {
         monitor.worked(6);
         return _expectHttpOkResponse(msg);
    }).then((String response) {
      _updateContainerEtag(response);
      monitor.worked(7);
      httpRequest = _buildLaunchRequest(_getTarget());
      return _setTimeout(_pushRequestToDevice(httpRequest, REGULAR_REQUEST_TIMEOUT));
    }).then((msg) {
      monitor.worked(8);
      return _expectHttpOkResponse(msg);
    }).whenComplete(() {
      _doWhenComplete();
    });
    });
  }
}

class USBDeployer extends AbstractDeployer {
  static const int DEPLOY_PORT = 2424;
  static const String TARGET = 'localhost';
  AndroidDevice _device;

  USBDeployer(Container appContainer, PreferenceStore _prefs)
     : super(appContainer, _prefs) {
  }

  Future init () {
    return _fetchAndroidDevice().then((deviceResult) {
      _device = deviceResult;
      return new Future.value();
    });
  }

  Future<List<int>> _pushRequestToDevice(List<int> httpRequest, Duration timeout) {
    return _device.sendHttpRequest(httpRequest, DEPLOY_PORT, timeout);
  }

  void addToKnownDevices(DeviceInfo info) {
    _knownDevices = [info];
  }

  String _getTarget() {
    return TARGET;
  }

  void _doWhenComplete() {
    if (_device != null) _device.dispose();
  }
}

class HttpDeployer extends AbstractDeployer {
  static const int DEPLOY_PORT = 2424;
  String _target;

  HttpDeployer(Container appContainer, PreferenceStore _prefs, this._target)
     : super(appContainer, _prefs);

  Future<List<int>> _pushRequestToDevice(List<int> httpRequest, Duration timeout) {
    TcpClient client;
    return TcpClient.createClient(_target, DEPLOY_PORT).then((TcpClient client) {
      client.write(httpRequest);
      Stream st = client.stream.timeout(timeout);
      List<int> response = new List<int>();
      return st.forEach((List<int> data) {
        response.addAll(data);
      }).catchError((_) {
        return response;
      }).whenComplete(() {
        return response;
      });
    }).whenComplete(() {
      if (client != null) {
        client.dispose();
      }
    });
  }

  String _getTarget() {
    return _target;
  }

  void _doWhenComplete() {
  }
}

class ADBDeployer extends HttpDeployer {
  static const String TARGET = '127.0.0.1';

  ADBDeployer(Container appContainer, PreferenceStore _prefs)
     : super(appContainer, _prefs, TARGET) {
  }
}

class LiveDeployManager {
    static final LiveDeployManager _singleton = new LiveDeployManager._internal();
    Notifier _notifier = Dependencies.dependency[Notifier];
    StreamSubscription _sub;

    factory LiveDeployManager() {
      return _singleton;
    }

    void _init(Project currentProject) {
      if (SparkFlags.liveDeployMode) {
        if (_sub != null) _sub.cancel();
        _sub = currentProject.workspace.onResourceChange.listen(null);
        _sub.onData((ResourceChangeEvent event) {
          event.modifiedProjects.forEach((Project p) {
            if (p == currentProject) {
              return _localPrefs.getValue("live-deployment").then((value) {
                if (value == true) {
                  return _liveDeploy(getAppContainerFor(p));
                }
              });
            }
          });
        });
      }
    }

    static startLiveDeploy(Project currentProject) {
      _singleton._init(currentProject);
    }

    LiveDeployManager._internal();

    Future _liveDeploy(Container deployContainer) {
      ProgressMonitor _monitor = new ProgressMonitor();
      MobileDeploy deployer = new MobileDeploy(deployContainer, _localPrefs);

      // Invoke the deployer methods in Futures in order to capture exceptions.
      Future f = new Future(() {
        //TODO(grv): add support for new usb api.
        return deployer.pushAdb(_monitor);
      });

      return _monitor.runCancellableFuture(f).then((_) {
        setDeploymentTime(deployContainer,
            (new DateTime.now()).millisecondsSinceEpoch);
      }).catchError((e) {
        _singleton._notifier.showMessage('Error',
            'Error during live deployment: ${e}');
      }).whenComplete(() {
        _monitor = null;
      });
    }
}

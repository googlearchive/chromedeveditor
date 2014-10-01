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
  MobileBuildInfo _appInfo;

  MobileDeploy(this.appContainer, this._prefs, [this._appInfo]) {
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
  Future pushAdb(ProgressMonitor monitor) {
    monitor.start('Deploying…', maxWork: 10);

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

  Future buildWithHost(String target, ProgressMonitor monitor) {
    monitor.start('Building…', maxWork: 10);

    _logger.info('building application to ip host');
    HttpDeployer dep = new HttpDeployer(appContainer, _prefs, target);
    return dep.build(monitor, _appInfo);
  }


  Future buildWithAdb(ProgressMonitor monitor) {
    monitor.start('Building…', maxWork: 10);

    // Try to find a local ADB server. If we fail, try to use USB.
    return AdbClientTcp.createClient().then((AdbClientTcp client) {
      _logger.info('building application via adb server');
      return client.forwardTcp(DEPLOY_PORT, DEPLOY_PORT).then((_) {
        // Push the app binary on DEPLOY_PORT.
        ADBDeployer dep = new ADBDeployer(appContainer, _prefs);
        return dep.build(monitor, _appInfo);
      });
    }, onError: (_) {
      _logger.info('building application via ADB over USB');
      USBDeployer dep = new USBDeployer(appContainer, _prefs);
      return dep.init().then((_) {
        return dep.build(monitor, _appInfo);
      });
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

  Future _pushViaUSB(ProgressMonitor monitor) {
    USBDeployer dep = new USBDeployer(appContainer, _prefs);
    return dep.init().then((_) {
      return dep.deploy(monitor);
    });
  }
}

abstract class AbstractDeployer {
  static const int DEPLOY_PORT = 2424;
  static Duration REGULAR_REQUEST_TIMEOUT = new Duration(seconds: 2);
  static Duration PUSH_REQUEST_TIMEOUT = new Duration(seconds: 60);
  static Duration BUILD_REQUEST_TIMEOUT = new Duration(seconds: 120);

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

  List<int> _makeBuildRequest(String target, List<int> archivedData) {
    return _buildHttpRequest("POST" ,target,
        "buildapk?appId=${appContainer.project.name}&appType=chrome",
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

  Future sleep1() {
    return new Future.delayed(const Duration(seconds: 10), () => "1");
  }

  Future build(ProgressMonitor monitor, MobileBuildInfo appInfo) {
    List<int> httpRequest;
    List<int> ad;

    httpRequest = _buildAssetManifestRequest(_getTarget());
    return _setTimeout(_pushRequestToDevice(httpRequest, REGULAR_REQUEST_TIMEOUT))
      .then((msg) {
        return _expectHttpOkResponse(msg);
    }).then((String result) {
        return _deleteObsoleteFiles(result);
    }).then((msg) {
      if (msg != null) {
        return _expectHttpOkResponse(msg);
      }
    }).then((_) {
      return archiveModifiedFilesInContainer(appContainer, true, [])
      .then((List<int> archivedData) {
          ad = archivedData;
          httpRequest = _buildPushRequest(_getTarget(), archivedData);
          return _setTimeout(_pushRequestToDevice(httpRequest, PUSH_REQUEST_TIMEOUT));
     }).then((msg) {
         return _expectHttpOkResponse(msg);
    }).then((String response) {
      _updateContainerEtag(response);
      return archiveDataForBuild(appContainer, appInfo);
    }).then((List<int> archivedData) {
      return sleep1();
    }).then((_) {

      Map<String, String> signInfo = new Map<String, String>();

      signInfo['storePassword']= 'android';
      signInfo['keyAlias']= 'AndroidDebugKey';
      signInfo['keyPassword'] = 'android';
      signInfo['storeData']="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"
+"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";
      httpRequest = _makeBuildRequest(_getTarget(), JSON.encode(signInfo).codeUnits);
      //TODO(albualexandru): make the request and save the file
      return _setTimeout(_pushRequestToDevice(httpRequest, BUILD_REQUEST_TIMEOUT));
      //return new Future.value("bla");
    }).then((msg) {
          return _expectHttpOkResponse(msg);
    }).then((String response) {
        print(response);
      //need to prompt for save as to save the APK
      chrome.ChooseEntryOptions options = new chrome.ChooseEntryOptions(
              type: chrome.ChooseEntryType.SAVE_FILE);
      return chrome.fileSystem.chooseEntry(options).then(
          (chrome.ChooseEntryResult res) {
        chrome.ChromeFileEntry r = res.entry;
        r.writeBytes(new chrome.ArrayBuffer.fromBytes(ad));
        return new Future.error("Not implemented");
      });
    });
    }).whenComplete(() {
      _doWhenComplete();
    });
}

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

class MobileBuildInfo {
  Map<String, String> mobileAppManifest = {};
  chrome.ChromeFileEntry publicKey;
  chrome.ChromeFileEntry privateKey;
}

// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * Launch services.
 */
library spark.launch;

import 'dart:async';
import 'dart:convert';
import 'dart:core' hide Resource;
import 'dart:html' show window;

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:chrome/gen/management.dart';
import 'package:chrome_net/server.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import 'apps/app_utils.dart';
import 'developer_private.dart';
import 'enum.dart';
import 'exception.dart';
import 'jobs.dart';
import 'package_mgmt/package_manager.dart';
import 'package_mgmt/pub.dart';
import 'platform_info.dart';
import 'services.dart';
import 'utils.dart';
import 'workspace.dart';
import 'workspace_utils.dart';

final Logger _logger = new Logger('spark.launch');

final NumberFormat _nf = new NumberFormat.decimalPattern();

final String SPARK_NIGHTLY_ID ="kcjgcakhgelcejampmijgkjkadfcncjl";
final String SPARK_NIGHTLY_KEY =
    "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwqXKrcvbi1a1IjFM5COs07Ee9xvPyO"
    "Sh9dhEF6kwBGjAH6/4F7MHOfPk+W04PURi707E8SsS2iCkvrMiJPh4GnrZ3fWqFUzlsAcUljcY"
    "bkyorKxglwdZEXWbFgcKVR/uzuzXD8mOcuXRLu0YyVSdEGzhfZ1HkeMQCKEncUCL5ziE4ZkZJ7"
    "I8YVhVG+uiROeMg3zjxxSQrYHOfG5HOqmVslRPCfyiRbIHH3JPD0lax5FudngdKy0+1nkkqVJC"
    "pRSf75cRRnxGPjdEvNzTEFmf5oGFxSVs7iXoVQvNXB35Qfyw5rV6N+JyERdu6a7xEnz9lbw41m"
    "/noKInlfP+uBQuaQIDAQAB";

final String SPARK_RELEASE_ID ="pnoffddplpippgcfjdhbmhkofpnaalpg";
final String SPARK_RELEASE_KEY =
    "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2OvldPjAqgEboHyyZM7GpCMmGMSQ8a"
    "ExOlQyOhN3C9fDRXqnAN/Ie20TEwD9Eb2CciV3Ru4Gm7PmDnkHzsljD84qLgBdN39FzPGDyViX"
    "TS442xTElWRZMZQfJYQpbMpiePL720kTHgLLAcwTgdP9DnvRPrKukIs/U4Y76NFk7NNbsNOc6F"
    "WisLJykw2POTB1RR5ZlZrA4Ax1P7kt7qQdomE6i8wy1TA1jDhG8AhEXKRfpyELvJmzyVIyR9ui"
    "SHDHCdihiS5oyjADjmmbklvL7Ns0cSAgEX/lWN8UX8r17zoKZzJ0MkmCQ5Nlfql8qUtn2oZXaH"
    "ztkkAcXCxkq9/37QIDAQAB";

class LaunchManager {
  final Workspace workspace;
  final Services _services;
  final PackageManager _pubManager;
  final PackageManager _bowerManager;
  final Notifier _notifier;

  Project _lastLaunchedProject;

  List<ApplicationLocator> applicationLocators = [];
  List<LaunchTargetHandler> launchTargetHandlers = [];
  List<LaunchParticipant> launchParticipants = [];

  LaunchManager(this.workspace, this._services, this._pubManager,
      this._bowerManager, this._notifier, LaunchController launchController) {

    applicationLocators.add(new ChromeAppLocator());
    applicationLocators.add(new WebAppLocator());

    launchTargetHandlers.add(new ChromeAppLocalLaunchHandler());
    launchTargetHandlers.add(new ChromeAppRemoteLaunchHandler(launchController));
    WebAppLocalLaunchHandler localWebHandler = new WebAppLocalLaunchHandler(
        this, workspace, _services, _pubManager, _bowerManager, _notifier);
    launchTargetHandlers.add(localWebHandler);
    launchTargetHandlers.add(
        new WebAppRemoteLaunchHandler(localWebHandler, _notifier));

    launchParticipants.add(new PubLaunchParticipant(_pubManager, _notifier));
    launchParticipants.add(new DartChromeAppParticipant(_services, _notifier));
  }

  /**
   * Indicates whether a particular [Resource] can be run.
   */
  bool canLaunch(Resource resource, LaunchTarget target) {
    Application application = _locateApplication(resource);
    if (application == null) return false;

    LaunchTargetHandler handler = _locateLaunchHandler(application, target);
    return handler != null;
  }

  /**
   * Launches the given [Resouce].
   */
  Future performLaunch(Resource resource, LaunchTarget target) {
    Application application = _locateApplication(resource);
    if (application == null) {
      _logger.warning('application to launch is null');
      return new Future.value();
    }

    LaunchTargetHandler handler = _locateLaunchHandler(application, target);
    if (handler == null) return new Future.value();

    _lastLaunchedProject = resource.project;

    List futures = [];
    List<LaunchParticipant> participants =
        _locateLaunchParticipants(application, target);
    participants.forEach((participant) {
      futures.add(participant.run(application, target));
    });

    return Future.wait(futures).then((List<bool> results) {
      if (results.any((result) => result == false)) {
        return new Future.value();
      } else {
        // All checks passed, continue launch.
        return handler.launch(application, target);
      }
    });
  }

  List<LaunchParticipant> _locateLaunchParticipants(
      Application application, LaunchTarget target) {
    List<LaunchParticipant> participants = [];
    launchParticipants.forEach((launchParticipant) {
      if (launchParticipant.canParticipate(application, target)) {
        participants.add(launchParticipant);
      }
    });
    return participants;
  }

  // This statefulness is for use by Bower, and will go away at some point.
  Project get lastLaunchedProject => _lastLaunchedProject;

  void dispose() {
    launchTargetHandlers.forEach((handler) => handler.dispose());
  }

  Application _locateApplication(Resource initialResource) {
    List<ApplicationResult> results = [];

    applicationLocators.forEach((locator) {
      ApplicationResult result = locator.locateAssociatedApplication(initialResource);
      if (result != null) {
        results.add(result);
      }
    });

    if (results.isEmpty) return null;

    results.sort();

    return results.last.application;
  }

  LaunchTargetHandler _locateLaunchHandler(Application application,
      LaunchTarget target) {
    for (LaunchTargetHandler handler in launchTargetHandlers) {
      if (handler.canLaunch(application, target)) {
        return handler;
      }
    }

    return null;
  }
}

abstract class LaunchController {
  void displayDeployToMobileDialog(Resource launchResource);
}

/**
 * The environments we know how to run applications in.
 */
class LaunchTarget extends Enum<String> {
  /// A local target - executing on the local device.
  static const LOCAL = const LaunchTarget._('local');

  /// A remote deploy - typically, executing on a mobile device.
  static const REMOTE = const LaunchTarget._('remote');

  const LaunchTarget._(String val) : super(val);

  String get enumName => 'LaunchTarget';
}

/**
 * The type of applications we know how to launch.
 */
class ApplicationType extends Enum<String> {
  static const CHROME_APP = const ApplicationType._('chrome_app');
  static const WEB_APP = const ApplicationType._('web_app');

  const ApplicationType._(String val) : super(val);

  String get enumName => 'ApplicationType';
}

/**
  * How certain we are that the application found is the correct one to launch.
  * `0.0` means not at all certain. `1.0` means absolutely certain. As an
  * example of affinities, a resource that is contained inside a chrome app
  * will return an affinity of `0.7` for launching that chrome app. An html
  * resource in the same app will return an affinity of `0.5` for launching a
  * web app. This ensures that the chrome app is choosen by the framework as
  * the app to launch.
  */
class Affinity extends Enum<num> {
  static const VERY_CERTAIN = const Affinity._(1.0);
  static const ALMOST_CERTAIN = const Affinity._(0.8);
  static const KIND_OF_CERTAIN = const Affinity._(0.7);
  static const MAYBE = const Affinity._(0.6);
  static const ON_THE_FENCE = const Affinity._(0.5);
  static const NOT_AT_ALL_CERTAIN = const Affinity._(0);

  const Affinity._(num val) : super(val);

  int compareTo(Affinity other) => value.compareTo(other.value);

  String get enumName => 'Affinity';
}

/**
 * An instance of an ApplicationType.
 */
class Application {
  final Resource primaryResource;
  final ApplicationType appType;

  final Map<String, String> _properties = {};

  Application(this.primaryResource, this.appType);

  String get name => appType == ApplicationType.CHROME_APP ?
      primaryResource.project.name : primaryResource.name;

  String getProperty(String key) => _properties[key];

  void setProperty(String key, String value) {
    _properties[key] = value;
  }

  bool get isDart => getProperty('dart') != null;

  String toString() => name;
}

/**
 * Given a starting resource, return an associated [Application], if any.
 */
abstract class ApplicationLocator {
  ApplicationResult locateAssociatedApplication(Resource resource);

  bool _isDartApp(Resource resource) {
    Container container = resource is Container ? resource : resource.parent;
    bool result = findPubspec(container) != null ? true : false;
    return result;
  }
}

/**
 * A tuple of an [Application] and an [Affinity].
 */
class ApplicationResult implements Comparable {
  /**
   * The application that was located.
   */
  final Application application;
  final Affinity affinity;

  ApplicationResult(this.application, this.affinity);

  int compareTo(ApplicationResult other) => affinity.compareTo(other.affinity);

  String toString() => '[${application}, ${affinity}]';
}

/**
 * Can launch a certain type of [Application] for a given [LaunchTarget].
 */
abstract class LaunchTargetHandler {
  String get name;

  bool canLaunch(Application application, LaunchTarget launchTarget);

  Future launch(Application application, LaunchTarget launchTarget);

  void dispose();

  String toString() => name;
}

/**
 * Performs prelaunch checks, based on a type of [Application] and [LaunchTarget].
 * Called before the [LaunchTargetHandler].
 */
abstract class LaunchParticipant {
  String get name;

  bool canParticipate(Application application, LaunchTarget launchTarget);

  /**
   * Participants can cancel the launch by returning false.
   */
  Future<bool> run(Application application, LaunchTarget launchTarget);

  String toString() => name;
}

class ChromeAppLocator extends ApplicationLocator {
  @override
  ApplicationResult locateAssociatedApplication(Resource resource) {
    Container container = getAppContainerFor(resource);
    if (container == null) return null;

    Application application = new Application(container, ApplicationType.CHROME_APP);
    if (_isDartApp(container)) {
      application.setProperty('dart', 'true');
    }

    return new ApplicationResult(application, Affinity.ALMOST_CERTAIN);
  }
}

class WebAppLocator extends ApplicationLocator {
  @override
  ApplicationResult locateAssociatedApplication(Resource resource) {
    if (resource.project == null) return null;

    // We can always launch .htm and .html files.
    if (resource is File) {
      if (resource.name.endsWith('.html') || resource.name.endsWith('.htm')) {
        return new ApplicationResult(
           _createApplication(resource), Affinity.KIND_OF_CERTAIN);
      }
    }

    // Check to see if there is a launchable file in the current folder.
    Container parent;
    if (resource is Container) {
      parent = resource;
    } else {
      parent = resource.parent;
    }

    if (_getLaunchResourceIn(parent) != null) {
      Resource r = _getLaunchResourceIn(parent);
      return new ApplicationResult(
           _createApplication(r), Affinity.MAYBE);
    }

    // Check for a launchable file in web/.
    if (resource.project.getChild('web') is Container) {
      Resource r = _getLaunchResourceIn(resource.project.getChild('web'));
      if (r != null) {
        return new ApplicationResult(
           _createApplication(r), Affinity.MAYBE);
      }
    }

    return null;
  }

  Application _createApplication(Resource resource) {
    Application application = new Application(resource, ApplicationType.WEB_APP);
    if (_isDartApp(resource)) {
      application.setProperty('dart', 'true');
    }
    return application;
  }

  Resource _getLaunchResourceIn(Container container) {
    if (container.getChild('index.html') is File) {
      return container.getChild('index.html');
    }

    for (Resource resource in container.getChildren()) {
      if (resource is File) {
        if (resource.name.endsWith('.html') || resource.name.endsWith('.htm')) {
          return resource;
        }
      }
    }

    return null;
  }
}

/**
 * A launch target handler to launch chrome apps locally on the development
 * machine.
 */
class ChromeAppLocalLaunchHandler extends LaunchTargetHandler {
  String get name => 'Chrome App';

  bool canLaunch(Application application, LaunchTarget launchTarget) {
    return launchTarget == LaunchTarget.LOCAL &&
        application.appType == ApplicationType.CHROME_APP;
  }

  Future launch(Application application, LaunchTarget launchTarget) {
    if (!management.available) {
      return new Future.error(
          'Unable to launch; the chrome.management API is not available.');
    }

    if (!developerPrivate.available) {
      return new Future.error(
          'Unable to launch; the chrome.developerPrivate API is not available.');
    }

    Container container = application.primaryResource;

    // TODO(grv): remove after chrome 38 is stable.
    final Pattern pattern = '/special/drive-';
    if (PlatformInfo.chromeVersion < 38 && PlatformInfo.isCros &&
        container.entry.fullPath.startsWith(pattern)) {
      return new Future.error(
          'Unable to launch; running Chrome Apps from Google Drive is only '
          'supported in Chrome 38 or higher.');
    }

    String idToLaunch;

    // Check if we need to fiddle with the app id to launch Spark.
    return _rewriteManifest(container.entry).then((String id) {
      idToLaunch = id;
      return developerPrivate.loadDirectory(container.entry);
    }).then((String appId) {
      // TODO: Use the returned appId once it has the correct results.
      // TODO: Delay a bit - there's a race condition.
      return new Future.delayed(new Duration(milliseconds: 500));
    }).then((_) {
      if (idToLaunch != null) return idToLaunch;
      // TODO(grv): This assumes that the loaded extension is directly loaded
      // from its location. This will not work with syncfs projects as they are
      // copied into apps_target directory. Remove this hack once the api returns
      // the appID on loading. The issue is tracked here
      // https://github.com/dart-lang/chromedeveditor/issues/3054
      return _getAppId(getOsPath(container.path));
    }).then((String launchId) {
      _launchId(launchId);
    });
  }

  /**
   * Launches a chrome app with given [id].
   */
  Future _launchId(String id) {
    if (id == null) {
      throw new SparkException(
          SparkErrorMessages.RUN_APP_NOT_FOUND_IN_CHROME_MSG,
          errorCode: SparkErrorConstants.RUN_APP_NOT_FOUND_IN_CHROME);
    }
    return management.launchApp(id);
  }

  String getOsPath(String path) {
    if (PlatformInfo.isWin) {
      path = path.replaceAll('/', '\\');
    }
    return path;
  }

  /**
   * TODO(grv): This is a temporary function until loadDirectory returns the
   * app_id.
   */
  Future<String> _getAppId(String path) {
    return developerPrivate.getItemsInfo(false, false).then((List<ItemInfo> items) {
      for (ItemInfo item in items) {
        if (item.is_unpacked && item.path.endsWith(path)) {
          return item.id;
        }
      };
      return null;
    });
  }

  /**
   * Update the manifest to re-write the app id if we are launching Spark.
   */
  Future<String> _rewriteManifest(chrome.DirectoryEntry dir) {
    String id = chrome.runtime.id;
    String launchId;

    // Special logic for launching spark within spark.
    // TODO (grv) : Implement a better way of handling launch of spark from
    // spark.
    if (id == SPARK_NIGHTLY_ID || id == SPARK_RELEASE_ID) {
      return dir.getFile('manifest.json').then((entry) {
        return entry.readText().then((content) {
          var manifestDict = JSON.decode(content);

          String key = manifestDict['key'];
          if (id == SPARK_NIGHTLY_ID && key == SPARK_NIGHTLY_KEY) {
            manifestDict['key'] = SPARK_RELEASE_KEY;
            launchId = SPARK_RELEASE_ID;
          } else if (id == SPARK_RELEASE_ID && key == SPARK_RELEASE_KEY) {
            manifestDict['key'] = SPARK_NIGHTLY_KEY;
            launchId = SPARK_NIGHTLY_ID;
          } else {
            return new Future.value();
          }

          // This modifies the manifest file permanently.
          return entry.writeText(new JsonPrinter().print(manifestDict)).then((_) {
            return new Future.value(launchId);
          });
        });
      });
    } else {
      return new Future.value();
    }
  }

  void dispose() { }
}

/**
 * A launch target handler to launch chrome apps on mobile devices.
 */
class ChromeAppRemoteLaunchHandler extends LaunchTargetHandler {
  final LaunchController launchController;

  ChromeAppRemoteLaunchHandler(this.launchController);

  String get name => 'Remote Chrome App';

  bool canLaunch(Application application, LaunchTarget launchTarget) {
    return launchTarget == LaunchTarget.REMOTE &&
        application.appType == ApplicationType.CHROME_APP;
  }

  Future launch(Application application, LaunchTarget launchTarget) {
    launchController.displayDeployToMobileDialog(application.primaryResource);
    return new Future.value();
  }

  void dispose() { }
}

/**
 * A launch target handler to launch web apps on locally on the development
 * machine.
 */
class WebAppLocalLaunchHandler extends LaunchTargetHandler {
  final int preferredPort = 31999;

  final LaunchManager launchManager;
  final Workspace workspace;
  final Services services;
  final PackageManager pubManager;
  final PackageManager bowerManager;

  Project get lastLaunchedProject => launchManager.lastLaunchedProject;

  PicoServer server;

  WebAppLocalLaunchHandler(this.launchManager, this.workspace, this.services,
      this.pubManager, this.bowerManager, Notifier notifier) {
    _createServer(preferredPort).then((s) {
      server = s;

      CompilerService compiler = services.getService("compiler");

      server.addServlet(new StaticResourcesServlet());
      server.addServlet(new Dart2JsServlet(workspace, notifier, compiler));
      server.addServlet(new PubPackagesServlet(workspace, pubManager));
      server.addServlet(new WorkspaceServlet(workspace));
      server.addServlet(new BowerPackagesServlet(this, bowerManager));

      _logger.info('embedded web server listening on port ${server.port}');
    }).catchError((error) {
      _logger.severe('Error starting up embedded server', error);
    });
  }

  Future<PicoServer> _createServer(int port) {
    return PicoServer.createServer(port).then((server) {
      return server;
    }).catchError((error) {
      _logger.info('could not open a port on ${port}');
      return PicoServer.createServer().then((server) {
        return server;
      });
    });
  }

  String get name => 'Web app';

  bool canLaunch(Application application, LaunchTarget launchTarget) {
    return launchTarget == LaunchTarget.LOCAL &&
        application.appType == ApplicationType.WEB_APP;
  }

  Future launch(Application application, LaunchTarget launchTarget) {
    window.open(_getUrlFor(server, application.primaryResource), '_blank');

    return new Future.value();
  }

  void dispose() {
    if (server != null) {
      server.dispose();
    }
  }

  String _getUrlFor(PicoServer server, Resource resource) {
    return 'http://127.0.0.1:${server.port}${resource.path}';
  }
}

/**
 * A launch target handler to launch web apps on mobile devices.
 */
class  WebAppRemoteLaunchHandler extends LaunchTargetHandler {
  final WebAppLocalLaunchHandler _localLaunchHandler;
  final Notifier _notifier;

  WebAppRemoteLaunchHandler(this._localLaunchHandler, this._notifier);

  String get name => 'Remote web app';

  PicoServer get server => _localLaunchHandler.server;

  bool canLaunch(Application application, LaunchTarget launchTarget) {
    return launchTarget == LaunchTarget.REMOTE &&
        application.appType == ApplicationType.WEB_APP;
  }

  Future launch(Application application, LaunchTarget launchTarget) {
    return getHostIP().then((hostIP) {
      if (application.isDart) {
        _notifier.showMessage('Mobile Web Deploy',
            'Please start Chrome or the Dart Content Shell on your connected '
            'mobile device and point it to '
            '${_getUrlFor(hostIP, server, application.primaryResource)}. You '
            'may need to set up port forwarding from your mobile device to port '
            '${server.port}.\nThe Dart Content Shell application can be found '
            'in the Dart SDK, available at www.dartlang.org.');
      } else {
        _notifier.showMessage('Mobile Web Deploy',
            'Please start Chrome on your connected mobile device and point it to '
            '${_getUrlFor(hostIP, server, application.primaryResource)}. You '
            'may need to set up port forwarding from your mobile device to '
            'port ${server.port}.');
      }
    });
  }

  void dispose() { }

  String _getUrlFor(String hostIP, PicoServer server, Resource resource) {
    return 'http://${hostIP}:${server.port}${resource.path}';
  }
}

/**
 * A launch pariticipant that works on dart apps. It checks to see if all the
 * specified packages are installed. If not it displays a message and terminates
 * the launch.
 */
class PubLaunchParticipant extends LaunchParticipant {
  final PackageManager pubManager;
  final Notifier notifier;

  PubLaunchParticipant(this.pubManager, this.notifier);

  String get name => 'Pub';

  bool canParticipate(Application application, LaunchTarget launchTarget) =>
      application.isDart;

  Future<bool> run(Application application, LaunchTarget launchTarget) {
    return pubManager.arePackagesInstalled(application.primaryResource.parent)
        .then((installed) {
      if (installed is String) {
        // TODO(devoncarew): This should give the user the option of continuing
        // the launch.
        return notifier.showMessageAndWait(
          'Run',
          "The '${installed}' package is missing from the packages directory. "
          "The application may not run correctly. To provision the packages, "
          "right-click on the pubspec.yaml file and select 'Pub Get'.");
      }
      return new Future.value(true);
    });
  }
}

/**
 * A launch pariticipant that works on dart chrome apps, and compiles the Dart
 * code to JavaScript on launch.
 */
class DartChromeAppParticipant extends LaunchParticipant {
  static final RegExp _regex1 = new RegExp(
      r'''<script\s+src=["'](\w+\.dart)["']\s+type=["']application/dart["']\s*>\s*</script>''');
  static final RegExp _regex2 = new RegExp(
      r'''<script\s+type=["']application/dart["']\s+src=["'](\w+\.dart)["']\s*>\s*</script>''');

  final Services _services;
  final Notifier _notifier;

  DartChromeAppParticipant(this._services, this._notifier);

  String get name => null;

  bool canParticipate(Application application, LaunchTarget launchTarget) {
    if (application.appType == ApplicationType.CHROME_APP && application.isDart) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> run(Application application, LaunchTarget launchTarget) {
    bool compileToJs = false;

    // If deploying the app, we always compile to JavaScript. If running it
    // locally, we only compile if the current runtime is not Dartium.
    if (launchTarget == LaunchTarget.REMOTE) {
      compileToJs = true;
    } else if (launchTarget == LaunchTarget.LOCAL) {
      compileToJs = isDart2js();
    }

    // Copy the /packages directory to /container/packages. Then optionally
    // compile the Dart code.

    return _copyPackages(application.primaryResource).then((_) {
      if (compileToJs) {
        return _compileToJs(application, launchTarget);
      }
    }).then((_) {
      // Continue the deploy.
      return true;
    }).catchError((e) {
      // Show an error message.
      String message = e is SparkException ? e.message : '${e}';
      _notifier.showMessage('Error Compiling File', message);

      // Cancel the deploy.
      return false;
    });
  }

  Future _compileToJs(Application application, LaunchTarget target) {
    Container container = application.primaryResource;

    // We need to parse the manifest, locate the entry point js script, parse
    // that to find the starting html file, parse that to find the Dart file to
    // compile.

    // Or, find all html files in the current directory. Look through them for
    // likely Dart scripts to compile.
    Iterable<File> htmlFiles = container.getChildren().where(
        (child) => child.isFile && isHtmlFilename(child.name));

    Set<File> dartFiles = new Set();
    File file;
    CompileResult result;

    return Future.forEach(htmlFiles, (file) {
      return _locateDartEntryPoints(file, dartFiles);
    }).then((_) {
      if (dartFiles.isEmpty) return true;

      // TODO(devoncarew): If there is more then 1 file, what do we do?
      CompilerService compiler = _services.getService("compiler");
      file = dartFiles.first;

      if (!_dartFileUpToDate(file, csp: true)) {
        // Show progress for the compile.
        Completer completer = new Completer();
        ProgressJob job = new ProgressJob('Compiling ${file.name}…', completer);
        container.workspace.jobManager.schedule(job);

        return compiler.compileFile(file, csp: true).then((CompileResult r) {
          result = r;

          if (!result.getSuccess()) throw new SparkException('${result}');

          String newFileName = '${file.name}.js';
          return file.parent.getOrCreateFile(newFileName, true);
        }).then((File newFile) {
          return newFile.setContents(result.output);
        }).whenComplete(() => completer.complete());
      }
    }).then((_) {
      return true;
    });
  }

  Future _locateDartEntryPoints(File htmlFile, Set<File> dartFiles) {
    return htmlFile.getContents().then((contents) {
      Iterable<String> paths = _getDartAppNames(contents);
      Iterable<File> files = paths
          .map((path) => resolvePath(htmlFile, path))
          .where((f) => f != null);
      dartFiles.addAll(files);
    });
  }

  Iterable<String> _getDartAppNames(String htmlContent) {
    List<String> results = [];

    Iterable<Match> matches = _regex1.allMatches(htmlContent);
    results.addAll(matches.map((match) => match.group(1)));

    matches = _regex2.allMatches(htmlContent);
    results.addAll(matches.map((match) => match.group(1)));

    return results;
  }

  /**
   * Copy any packages/ directory from the root of the project to the given
   * `container` directory.
   */
  Future _copyPackages(Container container) {
    Resource r =
        container.project.getChild(pubProperties.getPackagesDirName(container));

    if (r is Container) {
      return copyResource(r, container);
    } else {
      return new Future.value();
    }
  }
}

/**
 * A servlet that can serve `package:` urls (`/packages/`).
 */
class PubPackagesServlet extends PicoServlet {
  final Workspace workspace;
  final PackageManager pubManager;

  PubPackagesServlet(this.workspace, this.pubManager);

  bool canServe(HttpRequest request) {
    return request.uri.pathSegments.contains('packages');
  }

  Future<HttpResponse> serve(HttpRequest request) {
    String projectName = request.uri.pathSegments[0];
    Container project = workspace.getChild(projectName);

    if (project is Project) {
      PackageResolver resolver = pubManager.getResolverFor(project);
      File file = resolver.resolveRefToFile(_getPath(request));
      if (file != null) {
        return _serveFileResponse(file);
      }
    }

    return new Future.value(new HttpResponse.notFound());
  }
}

/**
 * A servlet that can serve Bower content from `bower_components`. This looks
 * for requests that match content in a `bower_components` directory and serves
 * that content. Our process looks like:
 *
 * - record the current project (the last launched project)
 * - use that to determine the correct `bower_components` directory
 * - look inside that directory for a file matching the current request
 *
 * So, a file `/FooProject/demo.html` will include a relative reference to a
 * polymer file. This reference will look like `../polymer/polymer.js`. The
 * browser will canonicalize that and ask our server for `/polymer/polymer.js`.
 * We'll convert that into a request for
 * `/FooProject/bower_components/polymer/polymer.js` and serve that file back.
 */
class BowerPackagesServlet extends PicoServlet {
  final WebAppLocalLaunchHandler webLaunchHandler;
  final PackageManager bowerManager;

  // TODO(devoncarew): We will want to change this from trying to serve
  // content from the last launch, to creating a server per project. This will
  // let us do something better then just guessing the project the user wants to
  // serve bower content from.
  BowerPackagesServlet(this.webLaunchHandler, this.bowerManager);

  bool canServe(HttpRequest request) {
    return _resolveRequest(request) != null;
  }

  Future<HttpResponse> serve(HttpRequest request) {
    File file = _resolveRequest(request);

    if (file != null) {
      return _serveFileResponse(file);
    } else {
      return new Future.value(new HttpResponse.notFound());
    }
  }

  File _resolveRequest(HttpRequest request) {
    Project project = webLaunchHandler.lastLaunchedProject;
    if (project == null) return null;

    if (!bowerManager.properties.isFolderWithPackages(project)) return null;

    String url = _getPath(request);
    File file = bowerManager.getResolverFor(project).resolveRefToFile(url);
    return file;
  }
}

/**
 * A servlet that can serve files from any of the [Project]s in the [Workspace]
 */
class WorkspaceServlet extends PicoServlet {
  final Workspace workspace;

  WorkspaceServlet(this.workspace);

  bool canServe(HttpRequest request) {
    if (request.uri.pathSegments.length <= 1) return false;
    var projectNamesList = workspace.getProjects().map((project) => project.name);
    return projectNamesList.contains(request.uri.pathSegments[0]);
  }

  Future<HttpResponse> serve(HttpRequest request) {
    String path = _getPath(request);

    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    Resource resource = workspace.getChildPath(path);

    if (resource is File) {
      return _serveFileResponse(resource);
    }

    if (resource is Container) {
      if (resource.getChild('index.html') != null) {
        // Issue a 302 redirect.
        HttpResponse response = new HttpResponse(statusCode: HttpStatus.FOUND);
        response.headers.set(HttpHeaders.LOCATION, request.uri.resolve('index.html'));
        response.headers.set(HttpHeaders.CONTENT_LENGTH, 0);
        return new Future.value(response);
      }
    }

    return new Future.value(new HttpResponse.notFound());
  }
}

Future<HttpResponse> _serveFileResponse(File file) {
  return file.getBytes().then((chrome.ArrayBuffer buffer) {
    HttpResponse response = new HttpResponse.ok();
    response.setContentBytes(buffer.getBytes());
    response.setContentTypeFrom(file.name);
    return new Future.value(response);
  }, onError: (_) {
    return new Future.value(new HttpResponse.notFound());
  });
}

/**
 * Serves up resources like `favicon.ico`.
 */
class StaticResourcesServlet extends PicoServlet {
  bool canServe(HttpRequest request) {
    return request.uri.path == '/favicon.ico';
  }

  Future<HttpResponse> serve(HttpRequest request) {
    HttpResponse response = new HttpResponse.ok();
    return getAppContentsBinary('images/icon_32.png').then((List<int> bytes) {
      response.setContentStream(new Stream.fromIterable([bytes]));
      response.setContentTypeFrom('favicon.ico');
      return new Future.value(response);
    });
  }
}

///**
// * Servlet that redirects to the landing page for the project that was run.
// */
//class ProjectRedirectServlet extends PicoServlet {
//  final LaunchManager _launchManager;
//  final PicoServer _server;
//  Resource _launchFile;
//
//  ProjectRedirectServlet(this._launchManager, this._server);
//
//  bool canServe(HttpRequest request) {
//    return request.uri.path == '/';
//  }
//
//  Future<HttpResponse> serve(HttpRequest request) {
//    String url = 'http://127.0.0.1:${_server.port}${launchPath}';
//
//    // Issue a 302 redirect.
//    HttpResponse response = new HttpResponse(statusCode: HttpStatus.FOUND);
//    response.headers.set(HttpHeaders.LOCATION, url);
//    response.headers.set(HttpHeaders.CONTENT_LENGTH, 0);
//
//    return new Future.value(response);
//  }
//
//  String get launchPath => _launchFile.path;
//}

// 3 successive launches; dart2js warms up quite a bit.
// [INFO] spark.launch: compiled /solar/web/solar.dart in 6,446 ms
// [INFO] spark.launch: compiled /solar/web/solar.dart in 2,928 ms
// [INFO] spark.launch: compiled /solar/web/solar.dart in 2,051 ms

/**
 * Servlet that compiles and serves up the JavaScript for Dart sources.
 */
class Dart2JsServlet extends PicoServlet {
  final Workspace workspace;
  final Notifier notifier;
  CompilerService compiler;

  Dart2JsServlet(this.workspace, this.notifier, CompilerService compiler) {
    this.compiler = new _CachingCompiler(compiler);
  }

  bool canServe(HttpRequest request) {
    String path = _getPath(request);
    return path.endsWith('.dart.js') && _getResource(path) is File;
  }

  Resource _getResource(String path) {
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    // check if there is a corresponding dart file
    var dartFileName = path.substring(0, path.length - 3);
    return workspace.getChildPath(dartFileName);
  }

  Future<HttpResponse> serve(HttpRequest request) {
    File file = _getResource(_getPath(request));
    Stopwatch stopwatch = new Stopwatch()..start();
    Completer completer = new Completer();

    file.workspace.jobManager.schedule(
        new ProgressJob('Compiling ${file.name}…', completer));

    // We cache the compiled results and re-use if this file is requested again
    // and the dependencies haven't changed.
    return compiler.compileFile(file).then((CompileResult result) {
      if (!result.hasOutput) {
        // Display a message to the user. In the future, we may want to write
        // this to a tools console.
        notifier.showMessage(
            'Error Compiling File',
            'Error compiling ${file.path}: ${result.problems.first}');

        HttpResponse response = new HttpResponse.ok();
        response.setContentTypeFrom('foo.js');

        String errorText = _createTextForError(file, result);
        String js = _convertToJavaScript(errorText);
        response.setContent(js);

        return response;
      } else {
        _logger.info('compiled ${file.path} in '
            '${_nf.format(stopwatch.elapsedMilliseconds)} ms, '
            '${result.output.length ~/ 1024} kb');
        HttpResponse response = new HttpResponse.ok();
        response.setContent(result.output);
        response.setContentTypeFrom(_getPath(request));
        return response;
      }
    }).whenComplete(() => completer.complete());
  }
}

/**
 * Return the [HttpRequest]'s uri with any query parameters stripped off.
 */
String _getPath(HttpRequest request) {
  String path = request.uri.pathSegments.join('/');
  int index = path.indexOf('?');
  return index == -1 ? path : path.substring(0, index);
}

/**
 * Get user disaplyable text for the given error.
 */
String _createTextForError(File file, CompileResult result) {
  StringBuffer buf = new StringBuffer();

  buf.write('Error compiling ${file.path}:<br><br>');

  for (CompileError problem in result.problems) {
    String path = problem.file == null ? '' : problem.file.path;
    buf.write(
        '[${problem.kind}] ${problem.message} (${path}:${problem.line})<br>');
  }

  return buf.toString();
}

/**
 * Given some text, return back JavaScript source which will display that
 * message in-line in a web page when executed.
 */
String _convertToJavaScript(String text) {
  String style = 'z-index: 100; border: 1px solid black; position: absolute; '
      'top: 10px; left: 10px; right: 10px; padding: 5px; background: #F89797; '
      'border-radius: 4px;';
  text = text.replaceAll("'", r"\'").replaceAll('\n', r'\n');

  return """
    var div = document.createElement('code');
    div.setAttribute('style', \'${style}\');
    div.innerHTML = '${text}';
    document.body.appendChild(div);
""";
}

/**
 * A coarse check to see if the compiled Javascript for the given Dart file is
 * up to date wrt its source. This currently just checks the timestamp of all
 * the Dart source in the project. We could narrow this down in the future if
 * we wanted to use the analysis engine. This would have performance / cost
 * issues however.
 */
bool _dartFileUpToDate(File file, {bool csp: false}) {
  String fileName = '${file.name}${csp ? ".precompiled" : ""}.js';
  File jsFile = file.parent.getChild(fileName);

  // TODO(devoncarew): Do we need to skip secondary package files?
  return isUpToDate(jsFile, file.project,
      (File file) => file.name.endsWith('.dart'));
}

/**
 * An implementation of [CompilerService] which delegates through to another
 * [CompilerService] while caching successful compiles.
 */
class _CachingCompiler implements CompilerService {
  final CompilerService _compiler;

  CompileResult _cachedResult;
  File _cachedFile;
  int _cachedTimestamp;

  _CachingCompiler(this._compiler);

  Future<CompileResult> compileFile(File file, {bool csp: false}) {
    if (_cachedResult != null && _cachedFile == file) {
      if (_isUpToDate(file, _cachedTimestamp)) {
        return new Future.value(_cachedResult);
      }
    }

    _cachedResult = null;
    _cachedFile = null;

    // Reset the cached timestamp.
    _cachedTimestamp = new DateTime.now().millisecondsSinceEpoch;

    return _compiler.compileFile(file, csp: csp).then((result) {
      if (result.getSuccess()) {
        _cachedResult = result;
        _cachedFile = file;
      }

      return result;
    });
  }

  bool _isUpToDate(File file, int cachedTimestamp) {
    // TODO(devoncarew): Do we need to skip secondary package files?
    return isUpToDateTimestamp(cachedTimestamp, file.project,
        (File file) => file.name.endsWith('.dart'));
  }

  Future<CompileResult> compileString(String string) =>
      _compiler.compileString(string);

  String get serviceId => _compiler.serviceId;

  void set services(Services _services) { }

  Services get services => _compiler.services;
}

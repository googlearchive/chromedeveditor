// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// TODO(ussuri): Add tests.

/**
 * Bower services.
 */
library spark.package_mgmt.bower;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:core' hide Resource;

import 'package:logging/logging.dart';

import 'bower_fetcher.dart';
import 'bower_properties.dart';
import 'package_manager.dart';
import '../jobs.dart';
import '../workspace.dart';

Logger _logger = new Logger('spark.bower');

class BowerManager extends PackageManager {
  /**
   * Create a new [BowerManager] instance. This is a heavy-weight object; it
   * creates a new [Builder].
   */
  BowerManager(Workspace workspace) : super(workspace);

  //
  // PackageManager abstract interface:
  //

  PackageServiceProperties get properties => bowerProperties;

  PackageBuilder getBuilderFor(Workspace workspace) =>
      new _BowerBuilder(workspace);

  PackageResolver getResolverFor(Project project) =>
      new _BowerResolver._(project);

  Future installPackages(Folder container, ProgressMonitor monitor) =>
      _installOrUpgradePackages(container, FetchMode.INSTALL, monitor);

  Future upgradePackages(Folder container, ProgressMonitor monitor) =>
      _installOrUpgradePackages(container, FetchMode.UPGRADE, monitor);

  // TODO(keertip): implement for bower
  Future<dynamic> arePackagesInstalled(Folder container) =>
      new Future.value(true);

  //
  // - end PackageManager abstract interface.
  //

  Future _installOrUpgradePackages(
      Folder container, FetchMode mode, ProgressMonitor monitor) {
    File specFile = container.getChild(properties.packageSpecFileName);

    // The client is expected to call us only when [container] has bower.json.
    if (specFile == null) {
      throw new StateError(
          '${properties.packageSpecFileName} not found under ${container.name}'
          'or one of its parents');
    }

    // TODO(ussuri): Code that knows names of the spec file / packages dir and
    // creates/reads them is spread between here and BowerFetcher. Concentrate.
    return container.getOrCreateFolder(
        properties.getPackagesDirName(container), true)
    .then((Folder packagesDir) {
      final fetcher = new BowerFetcher(
          packagesDir.entry, properties.packageSpecFileName, monitor);

      return fetcher.fetchDependencies(specFile.entry, mode).catchError((e) {
        _logger.severe('Error getting Bower packages', e);
        return new Future.error(e);
      }).then((_) {
        // Delay refreshing of the folder until after Bower is completely done.
        // This is needed to fix BUG #2946.
        return Timer.run(() => container.refresh());
      });
    });
  }
}

/**
 * A package resolver for Bower.
 */
class _BowerResolver extends PackageResolver {
  // TODO(ussuri): Right now this class handles only the top-level references.
  // Expand to account for possible lower-level .bowerrc's.

  final Project project;
  RegExp _packageRefPrefixRe;

  _BowerResolver._(this.project) {
    _packageRefPrefixRe =
        new RegExp('^(../|.*/${bowerProperties.getPackagesDirName(project)}/)');
  }

  //
  // PackageResolver virtual interface:
  //

  PackageServiceProperties get properties => bowerProperties;

  File resolveRefToFile(String url) {
    Folder folder = project.getChild(bowerProperties.getPackagesDirName(project));
    if (folder == null) return null;

    if (url.isEmpty) return null;
    url = url.replaceFirst(_packageRefPrefixRe, '');

    if (url.startsWith('/')) url = url.substring(1);

    return folder.getChildPath(url);
  }

  // Not used by anybody, but could return something like
  // `/bower_components/foo/bar.js`.
  String getReferenceFor(File file) => null;

  String toString() => 'Bower resolver for ${project}';
}

/**
 * A [Builder] implementation which watches for changes to `bower.json` files
 * and updates the project Bower metadata.
 */
class _BowerBuilder extends PackageBuilder {
  _BowerBuilder(Workspace workspace) {
    // Initialize local Bower configurations from .bowerrc files in project
    // subirectories on app start.
    _initConfigs(
        new ResourceChangeEvent.fromList(ChangeDelta.containerAdd(workspace)));
  }

  //
  // PackageBuilder virtual interface:
  //

  PackageServiceProperties get properties => bowerProperties;

  Future build(ResourceChangeEvent event, ProgressMonitor monitor) {
    return _initConfigs(event).then((_) => _build(event, monitor));
  }

  //
  // - end PackageBuilder virtual interface.
  //

  Future _initConfigs(ResourceChangeEvent event) {
    List futures = [];

    // Look for .bowerrc's in the unfiltered changes, as the very definition
    // of what is a packages directory or what is a derived resource can be
    // potentially shifting right under us now.
    for (ChangeDelta delta in event.changes) {
      Resource r = delta.resource;
      if (r.name == properties.configFileName ||
          (delta.originalResource != null &&
           delta.originalResource.name == properties.configFileName)) {
        futures.add(_handleConfigFileChange(delta));
      }
    }

    return Future.wait(futures);
  }

  Future _build(ResourceChangeEvent event, ProgressMonitor monitor) {
    List futures = [];
    for (ChangeDelta delta in filterPackageChanges(event.changes)) {
      Resource r = delta.resource;

      if (r.isDerived()) continue;

      if (r.name == properties.packageSpecFileName) {
        futures.add(_handlePackageSpecChange(delta));
      }
    }

    return Future.wait(futures);
  }

  Future _handleConfigFileChange(ChangeDelta delta) {
    return bowerProperties.handleConfigFileChange(delta);
  }

  Future _handlePackageSpecChange(ChangeDelta delta) {
    File file = delta.resource;

    if (delta.isDelete) {
      properties.setSelfReference(file.project, null);
      return new Future.value();
    } else {
      return file.getContents().then((String spec) {
        file.clearMarkers(properties.packageServiceName);

        try {
          properties.setSelfReference(
              file.project, _parsePackageNameFromSpec(spec));
        } on Exception catch (e) {
          file.createMarker(
              properties.packageServiceName, Marker.SEVERITY_ERROR, '${e}', 1);
        }
      });
    }
  }

  String _parsePackageNameFromSpec(String spec) {
    // TODO(ussuri): Similar code is now in 3 places in package_mgmt.
    // Generalize package spec parsing as a PackageServiceProperties API.
    Map<String, dynamic> specMap = JSON.decode(spec);
    return specMap == null ? null : specMap['name'];
  }
}

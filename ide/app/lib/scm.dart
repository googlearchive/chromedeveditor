// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to provide a common interface for and abstraction around source
 * control management (SCM) systems.
 */
library spark.scm;

import 'dart:async';

import 'package:chrome/chrome_app.dart' as chrome;

import 'builder.dart';
import 'jobs.dart';
import 'workspace.dart';
import 'git/objectstore.dart';
import 'git/options.dart';
import 'git/commands/branch.dart';
import 'git/commands/checkout.dart';
import 'git/commands/clone.dart';
import 'git/commands/commit.dart';

final List<ScmProvider> _providers = [new GitScmProvider()];

/**
 * Returns `true` if the given project is under SCM.
 */
bool isUnderScm(Project project) {
  return project != null
      && _providers.any((provider) => provider.isUnderScm(project));
}

/**
 * Return all the SCM providers known to the system.
 */
List<ScmProvider> getProviders() => _providers;

/**
 * Return the [ScmProvider] cooresponding to the given type. The only valid
 * value for [type] currently is `git`.
 */
ScmProvider getProviderType(String type) =>
    _providers.firstWhere((p) => p.id == type, orElse: () => null);

/**
 * This class manages SCM information for a given [Workspace]. It is used to
 * create and retrieve [ScmProjectOperations] for [Project]s. It also listens
 * to the workspace for resource change events and fires cooresponding SCM
 * change events.
 */
class ScmManager {
  final Workspace workspace;

  Map<Project, ScmProjectOperations> _operations = {};
  StreamController<ScmProjectOperations> _controller = new StreamController.broadcast();

  ScmManager(this.workspace) {
    // Add a workspace builder to listen for resource change events.
    workspace.builderManager.builders.add(new _ScmBuilder(this));
  }

  /**
   * Returns the [ScmProjectOperations] for the given project, or `null` if the
   * project is not under SCM.
   */
  ScmProjectOperations getScmOperationsFor(Project project) {
    if (project == null) return null;

    if (_operations[project] == null) {
      for (ScmProvider provider in getProviders()) {
        if (provider.isUnderScm(project)) {
          _operations[project] = provider.createOperationsFor(project);

          if (_operations[project] != null) {
            // TODO: Save the stream subscription, cancel it if the project is
            // deleted.
            _operations[project].onStatusChange.listen((e) => _controller.add(e));
          }

          break;
        }
      }
    }

    return _operations[project];
  }

  Stream<ScmProjectOperations> get onStatusChange => _controller.stream;

  void _fireStatusChangeFor(Project project) {
    if (_operations[project] != null) {
      _operations[project]._fireStatusChangeEvent();
    }
  }
}

/**
 * A abstract implementation of a SCM provider. This provides a
 * lowest-common-denominator interface. In some cases, it may be necessary to
 * cast to a particular [ScmProvider] implementation in order to get the full
 * range of functionality.
 */
abstract class ScmProvider {
  /**
   * The `id` of this provider, e.g. `git`.
   */
  String get id;

  /**
   * Returns whether the SCM provider is managing the given project. The
   * contract for this method is that it should return quickly.
   */
  bool isUnderScm(Project project);

  /**
   * Create an [ScmProjectOperations] instance for the given [Project].
   */
  ScmProjectOperations createOperationsFor(Project project);

  /**
   * Clone the repo at the given url into the given directory.
   */
  Future clone(String url, chrome.DirectoryEntry dir);
}

/**
 * A class that exports various SCM operations to act on the given [Project].
 */
abstract class ScmProjectOperations {
  final ScmProvider provider;
  final Project project;

  ScmProjectOperations(this.provider, this.project);

  chrome.DirectoryEntry get entry => project.entry;

  /**
   * Return the SCM status for the given file or folder.
   */
  FileStatus getFileStatus(Resource resource);

  Stream<ScmProjectOperations> get onStatusChange;

  Future<String> getBranchName();

  Future<List<String>> getAllBranchNames();

  Future createBranch(String branchName);

  Future checkoutBranch(String branchName);

  Future commit(String commitMessage);

  void _fireStatusChangeEvent();
}

/**
 * The possible SCM file statuses (`committed`, `dirty`, or `unknown`).
 */
class FileStatus {
  static final FileStatus COMITTED = new FileStatus._('comitted');
  static final FileStatus DIRTY = new FileStatus._('dirty');
  static final FileStatus UNKNOWN = new FileStatus._('unknown');

  final String _status;

  FileStatus._(this._status);

  String toString() => _status;
}

/**
 * The Git SCM provider.
 */
class GitScmProvider extends ScmProvider {
  GitScmProvider();

  String get id => 'git';

  bool isUnderScm(Project project) {
    return project.getChild('.git') is Folder;
  }

  ScmProjectOperations createOperationsFor(Project project) {
    if (isUnderScm(project)) {
      return new GitScmProjectOperations(this, project);
    }

    return null;
  }

  Future clone(String url, chrome.DirectoryEntry dir) {
    GitOptions options = new GitOptions(
        root: dir, repoUrl: url, depth: 1, store: new ObjectStore(dir));

    return options.store.init().then((_) {
      Clone clone = new Clone(options);
      return clone.clone();
    });
  }
}

/**
 * The Git SCM project operations implementation.
 */
class GitScmProjectOperations extends ScmProjectOperations {
  Completer<ObjectStore> _completer;
  ObjectStore _objectStore;
  StreamController<ScmProjectOperations> _statusController =
      new StreamController.broadcast();

  GitScmProjectOperations(ScmProvider provider, Project project) :
    super(provider, project) {

    _completer = new Completer();

    _objectStore = new ObjectStore(project.entry);
    _objectStore.init()
      .then((_) => _completer.complete(_objectStore))
      .catchError((e) => _completer.completeError(e));
  }

  FileStatus getFileStatus(Resource resource) {
    // TODO:
    return FileStatus.UNKNOWN;
  }

  Stream<ScmProjectOperations> get onStatusChange => _statusController.stream;

  Future<String> getBranchName() =>
      objectStore.then((store) => store.getCurrentBranch());

  Future<List<String>> getAllBranchNames() =>
      objectStore.then((store) => store.getLocalBranches());

  Future createBranch(String branchName) {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(
          root: entry, branchName: branchName, store: store);
      return Branch.branch(options);
    });
  }

  Future checkoutBranch(String branchName) {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(
          root: entry, branchName: branchName, store: store);
      return Checkout.checkout(options).then((_) {
        _statusController.add(this);

        // We changed files on disk - let the workspace know to re-scan the
        // project and fire any necessary resource change events.
        Timer.run(() => project.refresh());
      });
    });
  }

  Future commit(String commitMessage) {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(
          root: entry, store: store, commitMessage: commitMessage);
      return Commit.commit(options).then((_) {
        _statusController.add(this);
      });
    });
  }

  Future<ObjectStore> get objectStore => _completer.future;

  void _fireStatusChangeEvent() => _statusController.add(this);
}

/**
 * A builder that translates resource change events into SCM status change
 * events.
 */
class _ScmBuilder extends Builder {
  final ScmManager scmManager;

  _ScmBuilder(this.scmManager);

  Future build(ResourceChangeEvent changes, ProgressMonitor monitor) {
    // Get a list of all changed projects and fire SCM change events for them.
    for (Project project in changes.modifiedProjects) {
      scmManager._fireStatusChangeFor(project);
    }

    return new Future.value();
  }
}

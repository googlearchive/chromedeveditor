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
bool isUnderScm(Project project) =>
    _providers.any((provider) => provider.isUnderScm(project));

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
 * Returns the [ScmProjectOperations] for the given project, or `null` if the
 * project is not under SCM.
 */
ScmProjectOperations getScmOperationsFor(Project project) {
  for (ScmProvider provider in _providers) {
    if (provider.isUnderScm(project)) {
      return provider.getOperationsFor(project);
    }
  }

  return null;
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
   * Return the [ScmProjectOperations] cooresponding to the given [Project].
   */
  ScmProjectOperations getOperationsFor(Project project);

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
  Future<FileStatus> getFileStatus(Resource resource);

  Future<String> getBranchName();

  Future<List<String>> getAllBranchNames();

  Future createBranch(String branchName);

  Future checkoutBranch(String branchName);

  Future commit(String commitMessage);
}

/**
 * The possible SCM file statuses (`committed`, `dirty`, or `unknown`).
 */
class FileStatus {
  final FileStatus COMITTED = new FileStatus._('comitted');
  final FileStatus DIRTY = new FileStatus._('dirty');
  final FileStatus UNKNOWN = new FileStatus._('unknown');

  final String _status;

  FileStatus._(this._status);

  String toString() => _status;
}

/**
 * The Git SCM provider.
 */
class GitScmProvider extends ScmProvider {
  Map<Project, ScmProjectOperations> _operations = {};

  GitScmProvider();

  String get id => 'git';

  bool isUnderScm(Project project) {
    return project.getChild('.git') is Folder;
  }

  ScmProjectOperations getOperationsFor(Project project) {
    if (_operations[project] == null) {
      if (isUnderScm(project)) {
        _operations[project] = new GitScmProjectOperations(this, project);
      }
    }

    return _operations[project];
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

  GitScmProjectOperations(ScmProvider provider, Project project) :
    super(provider, project) {

    _completer = new Completer();

    _objectStore = new ObjectStore(project.entry);
    _objectStore.init()
      .then((_) => _completer.complete(_objectStore))
      .catchError((e) => _completer.completeError(e));
  }

  Future<FileStatus> getFileStatus(Resource resource) {
    return new Future.error('unimplemented - getFileStatus()');
  }

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
      return Checkout.checkout(options);
    });
  }

  Future commit(String commitMessage) {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(
          root: entry, store: store, commitMessage: commitMessage);
      return Commit.commit(options);
    });
  }

  Future<ObjectStore> get objectStore => _completer.future;
}

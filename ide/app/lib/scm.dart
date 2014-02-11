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
import 'package:intl/intl.dart';

import 'builder.dart';
import 'jobs.dart';
import 'workspace.dart';
import 'git/objectstore.dart';
import 'git/options.dart';
import 'git/commands/branch.dart';
import 'git/commands/checkout.dart';
import 'git/commands/clone.dart';
import 'git/commands/commit.dart';
import 'git/commands/constants.dart';
import 'git/commands/fetch.dart';
import 'git/commands/index.dart' as index;
import 'git/commands/pull.dart';
import 'git/commands/push.dart';
import 'git/commands/status.dart';

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

  void _updateStatusFor(Project project, List<ChangeDelta> changes) {
    if (_operations[project] != null) {
      _operations[project].updateForChanges(changes);
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

  String getBranchName();

  /**
   * Return the SCM status for the given file or folder.
   */
  FileStatus getFileStatus(Resource resource);

  Stream<ScmProjectOperations> get onStatusChange;

  Future<List<String>> getAllBranchNames();

  Future createBranch(String branchName);

  Future checkoutBranch(String branchName);

  Future commit(String userName, String userEmail, String commitMessage);

  Future push(String username, String password);

  void updateForChanges(List<ChangeDelta> changes);
}

/**
 * The possible SCM file statuses (`untracked`, `modified`, `staged`, or
 * `committed`).
 */
class FileStatus {
  static const FileStatus UNTRACKED = const FileStatus._('untracked');
  static const FileStatus MODIFIED = const FileStatus._('modified');
  static const FileStatus STAGED = const FileStatus._('staged');
  static const FileStatus COMMITTED = const FileStatus._('committed');

  final String status;

  const FileStatus._(this.status);

  factory FileStatus.createFrom(String value) {
    if (value == 'committed') return FileStatus.COMMITTED;
    if (value == 'modified') return FileStatus.MODIFIED;
    if (value == 'staged') return FileStatus.STAGED;
    return FileStatus.UNTRACKED;
  }

  factory FileStatus.fromIndexStatus(String status) {
    if (status == FileStatusType.COMMITTED) return FileStatus.COMMITTED;
    if (status == FileStatusType.MODIFIED) return FileStatus.MODIFIED;
    if (status == FileStatusType.STAGED) return FileStatus.STAGED;
    return FileStatus.UNTRACKED;
  }

  String toString() => status;
}

/**
 * The SCM commit information.
 */
class CommitInfo {
  String identifier;
  String authorName;
  String authorEmail;
  DateTime date;
  String message;

  String _getDateString() => date == null ? '' : new DateFormat.yMd("en_US").format(date);
  String _getTimeString() => date == null ? '' : new DateFormat("Hm", "en_US").format(date);
  String get dateString => '${_getDateString()} ${_getTimeString()}';
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

  String _branchName;

  GitScmProjectOperations(ScmProvider provider, Project project) :
    super(provider, project) {

    _completer = new Completer();

    _objectStore = new ObjectStore(project.entry);
    _objectStore.init()
      .then((_) {
        _completer.complete(_objectStore);

        // Populate the branch name.
        getBranchName();

        // TODO(devoncarew): this is only necessary currently because the
        // resource metadata is not persisted across sessions. Once it is, we
        // can remove this manual refresh.
        // Update the SCM status for the files.
        _refreshStatus(project: project);
      }).catchError((e) => _completer.completeError(e));
  }

  String getBranchName() {
    // We return the current idea of the branch name immediately. We also ask
    // git for the actual branch name asynchronously. If the two differ, we fire
    // a changed event so listeners who were returned the old name can update
    // themselves.
    objectStore.then((store) {
      return store.getCurrentBranch();
    }).then((String name) {
      if (name != _branchName) {
        _branchName = name;
        _statusController.add(this);
      }
    });

    return _branchName;
  }

  FileStatus getFileStatus(Resource resource) {
    return new FileStatus.createFrom(
        resource.getMetadata('scmStatus', 'committed'));
  }

  Stream<ScmProjectOperations> get onStatusChange => _statusController.stream;

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

  Future push(String username, String password) {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(root: entry, store: store,
          username: username, password: password);
      return Push.push(options);
    });
  }

  Future fetch() {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(root: entry, store: store);
      Fetch fetch = new Fetch(new GitOptions(root: entry, store: store));
      return fetch.fetch();
    });
  }

  Future pull() {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(root: entry, store: store);
      Pull pull = new Pull(options);
      return pull.pull();
    });
  }

  Future commit(String userName, String userEmail, String commitMessage) {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(
          root: entry, store: store, commitMessage: commitMessage,
          name: userName, email: userEmail);
      return Commit.commit(options).then((_) {
        _refreshStatus(project: project);
      });
    });
  }

  Future<List<CommitInfo>> getPendingCommits() {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(root: entry, store: store);
      return Push.getPendingCommits(options).then((commits) {
        return commits.map((item) {
          CommitInfo result = new CommitInfo();
          result.identifier = item.sha;
          result.authorName = item.author.name;
          result.authorEmail = item.author.email;
          result.date = item.author.date;
          result.message = item.message;
          return result;
        });
      });
    });
  }

  Future<ObjectStore> get objectStore => _completer.future;

  void updateForChanges(List<ChangeDelta> changes) {
    _refreshStatus(files: changes
        .where((d) => d.type != EventType.DELETE && d.resource is File)
        .map((d) => d.resource));
  }

  /**
   * Refresh either the entire given project, or the given list of files.
   */
  void _refreshStatus({Project project, Iterable<File> files}) {
    assert(project != null || files != null);

    // Get a list of all files in the project.
    if (project != null) {
      files = project.traverse().where((r) => r is File);
    }

    // For each file, request the SCM status asynchronously.
    objectStore.then((ObjectStore store) {
      Future.forEach(files, (File file) {
        return Status.getFileStatus(store, file.entry).then((index.FileStatus status) {
          file.setMetadata('scmStatus',
              new FileStatus.fromIndexStatus(status.type).status);
        });
      }).then((_) => _statusController.add(this));
    });
  }
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
      scmManager._updateStatusFor(project, changes.getChangesFor(project));
    }

    return new Future.value();
  }
}

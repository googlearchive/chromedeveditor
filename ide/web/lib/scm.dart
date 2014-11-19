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
import 'package:logging/logging.dart';
import 'package:observe/observe.dart';

import 'builder.dart';
import 'decorators.dart';
import 'exception.dart';
import 'jobs.dart';
import 'spark_flags.dart';
import 'workspace.dart';
import 'git/config.dart';
import 'git/objectstore.dart';
import 'git/object.dart';
import 'git/options.dart';
import 'git/utils.dart';
import 'git/commands/add.dart';
import 'git/commands/branch.dart';
import 'git/commands/checkout.dart';
import 'git/commands/clone.dart';
import 'git/commands/commit.dart';
import 'git/commands/constants.dart';
import 'git/commands/diff.dart';
import 'git/commands/fetch.dart';
import 'git/commands/ignore.dart';
import 'git/commands/index.dart';
import 'git/commands/merge.dart';
import 'git/commands/pull.dart';
import 'git/commands/push.dart';
import 'git/commands/revert.dart';
import 'git/commands/status.dart';
import 'git_salt/git_salt.dart';

final List<ScmProvider> _providers = [new GitScmProvider(), new GitSaltScmProvider()];

final Logger _logger = new Logger('spark.scm');

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
ScmProvider getProviderType(String type) {
  if (SparkFlags.gitSalt) {
    return _providers.firstWhere((p) => p.id == "git-salt", orElse: () => null);
  }
  return _providers.firstWhere((p) => p.id == type, orElse: () => null);
}

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

  Future _updateStatusFor(Project project, List<ChangeDelta> changes) {
    if (_operations[project] != null) {
      return _operations[project].updateForChanges(changes);
    } else {
      return new Future.value();
    }
  }

  void removeProject(Project project) {
    _operations.remove(project);
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
   * Returns whether [uri] represents an endpoint of this SCM provider.
   */
  bool isScmEndpoint(String uri);

  /**
   * Create an [ScmProjectOperations] instance for the given [Project].
   */
  ScmProjectOperations createOperationsFor(Project project);

  /**
   * Create an [ScmProjectOperations] instance for the given [DirectoryEntry].
   */
  ScmProjectOperations createOperationsForDir(chrome.DirectoryEntry dir);

  /**
   * Clone the repo at the given url into the given directory. Returns a
   * [ScmException] through the Future's error on a failure.
   */
  Future clone(String url, chrome.DirectoryEntry dir,
               {String username, String password, String branchName});

  /**
   * Initialize a given directory into a git repository.
   */
  Future init(chrome.DirectoryEntry dir);

  /**
   * Cancels the active clone in progress.
   */
  void cancelClone();
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
  ScmFileStatus getFileStatus(Resource resource);

  Stream<ScmProjectOperations> get onStatusChange;

  Future<List<String>> getLocalBranchNames();

  Future<List<String>> getRemoteBranchNames();

  Future<List<String>> getUpdatedRemoteBranchNames();

  Future<List<String>> lsRemoteRefs(String url);

  Future createBranch(String branchName, String sourceBranchName);

  Future checkoutBranch(String branchName);

  Future mergeBranch(String branchName, String sourceBranchName);

  Future diff();

  void markResolved(Resource resource);

  Future revertChanges(List<Resource> resources);

  Future commit(String userName, String userEmail, String commitMessage);

  Future push(String username, String password);

  Future updateForChanges(List<ChangeDelta> changes);
}

/**
 * The possible SCM file statuses (`untracked`, `modified`, `staged`, or
 * `committed`).
 */
class ScmFileStatus {
  static const ScmFileStatus UNTRACKED = const ScmFileStatus._('untracked');
  static const ScmFileStatus MODIFIED = const ScmFileStatus._('modified');
  static const ScmFileStatus STAGED = const ScmFileStatus._('staged');
  static const ScmFileStatus UNMERGED = const ScmFileStatus._('unmerged');
  static const ScmFileStatus COMMITTED = const ScmFileStatus._('committed');
  static const ScmFileStatus DELETED = const ScmFileStatus._('deleted');
  static const ScmFileStatus ADDED = const ScmFileStatus._('added');

  final String status;

  const ScmFileStatus._(this.status);

  factory ScmFileStatus.createFrom(String value) {
    if (value == 'committed') return ScmFileStatus.COMMITTED;
    if (value == 'modified') return ScmFileStatus.MODIFIED;
    if (value == 'staged') return ScmFileStatus.STAGED;
    if (value == 'unmerged') return ScmFileStatus.UNMERGED;
    if (value == 'deleted') return ScmFileStatus.DELETED;
    if (value == 'added') return ScmFileStatus.ADDED;
    return ScmFileStatus.UNTRACKED;
  }

  factory ScmFileStatus.fromIndexStatus(String status) {
    if (status == FileStatusType.DELETED) return ScmFileStatus.DELETED;
    if (status == FileStatusType.ADDED) return ScmFileStatus.ADDED;
    if (status == FileStatusType.COMMITTED) return ScmFileStatus.COMMITTED;
    if (status == FileStatusType.MODIFIED) return ScmFileStatus.MODIFIED;
    if (status == FileStatusType.STAGED) return ScmFileStatus.STAGED;
    if (status == FileStatusType.UNMERGED) return ScmFileStatus.UNMERGED;
    return ScmFileStatus.UNTRACKED;
  }

  String toString() => status;
}

/**
 * The SCM commit information.
 */
@reflectable
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
 * The GitSalt scm provider.
 */
class GitSaltScmProvider extends ScmProvider {
  GitSaltScmProvider();

  String get id => 'git-salt';

  bool isUnderScm(Project project) {
    if (SparkFlags.gitSalt == false) {
      return false;
    }
    Folder gitFolder = project.getChild('.git');
    if (gitFolder is! Folder) return false;
    if (gitFolder.getChild('index') is! File) return false;
    return true;
  }

  bool isScmEndpoint(String uri) => isGitUri(uri);

  ScmProjectOperations createOperationsFor(Project project) {
    if (isUnderScm(project)) {
      return new GitSaltScmProjectOperations(this, project);
    }

    return null;
  }

  ScmProjectOperations createOperationsForDir(chrome.DirectoryEntry dir) {
    return new GitSaltScmProjectOperations(this, null, dir);
  }

  Future clone(String url, chrome.DirectoryEntry dir,
      {String username, String password, String branchName}) {
    GitSalt gitSalt = GitSaltFactory.getInstance(dir.fullPath);
    return gitSalt.loadPlugin().then((_) {
      return gitSalt.clone(dir, url);
    });
  }

  Future init(chrome.DirectoryEntry dir) {
    GitSalt gitSalt = GitSaltFactory.getInstance(dir.fullPath);
    return gitSalt.loadPlugin().then((_) {
      return gitSalt.init(dir);
    });
  }

  void cancelClone() {
    throw "Not implemented";
  }
}

/**
 * The Git SCM provider.
 */
class GitScmProvider extends ScmProvider {
  GitScmProvider();

  String get id => 'git';

  Clone _activeClone;

  bool isUnderScm(Project project) {
    Folder gitFolder = project.getChild('.git');
    if (gitFolder is! Folder) return false;
    if (gitFolder.getChild('index2') is! File) return false;
    if (gitFolder.getChild('index') is File) return false;
    return true;
  }

  bool isScmEndpoint(String uri) => isGitUri(uri);

  ScmProjectOperations createOperationsFor(Project project) {
    if (isUnderScm(project)) {
      return new GitScmProjectOperations(this, project);
    }

    return null;
  }

  ScmProjectOperations createOperationsForDir(chrome.DirectoryEntry dir) {
    throw new UnsupportedError('GitScmProvider.createOperationsForDir not supported');
  }

  Future clone(String url, chrome.DirectoryEntry dir,
               {String username, String password, String branchName}) {
    GitOptions options = new GitOptions(
        root: dir, repoUrl: url, depth: 1, store: new ObjectStore(dir),
        branchName: branchName, username: username, password: password);

    return options.store.init().then((_) {
      _activeClone = new Clone(options);
      return _activeClone.clone().then((_) {
        return options.store.index.flush().then((_) {
          _activeClone = null;
        });
      });
    }).catchError((e) {
      _activeClone = null;
      throw SparkException.fromException(e);
    });
  }

  Future init(chrome.DirectoryEntry dir) {
    //TODO(grv): to be implemented.
    return new Future.value();
  }

  void cancelClone() {
    if (_activeClone != null) {
      _activeClone.cancel();
    }
  }
}


class GitSaltScmProjectOperations extends ScmProjectOperations {
  Completer _completer;
  GitSalt _gitSalt;
  StreamController<ScmProjectOperations> _statusController =
      new StreamController.broadcast();
  String _branchName;

  Future<GitSalt> get gitSalt => _completer.future;

  GitSaltScmProjectOperations(ScmProvider provider, Project project,
      [chrome.DirectoryEntry dir]) :
    super(provider, project) {
      _completer = new Completer();

      chrome.Entry entry = (dir == null) ? project.entry : dir;
      _gitSalt = GitSaltFactory.getInstance(entry.fullPath);
      _gitSalt.loadPlugin().then((_) {
        _gitSalt.load(entry).then((_) {
          _completer.complete(_gitSalt);
        });
      });

  }

  String getBranchName() {
    // We return the current idea of the branch name immediately. We also ask
    // git for the actual branch name asynchronously. If the two differ, we fire
    // a changed event so listeners who were returned the old name can update
    // themselves.
    gitSalt.then((git_salt) {
      return git_salt.getCurrentBranch();
    }).then((String name) {
      if (name != _branchName) {
        _branchName = name;
        _statusController.add(this);
      }
    });

    return _branchName;
  }

  ScmFileStatus getFileStatus(Resource resource) {
    return new ScmFileStatus.createFrom(
        resource.getMetadata('scmStatus', 'committed'));
  }

  Future<List<String>> getLocalBranchNames() {
    return gitSalt.then((git_salt) {
      return git_salt.getLocalBranches();
    });
  }

  Future<List<String>> getRemoteBranchNames() {
    return gitSalt.then((git_salt) {
      return git_salt.getRemoteBranches();
    });
  }

  Future<List<String>> getUpdatedRemoteBranchNames() {
    // TODO(grv): Implement.
    return new Future.value();
  }

    Future<List<String>> lsRemoteRefs(String url) {
    return gitSalt.then((git_salt) {
      return git_salt.lsRemoteRefs(url);
    });
  }

  Future createBranch(String branchName, String sourceBranchName) {
    // TODO(grv): Implement.
    return new Future.value();
  }

  Future checkoutBranch(String branchName) {
    // TODO(grv): Implement.
    return new Future.value();
  }

  Future mergeBranch(String branchName, String sourceBranchName) {
    // TODO(grv): Implement.
    return new Future.value();
  }

  Future diff() {
    // TODO(grv): Implement.
    return new Future.value();
  }

  void markResolved(Resource resource) {
    // TODO(grv): Implement.
  }

  Future revertChanges(List<Resource> resources) {
    // TODO(grv): Implement.
    return new Future.value();
  }


  Future commit(String userName, String userEmail, String commitMessage) {
    return gitSalt.then((git_salt) {
      Map<String, String> options = {
        "commitMessage": commitMessage,
        "userName": userName,
        "userEmail": userEmail
      };
      return git_salt.commit(options).then((_) {
        return _refreshStatus(project: project);
      }).catchError((e) => throw SparkException.fromException(e));
    });
  }

  Future push(String username, String password) {
    // TODO(grv): Implement.
    return new Future.value();
  }

  Future<List<String>> getDeletedFiles() {
    return gitSalt.then((git_salt) {
      return git_salt.status().then((Map<String, String> statuses) {
        List<String> deletedFiles = [];
        statuses.forEach((k,v ) {
          if (v == 512) {
            deletedFiles.add(k);
          }
        });
        return deletedFiles;
      });
    });
  }

  Future addFiles(List<chrome.Entry> files) {
    return gitSalt.then((git_salt) {
      return git_salt.add(files).then((_) {
        return _refreshStatus(project: project);
      });
    });
  }

  Stream<ScmProjectOperations> get onStatusChange => _statusController.stream;

  Future updateForChanges(List<ChangeDelta> changes) {
    return _refreshStatus(resources: changes
        .where((d) => d.type != EventType.DELETE)
        .map((d) => d.resource)
        .where((Resource f) => f.parent != null && !f.parent.isScmPrivate()));
  }

  Future _refreshStatus({Project project, Iterable<Resource> resources}) {
    assert(project != null || resources != null);

    // Get a list of all files in the project.
    if (project != null) {
      resources = project.traverse();
    }

    return gitSalt.then((git_salt) {
      if (project != null) {
        return git_salt.status().then((Map<String, String> statuses) {
          resources.forEach((resource) {
            _setStatus(resource, statuses[resource.entry.fullPath]);
          });
          return new Future.value();
        });
      } else {
          return git_salt.status().then((Map<String, String> statuses) {
            resources.forEach((resource) {
              String rootPath = resource.project.entry.fullPath;
              String path = resource.entry.fullPath.substring(rootPath.length + 1);
              //TODO(grv): Update status for ancestors.
              _setStatus(resource, statuses[path]);
          });
          return new Future.value();
        });
      }
    }).catchError((e, st) {
      _logger.severe("error calculating scm status", e, st);
    }).whenComplete(() => _statusController.add(this));
  }

  void _setStatus(Resource resource, String status) {
    String fileStatus = FileStatusType.COMMITTED;
    //TODO(grv): Add a type class for the  returned status types.
    // Handle case of untracked files.
    if (status == null) {
      fileStatus = FileStatusType.COMMITTED;
    } else if (resource.isFile) {
      if (status == 256) {
          fileStatus = FileStatusType.MODIFIED;
      } else  if (status == 512) {
        fileStatus = FileStatusType.DELETED;
      } else if (status == 128) {
        fileStatus = FileStatusType.ADDED;
      }
    }
    resource.setMetadata('scmStatus', new ScmFileStatus.fromIndexStatus(
        fileStatus).status);
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
    _objectStore.init().then((_) {
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

  Future<Map<String, dynamic>> getConfigMap() {
    return objectStore.then((store) {
      return store.readConfig().then((Config config) {
        return config.toMap();
      });
    });
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

  ScmFileStatus getFileStatus(Resource resource) {
    return new ScmFileStatus.createFrom(
        resource.getMetadata('scmStatus', 'committed'));
  }

  Stream<ScmProjectOperations> get onStatusChange => _statusController.stream;

  Future<List<String>> getLocalBranchNames() =>
      objectStore.then((store) => store.getLocalBranches());

  Future<List<String>> getRemoteBranchNames()  {
    return objectStore.then((store) {
      return store.getRemoteHeads().then((List<String> result) {
        GitOptions options = new GitOptions(root: entry, store: store);
        // Return immediately but requet async update.
        // TODO(grv): wait for it when, the UI support refreshing remote branches.
        Fetch.updateAndGetRemoteRefs(options);
        return result;
      });
    });
  }

  Future<List<String>> getUpdatedRemoteBranchNames()  {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(root: entry, store: store);
      return Fetch.updateAndGetRemoteRefs(options);
    });
  }

  Future createBranch(String branchName, String sourceBranchName,
                      {String username, String password}) {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(root: entry,
                                          branchName: branchName,
                                          store: store,
                                          username: username,
                                          password: password);

      return Branch.branch(options, sourceBranchName).catchError(
          (e) => throw SparkException.fromException(e));
    });
  }

  Future mergeBranch(String branchName, String sourceBranchName,
                     {String username, String password}) {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(root: entry,
                                          branchName: branchName,
                                          store: store,
                                          username: username,
                                          password: password);

      return Merge.merge(options, sourceBranchName).catchError(
          (e) => throw SparkException.fromException(e));
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
      }).catchError((e) => throw SparkException.fromException(e));
    });
  }

  Future<List<DiffResult>> diff() {
    return objectStore.then((store) {
      return Diff.diff(store);
    });
  }

  void markResolved(Resource resource) {
    // TODO(grv): Implement
    _logger.info('Implement markResolved()');

    // When finished, fire an SCM changed event.
    _statusController.add(this);
  }

  Future revertChanges(List<Resource> resources) {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(root: entry, store: store);
      return Revert.revert(options, resources.map((e) => e.entry).toList());
    });
  }

  Future<List<ScmFileStatus>> addFiles(List<chrome.Entry> files) {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(root: entry, store: store);
      return Add.addEntries(options, files).then((_) {
        return _refreshStatus(project: project);
      });
    });
  }

  Future push(String username, String password) {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(root: entry, store: store,
          username: username, password: password);
      return Push.push(options)
          .catchError((e) => new Future.error(SparkException.fromException(e)));
    });
  }

  Future<List<String>> getDeletedFiles() {
    return objectStore.then((store) {
      return Status.getDeletedFiles(store)
          .catchError((e) => new Future.error(SparkException.fromException(e)));
    });
  }

  Future fetch() {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(root: entry, store: store);
      Fetch fetch = new Fetch(new GitOptions(root: entry, store: store));
      return fetch.fetch()
          .catchError((e) => new Future.error(SparkException.fromException(e)));
    });
  }

  Future pull([String username, String password]) {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(
          root: entry, store: store, username: username, password: password);
      Pull pull = new Pull(options);
      return pull.pull().then((_) {
        _statusController.add(this);
        // We changed files on disk - let the workspace know to re-scan the
        // project and fire any necessary resource change events.
        Timer.run(() => project.refresh());
      }).catchError((e) => new Future.error(SparkException.fromException(e)));
    });
  }

  Future commit(String userName, String userEmail, String commitMessage) {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(
          root: entry, store: store, commitMessage: commitMessage,
          name: userName, email: userEmail);
      return Commit.commit(options).then((_) {
        _refreshStatus(project: project);
      }).catchError((e) => throw SparkException.fromException(e));
    });
  }

  Future<List<CommitInfo>> getPendingCommits(String username, String password) {
    return objectStore.then((store) {
      GitOptions options = new GitOptions(root: entry, store: store,
          username: username, password: password);
      return Push.getPendingCommits(options).then((List commits) {
        return commits.map((CommitObject item) {
          CommitInfo result = new CommitInfo();
          result.identifier = item.sha;
          result.authorName = item.author.name;
          result.authorEmail = item.author.email;
          result.date = item.author.date;
          result.message = item.message;
          return result;
        }).toList();
      }).catchError((e) => throw SparkException.fromException(e));
    });
  }

  Future<List<String>> lsRemoteRefs(String url) {
    //TODO(grv): to be implemented;
    return new Future.value();
  }

  Future<ObjectStore> get objectStore => _completer.future;

  Future updateForChanges(List<ChangeDelta> changes) {
    return _refreshStatus(resources: changes
        .where((d) => d.type != EventType.DELETE)
        .map((d) => d.resource)
        .where((Resource f) => f.parent != null && !f.parent.isScmPrivate()));
  }

  /**
   * Refresh either the entire given project, or the given list of Resources.
   */
  Future _refreshStatus({Project project, Iterable<Resource> resources}) {
    assert(project != null || resources != null);

    // Get a list of all files in the project.
    if (project != null) {
      resources = project.traverse();
    }

    return objectStore.then((ObjectStore store) {
      if (project != null) {
        return Status.getFileStatuses(store).then((statuses) {
          resources.forEach((resource) {
            // TODO(grv): This should be handled by git status.
            if (!GitIgnore.ignore(resource.entry.fullPath)) {
              _setStatus(resource, statuses[resource.entry.fullPath]);
            }
          });
          return new Future.value();
        });
      } else {
        // For each file, request the SCM status asynchronously.
        return Future.forEach(resources, (Resource resource) {
          return Status.updateAndGetStatus(store, resource.entry).then((status) {
            _updateStatusForAncestors(store, resource);
            return new Future.value();
          });
        });
      }
    }).catchError((e, st) {
      _logger.severe("error calculating scm status", e, st);
    }).whenComplete(() => _statusController.add(this));
  }

  void _updateStatusForAncestors(ObjectStore store, Resource resource) {
    _setStatus(resource, Status.getStatusForEntry(store, resource.entry));
    if (resource.entry.fullPath != store.root.fullPath) {
      _updateStatusForAncestors(store, resource.parent);
    }
  }

  void _setStatus(Resource resource, FileStatus status) {
    String fileStatus;
    if (status == null) {
      fileStatus = FileStatusType.UNTRACKED;
    } else if (resource.isFile) {
      if (status.type == FileStatusType.MODIFIED) {
        if (status.deleted) {
          fileStatus = FileStatusType.DELETED;
        } else if (status.headSha == null) {
          fileStatus = FileStatusType.ADDED;
        } else {
          fileStatus = FileStatusType.MODIFIED;
        }
      } else {
        fileStatus = status.type;
      }
    } else {
        fileStatus = status.type;
    }
    resource.setMetadata('scmStatus', new ScmFileStatus.fromIndexStatus(
        fileStatus).status);
  }
}

/**
 * A decorator to add text decorations for the current branch of a project.
 */
class ScmDecorator extends Decorator {
  final ScmManager _manager;
  final StreamController _controller = new StreamController.broadcast();

  ScmDecorator(this._manager) {
    _manager.onStatusChange.listen((_) => _controller.add(null));
  }

  bool canDecorate(Object object) {
    if (object is! Project) return false;
    return _manager.getScmOperationsFor(object) != null;
  }

  String getTextDecoration(Object object) {
    ScmProjectOperations scmOperations = _manager.getScmOperationsFor(object);
    String branchName = scmOperations.getBranchName();
    if (branchName == null) branchName = '';
    return '[${branchName}]';
  }

  Stream get onChanged => _controller.stream;
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
    changes =
        new ResourceChangeEvent.fromList(changes.changes, filterRename: true);
    return Future.forEach(changes.modifiedProjects, (project) {
      return scmManager._updateStatusFor(project, changes.getChangesFor(project));
    });
  }
}

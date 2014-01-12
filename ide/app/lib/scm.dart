// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to provide a common interface for and abstraction around source
 * control management (SCM) systems.
 */
library spark.scm;

import 'dart:collection';

import 'workspace.dart';

List<ScmProvider> _providers;

/**
 * Returns `true` if the given project is under SCM.
 */
bool isUnderScm(Project project) => getProvider(project) != null;

/**
 * Returns the [ScmProvider] for the given project, or `null` if the project is
 * not under SCM.
 */
ScmProvider getProvider(Project project) {
  _initialize();

  for (ScmProvider provider in _providers) {
    if (provider.isUnderScm(project)) {
      return provider;
    }
  }

  return null;
}

/**
 * Return all the SCM providers known to the system.
 */
List<ScmProvider> getProviders() {
  _initialize();

  return new UnmodifiableListView(_providers);
}

/**
 * Register a new [ScmProvider].
 */
void registerProvider(ScmProvider provider) {
  _initialize();
  _providers.add(provider);
}

void _initialize() {
  if (_providers != null) return;

  _providers = [];

  registerProvider(new GitScmProvider._());
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
}

/**
 * The Git SCM provider.
 */
class GitScmProvider extends ScmProvider {
  GitScmProvider._();

  String get id => 'git';

  bool isUnderScm(Project project) {
    return project.getChild('.git') is Folder;
  }
}

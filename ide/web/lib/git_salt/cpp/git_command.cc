// Copyright (c) 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "git_command.h"

int GitCommand::parseFileSystem(pp::VarDictionary message, std::string name,
    pp::FileSystem& system) {
  pp::Var var_filesystem = message.Get(name);

  if (!var_filesystem.is_resource()) {
    //TODO(grv): return error code;
     return 1;
  }

  pp::Resource resource_filesystem = var_filesystem.AsResource();
  fileSystem = pp::FileSystem(resource_filesystem);
  return 0;
}

int GitCommand::parseArgs() {

  if ((error = parseFileSystem(_args, kFileSystem, fileSystem))) {

  }

  if ((error = parseString(_args, kFullPath,  fullPath))) {

  }

  if ((error = parseString(_args, kUrl,  url))) {

  }
  return 0;
}

int GitClone::runCommand() {
  // mount the folder as a filesystem.
  ChromefsInit();

  git_threads_init();

  std::string message = "clone successful";

  if (!url.length()) {
    git_repository_open(&repo, "/chromefs");
    message = "repository load successful";
  } else {
    git_clone(&repo, url.c_str(), "/chromefs", NULL);
  }

  const git_error *a = giterr_last();

  if (a != NULL) {
    printf("giterror: %s\n", a->message);
  }

  pp::VarDictionary arg;
  arg.Set(kMessage, message);

  pp::VarDictionary response;
  response.Set(kRegarding, subject);
  response.Set(kArg, arg);
  response.Set(kName, kResult);

  _gitSalt->PostMessage(response);
  return 0;
}

int GitInit::runCommand() {
  ChromefsInit();

  git_threads_init();

  git_repository_init(&repo, "/chromefs", true);

  pp::VarDictionary arg;
  arg.Set(kMessage, "Git init success.");

  pp::VarDictionary response;
  response.Set(kRegarding, subject);
  response.Set(kArg, arg);
  response.Set(kName, kResult);

  _gitSalt->PostMessage(response);

  return 0;
}

void GitClone::ChromefsInit() {
  int32_t r = (int32_t) fileSystem.pp_resource();
  char fs_resource[100] = "filesystem_resource=";
  sprintf(&fs_resource[20], "%d", r);
  mount(fullPath.c_str(),                     /* source */
      "/chromefs",                            /* target */
      "html5fs",                              /* filesystemtype */
      0,                                      /* mountflags */
      fs_resource);                           /* data */
}

int GitCommit::parseArgs() {
  if ((error = parseString(_args, kUserName, userName))) {

  }

  if ((error = parseString(_args, kUserEmail, userEmail))) {

  }

  if ((error = parseString(_args, kCommitMessage, commitMsg))) {

  }

  return 0;
}

git_commit* GitCommit::getLastCommit() {
  git_commit * commit = NULL;
  git_oid oid_parent_commit;

  /* resolve HEAD into a SHA1 value */
  error = git_reference_name_to_id(&oid_parent_commit, repo, "HEAD");
  if (!error) {
    error = git_commit_lookup(&commit, repo, &oid_parent_commit);
    if (!error) {
      return commit;
    }
  }
  return NULL;
}

bool GitCommit::commitStage() {
  git_index* repo_idx;
  git_oid oid_idx_tree;
  git_oid oid_commit;
  git_tree* tree_cmt;
  // Head commit.
  git_commit* parent_commit;

  parent_commit = getLastCommit();
  git_signature* sign = NULL;
  git_signature_now(&sign, userName.c_str(), userEmail.c_str());
  if (parent_commit != NULL ) {
    error = git_repository_index(&repo_idx, repo);
    if (!error) {
      git_index_read(repo_idx, false);
      error = git_index_write_tree(&oid_idx_tree, repo_idx);
      if (!error) {
        error = git_tree_lookup(&tree_cmt, repo, &oid_idx_tree);
        if (!error) {
          error = git_commit_create(
              &oid_commit,
              repo,
              "HEAD",
              sign,
              sign,
              NULL,
              commitMsg.c_str(),
              tree_cmt,
              1,
              (const git_commit**)&parent_commit);
        }
      }
      git_index_free(repo_idx);
    }
    git_commit_free(parent_commit);
    git_signature_free(sign);
  }
  return !error;
}

int GitCommit::runCommand() {
  int r = commitStage();

  pp::VarDictionary arg;

  pp::VarDictionary response;
  response.Set(kRegarding, subject);
  response.Set(kArg, arg);
  response.Set(kName, kResult);
  if (r != 0) {
    //TODO(grv): handle error.
  }
  _gitSalt->PostMessage(response);
  return 0;
}

int GitCurrentBranch::parseArgs() {
  return 0;
}

int GitCurrentBranch::runCommand() {

  git_reference* ref = NULL;
  char *branch = NULL;
  int r= git_repository_head(&ref, repo);
  if (r == 0) {
    git_branch_name((const char**)&branch, ref);
  }

  const git_error *a = giterr_last();

  if (a != NULL) {
    printf("giterror: %s\n", a->message);
  }

  pp::VarDictionary arg;
  arg.Set(kBranch, branch);

  pp::VarDictionary response;
  response.Set(kRegarding, subject);
  response.Set(kArg, arg);
  response.Set(kName, kResult);

  _gitSalt->PostMessage(response);
  git_reference_free(ref);
  return 0;
}

int GitGetBranches::parseArgs() {
  if ((error = parseInt(_args, kFlags,  &flags))) {
  }
  return 0;
}

int GitGetBranches::runCommand() {

  git_branch_iterator* iter = NULL;

  git_branch_t type = (git_branch_t) flags;

  int r = git_branch_iterator_new(&iter, repo, type);

  pp::VarDictionary arg;
  pp::VarArray branches;
  int index = 0;

  char* branch = NULL;

  if (r == 0) {
    while (r == 0) {
      git_reference* ref;
      r = git_branch_next(&ref, &type, iter);
      if (r == 0) {
        git_branch_name((const char**)&branch, ref);
        branches.Set(index, branch);
        index++;
        git_reference_free(ref);
      }
    }
  }

  arg.Set(kBranches, branches);

  pp::VarDictionary response;
  response.Set(kRegarding, subject);
  response.Set(kArg, arg);
  response.Set(kName, kResult);

  _gitSalt->PostMessage(response);
  git_branch_iterator_free(iter);
  return 0;
}

int GitAdd::parseArgs() {
  pp::VarArray entryArray;
  if ((error = parseArray(_args, kEntries, entryArray))) {
  }

  uint32_t length = entryArray.GetLength();
  for (uint32_t i = 0; i < length; ++i) {
    entries.push_back(entryArray.Get(i).AsString());
  }
  return 0;
}

int GitAdd::runCommand() {
  git_index* index = NULL;
  error = git_repository_index(&index, repo);
  if (error) {
    //TODO(grv): handle errors.
  }
  for (uint32_t i = 0; i < entries.size(); i++) {
    //TODO(grv) : This only works for filepaths. Add support for adding
    // directory paths recursively.
    git_index_add_bypath(index, entries[i].c_str());
  }
  return 0;
}

int StatusCb(const char* path, unsigned int status, void* payload) {
  pp::VarDictionary* statuses = (pp::VarDictionary*) payload;
  statuses->Set(path, (int)status);
  return 0;
}

int GitStatus::runCommand() {

  git_status_cb cb = StatusCb;

  pp::VarDictionary statuses;
  git_status_foreach(repo, cb, &statuses);

  const git_error *a = giterr_last();

  if (a != NULL) {
    printf("giterror: %s\n", a->message);
  }

  pp::VarDictionary arg;
  arg.Set(kStatuses, statuses);

  pp::VarDictionary response;
  response.Set(kRegarding, subject);
  response.Set(kArg, arg);
  response.Set(kName, kResult);

  _gitSalt->PostMessage(response);
  return 0;
}

int GitLsRemote::parseArgs() {
  pp::VarArray entryArray;
  if ((error = parseString(_args, kUrl, url))) {
  }
  return 0;
}

int GitLsRemote::runCommand() {
  git_remote* remote = NULL;
  error = git_remote_create_anonymous(&remote, repo, url.c_str(), NULL);

  error = git_remote_connect(remote, GIT_DIRECTION_FETCH);

  size_t size = 0;
  git_remote_head** heads = NULL;

  git_remote_ls((const git_remote_head***)&heads, &size, remote);

  pp::VarArray refs;

  for (size_t i = 0; i < size; ++i) {
    refs.Set(i, heads[i]->name);
  }

  git_remote_free(remote);

  pp::VarDictionary arg;
  arg.Set(kRefs, refs);

  pp::VarDictionary response;
  response.Set(kRegarding, subject);
  response.Set(kArg, arg);
  response.Set(kName, kResult);

  _gitSalt->PostMessage(response);
  return 0;
}

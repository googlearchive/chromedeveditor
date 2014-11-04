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

  int error = 0;

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

int GitCommit::runCommand() {
  //TODO(grv): implement.
  char message[100];
  sprintf(message, "%s", subject.c_str());
  _gitSalt->PostMessage(pp::Var(message));
  printf("GitCommit: to be implemented");
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
  int error = 0;
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
  int error = 0;
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
  int error = git_repository_index(&index, repo);
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

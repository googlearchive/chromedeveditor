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

  git_clone(&repo, url.c_str(), "/chromefs", NULL);

  const git_error *a = giterr_last();

  if (a != NULL) {
    printf("giterror: %s\n", a->message);
  }

  pp::VarDictionary dict;
  dict.Set(kRegarding, subject);
  dict.Set("message", "clone successful");

  char message[100];
  sprintf(message, "%s", subject.c_str());
  _gitSalt->PostMessage(pp::Var(message));
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


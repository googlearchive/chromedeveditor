// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "git_salt.h"

GitSaltInstance::GitSaltInstance(PP_Instance instance)
  : pp::Instance(instance),
  callback_factory_(this),
  file_system_(this, PP_FILESYSTEMTYPE_LOCALPERSISTENT),
  file_system_ready_(false),
  file_thread_(this) {}

GitSaltInstance::~GitSaltInstance() { file_thread_.Join(); }

bool GitSaltInstance::Init(uint32_t /*argc*/,
    const char * /*argn*/ [],
    const char * /*argv*/ []) {
  file_thread_.Start();
  // Open the file system on the file_thread_. Since this is the first
  // operation we perform there, and because we do everything on the
  // file_thread_ synchronously, this ensures that the FileSystem is open
  // before any FileIO operations execute.
  file_thread_.message_loop().PostWork(
      callback_factory_.NewCallback(&GitSaltInstance::OpenFileSystem));
  return true;
}

void GitSaltInstance::HandleMessage(const pp::Var& var_message) {

  if (!var_message.is_dictionary()) {
    PostMessage("Error: Message was not a dictionary.");
    return;
  }

  pp::VarDictionary var_dictionary_message(var_message);

  int error = 0;
  std::string cmd;
  std::string subject;

  if ((error = parseString(var_dictionary_message, kName,  cmd))) {

  }

  if ((error = parseString(var_dictionary_message, kSubject,  subject))) {

  }

  pp::VarDictionary var_dictionary_args(var_dictionary_message.Get(kArg));


  if (!cmd.compare(kCmdClone)) {
    if (repo != NULL) {
      PostMessage("repository already exists.");
      return;
    }

    GitClone* clone = new GitClone(this, subject, var_dictionary_args, repo);
    clone->parseArgs();
    file_thread_.message_loop().PostWork(
        callback_factory_.NewCallback(&GitSaltInstance::Clone, clone));
  } else if (!cmd.compare(kCmdCommit)) {
    if (repo == NULL) {
      PostMessage("Git repository not initialized.");
      return;
    }
    GitCommit* commit = new GitCommit(this, subject, var_dictionary_args, repo);
    commit->parseArgs();
    file_thread_.message_loop().PostWork(
        callback_factory_.NewCallback(&GitSaltInstance::Commit, commit));
  } else if (!cmd.compare(kCmdCurrentBranch)) {
    if (repo == NULL) {
      PostMessage("Git repository not initialized.");
      return;
    }
    GitCurrentBranch* branch = new GitCurrentBranch(
      this, subject, var_dictionary_args, repo);
    branch->parseArgs();
    file_thread_.message_loop().PostWork(
        callback_factory_.NewCallback(&GitSaltInstance::CurrentBranch, branch));
  } else if (!cmd.compare(kCmdGetBranches)) {
    if (repo == NULL) {
      PostMessage("Git repository not initialized.");
      return;
    }
    GitGetBranches* getBranches = new GitGetBranches(
      this, subject, var_dictionary_args, repo);
    getBranches->parseArgs();
    file_thread_.message_loop().PostWork(
        callback_factory_.NewCallback(&GitSaltInstance::GetBranches, getBranches));
  } else if (!cmd.compare(kCmdAdd)) {
    if (repo == NULL) {
      PostMessage("Git repository not initialized.");
      return;
    }
    GitAdd* add = new GitAdd(this, subject, var_dictionary_args, repo);
    add->parseArgs();
    file_thread_.message_loop().PostWork(
        callback_factory_.NewCallback(&GitSaltInstance::Add, add));
  } else if (!cmd.compare(kCmdStatus)) {
    if (repo == NULL) {
      PostMessage("Git repository not initialized.");
      return;
    }
    GitStatus* status = new GitStatus(this, subject, var_dictionary_args, repo);
    status->parseArgs();
    file_thread_.message_loop().PostWork(
        callback_factory_.NewCallback(&GitSaltInstance::Status, status));
  } else if (!cmd.compare(kLsRemote)) {
    if (repo == NULL) {
      PostMessage("Git repository not initialized.");
      return;
    }
    GitLsRemote* lsRemote = new GitLsRemote(this, subject, var_dictionary_args, repo);
    lsRemote->parseArgs();
    file_thread_.message_loop().PostWork(
        callback_factory_.NewCallback(&GitSaltInstance::LsRemote, lsRemote));
  } else if (!cmd.compare(kCmdInit)) {
    GitInit* init = new GitInit(this, subject, var_dictionary_args, repo);
    init->parseArgs();
    file_thread_.message_loop().PostWork(
        callback_factory_.NewCallback(&GitSaltInstance::InitRepo, init));
  }
}

int GitSaltInstance::Clone(int32_t r, GitClone* clone) {
  clone->runCommand();
  return 0;
}

int GitSaltInstance::InitRepo(int32_t r, GitInit* init) {
  init->runCommand();
  return 0;
}

int GitSaltInstance::CurrentBranch(int32_t r, GitCurrentBranch* branch) {
  branch->runCommand();
  return 0;
}

int GitSaltInstance::Commit(int32_t r, GitCommit* commit) {
  commit->runCommand();
  return 0;
}

int GitSaltInstance::GetBranches(int32_t r, GitGetBranches* getBranches) {
  getBranches->runCommand();
  return 0;
}

int GitSaltInstance::Add(int32_t r, GitAdd* add) {
  add->runCommand();
  return 0;
}

int GitSaltInstance::Status(int32_t r, GitStatus* status) {
  status->runCommand();
  return 0;
}

int GitSaltInstance::LsRemote(int32_t r, GitLsRemote* lsRemote) {
  lsRemote->runCommand();
  return 0;
}

void GitSaltInstance::OpenFileSystem(int32_t /* result */) {
  int32_t rv = file_system_.Open(1024 * 1024, pp::BlockUntilComplete());
  if (rv == PP_OK) {
    file_system_ready_ = true;
    // Notify the user interface that we're ready
    PostMessage("READY|");
  } else {
    ShowErrorMessage("Failed to open file system", rv);
  }
  NaclIoInit();
}

void GitSaltInstance::NaclIoInit() {
  nacl_io_init_ppapi(pp::Instance::pp_instance(),
      pp::Module::Get()->get_browser_interface());

  // By default, nacl_io mounts / to pass through to the original NaCl
  // filesystem (which doesn't do much). Let's remount it to a memfs
  // filesystem.
  umount("/");
  mount("", "/", "memfs", 0, "");

  mount("",                                     /* source */
      "/grvfs",                                 /* target */
      "html5fs",                                /* filesystemtype */
      0,                                        /* mountflags */
      "type=PERSISTENT,expected_size=1048576"); /* data */

  mount("",       /* source. Use relative URL */
      "/http",  /* target */
      "httpfs", /* filesystemtype */
      0,        /* mountflags */
      "");      /* data */
  printf("mounted all filesystem!!\n");
}

void GitSaltInstance::ShowErrorMessage(const std::string& message, int32_t result) {
  std::stringstream ss;
  ss << "ERR|" << message << " -- Error #: " << result;
  PostMessage(ss.str());
}

void GitSaltInstance::ShowStatusMessage(const std::string& message) {
  std::stringstream ss;
  ss << "STAT|" << message;
  PostMessage(ss.str());
}

GitSaltModule::GitSaltModule() : pp::Module() {}

pp::Instance* GitSaltModule::CreateInstance(PP_Instance instance) {
  return new GitSaltInstance(instance);
}

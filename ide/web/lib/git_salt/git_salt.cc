// Copyright (c) 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
    GitClone* clone = new GitClone(subject, var_dictionary_args);
    clone->parseArgs();
    file_thread_.message_loop().PostWork(
        callback_factory_.NewCallback(&GitSaltInstance::Clone, clone));
  } else if (!cmd.compare(kCmdCommit)) {
    GitCommit* commit = new GitCommit(subject, var_dictionary_args);
    commit->parseArgs();
    file_thread_.message_loop().PostWork(
        callback_factory_.NewCallback(&GitSaltInstance::Commit, commit));
  }
}

int GitSaltInstance::Clone(int32_t r, GitClone* clone) {
  clone->runCommand();
  return 0;
}

int GitSaltInstance::Commit(int32_t r, GitCommit* commit) {
  commit->runCommand();
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

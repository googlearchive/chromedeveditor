// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#define __STDC_LIMIT_MACROS
#include <sstream>
#include <string>
#include <cstring>
#include <git2.h>
#include <sys/mount.h>
#include <stdio.h>
#include<iostream>

#include <dirent.h>
#include <stdlib.h>
#include <errno.h>

#include "ppapi/c/pp_stdint.h"
#include "ppapi/c/ppb_file_io.h"
#include "ppapi/cpp/directory_entry.h"
#include "ppapi/cpp/file_io.h"
#include "ppapi/cpp/file_ref.h"
#include "ppapi/cpp/file_system.h"
#include "ppapi/cpp/instance.h"
#include "ppapi/cpp/message_loop.h"
#include "ppapi/cpp/module.h"
#include "ppapi/cpp/var.h"
#include "ppapi/cpp/var_dictionary.h"
#include "ppapi/utility/completion_callback_factory.h"
#include "ppapi/utility/threading/simple_thread.h"
#include "nacl_io/nacl_io.h"

#ifndef INT32_MAX
#define INT32_MAX (0x7FFFFFFF)
#endif

#ifdef WIN32
#undef min
#undef max
#undef PostMessage

// Allow 'this' in initializer list
#pragma warning(disable : 4355)
#endif

namespace {
/// Used for our simple protocol to communicate with Javascript
const char* const kSavePrefix = "sv";
const char* const kChromefsPrefix = "cr";

const char* const kFileSystem = "filesystem";
const char* const kUrl = "url";
const char* const kFullPath = "fullPath";
const char* const kName = "name";
const char* const kSubject = "subject";
const char* const kArg = "arg";
const char* const kCmdClone = "clone";
const char* const kCmdCommit = "commit";

int parseString(pp::VarDictionary message, const char* name,
    std::string& option) {
  pp::Var var_option = message.Get(name);
  if (!var_option.is_string()) {
    //TODO(grv): return error code;
    return 1;
  }
  option = var_option.AsString();
  return 0;
}
}

/**
 * Abstract class to defining git command. Every git command
 * should extend this.
 */
class GitCommand {
 protected:
  std::string subject;
  pp::VarDictionary _args;

  int parseFileSystem(pp::VarDictionary message, std::string name,
      pp::FileSystem& fileSystem) {
    pp::Var var_filesystem = message.Get(name);

    if (!var_filesystem.is_resource()) {
      //TODO(grv): return error code;
      return 1;
    }

    pp::Resource resource_filesystem = var_filesystem.AsResource();
    fileSystem = pp::FileSystem(resource_filesystem);
    return 0;
  }

 public:
  pp::FileSystem fileSystem;
  std::string fullPath;
  std::string url;
  int error;
  git_repository* repo;

  GitCommand(const std::string& subject, const pp::VarDictionary& args)
      : subject(subject), _args(args) {}

  int parseArgs() {

    int error = 0;

    if ((error = parseFileSystem(_args, kFileSystem, fileSystem))) {

    }

    if ((error = parseString(_args, kFullPath,  fullPath))) {

    }

    if ((error = parseString(_args, kUrl,  url))) {

    }
    return 0;
  }

  virtual int runCommand() = 0;
};

class GitClone : public GitCommand {

 public:

  GitClone(std::string subject, pp::VarDictionary args)
      : GitCommand(subject, args) {
        repo = NULL;
  }

  int runCommand() {
    // mount the folder as a filesystem.
    ChromefsInit();

    git_threads_init();

    git_clone(&repo, url.c_str(), "/chromefs", NULL);

    const git_error *a = giterr_last();

    if (a != NULL) {
      printf("giterror: %s\n", a->message);
    }
    printf("cloning done %s\n", subject.c_str());
    return 0;
  }

  void ChromefsInit() {
    int32_t r = (int32_t) fileSystem.pp_resource();
    char fs_resource[100] = "filesystem_resource=";
    sprintf(&fs_resource[20], "%d", r);
    mount(fullPath.c_str(),                     /* source */
      "/chromefs",                              /* target */
      "html5fs",                                /* filesystemtype */
      0,                                        /* mountflags */
      fs_resource);                             /* data */
  }
};

class GitCommit : public GitCommand {

 public:
  GitCommit(std::string subject, pp::VarDictionary args)
      : GitCommand(subject, args) {}

  int runCommand() {
    //TODO(grv): implement.
    printf("GitCommit: to be implemented");
    return 0;
  }
};

/// The Instance class.  One of these exists for each instance of your NaCl
/// module on the web page.  The browser will ask the Module object to create
/// a new Instance for each occurrence of the <embed> tag that has these
class FileIoInstance : public pp::Instance {
 public:
  /// The constructor creates the plugin-side instance.
  /// @param[in] instance the handle to the browser-side plugin instance.
  explicit FileIoInstance(PP_Instance instance)
      : pp::Instance(instance),
        callback_factory_(this),
        file_system_(this, PP_FILESYSTEMTYPE_LOCALPERSISTENT),
        file_system_ready_(false),
        file_thread_(this) {}

  virtual ~FileIoInstance() { file_thread_.Join(); }

  virtual bool Init(uint32_t /*argc*/,
                    const char * /*argn*/ [],
                    const char * /*argv*/ []) {
    file_thread_.Start();
    // Open the file system on the file_thread_. Since this is the first
    // operation we perform there, and because we do everything on the
    // file_thread_ synchronously, this ensures that the FileSystem is open
    // before any FileIO operations execute.
    file_thread_.message_loop().PostWork(
        callback_factory_.NewCallback(&FileIoInstance::OpenFileSystem));
    return true;
  }

 private:
  pp::CompletionCallbackFactory<FileIoInstance> callback_factory_;
  pp::FileSystem file_system_;

  // Indicates whether file_system_ was opened successfully. We only read/write
  // this on the file_thread_.
  bool file_system_ready_;

  // We do all our file operations on the file_thread_.
  pp::SimpleThread file_thread_;

  /// Handler for messages coming in from the browser via postMessage().  The
  /// @a var_message is a json dictionary.
  ///
  /// Here we use messages to communicate with the user interface
  ///
  /// @param[in] var_message The message posted by the browser.
  virtual void HandleMessage(const pp::Var& var_message) {

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
          callback_factory_.NewCallback(&FileIoInstance::Clone, clone));
    } else if (!cmd.compare(kCmdCommit)) {
     GitCommit* commit = new GitCommit(subject, var_dictionary_args);
      commit->parseArgs();
      file_thread_.message_loop().PostWork(
        callback_factory_.NewCallback(&FileIoInstance::Commit, commit));
    }
  }

  int Clone(int32_t r, GitClone* clone) {
    clone->runCommand();
    return 0;
  }

  int Commit(int32_t r, GitCommit* commit) {
    commit->runCommand();
    return 0;
  }

  void OpenFileSystem(int32_t /* result */) {
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

  void NaclIoInit() {
    nacl_io_init_ppapi(pp::Instance::pp_instance(),
                      pp::Module::Get()->get_browser_interface());

    // By default, nacl_io mounts / to pass through to the original NaCl
    // filesystem (which doesn't do much). Let's remount it to a memfs
    // filesystem.
    umount("/");
    mount("", "/", "memfs", 0, "");

    mount("",                                       /* source */
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

  /// Encapsulates our simple javascript communication protocol
  void ShowErrorMessage(const std::string& message, int32_t result) {
    std::stringstream ss;
    ss << "ERR|" << message << " -- Error #: " << result;
    PostMessage(ss.str());
  }

  /// Encapsulates our simple javascript communication protocol
  void ShowStatusMessage(const std::string& message) {
    std::stringstream ss;
    ss << "STAT|" << message;
    PostMessage(ss.str());
  }
};

/// The Module class.  The browser calls the CreateInstance() method to create
/// an instance of your NaCl module on the web page.  The browser creates a new
/// instance for each <embed> tag with type="application/x-nacl".
class FileIoModule : public pp::Module {
 public:
  FileIoModule() : pp::Module() {}
  virtual ~FileIoModule() {}

  /// Create and return a FileIoInstance object.
  /// @param[in] instance The browser-side instance.
  /// @return the plugin-side instance.
  virtual pp::Instance* CreateInstance(PP_Instance instance) {
    return new FileIoInstance(instance);
  }
};

namespace pp {
/// Factory function called by the browser when the module is first loaded.
/// The browser keeps a singleton of this module.  It calls the
/// CreateInstance() method on the object you return to make instances.  There
/// is one instance per <embed> tag on the page.  This is the main binding
/// point for your NaCl module with the browser.
Module* CreateModule() { return new FileIoModule(); }
}  // namespace pp

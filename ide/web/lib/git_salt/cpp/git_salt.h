// Copyright (c) 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef GIT_SALT_GIT_SALT_H__
#define GIT_SALT_GIT_SALT_H__

#include <sstream>
#include <string>

#include "ppapi/cpp/file_system.h"
#include "ppapi/cpp/instance.h"
#include "ppapi/cpp/message_loop.h"
#include "ppapi/cpp/module.h"
#include "ppapi/cpp/var_dictionary.h"
#include "ppapi/utility/completion_callback_factory.h"
#include "ppapi/utility/threading/simple_thread.h"
#include "nacl_io/nacl_io.h"

#include "git_command.h"

class GitAdd;
class GitClone;
class GitCommit;
class GitCurrentBranch;
class GitGetBranches;
class GitInit;
class GitLsRemote;
class GitStatus;

/// The Instance class.  One of these exists for each instance of your NaCl
/// module on the web page.  The browser will ask the Module object to create
/// a new Instance for each occurrence of the <embed> tag that has these
class GitSaltInstance : public pp::Instance {
 public:
  /// The constructor creates the plugin-side instance.
  /// @param[in] instance the handle to the browser-side plugin instance.
  explicit GitSaltInstance(PP_Instance instance);

  virtual ~GitSaltInstance();

  virtual bool Init(uint32_t /*argc*/,
                    const char * /*argn*/ [],
                    const char * /*argv*/ []);

 private:
  pp::CompletionCallbackFactory<GitSaltInstance> callback_factory_;
  pp::FileSystem file_system_;
  git_repository* repo;

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
  virtual void HandleMessage(const pp::Var& var_message);

  int Clone(int32_t r, GitClone* clone);

  int InitRepo(int32_t r, GitInit* init);

  int Commit(int32_t r, GitCommit* commit);

  int CurrentBranch(int32_t r, GitCurrentBranch* branch);

  int GetBranches(int32_t r, GitGetBranches* getBranches);

  int Add(int32_t, GitAdd* add);

  int Status(int32_t r, GitStatus* status);

  int LsRemote(int32_t r, GitLsRemote* lsRemote);

  void OpenFileSystem(int32_t /* result */);

  void NaclIoInit();

  /// Encapsulates our simple javascript communication protocol
  void ShowErrorMessage(const std::string& message, int32_t result);

  /// Encapsulates our simple javascript communication protocol
  void ShowStatusMessage(const std::string& message);
};


/// The Module class.  The browser calls the CreateInstance() method to create
/// an instance of your NaCl module on the web page.  The browser creates a new
/// instance for each <embed> tag with type="application/x-nacl".
class GitSaltModule : public pp::Module {
 public:
  GitSaltModule();
  virtual ~GitSaltModule() {}

  /// Create and return a GitSaltInstance object.
  /// @param[in] instance The browser-side instance.
  /// @return the plugin-side instance.
  virtual pp::Instance* CreateInstance(PP_Instance instance);
};

#endif  // GIT_SALT_GIT_SALT_H__

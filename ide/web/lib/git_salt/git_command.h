#include <string>
#include <cstring>
#include <git2.h>
#include <sys/mount.h>
#include <stdio.h>

#include "ppapi/cpp/file_system.h"
#include "ppapi/cpp/var_dictionary.h"

namespace {
/// Used for our simple protocol to communicate with Javascript
const char* const kSavePrefix = "sv";
const char* const kChromefsPrefix = "cr";

const char* const kFileSystem = "filesystem";
const char* const kUrl = "url";
const char* const kFullPath = "fullPath";
const char* const kName = "name";
const char* const kSubject = "subject";
const char* const kRegarding = "regarding";
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
      pp::FileSystem& fileSystem);

 public:
  pp::FileSystem fileSystem;
  std::string fullPath;
  std::string url;
  int error;
  git_repository* repo;

  GitCommand(const std::string& subject, const pp::VarDictionary& args)
      : subject(subject), _args(args) {}

  int parseArgs();
  virtual int runCommand() = 0;
};

class GitClone : public GitCommand {

 public:
  GitClone(std::string subject, pp::VarDictionary args)
      : GitCommand(subject, args) {
        repo = NULL;
  }

  int runCommand();

  void ChromefsInit();
};

class GitCommit : public GitCommand {

 public:
  GitCommit(std::string subject, pp::VarDictionary args)
      : GitCommand(subject, args) {}

  int runCommand();
};


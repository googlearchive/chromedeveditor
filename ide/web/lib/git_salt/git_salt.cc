// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// @file file_io.cc
/// This example demonstrates the use of persistent file I/O

#define __STDC_LIMIT_MACROS
#include <sstream>
#include <string>
#include <git2.h>
#include <sys/mount.h>
#include <stdio.h>
#include<iostream>

#include <dirent.h>
#include <stdlib.h>
#include <errno.h>

using namespace std;



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
const char* const kLoadPrefix = "ld";
const char* const kSavePrefix = "sv";
const char* const kDeletePrefix = "de";
const char* const kListPrefix = "ls";
const char* const kMakeDirPrefix = "md";
const char* const kChromefsPrefix = "cr";
}

/*static void fetch_progress(
        const git_transfer_progress *stats,
        void *payload)
{
    int fetch_percent =
        (100 * stats->received_objects) /
        stats->total_objects;
    int index_percent =
        (100 * stats->indexed_objects) /
        stats->total_objects;
    int kbytes = stats->received_bytes / 1024;

    printf("network %3d%% (%4d kb, %5d/%5d)  /"
            "  index %3d%% (%5d/%5d)\n",
            fetch_percent, kbytes,
            stats->received_objects, stats->total_objects,
            index_percent,
            stats->indexed_objects, stats->total_objects);
}*/




/// The Instance class.  One of these exists for each instance of your NaCl
/// module on the web page.  The browser will ask the Module object to create
/// a new Instance for each occurrence of the <embed> tag that has these
/// attributes:
///     type="application/x-nacl"
///     src="file_io.nmf"
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
  /// @a var_message can contain anything: a JSON string; a string that encodes
  /// method names and arguments; etc.
  ///
  /// Here we use messages to communicate with the user interface
  ///
  /// @param[in] var_message The message posted by the browser.
  virtual void HandleMessage(const pp::Var& var_message) {
    if (!var_message.is_string()) {
      pp::Resource resource_filesystem = var_message.AsResource();
      printf("resource_filesystme = %d", (int32_t)resource_filesystem.pp_resource());
      //pp::Resource resource_filesystem = var_resource_filesystem.AsResource();
      pp::FileSystem filesystem(resource_filesystem);
      printf("inside chrome fs init\n");
      file_thread_.message_loop().PostWork(
          callback_factory_.NewCallback(&FileIoInstance::ChromefsInit, filesystem));
      return;
    }

    // Parse message into: instruction file_name_length file_name [file_text]
    std::string message = var_message.AsString();
    std::string instruction;
    std::string file_name;
    std::stringstream reader(message);
    int file_name_length;

    reader >> instruction >> file_name_length;
    file_name.resize(file_name_length);
    reader.ignore(1);  // Eat the delimiter
    reader.read(&file_name[0], file_name_length);

    if (file_name.length() == 0 || file_name[0] != '/') {
      ShowStatusMessage("File name must begin with /");
      return;
    }

    // Dispatch the instruction
    if (instruction == kLoadPrefix) {
      file_thread_.message_loop().PostWork(
          callback_factory_.NewCallback(&FileIoInstance::Load, file_name));
    } else if (instruction == kSavePrefix) {
      // Read the rest of the message as the file text
      reader.ignore(1);  // Eat the delimiter
      std::string file_text = message.substr(reader.tellg());
      file_thread_.message_loop().PostWork(callback_factory_.NewCallback(
          &FileIoInstance::Save, file_name, file_text));
    } else if (instruction == kDeletePrefix) {
      file_thread_.message_loop().PostWork(
          callback_factory_.NewCallback(&FileIoInstance::Delete, file_name));
    } else if (instruction == kListPrefix) {
      const std::string& dir_name = file_name;
      file_thread_.message_loop().PostWork(
          callback_factory_.NewCallback(&FileIoInstance::List, dir_name));
    } else if (instruction == kMakeDirPrefix) {
      const std::string& dir_name = file_name;
      file_thread_.message_loop().PostWork(
          callback_factory_.NewCallback(&FileIoInstance::MakeDir, dir_name));
    }
  }

  int cloning(int r, const char *url) {
    git_repository *repo = NULL;
    //const char path[100] = "/chromefs/nacl_checkout";
    const char path[100] = "/grvfs/nacl_checkout-8";
    printf("before gdit clone %s %s\n", url, path);
    const char url2[] = "https://github.com/dart-lang/spark.git";
    git_threads_init();
    int r2 = git_clone(&repo, url2, path, NULL);
    printf("clonidng repo %d %d\n", r2, r);
    return 2;
  }


 int do_clone(const char *url, const char *path) {

    file_thread_.message_loop().PostWork(
          callback_factory_.NewCallback(&FileIoInstance::cloning,url));
    return 1;
}

  void GitClone() {
    DIR* dir = opendir("/chromefs/nacl_checkout");
    if (dir) {
      printf("dir exists chromefs \n");
    } else {
      printf("dir is null chromefs\n");
    }
    const char url[100] = "https://github.com/gaurave/trep";
    const char local_path[100] = "/chromefs/naclgit";
    do_clone(url, local_path);
    printf("calling git clone %s %s\n", local_path, url);
    const git_error *a = giterr_last();
    if (a == NULL) {
      printf("something is wrong\n");
      return;
    }
      printf("%s\n", a->message);
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
      nacl_io_init_ppapi(pp::Instance::pp_instance(), pp::Module::Get()->get_browser_interface());

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

  void Save(int32_t /* result */,
            const std::string& file_name,
            const std::string& file_contents) {
            //  GitClone();
            char dir[100] = "filename.txt";
            pp::FileRef ref(file_system_, dir);
            pp::Var path = ref.GetPath();
            std::string debugString = path.AsString();
            printf("%s\n", debugString.c_str());
            GitClone();
             ShowStatusMessage("Save succddess");
            printf("asfklasdjfkjasdfjkasdfjkl\n");
    PostMessage("pyaflasdkfjkasl");
    return;

   /* if (!file_system_ready_) {
      ShowErrorMessage("File system is not open", PP_ERROR_FAILED);
      return;
    }
    pp::FileRef ref(file_system_, file_name.c_str());
    pp::FileIO file(this);

    int32_t open_result =
        file.Open(ref,
                  PP_FILEOPENFLAG_WRITE | PP_FILEOPENFLAG_CREATE |
                      PP_FILEOPENFLAG_TRUNCATE,
                  pp::BlockUntilComplete());
    if (open_result != PP_OK) {
      ShowErrorMessage("File open for write failed", open_result);
      return;
    }

    // We have truncated the file to 0 bytes. So we need only write if
    // file_contents is non-empty.
    if (!file_contents.empty()) {
      if (file_contents.length() > INT32_MAX) {
        ShowErrorMessage("File too big", PP_ERROR_FILETOOBIG);
        return;
      }
      int64_t offset = 0;
      int32_t bytes_written = 0;
      do {
        bytes_written = file.Write(offset,
                                   file_contents.data() + offset,
                                   file_contents.length(),
                                   pp::BlockUntilComplete());
        if (bytes_written > 0) {
          offset += bytes_written;
        } else {
          ShowErrorMessage("File write failed", bytes_written);
          return;
        }
      } while (bytes_written < static_cast<int64_t>(file_contents.length()));
    }
    // All bytes have been written, flush the write buffer to complete
    int32_t flush_result = file.Flush(pp::BlockUntilComplete());
    if (flush_result != PP_OK) {
      ShowErrorMessage("File fail to flush", flush_result);
      return;
    }
    ShowStatusMessage("Save success");*/
  }

  void Load(int32_t /* result */, const std::string& file_name) {
    if (!file_system_ready_) {
      ShowErrorMessage("File system is not open", PP_ERROR_FAILED);
      return;
    }
    pp::FileRef ref(file_system_, file_name.c_str());
    pp::FileIO file(this);

    int32_t open_result =
        file.Open(ref, PP_FILEOPENFLAG_READ, pp::BlockUntilComplete());
    if (open_result == PP_ERROR_FILENOTFOUND) {
      ShowErrorMessage("File not found", open_result);
      return;
    } else if (open_result != PP_OK) {
      ShowErrorMessage("File open for read failed", open_result);
      return;
    }
    PP_FileInfo info;
    int32_t query_result = file.Query(&info, pp::BlockUntilComplete());
    if (query_result != PP_OK) {
      ShowErrorMessage("File query failed", query_result);
      return;
    }
    // FileIO.Read() can only handle int32 sizes
    if (info.size > INT32_MAX) {
      ShowErrorMessage("File too big", PP_ERROR_FILETOOBIG);
      return;
    }

    std::vector<char> data(info.size);
    int64_t offset = 0;
    int32_t bytes_read = 0;
    int32_t bytes_to_read = info.size;
    while (bytes_to_read > 0) {
      bytes_read = file.Read(offset,
                             &data[offset],
                             data.size() - offset,
                             pp::BlockUntilComplete());
      if (bytes_read > 0) {
        offset += bytes_read;
        bytes_to_read -= bytes_read;
      } else if (bytes_read < 0) {
        // If bytes_read < PP_OK then it indicates the error code.
        ShowErrorMessage("File read failed", bytes_read);
        return;
      }
    }
    // Done reading, send content to the user interface
    std::string string_data(data.begin(), data.end());
    PostMessage("DISP|" + string_data);
    ShowStatusMessage("Load success");
  }

  void Delete(int32_t /* result */, const std::string& file_name) {
    if (!file_system_ready_) {
      ShowErrorMessage("File system is not open", PP_ERROR_FAILED);
      return;
    }
    pp::FileRef ref(file_system_, file_name.c_str());

    int32_t result = ref.Delete(pp::BlockUntilComplete());
    if (result == PP_ERROR_FILENOTFOUND) {
      ShowStatusMessage("File/Directory not found");
      return;
    } else if (result != PP_OK) {
      ShowErrorMessage("Deletion failed", result);
      return;
    }
    ShowStatusMessage("Delete success");
  }

  void List(int32_t /* result */, const std::string& dir_name) {
    if (!file_system_ready_) {
      ShowErrorMessage("File system is not open", PP_ERROR_FAILED);
      return;
    }

    pp::FileRef ref(file_system_, dir_name.c_str());

    // Pass ref along to keep it alive.
    ref.ReadDirectoryEntries(callback_factory_.NewCallbackWithOutput(
        &FileIoInstance::ListCallback, ref));
  }

  void ListCallback(int32_t result,
                    const std::vector<pp::DirectoryEntry>& entries,
                    pp::FileRef /* unused_ref */) {
    if (result != PP_OK) {
      ShowErrorMessage("List failed", result);
      return;
    }

    std::stringstream ss;
    ss << "LIST";
    for (size_t i = 0; i < entries.size(); ++i) {
      pp::Var path = entries[i].file_ref().GetPath();
      if (path.is_string()) {
        ss << "|" << path.AsString();
      }
    }
    PostMessage(ss.str());
    ShowStatusMessage("List success");
  }

  void MakeDir(int32_t /* result */, const std::string& dir_name) {
    if (!file_system_ready_) {
      ShowErrorMessage("File system is not open", PP_ERROR_FAILED);
      return;
    }
    pp::FileRef ref(file_system_, dir_name.c_str());

    int32_t result = ref.MakeDirectory(
        PP_MAKEDIRECTORYFLAG_NONE, pp::BlockUntilComplete());
    if (result != PP_OK) {
      ShowErrorMessage("Make directory failed", result);
      return;
    }
    ShowStatusMessage("Make directory success");
  }

    void ChromefsInit(int32_t /* result */, pp::FileSystem fs) {
      int32_t r = (int32_t) fs.pp_resource();
      char fs_resource[100] = "filesystem_resource=";
      sprintf(&fs_resource[20], "%d", r);
      printf("%s\n", fs_resource);

        mount("",                                 /* source */
        "/chromefs",                              /* target */
        "html5fs",                                /* filesystemtype */
        0,                                        /* mountflags */
        fs_resource); /* data */
        FILE* f = fopen("/chromefs/nacl_checkout/33/grv.txt", "w");
        if (!f) {
          printf("can't open file\n");
        } else {
          //fputs("i am here\n", f);
          printf("file open successful\n");
          //fclose(f);
        }
      /*  FILE* r4 = fopen("/chromefs/grv2.txt", "r");
        if (!r4) {
          printf("can't open file r\n");
        } else {
          printf("file open r successful\n");
        }
                 f = fopen("/grvfs/filename.txt", "r");
        if (!f) {
          printf("can't open file grv\n");
        } else {
          printf("file open successful grv\n");
        }*/
       /* pp::FileRef ref = pp::FileRef(fs, "/chromefs/nacl_checkout/grv.txt");
        if (ref.is_null()) {
          printf("ref is null\n");
        } else */
    ShowStatusMessage(fs_resource);
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

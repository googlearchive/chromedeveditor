// Copyright (c) 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef GIT_SALT_CONSTANTS_H__
#define GIT_SALT_CONSTANTS_H__

namespace {
// Used for our simple protocol to communicate with Javascript
const char* const kArg = "arg";
const char* const kBranch = "branch";
const char* const kBranches = "branches";
const char* const kCommitMessage = "commitMessage";
const char* const kEntries = "entries";
const char* const kFlags = "flags";
const char* const kFileSystem = "filesystem";
const char* const kFullPath = "fullPath";
const char* const kMessage = "message";
const char* const kName = "name";
const char* const kRefs = "refs";
const char* const kRegarding = "regarding";
const char* const kResult = "result";
const char* const kStatuses = "statuses";
const char* const kSubject = "subject";
const char* const kUrl = "url";
const char* const kUserEmail = "userEmail";
const char* const kUserName = "userName";

// Git command constants.
const char* const kCmdAdd = "add";
const char* const kCmdClone = "clone";
const char* const kCmdCommit = "commit";
const char* const kCmdCurrentBranch = "currentBranch";
const char* const kCmdGetBranches = "getBranches";
const char* const kLsRemote = "lsRemote";
const char* const kCmdStatus = "status";
const char* const kCmdInit = "init";
}
#endif  // GIT_SALT_CONSTANTS_H__


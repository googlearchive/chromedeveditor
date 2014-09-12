// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef INSTANCE_H

#define INSTANCE_H

#include "ppapi/cpp/instance.h"
#include "ppapi/cpp/var_array.h"

namespace pp {

class AndroidRSAInstance : public pp::Instance {
 public:
  explicit AndroidRSAInstance(PP_Instance instance);
  virtual ~AndroidRSAInstance();

  virtual void HandleMessage(const pp::Var& var_message);

 private:
  // Return result to Javascript caller.
  void postError(Var& uuid, std::string error);
  void postErrorInvalidNumberOfParameters(Var& uuid);
  void postErrorInvalidTypeOfParameters(Var& uuid);
  void postErrorInvalidMessage();
  void postResult(Var& uuid, Var result);

  // Commands implementation.
  void generateKey(Var& uuid, VarArray& parameters);
  void sign(Var& uuid, VarArray& parameters);
  void getPublicKey(Var& uuid, VarArray& parameters);
  void randomSeed(Var& uuid, VarArray& parameters);
};

}

#endif

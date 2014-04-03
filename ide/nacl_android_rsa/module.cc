// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/*
#include "ppapi/c/pp_stdint.h"
#include "ppapi/cpp/var.h"
#include "ppapi/cpp/var_dictionary.h"
#include "ppapi/cpp/var_array.h"
#include "ppapi/cpp/var_array_buffer.h"
*/
//#include "ppapi/cpp/instance.h"
#include "ppapi/cpp/module.h"

#include "instance.h"

using namespace pp;

class AndroidRSAModule : public pp::Module {
 public:
  AndroidRSAModule() : pp::Module() {}
  virtual ~AndroidRSAModule() {}

  virtual pp::Instance* CreateInstance(PP_Instance instance) {
    return new AndroidRSAInstance(instance);
  }
};

namespace pp {
Module* CreateModule() { return new AndroidRSAModule(); }
}

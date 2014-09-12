// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "instance.h"

#include "ppapi/c/pp_stdint.h"
#include "ppapi/cpp/instance.h"
#include "ppapi/cpp/module.h"
#include "ppapi/cpp/var.h"
#include "ppapi/cpp/var_dictionary.h"

#include "android_rsa.h"
#include "modp_b64.h"

using namespace pp;

namespace {
// Post a message with a vprintf-like formatted log message to the javascript.
//
// Here's a sample of a posted messsage:
// {"log":"here's log message"}
void vLog(pp::Instance* instance,
          const char* filename,
          unsigned int line,
          const char* format,
          va_list argp) {
  static char output[512];
  static char formatted[512];
  while (1) {
    const char* p = filename;

    p = strchr(filename, '/');
    if (p == NULL) {
      break;
    }
    filename = p + 1;
  }
  vsnprintf(formatted, sizeof(formatted), format, argp);
  snprintf(output, sizeof(output), "%s:%i: %s", filename, line, formatted);
  VarDictionary result;
  result.Set(Var("log"), Var(output));
  instance->PostMessage(result);
}

// Post a message with a printf-like formatted log message to the javascript.
//
// Here's a sample of a posted messsage:
// {"log":"here's log message"}
void log(pp::Instance* instance,
         const char* filename,
         unsigned int line,
         const char* format,
         ...) {
  va_list argp;
  va_start(argp, format);
  vLog(instance, filename, line, format, argp);
  va_end(argp);
}

// LOG() is a macro that will include the filename:line number in the log.
#define LOG(...) log(this, __FILE__, __LINE__, __VA_ARGS__)

}

AndroidRSAInstance::AndroidRSAInstance(PP_Instance instance)
    : pp::Instance(instance) {}

AndroidRSAInstance::~AndroidRSAInstance() {}

void AndroidRSAInstance::postError(Var& uuid, std::string error) {
  VarDictionary result;
  result.Set("error", error);
  if (!uuid.is_undefined()) {
    result.Set("uuid", uuid);
  }

  PostMessage(result);
}

void AndroidRSAInstance::postErrorInvalidNumberOfParameters(Var& uuid) {
  postError(uuid, "invalid_parameters");
}

void AndroidRSAInstance::postErrorInvalidTypeOfParameters(Var& uuid) {
  postError(uuid, "invalid_parameters_types");
}

void AndroidRSAInstance::postErrorInvalidMessage() {
  Var undefined;
  postError(undefined, "invalid_message");
}

void AndroidRSAInstance::postResult(Var& uuid, Var result) {
  VarDictionary response;
  if (!result.is_undefined()) {
    response.Set("result", result);
  }
  response.Set("uuid", uuid);
  PostMessage(response);
}

void AndroidRSAInstance::generateKey(Var& uuid, VarArray& parameters) {
  if (parameters.GetLength() != 0) {
    postErrorInvalidNumberOfParameters(uuid);
    return;
  }

  EVP_PKEY* key = AndroidRSAGeneratePrivateKey();
  if (key == NULL) {
    postError(uuid, "unexpected");
    return;
  }

  std::string exported = AndroidRSAExportPrivateKey(key);
  EVP_PKEY_free(key);
  if (!exported.length()) {
    postError(uuid, "unexpected");
    return;
  }
  // Returns the exported private key.
  postResult(uuid, exported);
}

void AndroidRSAInstance::sign(Var& uuid, VarArray& parameters) {
  if (parameters.GetLength() != 2) {
    postErrorInvalidNumberOfParameters(uuid);
    return;
  }
  // First parameter is the private key.
  Var key_to_import = parameters.Get(0);
  if (!key_to_import.is_string()) {
    postErrorInvalidTypeOfParameters(uuid);
    return;
  }
  // Second parameter is the base64 encoded message to sign.
  Var message = parameters.Get(1);
  if (!message.is_string()) {
    postErrorInvalidTypeOfParameters(uuid);
    return;
  }

  std::string privatekey = key_to_import.AsString();
  EVP_PKEY* key = AndroidRSAImportPrivateKey(privatekey);
  if (key == NULL) {
    postError(uuid, "invalid_key");
    return;
  }
  std::string b64_input = message.AsString();
  std::string input = modp_b64_decode(b64_input);
  if (!input.length()) {
    postError(uuid, "empty_input");
    return;
  }
  std::string output = AndroidRSASign(key, input);
  if (!output.length()) {
    postError(uuid, "unexpected");
    return;
  }
  // Returns the signed message encoded with base64.
  postResult(uuid, modp_b64_encode(output));
}

void AndroidRSAInstance::getPublicKey(Var& uuid, VarArray& parameters) {
  if (parameters.GetLength() != 1) {
    postErrorInvalidNumberOfParameters(uuid);
    return;
  }
  // First parameter is the private key.
  Var b64_privatekey = parameters.Get(0);
  if (!b64_privatekey.is_string()) {
    postErrorInvalidTypeOfParameters(uuid);
    return;
  }

  std::string privatekey = b64_privatekey.AsString();
  EVP_PKEY* key = AndroidRSAImportPrivateKey(privatekey);
  if (key == NULL) {
    postError(uuid, "invalid_key");
    return;
  }
  std::string publickey = AndroidRSAPublicKey(key);
  // Returns the public key.
  postResult(uuid, publickey);
}

void AndroidRSAInstance::randomSeed(Var& uuid, VarArray& parameters) {
  if (parameters.GetLength() != 1) {
    postErrorInvalidNumberOfParameters(uuid);
    return;
  }
  // First parameter is the unpredictable data encoded with base64.
  Var b64_data = parameters.Get(0);
  if (!b64_data.is_string()) {
    postErrorInvalidTypeOfParameters(uuid);
    return;
  }

  std::string b64_data_str = b64_data.AsString();
  std::string data = modp_b64_decode(b64_data_str);
  if (!data.length()) {
    postError(uuid, "empty_input");
    return;
  }
  AndroidRSARandomSeed(data);
  postResult(uuid, Var());
}

void AndroidRSAInstance::HandleMessage(const pp::Var& var_message) {
  Var undefined;
  
  if (!var_message.is_dictionary()) {
    postErrorInvalidMessage();
    return;
  }

  VarDictionary dict(var_message);
  Var uuid = dict.Get("uuid");
  Var command = dict.Get("command");
  Var value_parameters = dict.Get("parameters");
  VarArray parameters(value_parameters);

  if (uuid.is_undefined()) {
    postErrorInvalidMessage();
    return;
  }

  if (command.AsString() == "generate_key") {
    generateKey(uuid, parameters);
  } else if (command.AsString() == "sign") {
    sign(uuid, parameters);
  } else if (command.AsString() == "get_public_key") {
    getPublicKey(uuid, parameters);
  } else if (command.AsString() == "random_seed") {
    randomSeed(uuid, parameters);
  } else {
    postError(uuid, "unknown_command");
    return;
  }
}

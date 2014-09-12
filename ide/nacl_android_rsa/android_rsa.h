// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef ANDROID_RSA_H_
#define ANDROID_RSA_H_

// Implements cryptographic functions needed for ADB connection authentication.

#include <string>
#include <openssl/evp.h>

// Generates a private key. The returned result has to be freed using
// EVP_PKEY_free().
EVP_PKEY* AndroidRSAGeneratePrivateKey();

// Creates a key using base64 encoded bytes of the private key. The returned
// result has to be freed using EVP_PKEY_free().
EVP_PKEY* AndroidRSAImportPrivateKey(std::string& b64_privatekey);

// Returns base64 encoded bytes of the private key.
std::string AndroidRSAExportPrivateKey(EVP_PKEY* key);

// Returns the RSA public key in a format used by ADB protocol.
std::string AndroidRSAPublicKey(EVP_PKEY* key);

// Sign a content using the given RSA key. The signature is returned by this function.
std::string AndroidRSASign(EVP_PKEY* key, const std::string& body);

// Seed the cryptographic pseudo-random generator with unpredictable data.
void AndroidRSARandomSeed(const std::string& unpredictable_data);

#endif  // NDROID_RSA_H_

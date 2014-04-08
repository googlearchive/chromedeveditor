// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "android_rsa.h"

#include <openssl/bn.h>
#include <openssl/evp.h>
#include <openssl/pkcs12.h>
#include <openssl/rand.h>
#include <openssl/rsa.h>
#include <string.h>
#include <vector>

#include "endian.h"
#include "modp_b64.h"

namespace {

const int kRSAKeyBits = 2048;
const int kRSAKeyBytes = kRSAKeyBits / 8;
const size_t kRSANumWords = kRSAKeyBytes / sizeof(uint32_t);
const long kPublicExponent = 65537L;

static const char kDummyRSAPublicKey[] =
    "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA6OSJ64q+ZLg7VV2ojEPh5TRbYjwbT"
    "TifSPeFIV45CHnbTWYiiIn41wrozpYizNsMWZUBjdah1N78WVhbyDrnr0bDgFp+gXjfVppa3I"
    "gjiohEcemK3omXi3GDMK8ERhriLUKfQS842SXtQ8I+KoZtpCkGM//0h7+P+Rhm0WwdipIRMhR"
    "8haNAeyDiiCvqJcvevv2T52vqKtS3aWz+GjaTJJLVWydEpz9WdvWeLfFVhe2ZnqwwZNa30Qoj"
    "fsnvjaMwK2MU7uYfRBPuvLyK5QESWBpArNDd6ULl8Y+NU6kwNOVDc87OASCVEM1gw2IMi2mo2"
    "WO5ywp0UWRiGZCkK+wOFQIDAQAB";

typedef int(ExportFunction)(BIO*, EVP_PKEY*);

// Exports a bytes of a part of a key, specified by export_fn.
// For example, i2d_PKCS8PrivateKeyInfo_bio can be used to export the private
// key.
bool ExportKey(EVP_PKEY* key, ExportFunction export_fn, std::string& output) {
  BIO* bio = NULL;
  long len = 0;
  char* data = NULL;
  int res = 0;

  bio = BIO_new(BIO_s_mem());
  if (!bio) {
    goto err;
  }

  res = export_fn(bio, key);
  if (!res) {
    goto free_bio;
  }

  len = BIO_get_mem_data(bio, &data);
  if (!data || len < 0) {
    goto free_bio;
  }

  output.assign(data, len);
  BIO_free_all(bio);
  return true;

free_bio:
  BIO_free_all(bio);
err:
  return false;
}

// Write a unsigned 32-bits integer in the memory buffer at the given byte
// offset.
void set_uint32(char * data, size_t offset, uint32_t value) {
  memcpy(&data[offset], &value, sizeof(value));
}

// Write a big number encoded in little endian order, using a maximum size of
// max_size at the given byte offset.
bool set_bn(char * data, size_t offset, BIGNUM* n, size_t max_size) {
  int count = BN_num_bytes(n);
  if ((size_t) count > max_size) {
    return false;
  }
  unsigned char bn_bytes[max_size];
  memset(bn_bytes, 0, max_size);
  BN_bn2bin(n, bn_bytes + (max_size - count));
  for(unsigned int i = 0 ; i < max_size ; i ++) {
    data[offset + max_size - 1 - i] = bn_bytes[i];
  }
  return true;
}

}  // namespace

EVP_PKEY* AndroidRSAGeneratePrivateKey() {
  RSA* rsa = NULL;
  BIGNUM* bn = NULL;
  EVP_PKEY* key = NULL;
  
  rsa = RSA_new();
  if (!rsa) {
    goto err;
  }

  bn = BN_new();
  if (!bn) {
    goto free_rsa;
  }

  if (!BN_set_word(bn, kPublicExponent)) {
    goto free_bn;
  }
  
  if (!RSA_generate_key_ex(rsa, kRSAKeyBits, bn, NULL)) {
    goto free_bn;
  }

  key = EVP_PKEY_new();
  if (!key) {
    goto free_bn;
  }

  if (!EVP_PKEY_set1_RSA(key, rsa)) {
    goto free_key;
  }
  BN_free(bn);
  RSA_free(rsa);
  return key;
  
free_key:
  EVP_PKEY_free(key);
free_bn:
  BN_free(bn);
free_rsa:
  RSA_free(rsa);
err:
  return NULL;
}

EVP_PKEY* AndroidRSAImportPrivateKey(std::string& b64_privatekey) {
  std::string decoded_key;
  char* data = NULL;
  BIO* bio = NULL;
  PKCS8_PRIV_KEY_INFO* p8inf = NULL;
  EVP_PKEY* key = NULL;
  
  decoded_key = modp_b64_decode(b64_privatekey);
  if (!decoded_key.length()) {
    goto err;
  }
  data = const_cast<char*>(decoded_key.c_str());
  bio = BIO_new_mem_buf(data, decoded_key.size());
  if (!bio) {
    goto err;
  }
  p8inf = d2i_PKCS8_PRIV_KEY_INFO_bio(bio, NULL);
  if (!p8inf) {
    goto free_bio;
  }
  key = EVP_PKCS82PKEY(p8inf);
  if (!key) {
    goto free_p8inf;
  }

  PKCS8_PRIV_KEY_INFO_free(p8inf);
  BIO_free_all(bio);
  return key;

free_p8inf:
  PKCS8_PRIV_KEY_INFO_free(p8inf);
free_bio:
  BIO_free_all(bio);
err:
  return NULL;
}

std::string AndroidRSAExportPrivateKey(EVP_PKEY* key) {
  std::string output;
  if (!ExportKey(key, i2d_PKCS8PrivateKeyInfo_bio, output)) {
    return output;
  }
  std::string encoded_key = modp_b64_encode(output);
  if (!encoded_key.length()) {
    return encoded_key;
  }
  return encoded_key;
}

namespace {
bool Sign(EVP_PKEY* key,
          const char* data,
          int data_len,
          std::string& signature) {
  RSA* rsa_key = EVP_PKEY_get1_RSA(key);
  if (!rsa_key)
    return false;
  signature.resize(RSA_size(rsa_key));

  unsigned int len = 0;
  bool success = RSA_sign(
      NID_sha1,
      reinterpret_cast<const unsigned char*>(data),
      data_len,
      reinterpret_cast<unsigned char*>(const_cast<char*>(signature.data())),
      &len,
      rsa_key);
  if (!success) {
    signature.clear();
    return false;
  }
  signature.resize(len);
  return true;
}
}

std::string AndroidRSASign(EVP_PKEY* key,
                           const std::string& body) {
  std::string output;
  if (!Sign(key, body.c_str(), body.length(), output)) {
    output.clear();
  }
  return output;
}

std::string AndroidRSAPublicKey(EVP_PKEY* key) {
  // This function will prepare the public key in a format required by ADB connection.
  // The format is the following:
  //
  // We assume the modulus bits length is always 2048 bits since it's what we
  // generate as a key.
  //
  // 4 bytes: length of RSA key in 32-bits words: 2048 / 32 = 64
  // 4 bytes: inverse = (1 / (2^32 - n % 2^32)) % 2^32
  // 4 bytes: e = public exponent
  // 2048 bits: n = public modulus
  // 2048 bits: r2 = 2^4096 % n
  RSA* rsa = NULL;
  BN_CTX* ctx = NULL;
  BIGNUM* n = NULL;
  BIGNUM* twoTo32 = NULL;
  BIGNUM* firstWord = NULL;
  BIGNUM* negated = NULL;
  BIGNUM* inverse = NULL;
  BIGNUM* r = NULL;
  BIGNUM* r2 = NULL;
  BIGNUM* e = NULL;
  char* data = NULL;
  size_t offset = 0;
  std::string result;

  rsa = EVP_PKEY_get1_RSA(key);
  if (!rsa) {
    goto err;
  }

  ctx = BN_CTX_new();
  if (ctx == NULL) {
    goto free_rsa;
  }

  // n = key public modulus
  // inverse = (1 / (2^32 - n % 2^32)) % 2^32
  n = rsa->n;
  // twoTo32 = 2^32
  twoTo32 = BN_new();
  if (twoTo32 == NULL) {
    goto free_ctx;
  }
  if (!BN_zero(twoTo32)) {
    goto free_twoTo32;
  }
  if (!BN_set_bit(twoTo32, 32)) {
    goto free_twoTo32;
  }
  // firstWord = n % twoTo32
  firstWord = BN_new();
  if (firstWord == NULL) {
    goto free_twoTo32;
  }
  if (!BN_mod(firstWord, n, twoTo32, ctx)) {
    goto free_firstWord;
  }
  // negated = 2^32 - firstWord
  negated = BN_new();
  if (!negated) {
    goto free_firstWord;
  }
  if (!BN_sub(negated, twoTo32, firstWord)) {
    goto free_negated;
  }
  // inverse = (1 / negated) % 2^32
  inverse = BN_new();
  if (!inverse) {
    goto free_negated;
  }
  if (!BN_mod_inverse(inverse, negated, twoTo32, ctx)) {
    goto free_inverse;
  }
  
  // r2 = 2^4096 % n
  // r = 2^4096
  r = BN_new();
  if (!r) {
    goto free_inverse;
  }
  if (!BN_zero(r)) {
    goto free_r;
  }
  if (!BN_set_bit(r, 4096)) {
    goto free_r;
  }
  // r2 = r % n
  r2 = BN_new();
  if (!r2) {
    goto free_r;
  }
  BN_mod(r2, r, n, ctx);
  if (!r2) {
    goto free_r2;
  }

  // Prepare buffer to be sent.
  result.resize(sizeof(uint32_t) * 3 + kRSAKeyBytes * 2);
  data = const_cast<char*>(result.data());

  offset = 0;
  set_uint32(data, offset, htole32(kRSANumWords));
  offset += sizeof(uint32_t);

  set_uint32(data, offset, htole32(BN_get_word(inverse)));
  offset += sizeof(uint32_t);

  e = rsa->e;
  set_uint32(data, offset, htole32(BN_get_word(e)));
  offset += sizeof(uint32_t);

  if (!set_bn(data, offset, n, kRSAKeyBytes)) {
    goto free_inverse;
  }
  offset += kRSAKeyBytes;

  if (!set_bn(data, offset, r2, kRSAKeyBytes)) {
    goto free_r2;
  }
  offset += kRSAKeyBytes;

  BN_free(r2);
  BN_free(r);
  BN_free(inverse);
  BN_free(negated);
  BN_free(firstWord);
  BN_free(twoTo32);
  BN_CTX_free(ctx);
  RSA_free(rsa);

  return modp_b64_encode(result);

free_r2:
  BN_free(r2);
free_r:
  BN_free(r);
free_inverse:
  BN_free(inverse);
free_negated:
  BN_free(negated);
free_firstWord:
  BN_free(firstWord);
free_twoTo32:
  BN_free(twoTo32);
free_ctx:
  BN_CTX_free(ctx);
free_rsa:
  RSA_free(rsa);
err:
  return std::string();
}

void AndroidRSARandomSeed(const std::string& unpredictable_data)
{
  RAND_seed(reinterpret_cast<const void *>(unpredictable_data.c_str()),
            unpredictable_data.length());
}

// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to manage Android RSA key generation and signature.
 */
library spark.android_rsa_cipher;

import 'dart:convert';
import 'dart:typed_data';

import 'package:bignum/bignum.dart';
import 'package:cipher/cipher.dart';
import 'package:crypto/crypto.dart' show CryptoUtils;

class AndroidRSACipher {

  // Generates a RSA key.
  static AsymmetricKeyPair generateKey(ByteData seedToken) {
    // ADB uses 2048-bit RSA keys.
    RSAKeyGeneratorParameters params = new RSAKeyGeneratorParameters(
        new BigInteger(257), 2048, 90);

    SecureRandom rnd = new SecureRandom('AES/CTR/PRNG');
    // Using the random token from the device as the seed.
    ParametersWithIV rndParams = new ParametersWithIV(
        new KeyParameter(new Uint8List.view(seedToken.buffer, 0, 16)),
        new Uint8List(16));
    rnd.seed(rndParams);

    ParametersWithRandom paramsWithRandom = new ParametersWithRandom(params,
        rnd);
    KeyGenerator gen = new KeyGenerator("RSA");
    gen.init(paramsWithRandom);
    return gen.generateKeyPair();
  }

  // Returns a signature given a data buffer and a key.
  static ByteData sign(AsymmetricKeyPair keys, ByteData data) {
    // First we create a SecureRandom, using the latter 16 bytes of
    // the token as the seed. This is to keep it from being the same
    // as the key generator seed, which would have been the first 16.
    SecureRandom rnd = new SecureRandom('AES/CTR/PRNG');
    ParametersWithIV rndParams = new ParametersWithIV(
        new KeyParameter(new Uint8List.view(data.buffer, 4, 16)),
        new Uint8List(16));
    rnd.seed(rndParams);

    // Next we prepare the Signer.
    PrivateKeyParameter<RSAPrivateKey> pkParam =
        new PrivateKeyParameter<RSAPrivateKey>(keys.privateKey);
    ParametersWithRandom params = new ParametersWithRandom(pkParam,
        rnd);
    Signer signer = new Signer("SHA-1/RSA");
    signer.init(true, params);

    // And finally create the signature.
    RSASignature sig = signer.generateSignature(new Uint8List.view(data.buffer));
    return new ByteData.view(sig.bytes.buffer);
  }

  // Return a public key in a format expected by the ADB protocol.
  static String getPublicKey(AsymmetricKeyPair keys) {
    // If we have tried the keys, then send our public key.
    // The public key consists of the following:
    // - Length of key in words (64, for 2048-bit keys), 32-bit LE.
    // - Inverse of the least-significant 32 bits of the modulus.
    // - The modulus itself, little endian.
    // - 2^4096 mod n, also little endian.
    // - The exponent, same as is used in the key generation above.
    //   (32-bit little endian).
    // Which is all Base64-encoded and has a user@host username
    // appended. That may be important, so I'll include one.

    // Why this format? I have no idea. Especially the r^2 thing,
    // which can be recomputed from the modulus.
    ByteData data = new ByteData(4 + 4 + 256 + 256 + 4);
    // First compute the little checksum that goes near the beginning.
    // It's the multiplicative inverse of the first 32 bits of the
    // modulus.
    BigInteger modulus = keys.publicKey.modulus;
    BigInteger twoTo32 = BigInteger.TWO.pow(32);
    BigInteger firstWord = modulus.mod(twoTo32);
    BigInteger negated = twoTo32 - firstWord;
    BigInteger inverse = negated.modInverse(twoTo32);

    // Write in the length, inverse, and the exponent.
    data.setUint32(0, 64, Endianness.LITTLE_ENDIAN);
    data.setUint32(4, inverse.intValue(), Endianness.LITTLE_ENDIAN);
    data.setUint32(4+4+256+256, keys.publicKey.exponent.intValue(),
        Endianness.LITTLE_ENDIAN);

    // Write the modulus. It gets returned as a byte array, but it's
    // big-endian. We want it little-endian, so we write it backwards.
    List<int> beModulus = modulus.toByteArray();
    int top = 256 + 4 + 4 - 1; // Index of the most-significant byte.
    // HACK: For some reason, the BigInteger for the modulus is 257
    // bytes long, with an extra 0 in its MSB. So we skip over it.
    // Hopefully this applies to all keys, but it could be made more
    // robust, always copying the least-significant 256 bytes from the
    // array.
    int extra = beModulus.length - 256;
    for (int i = extra; i < beModulus.length; i++) {
      data.setUint8(top - (i - extra), beModulus[i]);
    }

    // Now the weird part: computing what's called r^2.
    // This is (2^2048)^2 % modulus.
    BigInteger r2 = BigInteger.TWO.pow(4096).mod(modulus);
    List<int> ber2 = r2.toByteArray();
    top = 256 + 256 + 4 + 4 - 1; // Index of the most-significant byte.
    extra = ber2.length - 256;
    for (int i = extra; i < ber2.length; i++) {
      data.setUint8(top - (i - extra), ber2[i]);
    }

    // Convert the binary data to a Base64 String.
    return CryptoUtils.bytesToBase64(new Uint8List.view(data.buffer).toList());
  }

  // Serializes the RSA private key and public key.
  static String serializeRSAKeys(AsymmetricKeyPair keys) {
    Map<String, String> cereal = new Map<String, String>();
    cereal['p'] = keys.privateKey.p.toString(16);
    cereal['q'] = keys.privateKey.q.toString(16);
    cereal['modulus'] = keys.privateKey.modulus.toString(16);
    cereal['privateexponent'] = keys.privateKey.exponent.toString(16);
    cereal['publicexponent'] = keys.publicKey.exponent.toString(16);
    return JSON.encode(cereal);
  }

  // Unserializes the RSA private key and public key.
  static AsymmetricKeyPair deserializeRSAKeys(String json) {
    Map<String, List<int>> cereal = JSON.decode(json);
    BigInteger p = new BigInteger(cereal['p'], 16);
    BigInteger q = new BigInteger(cereal['q'], 16);
    BigInteger modulus = new BigInteger(cereal['modulus'], 16);
    BigInteger publicExponent = new BigInteger(cereal['publicexponent'], 16);
    BigInteger privateExponent = new BigInteger(cereal['privateexponent'], 16);

    RSAPublicKey public = new RSAPublicKey(modulus, publicExponent);
    RSAPrivateKey private = new RSAPrivateKey(modulus, privateExponent, p, q);
    return new AsymmetricKeyPair(public, private);
  }
}


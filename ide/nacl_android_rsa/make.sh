#!/bin/sh
NACL_SDK_URL="http://storage.googleapis.com/nativeclient-mirror/nacl/nacl_sdk/nacl_sdk.zip"
NACL_SDK_VERSION=34

if ! test -d nacl_sdk ; then
  curl -O "$NACL_SDK_URL"
  unzip nacl_sdk.zip
  cd nacl_sdk
  ./naclsdk install "pepper_$NACL_SDK_VERSION" "NACL_SDK_VERSION=$NACL_SDK_VERSION"
  cd ..
fi
make

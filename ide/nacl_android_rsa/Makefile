# Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
# All rights reserved. Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

NACL_SDK_VERSION := 34

THIS_MAKEFILE := $(abspath $(lastword $(MAKEFILE_LIST)))
CURRENT_DIR := $(patsubst %/,%,$(dir $(THIS_MAKEFILE)))
NACL_SDK_ROOT := $(CURRENT_DIR)/nacl_sdk/pepper_$(NACL_SDK_VERSION)

WARNINGS := -W -Wall
CXXFLAGS := $(WARNINGS)

GETOS := python $(NACL_SDK_ROOT)/tools/getos.py
OSHELPERS = python $(NACL_SDK_ROOT)/tools/oshelpers.py
OSNAME := $(shell $(GETOS))

PNACL_TC_PATH := $(abspath $(NACL_SDK_ROOT)/toolchain/$(OSNAME)_pnacl)
PNACL_CXX := $(PNACL_TC_PATH)/bin/pnacl-clang++
PNACL_FINALIZE := $(PNACL_TC_PATH)/bin/pnacl-finalize
CXXFLAGS += -I$(NACL_SDK_ROOT)/include -Ideps/openssl/include
LDFLAGS := -L$(NACL_SDK_ROOT)/lib/pnacl/Release -lppapi_cpp -lppapi -Ldeps/openssl/lib -lcrypto

all: nacl_android_rsa.pexe

.cc.o:
	$(PNACL_CXX) -c -o $@ $< -O2 $(CXXFLAGS)

nacl_android_rsa.bc: module.o instance.o android_rsa.o modp_b64.o endian.o
	$(PNACL_CXX) -o $@ $^ $(LDFLAGS)

nacl_android_rsa.pexe: nacl_android_rsa.bc
	$(PNACL_FINALIZE) -o $@ $<

distclean: clean
	rm -rf nacl_sdk
	rm -f nacl_sdk.zip

clean:
	rm -f nacl_android_rsa.pexe nacl_android_rsa.bc *.o

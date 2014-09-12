// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "endian.h"

enum {
  O32_LITTLE_ENDIAN = 0x03020100UL,
  O32_BIG_ENDIAN = 0x00010203UL,
  O32_PDP_ENDIAN = 0x01000302UL
};

static const union {
  unsigned char bytes[4];
  uint32_t value;
} o32_host_order = {{0, 1, 2, 3}};

#define O32_HOST_ORDER (o32_host_order.value)
#define IS_LITTLE_ENDIAN (O32_HOST_ORDER == O32_LITTLE_ENDIAN)

namespace {

// Swap endianness of a 32-bits integer.
uint32_t swap_uint32(uint32_t val) {
  val = ((val << 8) & 0xFF00FF00) | ((val >> 8) & 0xFF00FF);
  return (val << 16) | (val >> 16);
}

}

uint32_t htole32(uint32_t val) {
  return IS_LITTLE_ENDIAN ? val : swap_uint32(val);
}

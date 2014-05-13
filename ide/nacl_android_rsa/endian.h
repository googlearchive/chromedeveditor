// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef ENDIAN_H

#define ENDIAN_H

#include <stdint.h>

// Encodes a 32-bits integer in little endian.
uint32_t htole32(uint32_t val);

#endif

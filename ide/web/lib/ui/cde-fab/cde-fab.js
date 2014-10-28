// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

Polymer('cde-fab', {
  handleClick: function(e) {
    if (this.command) {
      e.stopPropagation();
      this.fire('command', {command: this.command});
    }
  }
});

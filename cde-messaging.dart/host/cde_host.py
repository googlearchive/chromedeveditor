#!/usr/bin/env python
# Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
# All rights reserved. Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Chrome Dev Editor native messaging host

import struct
import sys
import json
from subprocess import Popen, PIPE
import shlex

# Function to launch Dartium
def launch_dartium(path, url):
  cmd = shlex.split('%s %s' % (path, url))
  try:
    p = Popen(cmd, stdout=PIPE, stderr=PIPE)
    out, err = p.communicate()
    if p.returncode != 0:
      send_message('{"error": "%s"}' % out.rstrip())
      send_message('{"error": "%s"}' % err.rstrip())
    else:
      send_message('{"result": "dartium launched"}')
  except OSError, e:
    send_message('{"error": "%s"}' % e.strerror)
  
# Helper function that sends a message to the webapp.
def send_message(message):
   # Write message size.
  sys.stdout.write(struct.pack('I', len(message)))
  # Write the message itself.
  sys.stdout.write(message)
  sys.stdout.flush()

# Thread that reads messages from the webapp.
def read_thread_func():
  while 1:
    # Read the message length (first 4 bytes).
    text_length_bytes = sys.stdin.read(4)
    if len(text_length_bytes) == 0:
      sys.exit(0)

    # Unpack message length as 4 byte integer.
    text_length = struct.unpack('i', text_length_bytes)[0]

    # Read the text (JSON object) of the message.
    text = sys.stdin.read(text_length).decode('utf-8')
    # cde is sending json encoded twice
    json_text = json.loads(json.loads(text))
    if 'action' in json_text:
      value = json_text['action']
      if value == 'dartium':
        path_string = json_text['path']
        lpath = path_string.lower()
        if lpath.endswith("chromium") or lpath.endswith("chrome"):
          launch_dartium(path_string, json_text['url'])

def Main():
    read_thread_func()
    sys.exit(0)

if __name__ == '__main__':
  Main()

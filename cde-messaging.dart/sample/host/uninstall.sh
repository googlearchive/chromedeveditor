#!/bin/bash
# Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
# All rights reserved. Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -e

if [ $(uname -s) == 'Darwin' ]; then
  if [ "$(whoami)" == "root" ]; then
    TARGET_DIR="/Library/Google/Chrome/NativeMessagingHosts"
    TARGET_DIR_CHROMIUM="/Library/Chromium/NativeMessagingHosts"
   else
    TARGET_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
    TARGET_DIR_CHROMIUM="$HOME/Library/Application Support/Chromium/NativeMessagingHosts"
  fi
else
  if [ "$(whoami)" == "root" ]; then
    TARGET_DIR="/etc/opt/chrome/native-messaging-hosts"
    TARGET_DIR_CHROMIUM="/etc/opt/chromium/native-messaging-hosts"
  else
    TARGET_DIR='$HOME/.config/google-chrome/NativeMessagingHosts'
    TARGET_DIR_CHROMIUM="$HOME/.config/chromium/NativeMessagingHosts"
  fi
fi

HOST_NAME=$1
rm "$TARGET_DIR/$1.json"
rm "$TARGET_DIR_CHROMIUM/$1.json"
echo Native messaging host $HOST_NAME has been uninstalled.

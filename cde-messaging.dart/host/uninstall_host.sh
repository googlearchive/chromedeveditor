#!/bin/sh
# Copyright 2013 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

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

HOST_NAME=com.google.chrome.example.dart
rm "$TARGET_DIR/com.google.chrome.example.dart.json"
rm "$TARGET_DIR_CHROMIUM/com.google.chrome.example.dart.json"
echo Native messaging host $HOST_NAME has been uninstalled.

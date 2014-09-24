#!/bin/bash
# Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
# All rights reserved. Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

set -e

DIR="$( cd "$( dirname "$0" )" && pwd )"
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
    TARGET_DIR="$HOME/.config/google-chrome/NativeMessagingHosts"
    TARGET_DIR_CHROMIUM="$HOME/.config/chromium/NativeMessagingHosts"
  fi
fi

HOST_NAME=$1

register_host() {
  # Create directory to store native messaging host.
  mkdir -p "$1"
  
  # Copy native messaging host manifest.
  cp "$DIR/$HOST_NAME.json" "$1"
  
  # Update host path in the manifest.
  HOST_PATH="$DIR/native-messaging-example-host"
  ESCAPED_HOST_PATH="${HOST_PATH////\\/}"
  sed -i -e "s/HOST_PATH/$ESCAPED_HOST_PATH/" "$1/$HOST_NAME.json"
  
  # Set permissions for the manifest so that all users can read it.
  chmod o+r "$1/$HOST_NAME.json"
}

register_host "$TARGET_DIR"
register_host "$TARGET_DIR_CHROMIUM"

echo Native messaging host $HOST_NAME has been installed for Chrome and Chromium.

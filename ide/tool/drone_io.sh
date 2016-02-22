# Install zip and start a virtual frame buffer.

if [ "$DRONE" = "true" ]; then
  sudo apt-get -y -q install zip
  sudo apt-get -y -q install libappindicator1
  curl -O https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo dpkg -i google-chrome-stable_current_amd64.deb
  sudo start xvfb
  export HAS_DARTIUM=true
fi

set -o errexit

# Display installed versions.
dart --version
/usr/bin/google-chrome --version

# Get our packages.
pub get

# Build the archive.
if test x$DRONE_REPO_SLUG = xgithub.com/dart-lang/spark -o x$FORCE_NIGHTLY = xyes ; then
  # Retrieve configuration from the master branch
  curl -o tool/release-config.json \
      https://raw.githubusercontent.com/dart-lang/chromedeveditor/master/ide/tool/release-config.json
  ./grind release-nightly
else
  ./grind deploy
fi

./grind mode-test

# Turn on fast fail for the bash script.
set -e

# Run tests on the Dart version of the app.
if [ "$HAS_DARTIUM" = "true" ]; then
  dart tool/test_runner.dart --dartium
fi

# Run tests on the dart2js version of the app.
if [ "$DRONE" = "true" ]; then
  dart tool/test_runner.dart --chrome-dev
else
  dart tool/test_runner.dart --chrome
fi

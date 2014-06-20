# Install zip and start a virtual frame buffer.
if [ "$DRONE" = "true" ]; then
  sudo apt-get -y -q install zip
  curl -O https://dl.google.com/linux/direct/google-chrome-unstable_current_amd64.deb
  sudo dpkg -i google-chrome-unstable_current_amd64.deb
  sudo start xvfb
  export HAS_DARTIUM=true
fi

# Display installed versions.
dart --version
/usr/bin/google-chrome --version

# Get our packages.
pub get

# Build the archive.
if test \( x$DRONE_REPO_SLUG = xgithub.com/dart-lang/spark -a x$DRONE_BRANCH = xmaster \) \
    -o x$FORCE_NIGHTLY = xyes ; then
  ./grind release-nightly
else
  ./grind archive
fi

./grind mode-test

# Run tests the Dart version of the app.
if [ "$HAS_DARTIUM" = "true" ]; then
  dart tool/test_runner.dart --dartium
fi

# Run tests on the dart2js version of the app.
if [ "$DRONE" = "true" ]; then
  dart tool/test_runner.dart --chrome-dev --appPath=build/deploy-out/web
else
  dart tool/test_runner.dart --chrome
fi

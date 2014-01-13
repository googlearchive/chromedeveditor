# Install zip and start a virtual frame buffer.
if [ "$DRONE" = "true" ]; then
  sudo apt-get -y -q install zip
  sudo start xvfb
fi

# Setup the build environment.
pub get 

# Build the archive.
if test x$DRONE_BRANCH = xmaster -o x$FORCE_NIGHTLY = xyes ; then
  ./grind release-nightly
else
  ./grind archive
fi

# Disable polymer deploy on drone.io for now.
#./grind deploy-test

./grind mode-test

# Run tests on dartium.
dart tool/test_runner.dart --dartium

# Run tests on chrome.
if [ "$DRONE" = "true" ]; then
  # Show the version of Chrome installed on drone.io.
  /usr/bin/google-chrome --version
fi
dart tool/test_runner.dart --chrome

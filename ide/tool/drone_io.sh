# Install zip and start a virtual frame buffer.
if [ "$DRONE" = "true" ]; then
  sudo apt-get -y -q install zip
  sudo start xvfb
fi

# Setup the build environment.
pub get 

# Build the archive.
if test x$DRONE_BRANCH = xmaster ; then
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
dart tool/test_runner.dart --chrome

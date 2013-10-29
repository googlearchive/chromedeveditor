# install zip and start a virtual frame buffer
sudo apt-get -y -q install zip
sudo start xvfb

# setup the build environment
pub install
./grind setup          

# run tests
./grind deploy-test
dart tool/test_runner.dart --dartium

# build the archive
./grind archive

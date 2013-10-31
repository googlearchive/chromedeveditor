# install zip and start a virtual frame buffer
sudo apt-get -y -q install zip
sudo start xvfb

# setup the build environment
pub install
./grind setup          

# build the archive
./grind archive

./grind deploy-test

# run tests on dartium
dart tool/test_runner.dart --dartium

# run tests on chrome
#dart tool/test_runner.dart --chrome

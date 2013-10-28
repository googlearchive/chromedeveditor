sudo apt-get -y -q install zip
sudo start xvfb

pub install
./grind setup          

# run tests
./grind mode-test
dart tool/test_runner.dart --dartium

./grind archive

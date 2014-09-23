#! /bin/bash

# Update git submodules
git submodule init
git submodule update

# Set up the android environment
source tools/android/setup.sh

function run_tests() {
  ./run-tests.sh \
    -b Remote \
    --remote-executor http://localhost:9515 \
    --remote-caps="chromeOptions=androidPackage=$CHROME_APP" \
    --load-list load-list.txt \
    --verbose || exit 1
}

# We split the test runs into two groups to avoid running out of memory in Travis.
echo "^[a].*" > load-list.txt
run_tests
echo "^[^a].*" > load-list.txt
run_tests

echo "Run $ANDROID_DIR/stop.sh if finished."

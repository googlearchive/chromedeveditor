# Spark

A Chrome app based development environment.

[![Build Status](https://drone.io/github.com/dart-lang/spark/status.png)](https://drone.io/github.com/dart-lang/spark/latest)

### Entry Point
The main entry point to the chrome app is `app/manifest.json`. It calls defines
the background script for the application (`app/background.js`). This script
gets invoked when the application starts. It open a new window with the contents
set to the `app/spark.html` file. This file it turn runs `app/spark.dart`.

### Packages
Chrome apps do not like symlinks. There's a chrome bug about this, but for now
symlinks are right out. We use pub and a pubspec.yaml to provision our
package dependencies. We then physically copy all the packages into the
app/packages directory. This is not a normal symlinked pub directory but has the
same layout as one.

Run:

    ./grind packages

to copy library code from packages/ to app/packages/.

### Lib
All the Dart code for the application (modulo the spark.dart entry point)
lives in the `app/lib` directory.

### Output
The output from dart2js lives in the app/ directory (`app/spark.dart.js`). To
re-compile the dart code to javascript, run:

    ./grind compile

### Tests
All the tests live in app/test. These are standard dart unit tests. Generally,
one library under test == 1 test file, and they should all be referenced from
`all.dart`.

In order to run the tests, we modify the html entry-point slightly to point to
`app/spark_test.dart`. This source file references the entire spark app as
well as the unit tests for the app.

Run `./grind mode-test` to switch the app over to including tests, and
`./grind mode-notest` to switch it back before commit.

Ideally, the application might include it's own tests. There's currently an
issue with the compiled javascript size if we do that however. It's still a work
in progress to make it easier to run the tests, and to get them running in a
continuous integration environment.

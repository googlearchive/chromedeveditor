# Spark

A Chrome App-based development environment.

[![Build Status](https://drone.io/github.com/dart-lang/spark/status.png)](https://drone.io/github.com/dart-lang/spark/latest)

### Requirements
Dart IDE needs to be installed and `dart/dart-sdk/bin` needs to be accessible
from `$PATH`. In addition, you should set a `DART_SDK` environment variable
and point it to `your/path/to/dart-sdk`.

You **need** to enable experimental Web Platform features in Chrome. From 
`chrome://flags`, enable `#enable-experimental-web-platform-features`.

### Entry Point
The main entry point to the Chrome App is `app/manifest.json`. It defines
the background script for the application (`app/background.js`). This script
gets invoked when the application starts. It opens a new window with the contents
set to the `app/spark.html` file. This file in turn runs `app/spark.dart`.

### Dependencies
Dependencies needs to be fetched first, using [pub](http://pub.dartlang.org).
Run:

    pub get

### Packages
Chrome apps do not like symlinks. There's a Chrome bug about this, but for now
symlinks are right out. We use pub and a pubspec.yaml to provision our
package dependencies. We then physically copy all the packages into the
app/packages directory. This is not a normal symlinked pub directory but has the
same layout as one.

Run:

    ./grind setup

to copy library code from packages/ to app/packages/. This step also copies the 
`dart:` code from the Dart SDK into the `app/sdk` directory.

### Lib
All the Dart code for the application (modulo the spark.dart entry point)
lives in the `app/lib` directory.

### API Documentation

Documentation for the Spark APIs is available [here](http://dart-lang.github.io/spark/docs/spark.html).

### Tests
All the tests live in app/test. These are standard Dart unit tests. Generally,
one library under test == 1 test file, and they should all be referenced from
`all.dart`.

In order to run the tests, we modify the HTML entry point slightly to point to
`app/spark_test.dart`. This source file references the entire Spark app as
well as the unit tests for the app.

Run

    ./grind mode-test

to switch the app over to including tests (the default mode).

More about the testing story [here](https://github.com/dart-lang/spark/wiki/Testing).

### Contributing
Contributions welcome! Please see our
[contributing](https://github.com/dart-lang/spark/wiki/Contributing) page.

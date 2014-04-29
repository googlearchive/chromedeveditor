# Spark

A Chrome App-based development environment.

[![Build Status](https://drone.io/github.com/dart-lang/spark/status.png)](https://drone.io/github.com/dart-lang/spark/latest)

### Requirements
Dart IDE needs to be installed and `dart/dart-sdk/bin` needs to be accessible
from `$PATH`. In addition, you should set a `DART_SDK` environment variable
and point it to `your/path/to/dart-sdk`.

We're currently developing against the weekly development release of the Dart
SDK.

You **need** to enable experimental Web Platform features in Chrome. From 
`chrome://flags`, enable `#enable-experimental-web-platform-features`.

### Entry Point
The main entry point to the Chrome App is `app/manifest.json`. It defines
the background script for the application (`app/background.js`). This script
gets invoked when the application starts. It opens a new window with the 
contents set to the `app/spark_polymer.html` file. This file in turn runs
`app/spark_polymer.dart`.

### Dependencies
Dependencies need to be fetched first, using [pub](http://pub.dartlang.org).
Run:

    pub get

### Packages
Chrome apps do not like symlinks. We use pub and a pubspec.yaml to provision our
package dependencies, but we then physically copy all the packages into the
app/packages directory. This is not a normal symlinked pub directory but has the
same layout as one.

Run:

    ./grind setup

to copy library code from packages/ to app/packages/.

### Lib
All the Dart code for the application (modulo the `spark_polymer.*` entry point
and `spark_polymer_ui.*` top-level UI) lives in the `app/lib` directory.

### Tests
All the tests live in app/test. These are standard Dart unit tests. Generally,
one library under test == 1 test file, and they should all be referenced from
`all.dart`.

Run

    ./grind mode-test

to switch the app over to including tests (the default mode).

More about the testing story [here](https://github.com/dart-lang/spark/wiki/Testing).

### Getting Code, Development and Contributing
Contributions are welcome! See [our Wiki](https://github.com/dart-lang/spark/wiki/)
for details on how to get the code, run, debug and build Spark, and contribute
the code back.

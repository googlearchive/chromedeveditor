# Spark

A Chrome app based development environment.

[![Build Status](https://drone.io/github.com/dart-lang/spark/status.png)](https://drone.io/github.com/dart-lang/spark/latest)

### Requirements
Dart IDE needs to be installed and `dart/dart-sdk/bin` needs to be accessible
from `$PATH`. You **need** to enable experimental Web Platform features in Chrome.
From `chrome://flags`, enable `#enable-experimental-web-platform-features`.

When you initially check the source out, in the Editor, right-click on the `app/sdk`
directory, and choose "Don't Analyze". This directory will contain the source code
for the `dart:` libraries. We don't want the Editor to analyze them as this will
be a significant overhead.

### Entry Point
The main entry point to the chrome app is `app/manifest.json`. It calls defines
the background script for the application (`app/background.js`). This script
gets invoked when the application starts. It open a new window with the contents
set to the `app/spark.html` file. This file it turn runs `app/spark.dart`.

### Dependencies
Dependencies need first to be fetched using [pub](http://pub.dartlang.org).
Run:

    pub install

### Packages
Chrome apps do not like symlinks. There's a chrome bug about this, but for now
symlinks are right out. We use pub and a pubspec.yaml to provision our
package dependencies. We then physically copy all the packages into the
app/packages directory. This is not a normal symlinked pub directory but has the
same layout as one.

Run:

    ./grind packages

to copy library code from packages/ to app/packages/.

### The Dart SDK
We copy the `dart:` code from the Dart SDK into the `app/sdk` directory. There
is a build step for this; run:

    ./grind sdk

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

Run

    ./grind mode-test

to switch the app over to including tests, and

    ./grind mode-notest

to switch it back before commit.

Ideally, the application might include it's own tests. There's currently an
issue with the compiled javascript size if we do that however. More about the
testing story [here](https://github.com/dart-lang/spark/wiki/Testing).

### Contributing
Contributions welcome! Please see our
[contributing](https://github.com/dart-lang/spark/wiki/Contributing) page.

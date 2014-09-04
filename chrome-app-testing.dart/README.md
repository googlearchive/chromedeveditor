# chrome_testing

This package contains a test harness for testing Chrome Apps. Specifically, it
contains a command line tool and an in-process library for Chrome Apps.

## How it works

A command line tool (`bin/chrome_testing.dart`) starts a test listener on port
5120. That tool then starts a Chrome (or Dartium) process which runs the chrome
app under test. This chrome app invokes the in-process test driver
(`TestDriver`). That driver connects to port 5120, runs the unit tests, and
pipes all the test results to the test listener via that port.

When the tests complete, the test driver closes the app window. The test
listener waits for the tests to complete or for a timeout. It then kills the
launched Chrome process, writes all the test results to stdout, and exits the
process with either a 0 or 1 exit code, depending on the test success or
failure.

## An example

The command line test runner and listener can be found in
`bin/chrome_testing.dart`. An example Chrome App which which runs unit tests
can be found in the `example/` directory.

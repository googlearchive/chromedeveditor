# chrome_testing

This package contains a test harness for testing chrome apps. Specifically, it
contains a command line tool and an in-process library for chrome apps.

The command line tool (`bin/chrome_testing.dart`) starts a test listener on port
5120. It then starts a Chrome (or Dartium) process which runs the chrome app
under test. This chrome app invokes the in-process testing agent. That agent
connects to port 5120, runs the unit tests, and pipes all the test results to
the test listener via that port.

When the tests complete, the test agent closes the app window. The test listener
waits for the tests to complete (or for a timeout). It then kills the launched
Chrome process, writes all the test results to stdout, and exits the process
with either a 0 or 1 exit code, depending on the test success or failure.

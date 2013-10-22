// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.app_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../lib/app.dart';

// TODO: test that adding a participant after start() has been called, calls
// the lifecycle methods of that participant.

main() {
  group('app', () {
    test('application fires start events', () {
      TestApplication app = new TestApplication();
      LifecycleParticipantMock mock = new LifecycleParticipantMock();
      app.addParticipant(mock);
      app.start().then((_) {
        expect(mock.startingCalled, true);
        expect(mock.startedCalled, true);
        expect(mock.closingCalled, false);
        expect(mock.closedCalled, false);
        expect(app.state, LifecycleState.STARTED);
      });
    });

    test('application fires close events', () {
      TestApplication app = new TestApplication();
      LifecycleParticipantMock mock = new LifecycleParticipantMock();
      app.addParticipant(mock);
      app.start().then((_) {
        return app.close();
      }).then((_) {
        expect(mock.startingCalled, true);
        expect(mock.startedCalled, true);
        expect(mock.closingCalled, true);
        expect(mock.closedCalled, true);
        expect(app.state, LifecycleState.CLOSED);
      });
    });

    test('calling the start method twice is bad', () {
      TestApplication app = new TestApplication();
      app.start();
      try {
        app.start();
        expect(false, true, reason: 'expected start() to throw');
      } on StateError catch (ex) {
        expect(true, true);
      }
    });
  });
}

class TestApplication extends Application {

}

class LifecycleParticipantMock extends LifecycleParticipant {
  bool startingCalled = false;
  bool startedCalled = false;
  bool closingCalled = false;
  bool closedCalled = false;

  Future applicationStarting(Application application) {
    startingCalled = true;
    return null;
  }

  Future applicationStarted(Application application) {
    startedCalled = true;
    return null;
  }

  Future applicationClosing(Application application) {
    closingCalled = true;
    return null;
  }

  Future applicationClosed(Application application) {
    closedCalled = true;
    return null;
  }
}

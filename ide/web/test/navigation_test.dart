// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.navigation_test;

import 'dart:async';

import 'package:unittest/unittest.dart';

import '../lib/files_mock.dart';
import '../lib/preferences.dart';
import '../lib/navigation.dart';
import '../lib/workspace.dart';

defineTests() {
  group('navigation', () {
    test('canNavigate', () {
      NavigationManager manager =
          new NavigationManager(new MockNavigationLocationProvider());
      expect(manager.canGoForward(), false);
      expect(manager.canGoBack(), false);

      manager.gotoLocation(_mockLocation());
      expect(manager.canGoForward(), false);
      expect(manager.canGoBack(), false);

      manager.gotoLocation(_mockLocation());
      expect(manager.canGoForward(), false);
      expect(manager.canGoBack(), true);
    });

    test('navigate', () {
      NavigationManager manager =
          new NavigationManager(new MockNavigationLocationProvider());
      Future f = manager.onNavigate.take(2).toList();
      manager.gotoLocation(_mockLocation());
      manager.gotoLocation(_mockLocation());
      expect(manager.canGoBack(), true);
      manager.goBack();
      expect(manager.canGoBack(), false);
      manager.goForward();
      expect(manager.canGoBack(), true);
      return f.then((List l) {
        expect(l.length, 2);
      });
    });

    test('location', () {
      NavigationManager manager =
          new NavigationManager(new MockNavigationLocationProvider());
      expect(manager.backLocation, isNull);

      manager.gotoLocation(_mockLocation());
      expect(manager.canGoBack(), false);
      expect(manager.backLocation, isNull);
      expect(manager.currentLocation, isNotNull);
      expect(manager.forwardLocation, isNull);

      manager.gotoLocation(_mockLocation());
      expect(manager.canGoForward(), false);
      expect(manager.canGoBack(), true);
      expect(manager.backLocation, isNotNull);
      expect(manager.currentLocation, isNotNull);
      expect(manager.forwardLocation, isNull);

      manager.goBack();
      expect(manager.backLocation, isNull);
      expect(manager.currentLocation, isNotNull);
      expect(manager.forwardLocation, isNotNull);
    });

    test('remove files in random order', () {
      MockNavigationLocationProviderWithFiles locationProvider = new MockNavigationLocationProviderWithFiles();
      NavigationManager manager = new NavigationManager(locationProvider);
      MockFileSystem fs = new MockFileSystem();

      Workspace workspace = new Workspace(new MapPreferencesStore());
      FileEntry fileEntry1 = fs.createFile('test1.txt', contents: 'foobar');
      FileEntry fileEntry2 = fs.createFile('test2.txt', contents: 'foobar');
      FileEntry fileEntry3 = fs.createFile('test3.txt', contents: 'foobar');
      FileEntry fileEntry4 = fs.createFile('test4.txt', contents: 'foobar');

      NavigationLocation nav1 = _mockLocationWithFile(new File(workspace, fileEntry1));
      NavigationLocation nav2 = _mockLocationWithFile(new File(workspace, fileEntry2));
      NavigationLocation nav3 = _mockLocationWithFile(new File(workspace, fileEntry3));
      NavigationLocation nav4 = _mockLocationWithFile(new File(workspace, fileEntry4));

      expect(manager.backLocation, isNull);
      expect(manager.forwardLocation, isNull);
      manager.gotoLocation(nav1);
      locationProvider.navigationLocation = nav1;
      manager.gotoLocation(nav2);
      locationProvider.navigationLocation = nav2;
      manager.gotoLocation(nav3);
      locationProvider.navigationLocation = nav3;
      manager.gotoLocation(nav4);
      locationProvider.navigationLocation = nav4;
      expect(manager.forwardLocation, isNull);
      expect(manager.backLocation, isNotNull);
      manager.removeFile(nav4.file);
      expect(manager.currentLocation, nav3);
      manager.removeFile(nav2.file);
      expect(manager.currentLocation, nav3);
      manager.removeFile(nav1.file);
      expect(manager.currentLocation, nav3);
      manager.removeFile(nav3.file);
      expect(manager.currentLocation, isNull);
    });

    test('remove files after some history navigation', () {
      MockNavigationLocationProviderWithFiles locationProvider = new MockNavigationLocationProviderWithFiles();
      NavigationManager manager = new NavigationManager(locationProvider);
      MockFileSystem fs = new MockFileSystem();

      Workspace workspace = new Workspace(new MapPreferencesStore());
      FileEntry fileEntry1 = fs.createFile('test1.txt', contents: 'foobar');
      FileEntry fileEntry2 = fs.createFile('test2.txt', contents: 'foobar');
      FileEntry fileEntry3 = fs.createFile('test3.txt', contents: 'foobar');
      FileEntry fileEntry4 = fs.createFile('test4.txt', contents: 'foobar');

      NavigationLocation nav1 = _mockLocationWithFile(new File(workspace, fileEntry1));
      NavigationLocation nav2 = _mockLocationWithFile(new File(workspace, fileEntry2));
      NavigationLocation nav3 = _mockLocationWithFile(new File(workspace, fileEntry3));
      NavigationLocation nav4 = _mockLocationWithFile(new File(workspace, fileEntry4));

      manager.gotoLocation(nav1);
      locationProvider.navigationLocation = nav1;
      manager.gotoLocation(nav2);
      locationProvider.navigationLocation = nav2;
      manager.gotoLocation(nav3);
      locationProvider.navigationLocation = nav3;
      manager.gotoLocation(nav4);
      locationProvider.navigationLocation = nav4;
      manager.removeFile(nav4.file);
      expect(manager.currentLocation, nav3);
      locationProvider.navigationLocation = nav3;
      manager.goBack();
      manager.removeFile(nav2.file);
      expect(manager.currentLocation, nav1);
      locationProvider.navigationLocation = nav1;
      manager.goForward();
      manager.removeFile(nav3.file);
      expect(manager.currentLocation, nav1);
      locationProvider.navigationLocation = nav1;
      manager.removeFile(nav1.file);
      expect(manager.currentLocation, isNull);
    });

    test('remove files after navigation', () {
      MockNavigationLocationProviderWithFiles locationProvider = new MockNavigationLocationProviderWithFiles();
      NavigationManager manager = new NavigationManager(locationProvider);
      MockFileSystem fs = new MockFileSystem();

      Workspace workspace = new Workspace(new MapPreferencesStore());
      FileEntry fileEntry1 = fs.createFile('test1.txt', contents: 'foobar');
      FileEntry fileEntry2 = fs.createFile('test2.txt', contents: 'foobar');
      FileEntry fileEntry3 = fs.createFile('test3.txt', contents: 'foobar');
      FileEntry fileEntry4 = fs.createFile('test4.txt', contents: 'foobar');

      NavigationLocation nav1 = _mockLocationWithFile(new File(workspace, fileEntry1));
      NavigationLocation nav2 = _mockLocationWithFile(new File(workspace, fileEntry2));
      NavigationLocation nav3 = _mockLocationWithFile(new File(workspace, fileEntry3));
      NavigationLocation nav4 = _mockLocationWithFile(new File(workspace, fileEntry4));
      locationProvider.navigationLocation = null;
      manager.gotoLocation(nav1);
      locationProvider.navigationLocation = nav1;
      manager.gotoLocation(nav2);
      locationProvider.navigationLocation = nav2;
      manager.gotoLocation(nav3);
      locationProvider.navigationLocation = nav3;
      manager.gotoLocation(nav4);
      locationProvider.navigationLocation = nav4;
      manager.gotoLocation(nav3);
      locationProvider.navigationLocation = nav3;
      manager.gotoLocation(nav4);
      locationProvider.navigationLocation = nav4;
      manager.gotoLocation(nav3);
      locationProvider.navigationLocation = nav3;
      manager.gotoLocation(nav4);
      locationProvider.navigationLocation = nav4;
      manager.gotoLocation(nav3);
      locationProvider.navigationLocation = nav3;
      manager.gotoLocation(nav4);
      locationProvider.navigationLocation = nav4;
      manager.goBack();
      expect(manager.backLocation.file, nav4.file);
      expect(manager.forwardLocation.file, nav4.file);
      manager.removeFile(nav3.file);
      expect(manager.currentLocation.file, nav4.file);
      expect(manager.backLocation.file, nav2.file);
    });

    test('remove file and check for duplication in history', () {
      MockNavigationLocationProviderWithFiles locationProvider = new MockNavigationLocationProviderWithFiles();
      NavigationManager manager = new NavigationManager(locationProvider);
      MockFileSystem fs = new MockFileSystem();

      Workspace workspace = new Workspace(new MapPreferencesStore());
      FileEntry fileEntry1 = fs.createFile('test1.txt', contents: 'foobar');
      FileEntry fileEntry2 = fs.createFile('test2.txt', contents: 'foobar');
      FileEntry fileEntry3 = fs.createFile('test3.txt', contents: 'foobar');
      FileEntry fileEntry4 = fs.createFile('test4.txt', contents: 'foobar');

      NavigationLocation nav1 = _mockLocationWithFile(new File(workspace, fileEntry1));
      NavigationLocation nav2 = _mockLocationWithFile(new File(workspace, fileEntry2));
      NavigationLocation nav3 = _mockLocationWithFile(new File(workspace, fileEntry3));
      NavigationLocation nav4 = _mockLocationWithFile(new File(workspace, fileEntry4));

      locationProvider.navigationLocation = null;
      manager.gotoLocation(nav1);
      locationProvider.navigationLocation = nav1;
      manager.gotoLocation(nav2);
      locationProvider.navigationLocation = nav2;
      manager.gotoLocation(nav3);
      locationProvider.navigationLocation = nav3;
      manager.gotoLocation(nav4);
      locationProvider.navigationLocation = nav4;
      manager.gotoLocation(nav3);
      locationProvider.navigationLocation = nav3;
      manager.gotoLocation(nav4);
      locationProvider.navigationLocation = nav4;
      manager.gotoLocation(nav3);
      locationProvider.navigationLocation = nav3;
      manager.gotoLocation(nav4);
      locationProvider.navigationLocation = nav4;
      manager.gotoLocation(nav3);
      locationProvider.navigationLocation = nav3;
      manager.gotoLocation(nav4);
      locationProvider.navigationLocation = nav4;
      manager.removeFile(nav1.file);
      expect(manager.currentLocation.file, nav4.file);
      manager.removeFile(nav2.file);
      expect(manager.currentLocation.file, nav4.file);
      manager.removeFile(nav4.file);
      expect(manager.currentLocation.file, nav3.file);
      expect(manager.canGoBack(), false);
      expect(manager.canGoForward(), false);
    });
  });
}

int navigationOffset = 0;

NavigationLocation _mockLocation() {
  return new NavigationLocation(null, new Span(navigationOffset++, 0));
}

NavigationLocation _mockLocationWithFile(File mockFile) {
  return new NavigationLocation(mockFile, new Span(navigationOffset++, 0));
}

class MockNavigationLocationProvider implements NavigationLocationProvider {
  bool first = true;

  NavigationLocation get navigationLocation {
    if (first) {
      first = false;
      return null;
    } else {
      return _mockLocation();
    }
  }
}

class MockNavigationLocationProviderWithFiles implements NavigationLocationProvider {
  NavigationLocation navigationLocation = null;
}

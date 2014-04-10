// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.pub_test;

import 'package:unittest/unittest.dart';

import 'files_mock.dart';
import '../lib/package_mgmt/package_manager.dart';
import '../lib/package_mgmt/pub.dart';
import '../lib/workspace.dart';

defineTests() {
  group('pub', () {
    Project project;
    PubManager pubManager;

    setUp(() {
      Workspace workspace = new Workspace();
      DirectoryEntry dir = _createSampleDirectory();
      return workspace.link(createWsRoot(dir)).then((Project _project) {
        project = _project;
        pubManager = new PubManager(workspace);
        return project.createNewFile('pubspec.yaml');
      }).then((File file) {
        return file.setContents('name: sample\nversion: 0.1.0\n');
      }).then((_) {
        return project.workspace.builderManager.waitForAllBuilds();
      });
    });

    test('isPackageRef', () {
      expect(pubManager.props.isPackageRef('package'), false);
      expect(pubManager.props.isPackageRef('package:'), true);
      expect(pubManager.props.isPackageRef('package:foo/bar.dart'), true);
      expect(pubManager.props.isPackageRef('dart:html'), false);
    });

    test('PubManager isPubProject', () {
      expect(pubManager.props.isProjectWithPackages(project), true);
      return project.getChild('pubspec.yaml').delete().then((_) {
        expect(pubManager.props.isProjectWithPackages(project), false);
      });
    });

    // TODO: This test fails intermittently when compiled to JS - investigate.
//    test('PubManager syntax error', () {
//      expect(project.getMarkers().length, 0);
//      File pubspec = project.getChild(PUBSPEC_FILE_NAME);
//      return pubspec.setContents('name: sample:\nversion: 0.1.0\n').then((_) {
//        return new Future.delayed(new Duration(milliseconds: 100));
//      }).then((_) {
//        return project.workspace.builderManager.waitForAllBuilds();
//      }).then((_) {
//        expect(project.getMarkers().length, 1);
//      });
//    });

    test('PubResolver resolveRefToFile', () {
      PackageResolver resolver = pubManager.getResolverFor(project);

      expect(resolver.resolveRefToFile('package:sample/sample.dart'), isNotNull);
      expect(resolver.resolveRefToFile('package:foo/foo.dart'), isNotNull);

      expect(resolver.resolveRefToFile('package:sample/foo.dart'), isNull);
      expect(resolver.resolveRefToFile('package:lib/foo.dart'), isNull);
    });

    test('PubResolver getReferenceFor', () {
      PackageResolver resolver = pubManager.getResolverFor(project);

      expect(resolver.getReferenceFor(project.getChildPath('lib/sample.dart')),
          'package:sample/sample.dart');
      expect(resolver.getReferenceFor(project.getChildPath('packages/foo/foo.dart')),
          'package:foo/foo.dart');

      expect(resolver.getReferenceFor(project.getChildPath('web/index.html')), null);
      expect(resolver.getReferenceFor(project.getChildPath('bar.txt')), null);
    });
  });
}

DirectoryEntry _createSampleDirectory([String projectName = 'sample_project']) {
  MockFileSystem fs = new MockFileSystem();
  DirectoryEntry project = fs.createDirectory(projectName);
  fs.createFile('${projectName}/bar.txt');
  fs.createFile('${projectName}/packages/foo/foo.dart', contents: 'foo() { }');
  fs.createFile('${projectName}/lib/sample.dart', contents: 'sample() { }');
  fs.createFile('${projectName}/web/index.html');
  fs.createFile('${projectName}/web/sample.css');
  return project;
}

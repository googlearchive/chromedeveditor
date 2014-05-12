// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library test.spark_button;

import 'dart:async' as async;
import 'dart:html' as dom;

import 'package:polymer/polymer.dart' as polymer;
import 'package:unittest/unittest.dart';
import 'package:unittest/html_enhanced_config.dart';

import 'package:spark_widgets/spark_button/spark_button.dart';

@polymer.initMethod
void main() {
  useHtmlEnhancedConfiguration();

  polymer.Polymer.onReady.then((e) {

    group('spark-button', () {
      test('default click', () {
        var btn = (dom.document.querySelector('#default') as SparkButton);
        expect(btn, isNotNull);

        async.StreamSubscription clickSubsrc;

        var clicked = expectAsync((dom.Event event) {
          expect(event.target, equals(btn));
          clickSubsrc.cancel();
        });
        clickSubsrc = btn.onClick.listen(clicked);
        btn.click();
      });

      test('attributes', () {
        var btn = (dom.document.querySelector('#default') as SparkButton);
        expect(btn, isNotNull);

        btn.attributes['primary'] = 'true';
        btn.attributes['active'] = 'true';
        btn.attributes['large'] = 'true';
        btn.attributes['small'] = 'false';
        btn.attributes['noPadding'] = 'true';

        var done = expectAsync((){});

        new async.Future.delayed(new Duration(milliseconds: 50),() {
          expect(btn.classes.contains('btn-primary'), isTrue);
          expect(btn.classes.contains('btn-default'), isFalse);
          expect(btn.classes.contains('enabled'), isTrue);
          expect(btn.classes.contains('disabled'), isFalse);
          expect(btn.classes.contains('btn-lg'), isTrue);
          expect(btn.classes.contains('btn-sm'), isFalse);
          expect(btn.noPadding, isTrue);
          expect(btn.getShadowDomElement('#button').getComputedStyle().padding,
                 equals('0px'));

          btn.attributes['primary'] = 'false';
          btn.attributes['active'] = 'false';
          btn.attributes['large'] = 'false';
          btn.attributes['small'] = 'true';
          btn.attributes['noPadding'] = 'false';

          new async.Future.delayed(new Duration(milliseconds: 550), () {
            expect(btn.classes.contains('btn-primary'), isFalse);
            expect(btn.classes.contains('btn-default'), isTrue);
            expect(btn.classes.contains('enabled'), isFalse);
            expect(btn.classes.contains('disabled'), isTrue);
            expect(btn.classes.contains('btn-lg'), isFalse);
            expect(btn.classes.contains('btn-sm'), isTrue);
            expect(btn.noPadding, isFalse);
            expect(btn.getShadowDomElement('#button').getComputedStyle().padding,
                   isNot(equals('10px')));
            done();
          });
        });
      });
    });
  });
}

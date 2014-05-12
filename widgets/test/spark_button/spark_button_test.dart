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
        final SparkButton btn = dom.document.querySelector('#default');
        expect(btn, isNotNull);

        async.StreamSubscription clickSubsrc;

        final clicked = expectAsync((dom.Event event) {
          expect(event.target, equals(btn));
          clickSubsrc.cancel();
        });
        clickSubsrc = btn.onClick.listen(clicked);
        btn.click();
      });

      test('attributes', () {
        // TODO(ussuri): Add similar tests for statically declared attributes
        // (e.g. <spark-button primary large noPadding></>).
        final SparkButton btnElt = dom.document.querySelector('#default');
        expect(btnElt, isNotNull);
        final btn = btnElt.getShadowDomElement('#button');
        expect(btn, isNotNull);

        final Function done = expectAsync((){});

        btnElt
            ..primary = true
            ..large = true
            ..small = false
            ..noPadding = true
            ..active = true
            ..enabled = true
            ..deliverChanges();

        expect(btn.classes.contains('btn-primary'), isTrue);
        expect(btn.classes.contains('btn-default'), isFalse);
        expect(btn.classes.contains('active'), isTrue);
        expect(btn.classes.contains('enabled'), isTrue);
        expect(btn.classes.contains('disabled'), isFalse);
        expect(btn.classes.contains('btn-lg'), isTrue);
        expect(btn.classes.contains('btn-sm'), isFalse);
        expect(btn.getComputedStyle().padding, equals('0px'));

        btnElt
            ..primary = false
            ..large = false
            ..small = true
            ..noPadding = false
            ..active = false
            ..enabled = false
            ..deliverChanges();

        expect(btn.classes.contains('btn-primary'), isFalse);
        expect(btn.classes.contains('btn-default'), isTrue);
        expect(btn.classes.contains('active'), isFalse);
        expect(btn.classes.contains('enabled'), isFalse);
        expect(btn.classes.contains('disabled'), isTrue);
        expect(btn.classes.contains('btn-lg'), isFalse);
        expect(btn.classes.contains('btn-sm'), isTrue);
        expect(btn.getComputedStyle().padding, isNot(equals('0px')));

        done();
      });
    });
  });
}

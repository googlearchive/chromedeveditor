// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark_widgets.button;

import 'dart:html';

import 'package:polymer/polymer.dart';

import '../../../scm.dart';

@CustomTag('spark-button')
class CommitMessageView extends PolymerElement {
  @published CommitInfo commitInfo;

  factory CommitMessageView() => (new Element.tag('commit-message-view')) as CommitMessageView;

  CommitMessageView.created() : super.created();
}

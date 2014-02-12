// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.polymer.commit_message_view;

import 'dart:html';

import 'package:polymer/polymer.dart';
import 'package:spark_widgets/common/spark_widget.dart';

import '../../../scm.dart';

@CustomTag('commit-message-view')
class CommitMessageView extends SparkWidget {
  @observable CommitInfo commitInfo;

  factory CommitMessageView() => new Element.tag('commit-message-view');

  CommitMessageView.created() : super.created();
}

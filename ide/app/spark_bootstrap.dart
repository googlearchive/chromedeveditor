// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * This script initializes Spark when run in a non-deployed build.
 */
library spark_bootstrap;

import 'package:polymer/polymer.dart';
import 'package:spark_widgets/common/spark_widget.dart' as i0;
import 'package:spark_widgets/spark_button/spark_button.dart' as i1;
import 'package:spark_widgets/spark_overlay/spark_overlay.dart' as i2;
import 'package:spark_widgets/spark_selection/spark_selection.dart' as i3;
import 'package:spark_widgets/spark_selector/spark_selector.dart' as i4;
import 'package:spark_widgets/spark_menu/spark_menu.dart' as i5;
import 'package:spark_widgets/spark_menu_button/spark_menu_button.dart' as i6;
import 'package:spark_widgets/spark_icon/spark_icon.dart' as i7;
import 'package:spark_widgets/spark_menu_item/spark_menu_item.dart' as i8;
import 'package:spark_widgets/spark_menu_separator/spark_menu_separator.dart' as i9;
import 'package:spark_widgets/spark_modal/spark_modal.dart' as i10;
import 'package:spark_widgets/spark_splitter/spark_splitter.dart' as i11;
import 'package:spark_widgets/spark_split_view/spark_split_view.dart' as i12;
import 'package:spark_widgets/spark_status/spark_status.dart' as i13;
import 'package:spark_widgets/spark_suggest_box/spark_suggest_box.dart' as i14;
import 'package:spark_widgets/spark_toolbar/spark_toolbar.dart' as i15;

import 'lib/utils.dart';
import 'lib/ui/polymer/commit_message_view/commit_message_view.dart' as i16;
import 'spark_polymer_ui.dart' as i17;
import 'spark_polymer.dart' as i18;

void main() {
  if (isDart2js()) return;

  startPolymer([], false);

  // Register polymer components.
  Polymer.register('spark-widget', i0.SparkWidget);
  Polymer.register('spark-button', i1.SparkButton);
  Polymer.register('spark-overlay', i2.SparkOverlay);
  Polymer.register('spark-selection', i3.SparkSelection);
  Polymer.register('spark-selector', i4.SparkSelector);
  Polymer.register('spark-menu', i5.SparkMenu);
  Polymer.register('spark-menu-button', i6.SparkMenuButton);
  Polymer.register('spark-icon', i7.SparkIcon);
  Polymer.register('spark-menu-item', i8.SparkMenuItem);
  Polymer.register('spark-menu-separator', i9.SparkMenuSeparator);
  Polymer.register('spark-modal', i10.SparkModal);
  Polymer.register('spark-splitter', i11.SparkSplitter);
  Polymer.register('spark-split-view', i12.SparkSplitView);
  Polymer.register('spark-status', i13.SparkStatus);
  Polymer.register('spark-suggest-box', i14.SparkSuggestBox);
  Polymer.register('spark-toolbar', i15.SparkToolbar);
  Polymer.register('commit-message-view', i16.CommitMessageView);
  Polymer.register('spark-polymer-ui', i17.SparkPolymerUI);

  // Invoke Spark's main method.
  i18.main();
}

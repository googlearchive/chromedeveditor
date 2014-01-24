// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.ui.widgets.tabview;

import 'dart:html';
import 'dart:async';

class TabBeforeCloseEvent {
  final Tab tab;
  TabBeforeCloseEvent(this.tab);
  bool _canceled = false;
  void cancel() { _canceled = true; }
}

class Tab {
  /// Parent [TabView]
  final TabView tabView;
  Element _page;

  DivElement _label;
  DivElement _labelCaption;
  ButtonElement _closeButton;
  DivElement _pageContainer;

  Tab(this.tabView, {Element page: null, bool closable: true}) {
    _label = new DivElement()..classes.add('tabview-tablabel');
    _label.onClick.listen((e) {
      select(forceFocus: true);
      e.stopPropagation();
      e.preventDefault();
    });

    _labelCaption = new DivElement()..classes.add('tabview-tablabel-caption');

    _closeButton = new ButtonElement()
        ..classes.add('tabview-tablabel-closebutton')
        ..classes.add('close')
        ..type = 'button';
    _closeButton.appendHtml('&times;');
    _closeButton.onClick.listen((e) {
      tabView.remove(this);
      e.stopPropagation();
      e.preventDefault();
    });
    _label.children.addAll([_labelCaption, _closeButton]);
    _pageContainer = new DivElement()..classes.add('tabview-page-container');

    this.closable = closable;
    this.page = page;
  }

  String get label => _labelCaption.innerHtml;
  set label(String label) {
    _labelCaption.innerHtml = label;
    _labelCaption.title = _labelCaption.text;
  }
  CssStyleDeclaration get labelStyle => _labelCaption.style;
  ElementEvents get labelEvents => _labelCaption.on;

  bool get closable => _label.classes.contains('tabview-tablabel-closable');
  set closable(bool closable) =>
      _label.classes.toggle('tabview-tablabel-closable', closable);

  Stream<Tab> get onClose =>
      tabView._onCloseStreamController.stream.where((t) => t == this);
  Stream<TabBeforeCloseEvent> get onBeforeClose =>
      tabView._onBeforeCloseStreamController.stream.where((t) => t.tab == this);
  Stream<Tab> get onSelected =>
      tabView._onSelectedStreamController.stream.where((t) => t == this);

  Element get page => _page;
  set page(Element value)  {
    if (value == _page) return;
    if (_page != null) _page.remove();
    _page = value;
    if (value != null) _pageContainer.append(value);
  }

  void deactivate() {
    _pageContainer.classes.remove('tabview-page-container-active');
    _label.classes.remove('tabview-tablabel-active');
  }

  void activate() {
    validatePage();
    _pageContainer.classes.add('tabview-page-container-active');
    _label.classes.add('tabview-tablabel-active');
    tabView.scrollIntoView(this);
  }

  void select({bool forceFocus}) {
    tabView.selectedTab = this;

    if (forceFocus) focus();
  }

  void focus() => _pageContainer.focus();

  bool close() => tabView.remove(this);

  void validatePage() {
    if (_page != null && _page.parent != _pageContainer)
      _pageContainer.append(_page);
  }

  void _cleanup() {
    _pageContainer.remove();
    _label.remove();
  }
}

class TabView {
  static const int SCROLL_MARGIN = 7;

  final Element parentElement;
  DivElement _tabViewContainer;
  DivElement _tabBar;
  DivElement _tabBarScroller;
  DivElement _tabBarScrollable;
  DivElement _tabViewWorkspace;

  StreamController<Tab> _onCloseStreamController =
      new StreamController<Tab>.broadcast(sync: true);
  StreamController<TabBeforeCloseEvent> _onBeforeCloseStreamController =
      new StreamController<TabBeforeCloseEvent>.broadcast(sync: true);
  StreamController<Tab> _onSelectedStreamController =
      new StreamController<Tab>.broadcast(sync: true);

  final List<Tab> tabs = new List<Tab>();
  Tab _selectedTab;

  TabView(this.parentElement) {
    List<Element> originalElements = parentElement.children.toList();

    _tabBar = new DivElement()..classes.add('tabview-tabbar');
    _tabBarScroller = new DivElement()
        ..classes.add('tabview-tabbar-scroller');
    _tabBarScroller.onMouseWheel.listen((WheelEvent e) {
      if (_tabBarScroller.clientWidth < _tabBarScroller.scrollWidth) {
        e.preventDefault();
        e.stopPropagation();
        _tabBarScroller.scrollLeft +=  e.deltaX.round();
      }
    });
    _tabBarScrollable = new DivElement()
        ..classes.add('tabview-tabbar-scrollable');
    _tabBarScroller.children.add(_tabBarScrollable);

    _tabBar.children.add(_tabBarScroller);
    _tabViewWorkspace = new DivElement()..classes.add('tabview-workspace');
    _tabViewContainer = new DivElement()..classes.add('tabview-container');
    _tabViewContainer.children.addAll([_tabBar, _tabViewWorkspace]);

    parentElement.children.clear();
    parentElement.children.add(_tabViewContainer);

    originalElements.forEach((Element element){
      Tab tab = add(new Tab(this, page: element));
      if (element.attributes['data-title'] != null) {
        tab.label = element.attributes['data-title'];
      }
    });
  }

  Tab get selectedTab => _selectedTab;
  void set selectedTab(Tab tab) {
    if (_selectedTab == tab) return;
    if (_selectedTab != null) _selectedTab.deactivate();
    _selectedTab = tab;
    if (tab != null) tab.activate();
    _onSelectedStreamController.add(tab);
  }

  bool get showLabelBar => !_tabBar.classes.contains('tabview-tabbar-hidden');
  set showLabelBar(bool showLabelBar) =>
      _tabBar.classes.toggle('tabview-tabbar-hidden', !showLabelBar);

  Tab add(Tab tab, {bool switchesTab: true}) {
    tabs.add(tab);
    _tabViewWorkspace.children.add(tab._pageContainer);
    _tabBarScrollable.children.add(tab._label);
    if (switchesTab) {
      selectedTab = tab;
    }
    return tab;
  }

  Tab replace(Tab tabToReplace, Tab tab, {bool switchesTab: true}) {
    if (tabToReplace == null) {
      add(tab, switchesTab: switchesTab);
    } else {
      int index = tabs.indexOf(tabToReplace);
      remove(tabToReplace, switchesTab: false);
      tabs.insert(index, tab);
      _tabViewWorkspace.children.insert(index, tab._pageContainer);
      _tabBarScrollable.children.insert(index, tab._label);
      if (switchesTab) {
        selectedTab = tab;
      }
    }
    return tab;
  }

  void scrollIntoView(Tab tab) {
    var label = tab._label;
    var scroller = _tabBarScroller;
      if (label.offsetWidth + label.offsetLeft > scroller.offsetWidth +
          scroller.scrollLeft - scroller.offsetLeft - SCROLL_MARGIN) {
        scroller.scrollLeft = label.offsetWidth + label.offsetLeft -
            scroller.offsetWidth + scroller.offsetLeft + SCROLL_MARGIN;
      } else if (label.offsetLeft < scroller.scrollLeft + SCROLL_MARGIN) {
        scroller.scrollLeft = label.offsetLeft - SCROLL_MARGIN;
      }
  }

  bool remove(Tab tab, {bool switchesTab: true}) {
    if (tab._label.parent == null) return false;
    var beforeCloseEvent = new TabBeforeCloseEvent(tab);
    _onBeforeCloseStreamController.add(beforeCloseEvent);
    if (beforeCloseEvent._canceled) return false;

    tab._cleanup();
    int index = tabs.indexOf(tab);
    tabs.removeAt(index);

    if (selectedTab == tab) {
      if (switchesTab && tabs.length > index) {
        selectedTab = tabs[index];
      } else if (switchesTab && tabs.length > 0) {
        selectedTab = tabs.last;
      } else {
        _selectedTab = null;
      }
    }

    if (_selectedTab != null) _selectedTab.validatePage();

    _onCloseStreamController.add(tab);
    return true;
  }

  void gotoPreviousTab() {
    if (tabs.length < 2) return;
    int index = tabs.indexOf(selectedTab);
    if (index == 0) index = tabs.length;
    selectedTab = tabs[index - 1];
  }

  void gotoNextTab() {
    if (tabs.length < 2) return;
    int index = tabs.indexOf(selectedTab);
    if (index == tabs.length - 1) index = -1;
    selectedTab = tabs[index + 1];
  }

  Stream<Tab> get onClose => _onCloseStreamController.stream;
  Stream<TabBeforeCloseEvent> get onBeforeClose =>
      _onBeforeCloseStreamController.stream;
  Stream<Tab> get onSelected => _onSelectedStreamController.stream;
}
